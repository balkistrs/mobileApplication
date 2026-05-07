import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/auth_provider.dart';
import '../models/notification_model.dart';

class NotificationProvider extends ChangeNotifier {
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;
  final AuthProvider _authProvider;

  NotificationProvider(this._authProvider);

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  // ✅ AJOUTEZ CE GETTER
  int get unreadCount {
    return _notifications.where((n) => !n.isRead).length;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> fetchNotifications() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final token = _authProvider.token;
      if (token == null) {
        _errorMessage = 'Not authenticated';
        _setLoading(false);
        return;
      }

      final url = '${AuthProvider.baseUrl}/api/notifications';
      print('📢 Fetching notifications from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      print('📡 Notifications response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📦 Response data: $data');
        
        List<dynamic> notificationsList = [];
        
        if (data is List) {
          notificationsList = data;
        } else if (data['success'] == true) {
          if (data['data'] is List) {
            notificationsList = data['data'];
          } else if (data['notifications'] is List) {
            notificationsList = data['notifications'];
          }
        } else if (data['notifications'] is List) {
          notificationsList = data['notifications'];
        }
        
        _notifications = notificationsList.map((json) {
          return NotificationModel.fromJson(json);
        }).toList();
        
        print('✅ Loaded ${_notifications.length} notifications');
        print('📊 Unread count: ${unreadCount}');
        _errorMessage = null;
      } else if (response.statusCode == 401) {
        _errorMessage = 'Session expired';
        _notifications = [];
      } else {
        _errorMessage = 'Server error: ${response.statusCode}';
        _notifications = [];
      }
    } catch (e) {
      print('❌ Failed to load notifications: $e');
      _errorMessage = 'Connection error: $e';
      _notifications = [];
    } finally {
      _setLoading(false);
    }
  }

  Future<void> markAsRead(int id) async {
    try {
      final token = _authProvider.token;
      if (token == null) return;

      final url = '${AuthProvider.baseUrl}/api/notifications/$id/read';
      print('📢 Marking notification $id as read from: $url');

      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await fetchNotifications();
      } else {
        print('Failed to mark as read: ${response.statusCode}');
      }
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> deleteNotification(int id) async {
    try {
      final token = _authProvider.token;
      if (token == null) return;

      final url = '${AuthProvider.baseUrl}/api/notifications/$id';
      print('📢 Deleting notification $id from: $url');

      final response = await http.delete(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await fetchNotifications();
      } else {
        print('Failed to delete notification: ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final token = _authProvider.token;
      if (token == null) return;

      final url = '${AuthProvider.baseUrl}/api/notifications/mark-all-read';
      print('📢 Marking all notifications as read from: $url');

      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await fetchNotifications();
      } else {
        print('Failed to mark all as read: ${response.statusCode}');
      }
    } catch (e) {
      print('Error marking all as read: $e');
    }
  }

  Future<void> deleteAllNotifications() async {
    try {
      final token = _authProvider.token;
      if (token == null) return;

      final url = '${AuthProvider.baseUrl}/api/notifications';
      print('📢 Deleting all notifications from: $url');

      final response = await http.delete(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await fetchNotifications();
      } else {
        print('Failed to delete all notifications: ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting all notifications: $e');
    }
  }
}