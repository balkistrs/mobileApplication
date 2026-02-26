// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://13a4-2c0f-f698-c140-2d52-c49a-dac6-216d-2512.ngrok-free.app/api';

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Create order
  Future<int> createOrder(List<Map<String, dynamic>> items) async {
    final token = await _getToken();
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/orders'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'items': items,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return data['order_id'];
      } else {
        throw Exception('Failed to create order: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Process payment
  Future<Map<String, dynamic>> processPayment(int orderId, double amount) async {
    final token = await _getToken();
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/payment/process'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'order_id': orderId,
          'amount': amount,
        }),
      );

      if (response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception('Payment failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get order status
  Future<String> getOrderStatus(int orderId) async {
    final token = await _getToken();
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/payment/status/$orderId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['payment_status'];
      } else {
        throw Exception('Failed to get order status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
