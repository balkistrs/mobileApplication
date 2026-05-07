import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// SCREENS
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/restaurant_screen.dart';
import 'screens/payment.dart';
import 'screens/admin_screen.dart';
import 'screens/chef_screen.dart';
import 'screens/serveur_screen.dart';
import 'screens/delivery_screen.dart';

// PROVIDERS
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/user_provider.dart';
import 'providers/notification_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final authProvider = AuthProvider();
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
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProxyProvider<AuthProvider, UserProvider>(
          create: (_) => UserProvider(),
          update: (_, auth, user) {
            if (user == null) throw Exception('UserProvider non initialisé');
            if (auth.token != null) {
              user.setToken(auth.token!);
            }
            return user;
          },
        ),
        // ✅ CORRIGÉ: NotificationProvider avec authProvider passé en paramètre
        ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (context) => NotificationProvider(authProvider),
          update: (_, auth, notif) {
            // Le NotificationProvider reçoit déjà authProvider dans son constructeur
            // Pas besoin de setToken ou setUserId
            return notif!;
          },
        ),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Yumix',
            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: const Color.fromARGB(255, 199, 154, 138),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color.fromARGB(255, 204, 148, 128),
                foregroundColor: Colors.white,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ),
            // Écran d'accueil basé sur l'état d'authentification
            home: _getHomeScreen(auth),
            routes: {
              '/home': (context) => const HomeScreen(),
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegisterScreen(),
              '/menu': (context) => const RestaurantScreen(),
              '/chef': (context) => const ChefScreen(),
              '/serveur': (context) => const ServeurScreen(),
              '/admin': (context) => const AdminScreen(),
              '/delivery': (context) => const DeliveryScreen(),
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
          );
        },
      ),
    );
  }

  /// Détermine l'écran d'accueil en fonction de l'état d'authentification et du rôle
  Widget _getHomeScreen(AuthProvider auth) {
    // Si l'utilisateur n'est pas authentifié, afficher l'écran de connexion
    if (!auth.isAuth) {
      debugPrint('🏠 User not authenticated, showing LoginScreen');
      return const LoginScreen();
    }

    // Afficher l'écran de chargement pendant que l'utilisateur se charge
    if (auth.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Récupérer la route de redirection basée sur le rôle
    final redirectRoute = auth.getRedirectRoute();
    debugPrint('🎯 User authenticated, redirecting to: $redirectRoute');
    debugPrint('📧 User email: ${auth.user?.email}');
    debugPrint('👤 User roles: ${auth.user?.roles}');
    debugPrint('🚚 isDelivery: ${auth.isDelivery}');
    debugPrint('👨‍🍳 isChef: ${auth.isChef}');
    debugPrint('🛎️ isServeur: ${auth.isServeur}');
    debugPrint('👑 isAdmin: ${auth.isAdmin}');
    debugPrint('🍽️ isClient: ${auth.isClient}');

    // Rediriger vers l'écran approprié
    switch (redirectRoute) {
      case '/admin':
        return const AdminScreen();
      case '/chef':
        return const ChefScreen();
      case '/serveur':
        return const ServeurScreen();
      case '/delivery':
        debugPrint('🚚 Showing DeliveryScreen');
        return const DeliveryScreen();
      case '/menu':
        return const RestaurantScreen();
      default:
        return const HomeScreen();
    }
  }
}