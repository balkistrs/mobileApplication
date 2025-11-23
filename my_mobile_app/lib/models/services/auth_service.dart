  import 'dart:convert';
  import 'package:http/http.dart' as http;
  import '../user.dart';

  class AuthService {
    static const String baseUrl = 'https://1cc7227c8427.ngrok-free.app/api';

    Future<Map<String, dynamic>> login(String email, String password) async {
      final res = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );

      if (res.statusCode != 200) {
        throw Exception('Login failed: ${res.statusCode} ${res.body}');
      }

      final data = json.decode(res.body) as Map<String, dynamic>;
      final token = data['token'] as String? ?? '';
      final user = AppUser.fromJson(data['user'] ?? {});
      return {'user': user, 'token': token};
    }
  }
    