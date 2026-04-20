import 'package:hive/hive.dart';

part 'models.g.dart';

@HiveType(typeId: 0)
class Task extends HiveObject {
  @HiveField(0)
  final int id;
  @HiveField(1)
  final String title;
  @HiveField(2)
  final String prayerAnchor;
  @HiveField(3)
  final DateTime dueDate;
  @HiveField(4)
  final bool isCompleted;
  @HiveField(5)
  final bool isHighPriority;

  Task({
    required this.id,
    required this.title,
    required this.prayerAnchor,
    required this.dueDate,
    this.isCompleted = false,
    this.isHighPriority = false,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'],
      prayerAnchor: json['prayer_anchor'],
      dueDate: DateTime.parse(json['due_date']),
      isCompleted: json['is_completed'] ?? false,
      isHighPriority: json['is_high_priority'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'prayer_anchor': prayerAnchor,
      'due_date': dueDate.toIso8601String(),
      'is_completed': isCompleted,
      'is_high_priority': isHighPriority,
    };
  }
}

@HiveType(typeId: 1)
class DayPlan extends HiveObject {
  @HiveField(0)
  final String date;
  @HiveField(1)
  final Map<String, dynamic> prayerTimes;
  @HiveField(2)
  final Map<String, List<Task>> sections;
  @HiveField(3)
  final DateTime updatedAt;

  DayPlan({
    required this.date,
    required this.prayerTimes,
    required this.sections,
    required this.updatedAt,
  });

  bool isStale() {
    return DateTime.now().difference(updatedAt).inHours >= 24;
  }
}
