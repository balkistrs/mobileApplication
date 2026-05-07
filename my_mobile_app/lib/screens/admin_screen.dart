// admin_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import 'admin_dashboard_screen.dart';
import 'admin_users_screen.dart';
import 'admin_profile_screen.dart';
import 'metabase_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _animationController;
  
  final Color primaryColor = const Color(0xFFFFB800);
  final Color backgroundColor = const Color(0xFF0A0A0F);
  final Color cardColor = const Color(0xFF14141F);

  final List<Widget> _screens = [
    const AdminDashboardScreen(),
    const AdminUsersScreen(),
    const MetabaseScreen(),
  ];

  final List<String> _titles = [
    'Dashboard',
    'Utilisateurs',
    'Analyses',
  ];

  final List<IconData> _icons = const [
    Icons.dashboard_rounded,
    Icons.people_alt_rounded,
    Icons.analytics_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Déconnexion', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Voulez-vous vraiment vous déconnecter ?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final auth = context.read<AuthProvider>();
      await auth.logout();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Administration'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        actions: [
          // Bouton profil
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminProfileScreen()),
            ),
          ),
          // Bouton déconnexion
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Décoration d'arrière-plan
          Positioned.fill(
            child: CustomPaint(
              painter: BackgroundPainter(primaryColor: primaryColor),
            ),
          ),
          
          // Contenu principal
          _screens[_selectedIndex],
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              backgroundColor.withOpacity(0.9),
            ],
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() => _selectedIndex = index);
            _animationController.reset();
            _animationController.forward();
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: primaryColor,
          unselectedItemColor: Colors.white.withOpacity(0.4),
          selectedLabelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: Colors.white.withOpacity(0.4),
          ),
          type: BottomNavigationBarType.fixed,
          items: List.generate(_titles.length, (index) {
            return BottomNavigationBarItem(
              icon: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.all(_selectedIndex == index ? 12 : 8),
                decoration: BoxDecoration(
                  color: _selectedIndex == index 
                      ? primaryColor.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _icons[index],
                  size: _selectedIndex == index ? 28 : 24,
                ),
              ),
              label: _titles[index],
            );
          }),
        ),
      ),
    );
  }
}

class BackgroundPainter extends CustomPainter {
  final Color primaryColor;

  BackgroundPainter({required this.primaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = primaryColor.withOpacity(0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final path = Path();
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    for (int i = 0; i < 5; i++) {
      final radius = size.width * (0.3 + i * 0.15);
      path.addOval(Rect.fromCircle(
        center: Offset(centerX, centerY),
        radius: radius,
      ));
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}