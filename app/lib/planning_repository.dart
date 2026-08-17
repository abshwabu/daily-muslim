import 'package:hive/hive.dart';
import 'models.dart';
import 'api_service.dart';
import 'prayer_service.dart';
import 'notification_service.dart';

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

      // 1. Monday & Thursday Voluntary Fasting
      if (date.weekday == DateTime.monday || date.weekday == DateTime.thursday) {
        final dayName = date.weekday == DateTime.monday ? 'Monday' : 'Thursday';
        final fajrTime = prayerTimes['Fajr']?.toString();
        final minutes = PrayerTimeValidation.parsePrayerMinutes(fajrTime) ?? 300;
        final taskDate = DateTime(date.year, date.month, date.day, minutes ~/ 60, minutes % 60);

        initialSections['fajr']!.add(Task(
          id: idCounter++,
          title: 'Voluntary Fasting ($dayName)',
          prayerAnchor: 'fajr',
          dueDate: taskDate,
          isCompleted: false,
          isHighPriority: true,
          description: 'Sunnah voluntary fasting on $dayName',
          category: 'Sunnah',
          isTemplate: true,
        ));
      }

      // 2. Friday Special (Surah Al-Kahf & Salawat)
      if (date.weekday == DateTime.friday) {
        final dhuhrTime = prayerTimes['Dhuhr']?.toString();
        final minutes = PrayerTimeValidation.parsePrayerMinutes(dhuhrTime) ?? 720;
        final taskDate = DateTime(date.year, date.month, date.day, minutes ~/ 60, minutes % 60);

        initialSections['dhuhr']!.add(Task(
          id: idCounter++,
          title: 'Recite Surah Al-Kahf',
          prayerAnchor: 'dhuhr',
          dueDate: taskDate,
          isCompleted: false,
          isHighPriority: true,
          description: 'Friday Sunnah recitation of Surah Al-Kahf',
          category: 'Quran',
          isTemplate: true,
        ));

        initialSections['dhuhr']!.add(Task(
          id: idCounter++,
          title: 'Abundant Salawat on Prophet (PBUH)',
          prayerAnchor: 'dhuhr',
          dueDate: taskDate.add(const Duration(minutes: 15)),
          isCompleted: false,
          isHighPriority: false,
          description: 'Send blessings upon the Prophet Muhammad (PBUH) on Friday',
          category: 'Azkar',
          isTemplate: true,
        ));
      }

      // 3. Populate standard templates
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

    if (plan != null && plan.prayerTimes.isNotEmpty) {
      NotificationService().schedulePrayerNotifications(plan.prayerTimes, date: date);
    }

    return plan;
  }

  Future<List<TaskTemplate>> getTaskTemplates() async {
    final box = await Hive.openBox<TaskTemplate>(templateBoxName);
    if (box.length < 10) {
      await box.clear();
      final defaultTemplates = [
        // Fajr
        TaskTemplate(id: 1, title: 'Sunnah Before Fajr (2 Rakat)', category: 'Sunnah', prayerAnchor: 'fajr', description: '2 Raka\'at Sunnah prayer before Fajr'),
        TaskTemplate(id: 2, title: 'Fajr Post-Salah Adhkar', category: 'Azkar', prayerAnchor: 'fajr', description: 'Tasbih, Tahmid, Takbir & Ayat al-Kursi after Fajr'),
        TaskTemplate(id: 3, title: 'Morning Adhkar (Sabah)', category: 'Azkar', prayerAnchor: 'fajr', description: 'Essential morning supplications & remembrance'),

        // Dhuhr
        TaskTemplate(id: 4, title: 'Duha Prayer (Forenoon)', category: 'Sunnah', prayerAnchor: 'dhuhr', description: '2-8 Raka\'at Duha prayer during forenoon'),
        TaskTemplate(id: 5, title: 'Sunnah Before Dhuhr (4 Rakat)', category: 'Sunnah', prayerAnchor: 'dhuhr', description: '4 Raka\'at Sunnah prayer before Dhuhr'),
        TaskTemplate(id: 6, title: 'Dhuhr Post-Salah Adhkar', category: 'Azkar', prayerAnchor: 'dhuhr', description: 'Remembrance and supplications after Dhuhr'),
        TaskTemplate(id: 7, title: 'Sunnah After Dhuhr (2 Rakat)', category: 'Sunnah', prayerAnchor: 'dhuhr', description: '2 Raka\'at Sunnah prayer after Dhuhr'),

        // Asr
        TaskTemplate(id: 8, title: 'Evening Adhkar (Masaa)', category: 'Azkar', prayerAnchor: 'asr', description: 'Protective evening supplications before sunset'),
        TaskTemplate(id: 9, title: 'Asr Post-Salah Adhkar', category: 'Azkar', prayerAnchor: 'asr', description: 'Remembrance and supplications after Asr'),
        TaskTemplate(id: 10, title: 'Daily Quran Recitation', category: 'Quran', prayerAnchor: 'asr', description: 'Daily Quran reading & contemplation'),

        // Maghrib
        TaskTemplate(id: 11, title: 'Maghrib Post-Salah Adhkar', category: 'Azkar', prayerAnchor: 'maghrib', description: 'Remembrance and supplications after Maghrib'),
        TaskTemplate(id: 12, title: 'Sunnah After Maghrib (2 Rakat)', category: 'Sunnah', prayerAnchor: 'maghrib', description: '2 Raka\'at Sunnah prayer after Maghrib'),

        // Isha
        TaskTemplate(id: 13, title: 'Isha Post-Salah Adhkar', category: 'Azkar', prayerAnchor: 'isha', description: 'Remembrance and supplications after Isha'),
        TaskTemplate(id: 14, title: 'Sunnah After Isha (2 Rakat)', category: 'Sunnah', prayerAnchor: 'isha', description: '2 Raka\'at Sunnah prayer after Isha'),
        TaskTemplate(id: 15, title: 'Night Prayer (Tahajjud & Witr)', category: 'Sunnah', prayerAnchor: 'isha', description: 'Night prayer & Witr before sleep'),
        TaskTemplate(id: 16, title: 'Recite Surah Al-Mulk', category: 'Quran', prayerAnchor: 'isha', description: 'Recite Surah Al-Mulk before sleeping'),
      ];
      await box.addAll(defaultTemplates);
    }
    return box.values.toList();
  }

  Future<bool> resetToDefaultTasks(DateTime date) async {
    final dateStr = _formatDateKey(date);
    final box = await Hive.openBox<DayPlan>(planBoxName);
    await box.delete(dateStr);
    await getDayPlan(date);
    return true;
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
    if (newCompletedState && task.id != null) {
      NotificationService().cancelTaskReminder(task.id!);
    } else if (!newCompletedState) {
      NotificationService().scheduleTaskReminder(task);
    }
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

    NotificationService().scheduleTaskReminder(newTask);
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

    if (finalTask.isCompleted == true && finalTask.id != null) {
      NotificationService().cancelTaskReminder(finalTask.id!);
    } else {
      NotificationService().scheduleTaskReminder(finalTask);
    }

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
    if (task.id != null) {
      NotificationService().cancelTaskReminder(task.id!);
    }
    return true;
  }

  Future<void> syncPendingTasks() async {
    // No-op in offline mode
  }
}
