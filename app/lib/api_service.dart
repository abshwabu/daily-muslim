import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:8000/api';

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': password,
      }),
    );

    final result = _handleResponse(response);
    if (result['success'] && result['data']['access_token'] != null) {
      print('Token found in response, saving...');
      await _saveToken(result['data']['access_token']);
    } else {
      print('Token NOT found in response: ${result['data']}');
    }
    return result;
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    final result = _handleResponse(response);
    if (result['success'] && result['data']['access_token'] != null) {
      print('Token found in response, saving...');
      await _saveToken(result['data']['access_token']);
    } else {
      print('Token NOT found in response: ${result['data']}');
    }
    return result;
  }

  static Future<Map<String, dynamic>> getPrayerTimes({
    required String city,
    int method = 3,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/prayer-times?city=$city&method=$method'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      final result = _handleResponse(response);
      if (result['success']) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_prayer_times', jsonEncode(result['data']));
        return result;
      }
      
      // If API returned error, try cache
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cached_prayer_times');
      if (cached != null) {
        return {'success': true, 'data': jsonDecode(cached), 'from_cache': true};
      }
      return result;
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cached_prayer_times');
      if (cached != null) {
        return {'success': true, 'data': jsonDecode(cached), 'from_cache': true};
      }
      return {'success': false, 'message': 'Network error and no cached data'};
    }
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false, 
          'message': data['message'] ?? 'An error occurred',
          'errors': data['errors']
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Invalid server response'};
    }
  }

  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }
}
