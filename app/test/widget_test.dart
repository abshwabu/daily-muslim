import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/models.dart';
import 'package:app/planning_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final tempDir = Directory.systemTemp.createTempSync('hive_test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TaskAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(DayPlanAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(TaskTemplateAdapter());
  });

  test('PlanningRepository task CRUD operations', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = PlanningRepository();
    final now = DateTime.now();

    // Create task
    final task = await repo.createTask('Test Read Quran', now, isHighPriority: true);
    expect(task, isNotNull);
    expect(task!.title, 'Test Read Quran');
    expect(task.isCompleted, false);

    // Toggle task
    final toggleSuccess = await repo.toggleTask(task);
    expect(toggleSuccess, isTrue);

    // Update task
    final updatedTask = Task(
      id: task.id,
      title: 'Updated Quran Reading',
      prayerAnchor: task.prayerAnchor,
      dueDate: now,
      isCompleted: true,
      isHighPriority: false,
    );
    final updateSuccess = await repo.updateTask(updatedTask);
    expect(updateSuccess, isTrue);

    // Delete task
    final deleteSuccess = await repo.deleteTask(updatedTask);
    expect(deleteSuccess, isTrue);
  });
}
