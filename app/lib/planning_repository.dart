import 'package:hive/hive.dart';
import 'models.dart';
import 'api_service.dart';
import 'prayer_service.dart';

class PlanningRepository {
  static const String planBoxName = 'dayPlanBox';
  static const String templateBoxName = 'taskTemplateBox';

  PlanningRepository({String? authToken});

  Future<DayPlan?> getDayPlan(DateTime date) async {
    final dateStr = date.toIso8601String().split('T')[0];
    final box = await Hive.openBox<DayPlan>(planBoxName);

    // Calculate prayer times offline for target date
    final prayerResult = await ApiService.getPrayerTimes(date: date);
    Map<String, dynamic> prayerTimes = {};
    if (prayerResult['success'] && prayerResult['data']?['data']?['timings'] != null) {
      prayerTimes = Map<String, dynamic>.from(prayerResult['data']['data']['timings']);
    }

    DayPlan? plan = box.get(dateStr);

    if (plan == null) {
      plan = DayPlan(
        date: dateStr,
        prayerTimes: prayerTimes,
        sections: {
          'fajr': [],
          'dhuhr': [],
          'asr': [],
          'maghrib': [],
          'isha': [],
        },
        updatedAt: DateTime.now(),
      );
      await box.put(dateStr, plan);
    } else {
      // Update prayer times if updated
      if (prayerTimes.isNotEmpty) {
        plan = DayPlan(
          date: plan.date,
          prayerTimes: prayerTimes,
          sections: plan.sections,
          updatedAt: DateTime.now(),
        );
        await box.put(dateStr, plan);
      }
    }

    return plan;
  }

  Future<List<TaskTemplate>> getTaskTemplates() async {
    final box = await Hive.openBox<TaskTemplate>(templateBoxName);
    if (box.isEmpty) {
      final defaultTemplates = [
        TaskTemplate(id: 1, title: 'Morning Adhkar & Surah Yasin', category: 'Spiritual', prayerAnchor: 'fajr', description: 'Begin the day in remembrance'),
        TaskTemplate(id: 2, title: 'Quran Recitation (1 Juz)', category: 'Quran', prayerAnchor: 'dhuhr', description: 'Daily Quran reading goal'),
        TaskTemplate(id: 3, title: 'Evening Adhkar', category: 'Spiritual', prayerAnchor: 'asr', description: 'Protective dhikr before sunset'),
        TaskTemplate(id: 4, title: 'Family Reflection & Gratitude', category: 'Family', prayerAnchor: 'maghrib', description: 'Gather with loved ones'),
        TaskTemplate(id: 5, title: 'Night Prayer & Witr', category: 'Spiritual', prayerAnchor: 'isha', description: 'Seal the day with prayer'),
      ];
      await box.addAll(defaultTemplates);
    }
    return box.values.toList();
  }

  Future<bool> rolloverTasks() async {
    final now = DateTime.now();
    final todayStr = now.toIso8601String().split('T')[0];
    final yesterdayStr = now.subtract(const Duration(days: 1)).toIso8601String().split('T')[0];

    final box = await Hive.openBox<DayPlan>(planBoxName);
    final yesterdayPlan = box.get(yesterdayStr);
    if (yesterdayPlan == null) return false;

    final todayPlan = await getDayPlan(now);
    if (todayPlan == null) return false;

    bool modified = false;
    yesterdayPlan.sections.forEach((anchor, tasks) {
      for (var task in tasks) {
        if (task.isCompleted != true) {
          final existing = todayPlan.sections[anchor] ?? [];
          if (!existing.any((t) => t.title == task.title)) {
            existing.add(Task(
              id: DateTime.now().millisecondsSinceEpoch,
              title: task.title,
              prayerAnchor: anchor,
              dueDate: now,
              isCompleted: false,
              isHighPriority: task.isHighPriority,
              description: task.description,
              category: task.category,
            ));
            todayPlan.sections[anchor] = existing;
            modified = true;
          }
        }
      }
    });

    if (modified) {
      await box.put(todayStr, todayPlan);
    }
    return true;
  }

  Future<bool> toggleTask(Task task) async {
    final dateStr = task.dueDate.toIso8601String().split('T')[0];
    final box = await Hive.openBox<DayPlan>(planBoxName);
    final plan = box.get(dateStr);
    if (plan == null) return false;

    final sectionTasks = plan.sections[task.prayerAnchor];
    if (sectionTasks == null) return false;

    for (int i = 0; i < sectionTasks.length; i++) {
      if (sectionTasks[i].title == task.title || (task.id != null && sectionTasks[i].id == task.id)) {
        final current = sectionTasks[i];
        sectionTasks[i] = Task(
          id: current.id,
          title: current.title,
          prayerAnchor: current.prayerAnchor,
          dueDate: current.dueDate,
          isCompleted: !(current.isCompleted ?? false),
          isHighPriority: current.isHighPriority,
          templateId: current.templateId,
          description: current.description,
          category: current.category,
          isTemplate: current.isTemplate,
        );
        break;
      }
    }

    final updatedPlan = DayPlan(
      date: plan.date,
      prayerTimes: plan.prayerTimes,
      sections: plan.sections,
      updatedAt: DateTime.now(),
    );

    await box.put(dateStr, updatedPlan);
    return true;
  }

  Future<Task?> createTask(String title, DateTime dueDate, {bool isHighPriority = false, String? category}) async {
    final dateStr = dueDate.toIso8601String().split('T')[0];
    final box = await Hive.openBox<DayPlan>(planBoxName);

    DayPlan? plan = box.get(dateStr);
    plan ??= await getDayPlan(dueDate);

    final prayerAnchor = PrayerTimeValidation.determinePrayerAnchor(
      dueDate.hour,
      dueDate.minute,
      plan?.prayerTimes,
    );

    final newTask = Task(
      id: DateTime.now().millisecondsSinceEpoch,
      title: title,
      prayerAnchor: prayerAnchor,
      dueDate: dueDate,
      isCompleted: false,
      isHighPriority: isHighPriority,
      category: category,
    );

    final sectionTasks = plan?.sections[prayerAnchor] ?? [];
    sectionTasks.add(newTask);
    sectionTasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    plan?.sections[prayerAnchor] = sectionTasks;

    if (plan != null) {
      await box.put(dateStr, plan);
    }

    return newTask;
  }

  Future<void> syncPendingTasks() async {
    // No-op in offline mode
  }
}
