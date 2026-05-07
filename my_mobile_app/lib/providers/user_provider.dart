import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import 'auth_provider.dart';

class UserProvider with ChangeNotifier {
  List<AppUser> _users = [];
  bool _isLoading = false;
  String? _error;
  String? _token;

  List<AppUser> get users => _users;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Setter pour le token (appelé par ChangeNotifierProxyProvider)
  void setToken(String token) {
    _token = token;
  }

  // Version sans paramètre token (utilise le token interne)
  Future<void> loadUsers() async {
    if (_token == null) {
      _error = 'Token non disponible';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${AuthProvider.baseUrl}/admin/users'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final usersData = data['data']['users'] as List;
          _users = usersData.map((userData) => AppUser.fromJson(userData)).toList();
        } else {
          _error = data['error'] ?? 'Erreur inconnue';
        }
      } else {
        _error = 'Erreur HTTP: ${response.statusCode}';
      }
    } catch (e) {
      _error = 'Erreur: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Version avec token pour compatibilité
  Future<void> loadUsersWithToken(String token) async {
    _token = token;
    return loadUsers();
  }

  Future<bool> deleteUser(int userId) async {
    if (_token == null) return false;

    try {
      final response = await http.delete(
        Uri.parse('${AuthProvider.baseUrl}/admin/users/$userId'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _users.removeWhere((user) => user.id == userId);
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('❌ Delete user error: $e');
      return false;
    }
  }

  Future<AppUser?> updateUser(int userId, Map<String, dynamic> data) async {
    if (_token == null) return null;

    try {
      final response = await http.put(
        Uri.parse('${AuthProvider.baseUrl}/admin/users/$userId'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode(data),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          final updatedUser = AppUser.fromJson(result['data']['user']);
          final index = _users.indexWhere((u) => u.id == userId);
          if (index != -1) {
            _users[index] = updatedUser;
            notifyListeners();
          }
          return updatedUser;
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Update user error: $e');
      return null;
    }
  }
}