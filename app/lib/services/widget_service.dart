import 'package:home_widget/home_widget.dart';
import '../models.dart';

class WidgetService {
  static const String appGroupId = 'group.com.example.daily_muslim';
  static const String androidWidgetName = 'PrayerWidgetProvider';
  static const String iOSWidgetName = 'PrayerWidget';

  /// Initialize HomeWidget with optional AppGroup ID for iOS
  static Future<void> init() async {
    try {
      await HomeWidget.setAppGroupId(appGroupId);
    } catch (_) {}
  }

  /// Updates all home screen widget data fields
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
        name: androidWidgetName,
        iOSName: iOSWidgetName,
      );
    } catch (e) {
      // Gracefully handle any platform widget update errors
    }
  }

  /// Syncs task updates specifically to widget
  static Future<void> syncTasksToWidget(List<Task> tasks) async {
    try {
      final total = tasks.length;
      final completed = tasks.where((t) => t.isCompleted ?? false).length;
      await HomeWidget.saveWidgetData<String>('tasks_summary', '$completed / $total completed');
      
      final nextPending = tasks.where((t) => !(t.isCompleted ?? false)).firstOrNull;
      if (nextPending != null) {
        await HomeWidget.saveWidgetData<String>('next_task', nextPending.title);
      } else {
        await HomeWidget.saveWidgetData<String>('next_task', 'All tasks done!');
      }

      await HomeWidget.updateWidget(
        name: androidWidgetName,
        iOSName: iOSWidgetName,
      );
    } catch (_) {}
  }
}
