import 'package:hive/hive.dart';
import 'models.dart';
import 'api_service.dart';
import 'prayer_service.dart';

class PlanningRepository {
  static const String planBoxName = 'dayPlanBox';
  static const String templateBoxName = 'taskTemplateBox';

  PlanningRepository({String? authToken});

  String _formatDateKey(DateTime date) {
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<DayPlan?> getDayPlan(DateTime date) async {
    final dateStr = _formatDateKey(date);
    final box = await Hive.openBox<DayPlan>(planBoxName);

    DayPlan? plan = box.get(dateStr);

    if (plan == null) {
      // Calculate prayer times offline/online for new date plan
      final prayerResult = await ApiService.getPrayerTimes(date: date);
      Map<String, dynamic> prayerTimes = {};
      if (prayerResult['success'] && prayerResult['data']?['data']?['timings'] != null) {
        prayerTimes = Map<String, dynamic>.from(prayerResult['data']['data']['timings']);
      }

      final templates = await getTaskTemplates();
      final Map<String, List<Task>> initialSections = {
        'fajr': [],
        'dhuhr': [],
        'asr': [],
        'maghrib': [],
        'isha': [],
      };

      int idCounter = DateTime.now().millisecondsSinceEpoch;
      for (var t in templates) {
        final anchor = t.prayerAnchor.toLowerCase();
        initialSections.putIfAbsent(anchor, () => []);
        
        final timeStr = prayerTimes[anchor.substring(0, 1).toUpperCase() + anchor.substring(1).toLowerCase()]?.toString();
        final minutes = PrayerTimeValidation.parsePrayerMinutes(timeStr) ?? 480;
        final hour = minutes ~/ 60;
        final minute = minutes % 60;
        final taskDate = DateTime(date.year, date.month, date.day, hour, minute);

        initialSections[anchor]!.add(Task(
          id: idCounter++,
          title: t.title,
          prayerAnchor: anchor,
          dueDate: taskDate,
          isCompleted: false,
          isHighPriority: false,
          templateId: t.id,
          description: t.description,
          category: t.category,
          isTemplate: true,
        ));
      }

      plan = DayPlan(
        date: dateStr,
        prayerTimes: prayerTimes,
        sections: initialSections,
        updatedAt: DateTime.now(),
      );
      await box.put(dateStr, plan);
    } else {
      // Ensure all anchor keys exist
      for (final key in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']) {
        plan.sections.putIfAbsent(key, () => []);
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
    final todayStr = _formatDateKey(now);
    final yesterdayStr = _formatDateKey(now.subtract(const Duration(days: 1)));

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

  Future<bool> toggleTask(Task task, {DateTime? targetDate, bool? forceCompleted}) async {
    final searchDates = [
      _formatDateKey(task.dueDate),
      _formatDateKey(task.dueDate.toLocal()),
      if (targetDate != null) _formatDateKey(targetDate),
    ].toSet();

    final box = await Hive.openBox<DayPlan>(planBoxName);
    DayPlan? plan;
    String? matchedDateKey;

    for (final dateKey in searchDates) {
      final p = box.get(dateKey);
      if (p != null) {
        plan = p;
        matchedDateKey = dateKey;
        break;
      }
    }

    if (plan == null) {
      matchedDateKey = _formatDateKey(targetDate ?? task.dueDate);
      plan = await getDayPlan(targetDate ?? task.dueDate);
    }
    if (plan == null) return false;

    final newCompletedState = forceCompleted ?? !(task.isCompleted ?? false);

    bool found = false;
    Map<String, List<Task>> newSections = {};

    plan.sections.forEach((anchor, sectionTasks) {
      List<Task> updatedList = [];
      for (int i = 0; i < sectionTasks.length; i++) {
        final current = sectionTasks[i];
        bool isMatch = false;

        if (task.id != null && current.id != null && current.id == task.id) {
          isMatch = true;
        } else if (task.templateId != null && current.templateId != null && current.templateId == task.templateId) {
          isMatch = true;
        } else if (current.title.trim().toLowerCase() == task.title.trim().toLowerCase()) {
          isMatch = true;
        }

        if (isMatch && !found) {
          found = true;
          updatedList.add(Task(
            id: current.id ?? task.id ?? DateTime.now().microsecondsSinceEpoch,
            title: current.title,
            prayerAnchor: current.prayerAnchor,
            dueDate: current.dueDate,
            isCompleted: newCompletedState,
            isHighPriority: current.isHighPriority,
            templateId: current.templateId,
            description: current.description,
            category: current.category,
            isTemplate: current.isTemplate,
          ));
        } else {
          updatedList.add(current);
        }
      }
      newSections[anchor] = updatedList;
    });

    if (!found) {
      final anchor = task.prayerAnchor.toLowerCase();
      newSections.putIfAbsent(anchor, () => []);
      newSections[anchor]!.add(Task(
        id: task.id ?? DateTime.now().millisecondsSinceEpoch,
        title: task.title,
        prayerAnchor: anchor,
        dueDate: task.dueDate,
        isCompleted: newCompletedState,
        isHighPriority: task.isHighPriority,
        templateId: task.templateId,
        description: task.description,
        category: task.category,
        isTemplate: task.isTemplate,
      ));
    }

    final updatedPlan = DayPlan(
      date: plan.date,
      prayerTimes: plan.prayerTimes,
      sections: newSections,
      updatedAt: DateTime.now(),
    );

    await box.put(matchedDateKey, updatedPlan);
    return true;
  }

  Future<Task?> createTask(String title, DateTime dueDate, {bool isHighPriority = false, String? category}) async {
    final dateStr = _formatDateKey(dueDate);
    final box = await Hive.openBox<DayPlan>(planBoxName);

    DayPlan? plan = box.get(dateStr);
    plan ??= await getDayPlan(dueDate);

    final prayerAnchor = PrayerTimeValidation.determinePrayerAnchor(
      dueDate.hour,
      dueDate.minute,
      plan?.prayerTimes,
    ).toLowerCase();

    final newTask = Task(
      id: DateTime.now().millisecondsSinceEpoch,
      title: title,
      prayerAnchor: prayerAnchor,
      dueDate: dueDate,
      isCompleted: false,
      isHighPriority: isHighPriority,
      category: category,
    );

    Map<String, List<Task>> newSections = Map.from(plan?.sections ?? {});
    final sectionTasks = List<Task>.from(newSections[prayerAnchor] ?? []);
    sectionTasks.add(newTask);
    sectionTasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    newSections[prayerAnchor] = sectionTasks;

    if (plan != null) {
      final updatedPlan = DayPlan(
        date: plan.date,
        prayerTimes: plan.prayerTimes,
        sections: newSections,
        updatedAt: DateTime.now(),
      );
      await box.put(dateStr, updatedPlan);
    }

    return newTask;
  }

  Future<bool> updateTask(Task updatedTask, {DateTime? targetDate}) async {
    final searchDates = [
      _formatDateKey(updatedTask.dueDate),
      _formatDateKey(updatedTask.dueDate.toLocal()),
      if (targetDate != null) _formatDateKey(targetDate),
    ].toSet();

    final box = await Hive.openBox<DayPlan>(planBoxName);
    DayPlan? plan;
    String? matchedDateKey;

    for (final dateKey in searchDates) {
      final p = box.get(dateKey);
      if (p != null) {
        plan = p;
        matchedDateKey = dateKey;
        break;
      }
    }

    if (plan == null) {
      matchedDateKey = _formatDateKey(targetDate ?? updatedTask.dueDate);
      plan = await getDayPlan(targetDate ?? updatedTask.dueDate);
    }
    if (plan == null) return false;

    final targetAnchor = PrayerTimeValidation.determinePrayerAnchor(
      updatedTask.dueDate.hour,
      updatedTask.dueDate.minute,
      plan.prayerTimes,
    ).toLowerCase();

    final finalTask = Task(
      id: updatedTask.id ?? DateTime.now().microsecondsSinceEpoch,
      title: updatedTask.title,
      prayerAnchor: targetAnchor,
      dueDate: updatedTask.dueDate,
      isCompleted: updatedTask.isCompleted,
      isHighPriority: updatedTask.isHighPriority,
      templateId: updatedTask.templateId,
      description: updatedTask.description,
      category: updatedTask.category,
      isTemplate: updatedTask.isTemplate,
    );

    Map<String, List<Task>> newSections = {};
    plan.sections.forEach((anchor, sectionTasks) {
      final filtered = sectionTasks.where((t) {
        if (updatedTask.id != null && t.id != null && t.id == updatedTask.id) return false;
        if (updatedTask.templateId != null && t.templateId != null && t.templateId == updatedTask.templateId) return false;
        if (t.title.trim().toLowerCase() == updatedTask.title.trim().toLowerCase()) return false;
        return true;
      }).toList();
      newSections[anchor] = filtered;
    });

    newSections.putIfAbsent(targetAnchor, () => []);
    newSections[targetAnchor]!.add(finalTask);
    newSections[targetAnchor]!.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    final newDayPlan = DayPlan(
      date: plan.date,
      prayerTimes: plan.prayerTimes,
      sections: newSections,
      updatedAt: DateTime.now(),
    );

    await box.put(matchedDateKey, newDayPlan);
    return true;
  }

  Future<bool> deleteTask(Task task, {DateTime? targetDate}) async {
    final searchDates = [
      _formatDateKey(task.dueDate),
      _formatDateKey(task.dueDate.toLocal()),
      if (targetDate != null) _formatDateKey(targetDate),
    ].toSet();

    final box = await Hive.openBox<DayPlan>(planBoxName);
    DayPlan? plan;
    String? matchedDateKey;

    for (final dateKey in searchDates) {
      final p = box.get(dateKey);
      if (p != null) {
        plan = p;
        matchedDateKey = dateKey;
        break;
      }
    }

    if (plan == null) return false;

    Map<String, List<Task>> newSections = {};
    plan.sections.forEach((anchor, sectionTasks) {
      final filtered = sectionTasks.where((t) {
        if (task.id != null && t.id != null && t.id == task.id) return false;
        if (task.templateId != null && t.templateId != null && t.templateId == task.templateId) return false;
        if (t.title.trim().toLowerCase() == task.title.trim().toLowerCase()) return false;
        return true;
      }).toList();
      newSections[anchor] = filtered;
    });

    final newDayPlan = DayPlan(
      date: plan.date,
      prayerTimes: plan.prayerTimes,
      sections: newSections,
      updatedAt: DateTime.now(),
    );

    await box.put(matchedDateKey, newDayPlan);
    return true;
  }

  Future<void> syncPendingTasks() async {
    // No-op in offline mode
  }
}
