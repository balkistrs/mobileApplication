import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:resto_app/screens/admin_screen.dart';
import 'package:resto_app/screens/ChefScreen.dart';
import 'package:resto_app/screens/ServeurScreen.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'screens/login_screen.dart';
import 'screens/restaurant_screen.dart';
import 'screens/payment.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Restaurant App',
        theme: ThemeData(
          useMaterial3: true, 
          colorSchemeSeed: const Color(0xFF6A5ACD),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF6A5ACD),
            foregroundColor: Colors.white,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6A5ACD),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ),
        initialRoute: '/login',
        routes: {
          '/login': (context) => const LoginScreen(),
          '/menu': (context) => const RestaurantScreen(),
          '/chef': (context) => const ChefScreen(), 
          
          '/serveur': (context) => const ServeurScreen(), 
          '/admin': (context) => const AdminScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/payment') {
            final args = settings.arguments as double;
            return MaterialPageRoute(
              builder: (context) => PaymentScreen(totalAmount: args),
            );
          }
          return null;
        },
      ),
    );
  }
}