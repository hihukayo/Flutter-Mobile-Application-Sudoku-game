import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class ApiService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8080/api';
    }

    try {
      final result = Process.runSync('getprop', ['ro.product.model']);
      if (result.stdout.toString().toLowerCase().contains('sdk') ||
          result.stdout.toString().toLowerCase().contains('generic') ||
          result.stdout.toString().toLowerCase().contains('emulator')) {
        return 'http://10.0.2.2:8080/api';
      }
    } catch (_) {}

    return 'http://localhost:8080/api';
  }

  static Future<Map<String, dynamic>> register({
    required String username,
    required String phone,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'phone': phone,
        'password': password,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> login({
    required String account,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'account': account, 'password': password}),
    );
    return jsonDecode(res.body);
  }
}
