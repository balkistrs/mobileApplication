import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthProvider with ChangeNotifier {
  AppUser? _user;
  int? _userId;

  String? _token;
  bool _isLoading = false;
  String? _selectedRole;
  
  int? get userId => _userId;
  AppUser? get user => _user;
  String? get token => _token;
  bool get isAuth => _token != null;
  bool get isLoading => _isLoading;
  String? get selectedRole => _selectedRole;

  static const String baseUrl = 'https://13a4-2c0f-f698-c140-2d52-c49a-dac6-216d-2512.ngrok-free.app/api';

  // Helper function
  int min(int a, int b) => a < b ? a : b;

  // Méthode pour obtenir la route de redirection
  String getRedirectRoute() {
    if (isAdmin) return '/admin';
    if (isChef) return '/chef';
    if (isServeur) return '/serveur';
    if (isClient) return '/client';
    return '/home';
  }

  Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/test'),
        headers: {
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 90));
      
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Connection test failed: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('🔐 Attempting login for: $email');
      
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 90));

      debugPrint('📩 Login response status: ${response.statusCode}');
      debugPrint('📩 Login response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        final responseData = data['data'];
        _token = responseData['token'];
        
        if (_token == null) {
          debugPrint('❌ CRITICAL: Token is null in login response!');
          debugPrint('❌ Full response data: $data');
          throw Exception('Server did not return a token');
        }
        
        if (_token!.isEmpty) {
          debugPrint('❌ CRITICAL: Token is empty in login response!');
          throw Exception('Server returned an empty token');
        }
        
        debugPrint('✅ Token received successfully');
        debugPrint('✅ Token preview: ${_token!.substring(0, min(50, _token!.length))}...');
        debugPrint('✅ Token length: ${_token!.length}');
        
        _user = AppUser.fromJson(responseData['user'] ?? {});
        _userId = _user?.id;
        
        debugPrint('✅ Login response user data: ${responseData['user']}');
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);
        await prefs.setString('user', json.encode(_user!.toJson()));
        await prefs.setInt('userId', _userId!);
        
        debugPrint('✅ Token and user ID saved to shared preferences');
        
        _isLoading = false;
        notifyListeners();
        
        return {
          'success': true,
          'message': 'Connexion réussie',
          'redirectRoute': getRedirectRoute()
        };
      } else {
        debugPrint('❌ Login failed: ${response.statusCode} ${response.body}');
        _isLoading = false;
        notifyListeners();
        return {
          'success': false,
          'message': 'Échec de la connexion: ${response.statusCode}'
        };
      }
    } catch (e) {
      debugPrint('❌ Login error: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      _isLoading = false;
      notifyListeners();
      return {
        'success': false,
        'message': 'Erreur de connexion: $e'
      };
    }
  }

  Future<Map<String, dynamic>> register(String email, String password, String role) async {
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('📨 Sending registration request: $email, role: $role');
      
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'email': email,
          'password': password,
          'role': role
        }),
      ).timeout(const Duration(seconds: 30));

      debugPrint('📩 Register response: ${response.statusCode} ${response.body}');

      _isLoading = false;
      notifyListeners();
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = json.decode(response.body);
        debugPrint('📩 Decoded register body: $decoded');

        final responseData = decoded['data'] ?? {};
        _token = responseData['token'];
        _user = AppUser.fromJson(responseData['user'] ?? {});

        if (_token == null || _token!.isEmpty) {
          debugPrint('❌ Register: token missing in response');
          return {'success': false, 'message': 'Le serveur n\'a pas renvoyé de token'};
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);
        await prefs.setString('user', json.encode(_user!.toJson()));

        debugPrint('✅ Registration successful, token saved');

        notifyListeners();
        return {
          'success': true,
          'message': 'Inscription réussie',
          'redirectRoute': getRedirectRoute()
        };
      } else {
        final responseBody = json.decode(response.body);
        String errorMessage = 'Erreur d\'inscription (${response.statusCode})';

        if (responseBody is Map && responseBody['message'] != null) {
          errorMessage = responseBody['message'];
        } else if (responseBody is Map && responseBody['error'] != null) {
          errorMessage = responseBody['error'];
        }

        debugPrint('❌ Register failed: $errorMessage');
        return {'success': false, 'message': errorMessage};
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ Register error: $e');
      
      String errorMessage = 'Erreur de connexion';
      if (e.toString().contains('Failed host lookup') || 
          e.toString().contains('Connection failed')) {
        errorMessage = 'Impossible de se connecter au serveur. Vérifiez votre connexion Internet.';
      } else if (e.toString().contains('Timeout')) {
        errorMessage = 'Le serveur met trop de temps à répondre. Veuillez réessayer.';
      }
      
      return {'success': false, 'message': errorMessage};
    }
  }

  Future<List<AppUser>> getUsers() async {
    try {
      final url = '$baseUrl/admin/users';
      debugPrint('🔄 Calling URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('📩 Response status: ${response.statusCode}');
      debugPrint('📩 Full response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        final responseData = data['data'];
        final List<dynamic> usersData = responseData['users'] ?? [];
        
        debugPrint('✅ Successfully loaded ${usersData.length} users');
        return usersData.map((userData) => AppUser.fromJson(userData)).toList();
      } else {
        debugPrint('❌ Get users failed with status: ${response.statusCode}');
        throw Exception('Failed to load users: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Get users error: $e');
      throw Exception('Failed to load users: $e');
    }
  }
Future<List<Map<String, dynamic>>> getOrders() async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/real-orders'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
        'Accept': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
    ).timeout(const Duration(seconds: 10));

    debugPrint('📩 Orders response status: ${response.statusCode}');
    debugPrint('📩 Orders response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      
      // Adapter selon le format de votre réponse
      List<dynamic> ordersData = [];
      
      if (data is Map) {
        if (data.containsKey('success') && data['success'] == true) {
          if (data.containsKey('data') && data['data'] is Map) {
            ordersData = data['data']['orders'] ?? [];
          } else if (data.containsKey('orders')) {
            ordersData = data['orders'];
          }
        } else if (data.containsKey('orders')) {
          ordersData = data['orders'];
        }
      } else if (data is List) {
        ordersData = data;
      }
      
      // Convertir en List<Map<String, dynamic>>
      final List<Map<String, dynamic>> orders = [];
      for (var order in ordersData) {
        if (order is Map<String, dynamic>) {
          orders.add(order);
        }
      }
      
      debugPrint('✅ Successfully loaded ${orders.length} orders');
      return orders;
    } else {
      debugPrint('❌ Failed to load orders: ${response.statusCode}');
      return [];
    }
  } catch (e) {
    debugPrint('Get orders error: $e');
    return [];
  }
}

  Future<List<Map<String, dynamic>>> _getMockOrders() async {
    return [
      {
        'id': 1,
        'status': 'pending',
        'total': 25.50,
        'user': 'client@example.com',
        'orderItems': [
          {'name': 'Pizza Margherita', 'quantity': 1, 'price': 12.50},
          {'name': 'Coca-Cola', 'quantity': 2, 'price': 6.50}
        ],
        'createdAt': '2025-09-02 18:52:36',
        'updatedAt': '2025-09-02 18:52:38'
      },
      {
        'id': 2,
        'status': 'preparing',
        'total': 18.75,
        'user': 'client2@example.com',
        'orderItems': [
          {'name': 'Pasta Carbonara', 'quantity': 1, 'price': 15.25},
          {'name': 'Eau minérale', 'quantity': 1, 'price': 3.50}
        ],
        'createdAt': '2025-09-02 19:30:15',
        'updatedAt': '2025-09-02 19:35:22'
      }
    ];
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/products-list'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 10));

      debugPrint('📩 Products response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        List<dynamic> productsData = [];
        
        if (data is Map && data.containsKey('success') && data['success'] == true) {
          final responseData = data['data'] ?? {};
          if (responseData is List) {
            productsData = responseData;
          } else if (responseData is Map && responseData.containsKey('products')) {
            productsData = responseData['products'] ?? [];
          } else if (responseData is Map) {
            productsData = responseData.values.toList();
          }
        } else if (data is List) {
          productsData = data;
        }
        
        final List<Map<String, dynamic>> products = [];
        
        for (var product in productsData) {
          if (product is Map<String, dynamic>) {
            products.add({
              'id': product['id'].toString(),
              'name': product['name'] ?? 'Unknown',
              'price': (product['price'] is String) 
                ? double.tryParse(product['price']) ?? 0.0
                : (product['price'] ?? 0.0).toDouble(),
              'category': product['category'] ?? 'Other',
              'image': product['image'] ?? 'https://via.placeholder.com/200',
              'rating': product['rating'] ?? 4.0,
              'prepTime': product['prepTime'] ?? '15-20 min',
              'isPopular': product['isPopular'] ?? false,
            });
          }
        }
        
        debugPrint('✅ Successfully loaded ${products.length} products');
        return products;
      } else {
        debugPrint('❌ Products endpoint error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Get products error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUserNotifications() async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/notifications'),
      headers: {
        'Authorization': 'Bearer $_token',
        'ngrok-skip-browser-warning': 'true',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));

    debugPrint('📩 Notifications response status: ${response.statusCode}');
    debugPrint('📩 Notifications response body: ${response.body}');

    final responseBody = response.body.trim();
    if (responseBody.startsWith('<!DOCTYPE') || 
        responseBody.startsWith('<html') ||
        responseBody.contains('<!DOCTYPE')) {
      debugPrint('❌ API returned HTML instead of JSON for notifications');
      return [];
    }

    if (response.statusCode == 200) {
      try {
        final data = json.decode(responseBody);
        
        // Gérer différents formats de réponse
        List<dynamic> notificationsData = [];
        
        if (data is Map) {
          if (data.containsKey('data') && data['data'] is List) {
            notificationsData = data['data'];
          } else if (data.containsKey('notifications') && data['notifications'] is List) {
            notificationsData = data['notifications'];
          }
        } else if (data is List) {
          notificationsData = data;
        }
        
        final List<Map<String, dynamic>> notifications = [];
        
        for (var notif in notificationsData) {
          if (notif is Map<String, dynamic>) {
            Map<String, dynamic> processedNotif = {};
            
            notif.forEach((key, value) {
              // Gestion spéciale pour le champ 'id'
              if (key == 'id') {
                if (value is String) {
                  processedNotif[key] = int.tryParse(value) ?? 0;
                } else if (value is int) {
                  processedNotif[key] = value;
                } else {
                  processedNotif[key] = 0;
                }
              }
              // Gestion spéciale pour le champ 'orderId'
              else if (key == 'orderId') {
                if (value is String) {
                  processedNotif[key] = int.tryParse(value) ?? 0;
                } else if (value is int) {
                  processedNotif[key] = value;
                } else {
                  processedNotif[key] = 0;
                }
              }
              // Gestion spéciale pour le champ 'user' (qui peut être une chaîne comme "/api/users/1")
              else if (key == 'user') {
                if (value is String) {
                  // Extraire l'ID du format "/api/users/1"
                  final parts = value.split('/');
                  final userIdStr = parts.last;
                  processedNotif['userId'] = int.tryParse(userIdStr) ?? 0;
                  processedNotif[key] = value; // Garder la chaîne originale
                } else if (value is Map) {
                  processedNotif[key] = value;
                } else {
                  processedNotif[key] = value;
                }
              }
              // Gestion du champ 'isRead'
              else if (key == 'isRead') {
                if (value is bool) {
                  processedNotif[key] = value;
                } else if (value is int) {
                  processedNotif[key] = value == 1;
                } else if (value is String) {
                  processedNotif[key] = value.toLowerCase() == 'true';
                } else {
                  processedNotif[key] = false;
                }
              }
              // Pour tous les autres champs
              else {
                processedNotif[key] = value;
              }
            });
            
            // S'assurer que les champs obligatoires existent
            processedNotif['id'] ??= 0;
            processedNotif['isRead'] ??= false;
            processedNotif['title'] ??= 'Notification';
            processedNotif['message'] ??= '';
            processedNotif['type'] ??= 'info';
            processedNotif['created_at'] ??= processedNotif['createdAt'] ?? DateTime.now().toIso8601String();
            
            notifications.add(processedNotif);
          }
        }
        
        debugPrint('✅ Successfully loaded ${notifications.length} notifications');
        return notifications;
      } catch (e) {
        debugPrint('❌ JSON decode error: $e');
        debugPrint('❌ Response body: $responseBody');
        return [];
      }
    } else {
      debugPrint('❌ Failed to load notifications: ${response.statusCode}');
      return [];
    }
  } catch (e) {
    debugPrint('Error fetching notifications: $e');
    return [];
  }
}

  Future<bool> deleteNotification(int notificationId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/notifications/$notificationId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Delete notification error: $e');
      return false;
    }
  }

  Future<bool> markNotificationAsRead(int notificationId) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/notifications/$notificationId/read'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Mark notification read error: $e');
      return false;
    }
  }

  Future<bool> updateUser(String email, String newEmail, String newName, String? role) async {
    try {
      final encodedEmail = Uri.encodeComponent(email);
      final body = {
        'email': newEmail,
        'name': newName,
      };
      if (role != null && role.isNotEmpty && hasRole('ROLE_ADMIN')) {
        body['role'] = role;
      }

      final response = await http.put(
        Uri.parse('$baseUrl/users/$encodedEmail'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode(body),
      ).timeout(const Duration(seconds: 10));

      debugPrint('📩 Update user response: ${response.statusCode} ${response.body}');
      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          final updatedUser = AppUser.fromJson(data['data']?['user'] ?? {});
          if (updatedUser.id > 0) {
            _user = updatedUser;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user', json.encode(_user!.toJson()));
            notifyListeners();
          } else {
            if (_user != null) {
              _user = AppUser(id: _user!.id, email: newEmail, name: newName, roles: _user!.roles);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('user', json.encode(_user!.toJson()));
              notifyListeners();
            }
          }
        } catch (_) {}
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Update user error: $e');
      return false;
    }
  }

  Future<bool> deleteUser(String email) async {
    try {
      final encodedEmail = Uri.encodeComponent(email);
      debugPrint('🗑️ Deleting user with email: $email (encoded: $encodedEmail)');
      
      final response = await http.delete(
        Uri.parse('$baseUrl/admin/users/$encodedEmail'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('📩 Delete user response status: ${response.statusCode}');
      debugPrint('📩 Delete user response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      } else if (response.statusCode == 204) {
        return true;
      } else if (response.statusCode == 404) {
        debugPrint('❌ User not found (404)');
        return false;
      }
      
      debugPrint('❌ Delete failed with status: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('❌ Delete user error: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      
      if (e is http.ClientException) {
        debugPrint('❌ Network error: ${e.message}');
        debugPrint('❌ URI: ${e.uri}');
      }
      
      return false;
    }
  }

  Future<bool> updateOrderStatus(String orderId, String status) async {
    try {
      final englishStatus = _convertStatusToEnglish(status);
      
      debugPrint('🔄 Updating order $orderId to status: $englishStatus (original: $status)');
      debugPrint('📞 Calling: $baseUrl/orders/$orderId/status');
      debugPrint('📞 Using method: PUT');
      
      final response = await http.put(
        Uri.parse('$baseUrl/orders/$orderId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({'status': englishStatus}),
      ).timeout(const Duration(seconds: 10));

      debugPrint('📩 Update response status: ${response.statusCode}');
      debugPrint('📩 Update response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final success = data['success'] == true;
        debugPrint('✅ Update successful: $success');
        
        if (success) {
          debugPrint('✅ Server confirmed status update');
        } else {
          debugPrint('❌ Server returned success:false');
        }
        
        return success;
      } else if (response.statusCode == 404) {
        debugPrint('❌ Order not found on server');
        return false;
      } else if (response.statusCode == 401) {
        debugPrint('❌ Unauthorized - token may be invalid');
        return false;
      } else if (response.statusCode == 405) {
        debugPrint('❌ Method Not Allowed - Vérifiez que votre API accepte PUT');
        return false;
      }
      
      debugPrint('❌ Update failed with status: ${response.statusCode}');
      return false;
      
    } catch (e) {
      debugPrint('❌ Update order status error: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      
      if (e is http.ClientException) {
        debugPrint('❌ Network error: ${e.message}');
      }
      
      return false;
    }
  }

  String getStatusText(String status) {
    switch (status) {
      case 'paid': return 'Payée';
      case 'pending': return 'En attente';
      case 'cancelled': return 'Annulée';
      case 'completed': return 'Terminée';
      case 'en attente': return 'En attente';
      case 'payée': return 'Payée';
      case 'annulée': return 'Annulée';
      case 'terminée': return 'Terminée';
      default: return status;
    }
  }

  String _convertStatusToEnglish(String frenchStatus) {
    switch (frenchStatus.toLowerCase()) {
      case 'en attente': return 'pending';
      case 'payée': return 'paid';
      case 'annulée': return 'cancelled';
      case 'terminée': return 'completed';
      default: return frenchStatus;
    }
  }

  Future<void> tryAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final userJson = prefs.getString('user');
      final userId = prefs.getInt('userId');
      
      debugPrint('🔍 Auto login check - Token: ${token != null}');
      debugPrint('🔍 Auto login check - User: ${userJson != null}');
      debugPrint('🔍 Auto login check - User ID: ${userId != null}');
      
      if (token != null && userJson != null) {
        _token = token;
        _user = AppUser.fromJson(json.decode(userJson));
        _userId = userId;
        debugPrint('✅ Auto login successful');
        notifyListeners();
      } else {
        debugPrint('❌ Auto login failed: Missing token or user data');
      }
    } catch (e) {
      debugPrint('❌ Auto login failed: $e');
    }
  }

  Future<void> logout() async {
    _user = null;
    _token = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
    
    debugPrint('✅ Logout successful');
    notifyListeners();
  }

  Map<String, dynamic> parseJwt(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw Exception('Invalid token');
    }
    
    final payload = _decodeBase64(parts[1]);
    final payloadMap = json.decode(payload);
    if (payloadMap is! Map<String, dynamic>) {
      throw Exception('Invalid payload');
    }
    
    return payloadMap;
  }

  String _decodeBase64(String str) {
    String output = str.replaceAll('-', '+').replaceAll('_', '/');
    
    switch (output.length % 4) {
      case 0:
        break;
      case 2:
        output += '==';
        break;
      case 3:
        output += '=';
        break;
      default:
        throw Exception('Illegal base64url string!"');
    }
    
    return utf8.decode(base64Url.decode(output));
  }

  void debugJwtContent() {
    if (_token == null) {
      debugPrint('No token available');
      return;
    }
    
    try {
      final payload = parseJwt(_token!);
      debugPrint('JWT Payload content:');
      payload.forEach((key, value) {
        debugPrint('  $key: $value (${value.runtimeType})');
      });
    } catch (e) {
      debugPrint('Error debugging JWT: $e');
    }
  }

  String? getUserEmail() {
    if (_user?.email != null && _user!.email.isNotEmpty) {
      return _user!.email;
    }
    
    if (_token != null) {
      try {
        final payload = parseJwt(_token!);
        debugPrint('JWT Payload for email: $payload');
        
        final email = payload['email'] ?? 
                     payload['username'] ?? 
                     payload['sub'];
        
        if (email is String && email.isNotEmpty) {
          return email;
        }
      } catch (e) {
        debugPrint('Error getting email from JWT: $e');
      }
    }
    
    debugPrint('Email not found in user object or JWT');
    return null;
  }

  int? getUserId() {
    if (_user?.id != null) {
      return _user!.id;
    }
    
    if (_token != null) {
      try {
        final payload = parseJwt(_token!);
        
        final userId = payload['id'] ?? 
                      payload['user_id'] ?? 
                      payload['userId'] ??
                      payload['sub'];
        
        if (userId is int) return userId;
        if (userId is String) return int.tryParse(userId);
        if (userId is double) return userId.toInt();
      } catch (e) {
        debugPrint('Error getting user ID from JWT: $e');
      }
    }
    
    return null;
  }

  void setSelectedRole(String role) {
    _selectedRole = role;
    notifyListeners();
  }

  bool hasRole(String role) {
    if (_token != null) {
      try {
        final payload = parseJwt(_token!);
        final roles = payload['roles'] ?? [];
        if (roles is List && roles.contains(role)) {
          return true;
        }
      } catch (e) {
        debugPrint('Error checking role in JWT: $e');
      }
    }
    
    if (_user != null) {
      if (_user!.roles != null && _user!.roles!.contains(role)) {
        return true;
      }
    }
    
    return false;
  }

  Future<bool> submitVote(int stars) async {
    try {
      if (_token == null) {
        debugPrint('❌ No token available for vote submission');
        return false;
      }

      debugPrint('⭐ Submitting vote with $stars stars');
      
      final response = await http.put(
        Uri.parse('$baseUrl/users/${_user?.email}/vote'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({'vote': stars.toString()}),
      ).timeout(const Duration(seconds: 10));

      debugPrint('📩 Vote response status: ${response.statusCode}');
      debugPrint('📩 Vote response body: ${response.body}');

      if (response.statusCode == 200) {
        
        if (_user != null) {
          _user = AppUser(
            id: _user!.id,
            email: _user!.email,
            name: _user!.name,
            roles: _user!.roles,
            vote: stars.toString(),
          );
          notifyListeners();
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_vote', stars.toString());
        }
        
        debugPrint('✅ Vote submitted successfully: $stars stars');
        return true;
      } else {
        debugPrint('❌ Vote submission failed with status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Vote submission error: $e');
      return false;
    }
  }

  bool get isAdmin => hasRole('ROLE_ADMIN');
  bool get isChef => hasRole('ROLE_CHEF');
  bool get isServeur => hasRole('ROLE_SERVEUR');
  bool get isClient => hasRole('ROLE_CLIENT');
  bool get isRestaurateur => hasRole('ROLE_RESTAURANT');
  bool get isLivreur => hasRole('ROLE_DELIVERY');
}