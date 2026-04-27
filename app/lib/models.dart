import 'package:hive/hive.dart';

part 'models.g.dart';

@HiveType(typeId: 0)
class Task extends HiveObject {
  @HiveField(0)
  final int? id;
  @HiveField(1)
  final String title;
  @HiveField(2)
  final String prayerAnchor;
  @HiveField(3)
  final DateTime dueDate;
  @HiveField(4)
  final bool? isCompleted;
  @HiveField(5)
  final bool? isHighPriority;
  @HiveField(6)
  final int? templateId;
  @HiveField(7)
  final String? description;
  @HiveField(8)
  final String? category;
  @HiveField(9)
  final bool? isTemplate;

  Task({
    this.id,
    required this.title,
    required this.prayerAnchor,
    required this.dueDate,
    this.isCompleted = false,
    this.isHighPriority = false,
    this.templateId,
    this.description,
    this.category,
    this.isTemplate = false,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'],
      prayerAnchor: json['prayer_anchor'],
      dueDate: DateTime.parse(json['due_date']),
      isCompleted: json['is_completed'] ?? false,
      isHighPriority: json['is_high_priority'] ?? false,
      templateId: json['template_id'],
      description: json['description'],
      category: json['category'],
      isTemplate: json['is_template'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'prayer_anchor': prayerAnchor,
      'due_date': dueDate.toIso8601String(),
      'is_completed': isCompleted ?? false,
      'is_high_priority': isHighPriority ?? false,
      'template_id': templateId,
      'description': description,
      'category': category,
      'is_template': isTemplate ?? false,
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

@HiveType(typeId: 2)
class TaskTemplate extends HiveObject {
  @HiveField(0)
  final int id;
  @HiveField(1)
  final String title;
  @HiveField(2)
  final String? description;
  @HiveField(3)
  final String category;
  @HiveField(4)
  final String prayerAnchor;
  @HiveField(5)
  final String? dayOfWeek;

  TaskTemplate({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    required this.prayerAnchor,
    this.dayOfWeek,
  });

  factory TaskTemplate.fromJson(Map<String, dynamic> json) {
    return TaskTemplate(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      category: json['category'],
      prayerAnchor: json['prayer_anchor'],
      dayOfWeek: json['day_of_week'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'prayer_anchor': prayerAnchor,
      'day_of_week': dayOfWeek,
    };
  }
}
