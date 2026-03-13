import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:resto_app/screens/admin_screen.dart';
import 'package:resto_app/screens/chef_screen.dart';
import 'package:resto_app/screens/serveur_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/user_provider.dart';
import 'screens/login_screen.dart';
import 'screens/restaurant_screen.dart';
import 'screens/payment.dart';
import 'screens/admin_profile_screen.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Créer l'instance AuthProvider
  final authProvider = AuthProvider();
  
  // Charger les préférences (token, etc.)
  await authProvider.tryAutoLogin();
  
  runApp(MyApp(authProvider: authProvider));
}

class MyApp extends StatelessWidget {
  final AuthProvider authProvider;
  
  const MyApp({super.key, required this.authProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // AuthProvider déjà initialisé
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        
        // CartProvider
        ChangeNotifierProvider<CartProvider>(create: (_) => CartProvider()),
        
        // UserProvider dépend de AuthProvider pour le token
        ChangeNotifierProxyProvider<AuthProvider, UserProvider>(
          create: (_) => UserProvider(),
          update: (_, authProvider, userProvider) {
            if (userProvider == null) throw Exception('UserProvider non initialisé');
            if (authProvider.token != null) {
              userProvider.setToken(authProvider.token!);
            }
            return userProvider;
          },
        ),
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