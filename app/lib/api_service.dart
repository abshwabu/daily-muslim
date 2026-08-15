import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'prayer_service.dart';

class ApiService {
  static const String journalBoxName = 'journalEntriesBox';

  static final List<String> _prompts = [
    "What are you grateful for in this quiet moment?",
    "How can you bring more mindfulness and intention to your prayers today?",
    "Reflect on a recent hardship that brought you closer to Allah.",
    "What is one bad habit you wish to replace with a noble deed today?",
    "Who is someone you can pray for or perform a silent act of kindness for today?",
    "How did you feel during your last prayer, and what helped you find tranquility?",
    "What Ayah or Hadith gave your heart comfort this week?",
    "In what ways have you noticed Allah's subtle blessings in your daily routine?",
    "What intentions are you setting for tomorrow's spiritual growth?",
    "How can you practice patience (Sabr) in your interactions today?",
  ];

  static Future<String?> getToken() async {
    return 'offline_token';
  }

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    await prefs.setString('user_email', email);
    await prefs.setString('auth_token', 'offline_token');
    return {
      'success': true,
      'data': {'access_token': 'offline_token'}
    };
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', 'offline_token');
    return {
      'success': true,
      'data': {'access_token': 'offline_token'}
    };
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', 'offline_token');
  }

  static Future<Map<String, dynamic>> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name') ?? 'Muslim';
    final email = prefs.getString('user_email') ?? 'offline@dailymuslim.app';
    final city = prefs.getString('city') ?? 'Addis Ababa, Ethiopia';
    final prayerMethod = prefs.getInt('prayer_method') ?? 3;
    final isHanafi = prefs.getBool('is_hanafi') ?? false;

    // Count journal entries
    int journalCount = 0;
    try {
      final box = await Hive.openBox(journalBoxName);
      journalCount = box.length;
    } catch (_) {}

    return {
      'success': true,
      'data': {
        'name': name,
        'email': email,
        'city': city,
        'prayer_method': prayerMethod,
        'is_hanafi': isHanafi,
        'journal_entries_count': journalCount,
        'tasks_count': 0,
      }
    };
  }

  static Future<Map<String, dynamic>> updateSettings({
    String? name,
    String? city,
    int? prayerMethod,
    bool? isHanafi,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (name != null) await prefs.setString('user_name', name);
    if (prayerMethod != null) await prefs.setInt('prayer_method', prayerMethod);
    if (isHanafi != null) await prefs.setBool('is_hanafi', isHanafi);
    
    if (city != null) {
      final cityLoc = PrayerService.findCity(city);
      await prefs.setString('city', cityLoc.fullName);
      await prefs.setDouble('latitude', cityLoc.latitude);
      await prefs.setDouble('longitude', cityLoc.longitude);
    }
    
    return {'success': true, 'message': 'Settings updated locally'};
  }

  static Future<Map<String, dynamic>> getPrayerTimes({
    String? city,
    int? method,
    DateTime? date,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final targetCityName = city ?? prefs.getString('city') ?? 'Addis Ababa, Ethiopia';
    final cityLoc = PrayerService.findCity(targetCityName);

    double lat = prefs.getDouble('latitude') ?? cityLoc.latitude;
    double lng = prefs.getDouble('longitude') ?? cityLoc.longitude;
    int methodId = method ?? prefs.getInt('prayer_method') ?? 3;
    bool isHanafi = prefs.getBool('is_hanafi') ?? false;
    final targetDate = date ?? DateTime.now();

    final timings = PrayerService.calculatePrayerTimes(
      latitude: lat,
      longitude: lng,
      date: targetDate,
      methodId: methodId,
      isHanafi: isHanafi,
    );

    return {
      'success': true,
      'data': {
        'data': {
          'timings': timings,
          'meta': {
            'latitude': lat,
            'longitude': lng,
            'timezone': targetDate.timeZoneName,
            'method': {'id': methodId, 'name': 'Offline Calculation'}
          }
        }
      }
    };
  }

  static Future<Map<String, dynamic>> getPrayerMethods() async {
    return {
      'success': true,
      'data': {
        'data': PrayerService.prayerMethods,
      }
    };
  }

  static Future<List<String>> searchCities(String query) async {
    return PrayerService.searchCities(query);
  }

  static Future<Map<String, dynamic>> getJournalPrompt() async {
    final now = DateTime.now();
    final dayOfYear = int.parse("${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}");
    final index = dayOfYear % _prompts.length;
    return {
      'success': true,
      'data': {
        'data': {'prompt': _prompts[index]}
      }
    };
  }

  static Future<Map<String, dynamic>> getJournalEntries() async {
    final box = await Hive.openBox(journalBoxName);
    final entries = <Map<String, dynamic>>[];
    for (var key in box.keys) {
      final raw = box.get(key);
      if (raw != null) {
        if (raw is Map) {
          entries.add(Map<String, dynamic>.from(raw));
        } else if (raw is String) {
          try {
            entries.add(Map<String, dynamic>.from(jsonDecode(raw)));
          } catch (_) {}
        }
      }
    }
    // Sort descending by date
    entries.sort((a, b) => (b['date'] ?? '').compareTo(a['date'] ?? ''));
    return {
      'success': true,
      'data': {'data': entries}
    };
  }

  static Future<Map<String, dynamic>> getJournalEntry(String date) async {
    final box = await Hive.openBox(journalBoxName);
    for (var key in box.keys) {
      final raw = box.get(key);
      Map<String, dynamic>? item;
      if (raw is Map) item = Map<String, dynamic>.from(raw);
      if (raw is String) {
        try { item = Map<String, dynamic>.from(jsonDecode(raw)); } catch (_) {}
      }
      if (item != null && item['date'] == date) {
        return {'success': true, 'data': item};
      }
    }
    return {'success': false, 'message': 'Entry not found'};
  }

  static Future<Map<String, dynamic>> saveJournalEntry({
    required String content,
    required String date,
    String? prompt,
  }) async {
    final box = await Hive.openBox(journalBoxName);
    dynamic existingKey;
    int nextId = DateTime.now().millisecondsSinceEpoch;

    for (var key in box.keys) {
      final raw = box.get(key);
      Map<String, dynamic>? item;
      if (raw is Map) item = Map<String, dynamic>.from(raw);
      if (raw is String) {
        try { item = Map<String, dynamic>.from(jsonDecode(raw)); } catch (_) {}
      }
      if (item != null && item['date'] == date) {
        existingKey = key;
        if (item['id'] != null) nextId = item['id'];
        break;
      }
    }

    final entryData = {
      'id': nextId,
      'content': content,
      'date': date,
      'prompt': prompt ?? _prompts[0],
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (existingKey != null) {
      await box.put(existingKey, entryData);
    } else {
      await box.add(entryData);
    }

    return {'success': true, 'data': entryData};
  }

  static Future<Map<String, dynamic>> deleteJournalEntry(int id) async {
    final box = await Hive.openBox(journalBoxName);
    dynamic keyToDelete;
    for (var key in box.keys) {
      final raw = box.get(key);
      Map<String, dynamic>? item;
      if (raw is Map) item = Map<String, dynamic>.from(raw);
      if (raw is String) {
        try { item = Map<String, dynamic>.from(jsonDecode(raw)); } catch (_) {}
      }
      if (item != null && item['id'] == id) {
        keyToDelete = key;
        break;
      }
    }

    if (keyToDelete != null) {
      await box.delete(keyToDelete);
    }
    return {'success': true, 'message': 'Journal entry deleted'};
  }
}
