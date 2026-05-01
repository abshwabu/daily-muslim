import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'models.dart';

class PlanningRepository {
  static const String baseUrl = 'http://localhost:8000/api/v1';
  static const String planBoxName = 'dayPlanBox';
  static const String templateBoxName = 'taskTemplateBox';
  static const String pendingTasksBoxName = 'pendingTasksBox';

  final String? authToken;

  PlanningRepository({this.authToken});

  Future<DayPlan?> getDayPlan(DateTime date) async {
    final dateStr = date.toIso8601String().split('T')[0];
    final box = await Hive.openBox<DayPlan>(planBoxName);

    // Try to sync pending tasks before fetching
    await syncPendingTasks();

    // 1. Check Local Cache
    DayPlan? plan = box.get(dateStr);
    
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

        plan = DayPlan(
          date: dateStr,
          prayerTimes: data['prayer_times'] ?? {},
          sections: sections,
          updatedAt: DateTime.now(),
        );

        // 3. Update Local Store
        await box.put(dateStr, plan);
      }
    } catch (e) {
      print('Network error in getDayPlan: $e');
    }
    
    // Fallback: Use most recent cache if plan is still null
    if (plan == null && box.isNotEmpty) {
      final plans = box.values.toList();
      plans.sort((a, b) => b.date.compareTo(a.date));
      plan = plans.first;
    }

    // 4. Merge Pending Tasks into the plan
    if (plan != null) {
      final pendingBox = await Hive.openBox<Task>(pendingTasksBoxName);
      final pendingTasks = pendingBox.values.where((t) => 
        t.dueDate.toIso8601String().split('T')[0] == plan!.date
      ).toList();

      for (var task in pendingTasks) {
        final section = plan.sections[task.prayerAnchor] ?? [];
        // Check if task already exists (by title and anchor if no ID)
        if (!section.any((t) => t.title == task.title)) {
          section.add(task);
          plan.sections[task.prayerAnchor] = section;
        }
      }
    }
    
    return plan;
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
        if (task.id == null) {
          // Task is pending, just toggle locally
          final box = await Hive.openBox<Task>(pendingTasksBoxName);
          if (task.key != null) {
            final updatedTask = Task(
              title: task.title,
              prayerAnchor: task.prayerAnchor,
              dueDate: task.dueDate,
              isCompleted: !(task.isCompleted ?? false),
              isHighPriority: task.isHighPriority,
            );
            await box.put(task.key, updatedTask);
            return true;
          }
          return false;
        }
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
    final taskData = {
      'title': title,
      'prayer_anchor': prayerAnchor,
      'due_date': dueDate.toIso8601String().split('T')[0],
      'is_high_priority': isHighPriority,
    };

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tasks'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(taskData),
      );

      if (response.statusCode == 201 || response.statusCode == 210) {
        final data = jsonDecode(response.body)['data'];
        final task = Task.fromJson(data);
        
        final box = await Hive.openBox<DayPlan>(planBoxName);
        await box.delete(dueDate.toIso8601String().split('T')[0]);
        
        return task;
      }
    } catch (e) {
      print('Offline: Saving task to pending queue');
    }

    // Offline or Error: Save to pending tasks
    final pendingTask = Task(
      title: title,
      prayerAnchor: prayerAnchor,
      dueDate: dueDate,
      isHighPriority: isHighPriority,
      isCompleted: false,
    );

    final pendingBox = await Hive.openBox<Task>(pendingTasksBoxName);
    await pendingBox.add(pendingTask);

    return pendingTask;
  }

  Future<void> syncPendingTasks() async {
    final pendingBox = await Hive.openBox<Task>(pendingTasksBoxName);
    if (pendingBox.isEmpty) return;

    print('Syncing ${pendingBox.length} pending tasks...');
    final tasks = List<Task>.from(pendingBox.values);
    
    for (int i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/tasks'),
          headers: {
            'Authorization': 'Bearer $authToken',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'title': task.title,
            'prayer_anchor': task.prayerAnchor,
            'due_date': task.dueDate.toIso8601String().split('T')[0],
            'is_high_priority': task.isHighPriority,
            'is_completed': task.isCompleted,
          }),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 201 || response.statusCode == 210) {
          await pendingBox.deleteAt(0); // Delete the first one as we are iterating a copy
          print('Synced task: ${task.title}');
        }
      } catch (e) {
        print('Failed to sync task: ${task.title}. Error: $e');
        break; // Stop syncing if network error
      }
    }
  }
}
