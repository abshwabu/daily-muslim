import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'main_screen.dart';
import 'models.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(TaskAdapter());
  Hive.registerAdapter(DayPlanAdapter());
  Hive.registerAdapter(TaskTemplateAdapter());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sakinah',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF546356),
          surface: const Color(0xFFFBF9F4),
        ),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}
