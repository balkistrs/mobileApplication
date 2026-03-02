import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  static const String baseUrl = 'https://13a4-2c0f-f698-c140-2d52-c49a-dac6-216d-2512.ngrok-free.app/api';

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

  // MÉTHODE GOOGLE SIGN-IN UNIFIÉE
  Future<Map<String, dynamic>> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('🔐 Tentative de connexion avec Google');
      
      // Sign out first to ensure clean state
      await _googleSignIn.signOut();
      
      // Get Google user
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return {
          'success': false,
          'message': 'Connexion annulée'
        };
      }

      // Get authentication (required for both web and mobile)
      await googleUser.authentication;
      
      // Prepare request body - ONLY what the backend needs
      final Map<String, dynamic> requestBody = {
        'email': googleUser.email,
        'name': googleUser.displayName ?? googleUser.email.split('@')[0],
        'google_id': googleUser.id,
        'photo_url': googleUser.photoUrl,
      };

      debugPrint('📤 Envoi requête à: $baseUrl/auth/google');
      debugPrint('📤 Body: $requestBody');

      final response = await http.post(
        Uri.parse('$baseUrl/auth/google'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 30));

      debugPrint('📩 Status code: ${response.statusCode}');
      debugPrint('📩 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        final responseData = data['data'] ?? data;
        
        _token = responseData['token'];
        
        if (_token == null) {
          throw Exception('Token non reçu du serveur');
        }
        
        // Parse user data safely
        final userData = responseData['user'] ?? {};
        
        _user = AppUser(
          id: userData['id'] ?? 0,
          email: userData['email'] ?? googleUser.email,
          name: userData['name'] ?? googleUser.displayName ?? googleUser.email.split('@')[0],
          roles: _parseRoles(userData['roles']),
          googleId: userData['google_id'] ?? googleUser.id,
          photoUrl: userData['photo_url'] ?? googleUser.photoUrl,
        );
        
        _userId = _user?.id;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);
        await prefs.setString('user', json.encode(_user!.toJson()));
        if (_userId != null) {
          await prefs.setInt('userId', _userId!);
        }
        await prefs.setBool('isGoogleUser', true);
        
        _isLoading = false;
        notifyListeners();

        debugPrint('✅ Utilisateur Google connecté avec rôle: ${_user?.roles}');
        
        return {
          'success': true,
          'message': 'Connexion réussie avec Google',
          'redirectRoute': getRedirectRoute()
        };
      } else {
        _isLoading = false;
        notifyListeners();
        
        String errorMessage = 'Échec de l\'authentification avec le serveur';
        try {
          final errorData = json.decode(response.body);
          errorMessage = errorData['error'] ?? errorData['message'] ?? errorMessage;
          debugPrint('❌ Error from server: $errorMessage');
        } catch (_) {}
        
        return {
          'success': false,
          'message': errorMessage
        };
      }
    } catch (e) {
      debugPrint('❌ Google Sign-In error: $e');
      _isLoading = false;
      notifyListeners();
      
      String errorMessage = 'Erreur de connexion';
      if (e.toString().contains('popup')) {
        errorMessage = 'La fenêtre de connexion Google a été fermée. Veuillez autoriser les popups pour ce site.';
      } else {
        errorMessage = 'Erreur de connexion: ${e.toString()}';
      }
      
      return {
        'success': false,
        'message': errorMessage
      };
    }
  }

  // Helper method to parse roles safely
  List<String> _parseRoles(dynamic roles) {
    if (roles == null) {
      debugPrint('⚠️ Aucun rôle fourni, utilisation de ROLE_CLIENT par défaut');
      return ['ROLE_CLIENT'];
    }
    
    debugPrint('📦 Parsing roles: $roles (type: ${roles.runtimeType})');
    
    if (roles is List) {
      final List<String> roleList = roles.map((role) {
        if (role is String) return role;
        if (role is Map && role.containsKey('role')) return role['role'].toString();
        return role.toString();
      }).toList();
      
      debugPrint('✅ Roles parsed from List: $roleList');
      return roleList.isNotEmpty ? roleList : ['ROLE_CLIENT'];
    }
    
    if (roles is String) {
      if (roles.startsWith('[') && roles.endsWith(']')) {
        try {
          final parsed = json.decode(roles);
          if (parsed is List) {
            final List<String> roleList = parsed.map((e) => e.toString()).toList();
            debugPrint('✅ Roles parsed from JSON string: $roleList');
            return roleList.isNotEmpty ? roleList : ['ROLE_CLIENT'];
          }
        } catch (e) {
          debugPrint('⚠️ Failed to parse roles JSON: $e');
        }
      }
      
      debugPrint('✅ Single role from string: [$roles]');
      return [roles];
    }
    
    debugPrint('⚠️ Unknown roles format, using ROLE_CLIENT');
    return ['ROLE_CLIENT'];
  }

  // MÉTHODE POUR DÉCONNEXION GOOGLE
  Future<void> signOutGoogle() async {
    try {
      await _googleSignIn.signOut();
      debugPrint('✅ Déconnexion Google réussie');
    } catch (e) {
      debugPrint('❌ Erreur déconnexion Google: $e');
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
        
        if (_token == null || _token!.isEmpty) {
          throw Exception('Server did not return a valid token');
        }
        
        _user = AppUser.fromJson(responseData['user'] ?? {});
        _userId = _user?.id;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);
        await prefs.setString('user', json.encode(_user!.toJson()));
        await prefs.setInt('userId', _userId!);
        
        _isLoading = false;
        notifyListeners();
        
        return {
          'success': true,
          'message': 'Connexion réussie',
          'redirectRoute': getRedirectRoute()
        };
      } else {
        _isLoading = false;
        notifyListeners();
        return {
          'success': false,
          'message': 'Échec de la connexion: ${response.statusCode}'
        };
      }
    } catch (e) {
      debugPrint('❌ Login error: $e');
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
        final responseData = decoded['data'] ?? {};
        _token = responseData['token'];
        _user = AppUser.fromJson(responseData['user'] ?? {});

        if (_token == null || _token!.isEmpty) {
          return {'success': false, 'message': 'Le serveur n\'a pas renvoyé de token'};
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);
        await prefs.setString('user', json.encode(_user!.toJson()));

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
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final responseData = data['data'];
        final List<dynamic> usersData = responseData['users'] ?? [];
        return usersData.map((userData) => AppUser.fromJson(userData)).toList();
      } else {
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

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
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
        
        final List<Map<String, dynamic>> orders = [];
        for (var order in ordersData) {
          if (order is Map<String, dynamic>) {
            orders.add(order);
          }
        }
        
        return orders;
      } else {
        return [];
      }
    } catch (e) {
      debugPrint('Get orders error: $e');
      return [];
    }
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
        
        return products;
      } else {
        return [];
      }
    } catch (e) {
      debugPrint('❌ Get products error: $e');
      return [];
    }
  }

  Future<bool> submitOrderRating(int orderId, int rating) async {
    try {
      if (_token == null) {
        debugPrint('❌ No token available for rating submission');
        return false;
      }

      debugPrint('⭐ Soumission évaluation pour commande #$orderId: $rating étoiles');
      
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/orders/$orderId/rating'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_token',
            'Accept': 'application/json',
            'ngrok-skip-browser-warning': 'true',
          },
          body: json.encode({'rating': rating}),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200 || response.statusCode == 201) {
          debugPrint('✅ Évaluation soumise avec succès');
          await _saveRatingLocally(orderId, rating);
          return true;
        } else {
          debugPrint('❌ Échec de soumission évaluation: ${response.statusCode}');
          await _saveRatingLocally(orderId, rating);
          return true;
        }
      } catch (e) {
        debugPrint('❌ Rating submission error: $e');
        await _saveRatingLocally(orderId, rating);
        return true;
      }
    } catch (e) {
      debugPrint('❌ Global rating error: $e');
      return false;
    }
  }

  Future<void> _saveRatingLocally(int orderId, int rating) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ratingsKey = 'order_ratings_${_user?.id ?? 'guest'}';
      final existingRatings = prefs.getString(ratingsKey) ?? '{}';
      final Map<String, dynamic> ratingsMap = json.decode(existingRatings);
      
      ratingsMap[orderId.toString()] = {
        'rating': rating,
        'date': DateTime.now().toIso8601String(),
      };
      
      await prefs.setString(ratingsKey, json.encode(ratingsMap));
      debugPrint('✅ Évaluation sauvegardée localement pour la commande #$orderId');
    } catch (e) {
      debugPrint('❌ Erreur sauvegarde locale évaluation: $e');
    }
  }

  Future<int?> getOrderRatingLocally(int orderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ratingsKey = 'order_ratings_${_user?.id ?? 'guest'}';
      final existingRatings = prefs.getString(ratingsKey);
      
      if (existingRatings == null) return null;
      
      final Map<String, dynamic> ratingsMap = json.decode(existingRatings);
      if (ratingsMap.containsKey(orderId.toString())) {
        return ratingsMap[orderId.toString()]['rating'];
      }
      return null;
    } catch (e) {
      debugPrint('❌ Erreur récupération évaluation locale: $e');
      return null;
    }
  }

  Future<Map<int, int>> getAllLocalRatings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ratingsKey = 'order_ratings_${_user?.id ?? 'guest'}';
      final existingRatings = prefs.getString(ratingsKey);
      
      if (existingRatings == null) return {};
      
      final Map<String, dynamic> ratingsMap = json.decode(existingRatings);
      final Map<int, int> result = {};
      
      ratingsMap.forEach((key, value) {
        final orderId = int.tryParse(key);
        final rating = value['rating'];
        if (orderId != null && rating != null) {
          result[orderId] = rating;
        }
      });
      
      return result;
    } catch (e) {
      debugPrint('❌ Erreur chargement évaluations locales: $e');
      return {};
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

      final responseBody = response.body.trim();
      if (responseBody.startsWith('<!DOCTYPE') || 
          responseBody.startsWith('<html')) {
        return [];
      }

      if (response.statusCode == 200) {
        try {
          final data = json.decode(responseBody);
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
                if (key == 'id') {
                  if (value is String) {
                    processedNotif[key] = int.tryParse(value) ?? 0;
                  } else if (value is int) {
                    processedNotif[key] = value;
                  } else {
                    processedNotif[key] = 0;
                  }
                } else if (key == 'orderId') {
                  if (value is String) {
                    processedNotif[key] = int.tryParse(value) ?? 0;
                  } else if (value is int) {
                    processedNotif[key] = value;
                  } else {
                    processedNotif[key] = 0;
                  }
                } else if (key == 'isRead') {
                  if (value is bool) {
                    processedNotif[key] = value;
                  } else if (value is int) {
                    processedNotif[key] = value == 1;
                  } else if (value is String) {
                    processedNotif[key] = value.toLowerCase() == 'true';
                  } else {
                    processedNotif[key] = false;
                  }
                } else {
                  processedNotif[key] = value;
                }
              });
              
              processedNotif['id'] ??= 0;
              processedNotif['isRead'] ??= false;
              processedNotif['title'] ??= 'Notification';
              processedNotif['message'] ??= '';
              processedNotif['type'] ??= 'info';
              processedNotif['created_at'] ??= processedNotif['createdAt'] ?? DateTime.now().toIso8601String();
              
              notifications.add(processedNotif);
            }
          }
          
          return notifications;
        } catch (e) {
          return [];
        }
      } else {
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      return [];
    }
  }

  Future<bool> deleteNotification(int notificationId) async {
    try {
      if (_token == null) return false;
      
      final response = await http.delete(
        Uri.parse('$baseUrl/notifications/$notificationId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 10));
      
      return response.statusCode == 200 || response.statusCode == 204;
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

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          final updatedUser = AppUser.fromJson(data['data']?['user'] ?? {});
          if (updatedUser.id > 0) {
            _user = updatedUser;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user', json.encode(_user!.toJson()));
            notifyListeners();
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
      
      final response = await http.delete(
        Uri.parse('$baseUrl/admin/users/$encodedEmail'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      } else if (response.statusCode == 204) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Delete user error: $e');
      return false;
    }
  }

  Future<bool> updateOrderStatus(String orderId, String status) async {
    try {
      final englishStatus = _convertStatusToEnglish(status);
      
      final response = await http.put(
        Uri.parse('$baseUrl/orders/$orderId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({'status': englishStatus}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Update order status error: $e');
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
      
      if (token != null && userJson != null) {
        _token = token;
        _user = AppUser.fromJson(json.decode(userJson));
        _userId = userId;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Auto login failed: $e');
    }
  }

  @override
  Future<void> logout() async {
    await signOutGoogle();
    
    _user = null;
    _token = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
    await prefs.remove('userId');
    await prefs.remove('isGoogleUser');
    
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

  String? getUserEmail() {
    if (_user?.email != null && _user!.email.isNotEmpty) {
      return _user!.email;
    }
    
    if (_token != null) {
      try {
        final payload = parseJwt(_token!);
        final email = payload['email'] ?? payload['username'] ?? payload['sub'];
        if (email is String && email.isNotEmpty) {
          return email;
        }
      } catch (e) {}
    }
    
    return null;
  }

  int? getUserId() {
    if (_user?.id != null) {
      return _user!.id;
    }
    
    if (_token != null) {
      try {
        final payload = parseJwt(_token!);
        final userId = payload['id'] ?? payload['user_id'] ?? payload['userId'] ?? payload['sub'];
        if (userId is int) return userId;
        if (userId is String) return int.tryParse(userId);
        if (userId is double) return userId.toInt();
      } catch (e) {}
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
      } catch (e) {}
    }
    
    if (_user != null && _user!.roles != null) {
      return _user!.roles!.contains(role);
    }
    
    return false;
  }

  Future<bool> submitVote(int stars) async {
    try {
      if (_token == null) return false;

      final response = await http.put(
        Uri.parse('$baseUrl/users/${_user?.email}/vote'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({'vote': stars.toString()}),
      ).timeout(const Duration(seconds: 10));

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
        return true;
      }
      return false;
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