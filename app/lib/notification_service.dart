import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'prayer_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  // Preferences Keys
  static const String prefPrayerNotifications = 'notify_prayer_times';
  static const String prefTaskReminders = 'notify_task_reminders';
  static const String prefJournalReminder = 'notify_journal_reminder';
  static const String prefJournalTimeHour = 'journal_reminder_hour';
  static const String prefJournalTimeMinute = 'journal_reminder_minute';

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Initialize TimeZone database
      tz.initializeTimeZones();

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification tapped: ${response.payload}');
        },
      );

      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  Future<bool> requestPermissions() async {
    if (!_isInitialized) return false;
    try {
      final androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final granted = await androidImplementation?.requestNotificationsPermission();
      await androidImplementation?.requestExactAlarmsPermission();
      return granted ?? true;
    } catch (e) {
      debugPrint('Request permissions error: $e');
      return false;
    }
  }

  // ----------------------------------------------------
  // 1. PRAYER TIME NOTIFICATIONS
  // ----------------------------------------------------
  Future<void> schedulePrayerNotifications(Map<String, dynamic> prayerTimes, {DateTime? date}) async {
    if (!_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(prefPrayerNotifications) ?? true;
      if (!enabled) return;

      final targetDate = date ?? DateTime.now();
      final prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

      for (int i = 0; i < prayers.length; i++) {
        final prayerName = prayers[i];
        final timeStr = prayerTimes[prayerName]?.toString();
        if (timeStr == null) continue;

        final minutes = PrayerTimeValidation.parsePrayerMinutes(timeStr);
        if (minutes == null) continue;

        final hour = minutes ~/ 60;
        final minute = minutes % 60;

        final scheduledDateTime = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          hour,
          minute,
        );

        // Only schedule for future times
        if (scheduledDateTime.isBefore(DateTime.now())) continue;

        final tzScheduled = tz.TZDateTime.from(scheduledDateTime, tz.local);
        final notificationId = 1000 + (targetDate.day * 10) + i;

        await _notificationsPlugin.zonedSchedule(
          id: notificationId,
          title: '$prayerName Prayer Time 🕌',
          body: 'Time for $prayerName prayer ($timeStr). May Allah accept your salah.',
          scheduledDate: tzScheduled,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'prayer_channel',
              'Prayer Times Adhan Notifications',
              channelDescription: 'Reminders when it is time for Fajr, Dhuhr, Asr, Maghrib, and Isha prayers.',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
            ),
            iOS: DarwinNotificationDetails(
              sound: 'default',
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      }
    } catch (e) {
      debugPrint('Schedule prayer notifications error: $e');
    }
  }

  // ----------------------------------------------------
  // 2. TASK REMINDERS
  // ----------------------------------------------------
  Future<void> scheduleTaskReminder(Task task) async {
    if (!_isInitialized) return;
    if (task.id == null || task.isCompleted == true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(prefTaskReminders) ?? true;
      if (!enabled) return;

      if (task.dueDate.isBefore(DateTime.now())) return;

      final tzScheduled = tz.TZDateTime.from(task.dueDate, tz.local);
      final notificationId = 200000 + (task.id! % 50000);

      await _notificationsPlugin.zonedSchedule(
        id: notificationId,
        title: 'Task Reminder 📋',
        body: 'Reminder for: ${task.title}',
        scheduledDate: tzScheduled,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_channel',
            'Task Reminders',
            channelDescription: 'Reminders for scheduled daily tasks and habits.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            sound: 'default',
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Schedule task reminder error: $e');
    }
  }

  Future<void> cancelTaskReminder(int taskId) async {
    if (!_isInitialized) return;
    try {
      final notificationId = 200000 + (taskId % 50000);
      await _notificationsPlugin.cancel(id: notificationId);
    } catch (e) {
      debugPrint('Cancel task reminder error: $e');
    }
  }

  // ----------------------------------------------------
  // 3. DAILY JOURNAL REMINDER
  // ----------------------------------------------------
  Future<void> scheduleDailyJournalReminder() async {
    if (!_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(prefJournalReminder) ?? true;
      final hour = prefs.getInt(prefJournalTimeHour) ?? 21; // Default 9:00 PM
      final minute = prefs.getInt(prefJournalTimeMinute) ?? 0;

      await _notificationsPlugin.cancel(id: 30001); // Cancel existing journal reminder ID

      if (!enabled) return;

      final now = DateTime.now();
      var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      final tzScheduled = tz.TZDateTime.from(scheduledDate, tz.local);

      await _notificationsPlugin.zonedSchedule(
        id: 30001,
        title: 'Daily Reflection & Journal 📖',
        body: 'Take a quiet moment to reflect on your day and write your journal entry.',
        scheduledDate: tzScheduled,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'journal_channel',
            'Daily Journal Reminders',
            channelDescription: 'Evening reminder to log daily reflection and journal entries.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            sound: 'default',
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('Schedule journal reminder error: $e');
    }
  }

  Future<void> cancelAll() async {
    if (!_isInitialized) return;
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('Cancel all error: $e');
    }
  }
}
