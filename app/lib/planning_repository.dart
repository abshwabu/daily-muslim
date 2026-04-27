import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'models.dart';

class PlanningRepository {
  static const String baseUrl = 'http://localhost:8000/api/v1';
  static const String planBoxName = 'dayPlanBox';
  static const String templateBoxName = 'taskTemplateBox';

  final String? authToken;

  PlanningRepository({this.authToken});

  Future<DayPlan?> getDayPlan(DateTime date) async {
    final dateStr = date.toIso8601String().split('T')[0];
    final box = await Hive.openBox<DayPlan>(planBoxName);

    // 1. Check Local Cache
    final cachedPlan = box.get(dateStr);
    
    // If we have a fresh cached plan, return it
    if (cachedPlan != null && !cachedPlan.isStale()) {
      return cachedPlan;
    }

    // 2. Fetch from API if stale or empty
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/plan/$dateStr'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final data = jsonResponse['data'];

        final Map<String, dynamic> sectionsJson = data['sections'] ?? {};
        final Map<String, List<Task>> sections = {};
        
        sectionsJson.forEach((key, value) {
          try {
            if (value is List) {
              sections[key] = value.map((t) => Task.fromJson(t)).toList();
            } else {
              sections[key] = [];
            }
          } catch (e) {
            sections[key] = [];
          }
        });

        final newPlan = DayPlan(
          date: dateStr,
          prayerTimes: data['prayer_times'] ?? {},
          sections: sections,
          updatedAt: DateTime.now(),
        );

        // 3. Update Local Store
        await box.put(dateStr, newPlan);
        return newPlan;
      }
    } catch (e) {
      print('Network error in getDayPlan: $e');
    }
    
    // Fallback: Use exact date cache even if stale
    if (cachedPlan != null) return cachedPlan;

    // Last Resort: Use the most recent plan available in cache
    if (box.isNotEmpty) {
      final plans = box.values.toList();
      plans.sort((a, b) => b.date.compareTo(a.date));
      return plans.first;
    }
    
    return null;
  }

  Future<List<TaskTemplate>> getTaskTemplates() async {
    final box = await Hive.openBox<TaskTemplate>(templateBoxName);
    
    // Check if we have templates and they are not too old (7 days)
    final settingsBox = await Hive.openBox('settings');
    final lastUpdateStr = settingsBox.get('templates_last_update');
    if (lastUpdateStr != null) {
      final lastUpdate = DateTime.parse(lastUpdateStr);
      if (DateTime.now().difference(lastUpdate).inDays < 7 && box.isNotEmpty) {
        return box.values.toList();
      }
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/templates'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body)['data'];
        final templates = data.map((t) => TaskTemplate.fromJson(t)).toList();

        await box.clear();
        await box.addAll(templates);
        final settingsBox = await Hive.openBox('settings');
        await settingsBox.put('templates_last_update', DateTime.now().toIso8601String());

        return templates;
      }
    } catch (e) {
      if (box.isNotEmpty) return box.values.toList();
    }
    return [];
  }

  Future<bool> rolloverTasks() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tasks/rollover'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final box = await Hive.openBox<DayPlan>(planBoxName);
        await box.delete(DateTime.now().toIso8601String().split('T')[0]);
        return true;
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  Future<bool> toggleTask(Task task) async {
    try {
      final String url;
      final Map<String, dynamic>? body;
      final String method;

      if (task.isTemplate ?? false) {
        url = '$baseUrl/tasks/template/toggle';
        method = 'POST';
        body = {
          'template_id': task.templateId,
          'date': task.dueDate.toIso8601String().split('T')[0],
        };
      } else {
        url = '$baseUrl/tasks/${task.id}/toggle';
        method = 'PATCH';
        body = null;
      }

      final http.Response response;
      if (method == 'POST') {
        response = await http.post(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(body),
        );
      } else {
        response = await http.patch(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $authToken',
            'Accept': 'application/json',
          },
        );
      }

      if (response.statusCode == 200) {
        final box = await Hive.openBox<DayPlan>(planBoxName);
        await box.delete(task.dueDate.toIso8601String().split('T')[0]);
        return true;
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  Future<Task?> createTask(String title, String prayerAnchor, DateTime dueDate, {bool isHighPriority = false}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tasks'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'title': title,
          'prayer_anchor': prayerAnchor,
          'due_date': dueDate.toIso8601String().split('T')[0],
          'is_high_priority': isHighPriority,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 210) {
        final data = jsonDecode(response.body)['data'];
        final task = Task.fromJson(data);
        
        final box = await Hive.openBox<DayPlan>(planBoxName);
        await box.delete(dueDate.toIso8601String().split('T')[0]);
        
        return task;
      }
    } catch (e) {
      return null;
    }
    return null;
  }
}
