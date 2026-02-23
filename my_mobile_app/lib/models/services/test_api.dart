import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

void testLogin() async {
  try {
    final response = await http.post(
      Uri.parse('https://13a4-2c0f-f698-c140-2d52-c49a-dac6-216d-2512.ngrok-free.app/api/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': 'example@gmail.com', 'password': '02340169'}),
    );

    debugPrint('Status Code: ${response.statusCode}');
    debugPrint('Headers: ${response.headers}');
    debugPrint('Body: ${response.body}');

    try {
      final data = json.decode(response.body);
      debugPrint('Parsed JSON: $data');
    } catch (e) {
      debugPrint('Error parsing JSON: $e');
    }
  } catch (e) {
    debugPrint('Network error: $e');
  }
}