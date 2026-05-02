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

    print('PlanningRepository: getDayPlan for $dateStr');

    // Try to sync pending tasks before fetching
    await syncPendingTasks();

    // 1. Try to Fetch from API
    DayPlan? plan;
    try {
      print('PlanningRepository: Fetching from API $baseUrl/plan/$dateStr');
      final response = await http.get(
        Uri.parse('$baseUrl/plan/$dateStr'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('PlanningRepository: API Response Status: ${response.statusCode}');

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

        // Update Local Store
        await box.put(dateStr, plan);
      } else {
        print('PlanningRepository: API Error: ${response.body}');
      }
    } catch (e) {
      print('PlanningRepository: Network error: $e');
    }
    
    // 2. Fallback to Local Cache for THIS date
    if (plan == null) {
      plan = box.get(dateStr);
      if (plan != null) {
        print('PlanningRepository: Using cached plan for $dateStr');
      }
    }

    // 3. Create a minimal plan shell if still null (to allow merging pending tasks)
    if (plan == null) {
      print('PlanningRepository: Creating empty plan shell for $dateStr');
      plan = DayPlan(
        date: dateStr,
        prayerTimes: {},
        sections: {
          'fajr': [],
          'dhuhr': [],
          'asr': [],
          'maghrib': [],
          'isha': [],
        },
        updatedAt: DateTime.now(),
      );
    }

    // 4. Merge Pending Tasks into the plan
    final pendingBox = await Hive.openBox<Task>(pendingTasksBoxName);
    final pendingTasks = pendingBox.values.where((t) => 
      t.dueDate.toIso8601String().split('T')[0] == plan!.date
    ).toList();

    print('PlanningRepository: Merging ${pendingTasks.length} pending tasks');

    for (var task in pendingTasks) {
      final section = plan.sections[task.prayerAnchor] ?? [];
      // Check if task already exists (by title and anchor if no ID)
      if (!section.any((t) => t.title == task.title)) {
        section.add(task);
        plan.sections[task.prayerAnchor] = section;
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

    print('PlanningRepository: createTask $taskData');

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

      print('PlanningRepository: createTask API Response Status: ${response.statusCode}');

      if (response.statusCode == 201 || response.statusCode == 210) {
        final data = jsonDecode(response.body)['data'];
        final task = Task.fromJson(data);
        
        final box = await Hive.openBox<DayPlan>(planBoxName);
        await box.delete(dueDate.toIso8601String().split('T')[0]);
        
        print('PlanningRepository: Task created successfully on server: ${task.id}');
        return task;
      } else {
        print('PlanningRepository: createTask API Error: ${response.body}');
      }
    } catch (e) {
      print('PlanningRepository: createTask Network error: $e');
    }

    // Offline or Error: Save to pending tasks
    print('PlanningRepository: Saving task to pending queue locally');
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

    print('PlanningRepository: Syncing ${pendingBox.length} pending tasks...');
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

        print('PlanningRepository: syncPendingTasks [${task.title}] Status: ${response.statusCode}');

        if (response.statusCode == 201 || response.statusCode == 210) {
          await pendingBox.deleteAt(0); 
          print('PlanningRepository: Synced task: ${task.title}');
        } else {
          print('PlanningRepository: Sync failed for ${task.title}: ${response.body}');
          break; // Stop syncing if server error
        }
      } catch (e) {
        print('PlanningRepository: Sync network error for ${task.title}: $e');
        break; // Stop syncing if network error
      }
    }
  }
}
