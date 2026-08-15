import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:app/main.dart';
import 'package:app/models.dart';

void main() {
  setUpAll(() async {
    final tempDir = Directory.systemTemp.createTempSync('hive_test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TaskAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(DayPlanAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(TaskTemplateAdapter());
  });

  testWidgets('App loads cleanly', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(MyApp), findsOneWidget);
  });
}
