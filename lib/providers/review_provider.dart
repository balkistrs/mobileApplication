import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/review_model.dart';
import 'auth_provider.dart';

class ReviewProvider extends ChangeNotifier {
  List<ReviewModel> _reviews = [];
  bool _isLoading = false;
  String? _error;
  double _averageRating = 0.0;
  int _totalReviews = 0;

  List<ReviewModel> get reviews => _reviews;
  bool get isLoading => _isLoading;
  String? get error => _error;
  double get averageRating => _averageRating;
  int get totalReviews => _totalReviews;

  Future<void> loadReviews(String productId) async {
    setLoading(true);
    try {
      final response = await http.get(
        Uri.parse('${AuthProvider.baseUrl}/reviews/product/$productId'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> reviewsData = [];
        
        if (data is List) {
          reviewsData = data;
        } else if (data['data'] is List) {
          reviewsData = data['data'];
        } else if (data['reviews'] is List) {
          reviewsData = data['reviews'];
        }

        _reviews = reviewsData.map((r) => ReviewModel.fromJson(r)).toList();
        _calculateStats();
        notifyListeners();
      }
    } catch (e) {
      _error = 'Error loading reviews: $e';
      notifyListeners();
    } finally {
      setLoading(false);
    }
  }

  Future<bool> submitReview(ReviewModel review, String token) async {
    setLoading(true);
    try {
      final response = await http.post(
        Uri.parse('${AuthProvider.baseUrl}/reviews'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode(review.toJson()),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 201 || response.statusCode == 200) {
        _reviews.insert(0, review);
        _calculateStats();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = 'Error submitting review: $e';
      notifyListeners();
      return false;
    } finally {
      setLoading(false);
    }
  }

  Future<bool> hasUserReviewed(String userId, String orderId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AuthProvider.baseUrl}/reviews/check?userId=$userId&orderId=$orderId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['hasReviewed'] ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void _calculateStats() {
    if (_reviews.isEmpty) {
      _averageRating = 0.0;
      _totalReviews = 0;
      return;
    }
    
    _totalReviews = _reviews.length;
    _averageRating = _reviews.map((r) => r.rating).reduce((a, b) => a + b) / _totalReviews;
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}