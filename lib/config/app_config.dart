// config/app_config.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class AppConfig {
  // Base URL for API
  static const String baseUrl = 'http://10.0.2.2:8080'; // Android emulator
  
  // Metabase configuration
  static String get metabaseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000';
    }
    
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000'; // Android emulator
    }
    
    if (Platform.isIOS) {
      return 'http://localhost:3000'; // iOS simulator
    }
    
    return 'http://localhost:3000'; // Default
  }
  
  static String get dashboardUrl => '$metabaseUrl/dashboard/1-e-commerce-insights';
  
  // Colors (static, not const)
  static final Color primaryColor = const Color(0xFFDF8EFF);
  static final Color secondaryColor = const Color(0xFF00EEFC);
  static final Color surfaceColor = const Color(0xFF0E0E11);
  static final Color surfaceContainer = const Color(0xFF19191D);
  static final Color onSurfaceVariant = const Color(0xFFACAAAE);
  static final Color successColor = const Color(0xFF2ECC71);
  static final Color warningColor = const Color(0xFFF39C12);
  static final Color errorColor = const Color(0xFFD73357);
}