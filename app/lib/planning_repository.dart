import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'models.dart';

class PlanningRepository {
  static const String baseUrl = 'http://localhost:8000/api/v1';
  static const String planBoxName = 'dayPlanBox';

  final String? authToken;

  PlanningRepository({this.authToken});

  Future<DayPlan?> getDayPlan(DateTime date) async {
    final dateStr = date.toIso8601String().split('T')[0];
    final box = await Hive.openBox<DayPlan>(planBoxName);

    // 1. Check Local Cache
    final cachedPlan = box.get(dateStr);
    print('Cached plan for $dateStr: ${cachedPlan != null ? "Found" : "Not Found"}');
    
    if (cachedPlan != null && !cachedPlan.isStale()) {
      print('Using fresh cached plan');
      return cachedPlan;
    }

    // 2. Fetch from API if stale or empty
    try {
      print('Fetching from API: $baseUrl/plan/$dateStr');
      final response = await http.get(
        Uri.parse('$baseUrl/plan/$dateStr'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Accept': 'application/json',
        },
      );

      print('API Response Code: ${response.statusCode}');
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        print('API Data: ${jsonResponse['success']}');
        final data = jsonResponse['data'];

        final Map<String, dynamic> sectionsJson = data['sections'] ?? {};
        final Map<String, List<Task>> sections = {};
        
        sectionsJson.forEach((key, value) {
          if (value is List) {
            sections[key] = value.map((t) => Task.fromJson(t)).toList();
          } else {
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
      // If API fails, return cached even if stale
      if (cachedPlan != null) return cachedPlan;
      rethrow;
    }
    
    return cachedPlan;
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
        // Clear cache for today to force refresh
        final box = await Hive.openBox<DayPlan>(planBoxName);
        await box.delete(DateTime.now().toIso8601String().split('T')[0]);
        return true;
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  Future<bool> toggleTask(int taskId, DateTime dueDate) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/tasks/$taskId/toggle'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // Invalidate cache for that date
        final box = await Hive.openBox<DayPlan>(planBoxName);
        await box.delete(dueDate.toIso8601String().split('T')[0]);
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
        
        // Invalidate cache for that date
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
