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
      _error = 'Token not available';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // CORRECTION: Ajouter /api/ dans l'URL
      final url = '${AuthProvider.baseUrl}/api/admin/users';
      debugPrint('📡 Loading users from: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final usersData = data['data']['users'] as List;
          _users = usersData.map((userData) => AppUser.fromJson(userData)).toList();
          debugPrint('✅ Loaded ${_users.length} users');
        } else {
          _error = data['error'] ?? 'Unknown error';
          debugPrint('❌ Error loading users: $_error');
        }
      } else if (response.statusCode == 401) {
        _error = 'Session expired. Please login again.';
        debugPrint('❌ Session expired');
      } else {
        _error = 'HTTP Error: ${response.statusCode}';
        debugPrint('❌ HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      _error = 'Connection error: $e';
      debugPrint('❌ Connection error: $e');
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
    if (_token == null) {
      debugPrint('❌ No token available for delete');
      return false;
    }

    try {
      // CORRECTION: Ajouter /api/ dans l'URL
      final url = '${AuthProvider.baseUrl}/api/admin/users/$userId';
      debugPrint('🗑️ Deleting user $userId at: $url');
      
      final response = await http.delete(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('📡 Delete response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _users.removeWhere((user) => user.id == userId);
          notifyListeners();
          debugPrint('✅ User $userId deleted successfully');
          return true;
        } else {
          debugPrint('❌ Delete failed: ${data['error']}');
        }
      } else if (response.statusCode == 204) {
        _users.removeWhere((user) => user.id == userId);
        notifyListeners();
        debugPrint('✅ User $userId deleted successfully (204)');
        return true;
      } else if (response.statusCode == 401) {
        _error = 'Session expired. Please login again.';
        debugPrint('❌ Session expired during delete');
      } else {
        debugPrint('❌ Delete failed with status: ${response.statusCode}');
      }
      return false;
    } catch (e) {
      debugPrint('❌ Delete user error: $e');
      return false;
    }
  }

  Future<AppUser?> updateUser(int userId, Map<String, dynamic> data) async {
    if (_token == null) {
      debugPrint('❌ No token available for update');
      return null;
    }

    try {
      // CORRECTION: Ajouter /api/ dans l'URL
      final url = '${AuthProvider.baseUrl}/api/admin/users/$userId';
      debugPrint('✏️ Updating user $userId at: $url');
      debugPrint('📦 Update data: $data');
      
      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode(data),
      ).timeout(const Duration(seconds: 15));

      debugPrint('📡 Update response status: ${response.statusCode}');
      debugPrint('📡 Update response body: ${response.body}');

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          final updatedUser = AppUser.fromJson(result['data']['user']);
          final index = _users.indexWhere((u) => u.id == userId);
          if (index != -1) {
            _users[index] = updatedUser;
            notifyListeners();
          }
          debugPrint('✅ User $userId updated successfully');
          return updatedUser;
        } else {
          debugPrint('❌ Update failed: ${result['error']}');
        }
      } else if (response.statusCode == 401) {
        _error = 'Session expired. Please login again.';
        debugPrint('❌ Session expired during update');
      } else if (response.statusCode == 404) {
        debugPrint('❌ User not found (404)');
      } else {
        debugPrint('❌ Update failed with status: ${response.statusCode}');
      }
      return null;
    } catch (e) {
      debugPrint('❌ Update user error: $e');
      return null;
    }
  }

  // Méthode pour rafraîchir la liste des utilisateurs
  Future<void> refreshUsers() async {
    await loadUsers();
  }

  // Méthode pour obtenir un utilisateur par son ID
  AppUser? getUserById(int userId) {
    try {
      return _users.firstWhere((user) => user.id == userId);
    } catch (e) {
      return null;
    }
  }

  // Méthode pour obtenir les utilisateurs par rôle
  List<AppUser> getUsersByRole(String role) {
    return _users.where((user) => user.roles?.contains(role) ?? false).toList();
  }

  // Méthode pour obtenir le nombre total d'utilisateurs
  int get totalUsers => _users.length;

  // Méthode pour obtenir le nombre d'utilisateurs par rôle
  Map<String, int> getUsersCountByRole() {
    final Map<String, int> count = {
      'admin': 0,
      'chef': 0,
      'serveur': 0,
      'delivery': 0,
      'client': 0,
    };
    
    for (var user in _users) {
      if (user.roles?.contains('ROLE_ADMIN') ?? false) {
        count['admin'] = (count['admin'] ?? 0) + 1;
      } else if (user.roles?.contains('ROLE_CHEF') ?? false) {
        count['chef'] = (count['chef'] ?? 0) + 1;
      } else if (user.roles?.contains('ROLE_SERVEUR') ?? false) {
        count['serveur'] = (count['serveur'] ?? 0) + 1;
      } else if (user.roles?.contains('ROLE_DELIVERY') ?? false) {
        count['delivery'] = (count['delivery'] ?? 0) + 1;
      } else {
        count['client'] = (count['client'] ?? 0) + 1;
      }
    }
    
    return count;
  }
}