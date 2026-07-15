import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class ApiService {
  // Save token to phone storage
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  // Login - returns token
  static Future<String> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'username': email, 'password': password},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['access_token'];
    } else {
      throw Exception('Invalid email or password');
    }
  }

  // Get current user info
  static Future<Map<String, dynamic>> getMe() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/auth/me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get user');
    }
  }

  // Generic GET with auth
  static Future<dynamic> get(String path) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}$path'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Request failed: ${response.statusCode}');
    }
  }

  // Generic POST with auth (query params)
  static Future<dynamic> post(String path) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}$path'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Request failed: ${response.statusCode}');
    }
  }
  // Generic PUT with auth
  static Future<dynamic> put(String path) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('${AppConfig.baseUrl}$path'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Request failed: ${response.statusCode}');
    }
  }

  // Generic PATCH with auth
  static Future<dynamic> patch(String path) async {
    final token = await getToken();
    final response = await http.patch(
      Uri.parse('${AppConfig.baseUrl}$path'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Request failed: ${response.statusCode}');
    }
  }

  // Generic DELETE with auth
  static Future<dynamic> delete(String path) async {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('${AppConfig.baseUrl}$path'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Request failed: ${response.statusCode}');
    }
  }
}