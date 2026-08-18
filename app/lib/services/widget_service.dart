import 'package:home_widget/home_widget.dart';
import '../models.dart';

class WidgetService {
  static const String appGroupId = 'group.com.example.daily_muslim';
  
  static const String prayerWidgetAndroid = 'PrayerWidgetProvider';
  static const String dhikrWidgetAndroid = 'DhikrWidgetProvider';
  static const String verseWidgetAndroid = 'VerseWidgetProvider';
  static const String taskWidgetAndroid = 'TaskWidgetProvider';

  static const String prayerWidgetIOS = 'PrayerWidget';
  static const String dhikrWidgetIOS = 'DhikrWidget';
  static const String verseWidgetIOS = 'VerseWidget';
  static const String taskWidgetIOS = 'TaskWidget';

  /// Initialize HomeWidget with default values for all widgets
  static Future<void> init() async {
    try {
      await HomeWidget.setAppGroupId(appGroupId);

      // Seed Prayer Widget defaults
      await HomeWidget.saveWidgetData<String>('next_prayer_name', 'DHUHR');
      await HomeWidget.saveWidgetData<String>('next_prayer_time', '12:28');
      await HomeWidget.saveWidgetData<String>('time_until_next', 'Upcoming');
      await HomeWidget.saveWidgetData<String>('city_name', 'Addis Ababa');
      await HomeWidget.saveWidgetData<String>('tasks_summary', 'Daily Muslim • Sakinah');

      // Seed Dhikr Widget defaults
      await HomeWidget.saveWidgetData<String>('dhikr_title', 'SUBHANALLAH');
      await HomeWidget.saveWidgetData<String>('dhikr_meaning', 'Glory be to Allah');
      await HomeWidget.saveWidgetData<String>('dhikr_count', '0');
      await HomeWidget.saveWidgetData<String>('dhikr_target', '33');

      // Seed Verse Widget defaults
      await HomeWidget.saveWidgetData<String>('verse_text', '"Verily, with every hardship comes ease."');
      await HomeWidget.saveWidgetData<String>('verse_ref', 'Surah Ash-Sharh 94:6');

      // Seed Task Widget defaults
      await HomeWidget.saveWidgetData<String>('next_task', 'Morning Quran recitation (1 Juz)');

      await updateAllWidgets();
    } catch (_) {}
  }

  /// Update all 4 home screen widgets
  static Future<void> updateAllWidgets() async {
    try {
      await HomeWidget.updateWidget(name: prayerWidgetAndroid, iOSName: prayerWidgetIOS);
      await HomeWidget.updateWidget(name: dhikrWidgetAndroid, iOSName: dhikrWidgetIOS);
      await HomeWidget.updateWidget(name: verseWidgetAndroid, iOSName: verseWidgetIOS);
      await HomeWidget.updateWidget(name: taskWidgetAndroid, iOSName: taskWidgetIOS);
    } catch (_) {}
  }

  /// Updates prayer pulse widget data fields
  static Future<void> updatePrayerWidget({
    required String nextPrayerName,
    required String nextPrayerTime,
    required String timeUntilNext,
    String? prevPrayerName,
    String? prevPrayerTime,
    String? cityName,
    int? completedTasks,
    int? totalTasks,
    String? dailyAyah,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('next_prayer_name', nextPrayerName);
      await HomeWidget.saveWidgetData<String>('next_prayer_time', nextPrayerTime);
      await HomeWidget.saveWidgetData<String>('time_until_next', timeUntilNext);
      
      if (prevPrayerName != null) {
        await HomeWidget.saveWidgetData<String>('prev_prayer_name', prevPrayerName);
      }
      if (prevPrayerTime != null) {
        await HomeWidget.saveWidgetData<String>('prev_prayer_time', prevPrayerTime);
      }
      if (cityName != null) {
        await HomeWidget.saveWidgetData<String>('city_name', cityName);
      }
      if (completedTasks != null && totalTasks != null) {
        await HomeWidget.saveWidgetData<String>('tasks_summary', '$completedTasks / $totalTasks done');
      }
      if (dailyAyah != null) {
        await HomeWidget.saveWidgetData<String>('daily_ayah', dailyAyah);
      }

      await HomeWidget.updateWidget(
        name: prayerWidgetAndroid,
        iOSName: prayerWidgetIOS,
      );
    } catch (_) {}
  }

  /// Updates Dhikr widget
  static Future<void> updateDhikrWidget({
    required String title,
    required String meaning,
    required int count,
    required int target,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('dhikr_title', title);
      await HomeWidget.saveWidgetData<String>('dhikr_meaning', meaning);
      await HomeWidget.saveWidgetData<String>('dhikr_count', '$count');
      await HomeWidget.saveWidgetData<String>('dhikr_target', '$target');

      await HomeWidget.updateWidget(
        name: dhikrWidgetAndroid,
        iOSName: dhikrWidgetIOS,
      );
    } catch (_) {}
  }

  /// Updates Verse reflection widget
  static Future<void> updateVerseWidget({
    required String text,
    required String reference,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('verse_text', text);
      await HomeWidget.saveWidgetData<String>('verse_ref', reference);

      await HomeWidget.updateWidget(
        name: verseWidgetAndroid,
        iOSName: verseWidgetIOS,
      );
    } catch (_) {}
  }

  /// Syncs task updates specifically to widget
  static Future<void> syncTasksToWidget(List<Task> tasks) async {
    try {
      final total = tasks.length;
      final completed = tasks.where((t) => t.isCompleted ?? false).length;
      final summary = '$completed / $total completed';
      await HomeWidget.saveWidgetData<String>('tasks_summary', summary);
      
      final nextPending = tasks.where((t) => !(t.isCompleted ?? false)).firstOrNull;
      if (nextPending != null) {
        await HomeWidget.saveWidgetData<String>('next_task', nextPending.title);
      } else {
        await HomeWidget.saveWidgetData<String>('next_task', 'All tasks done for today!');
      }

      await HomeWidget.updateWidget(
        name: taskWidgetAndroid,
        iOSName: taskWidgetIOS,
      );
      await HomeWidget.updateWidget(
        name: prayerWidgetAndroid,
        iOSName: prayerWidgetIOS,
      );
    } catch (_) {}
  }
}
