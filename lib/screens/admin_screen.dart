import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'admin_dashboard_screen.dart';
import 'admin_users_screen.dart';
import 'admin_reservations_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_team_management_screen.dart';

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

  final List<Widget> _screens = [
    const AdminDashboardScreen(),
    const AdminUsersScreen(),
    const AdminReservationsScreen(),
    const AdminTeamManagementScreen(),
  ];

  final List<String> _titles = [
    'Dashboard',
    'Users',
    'Reservations',
    'Team',
  ];

  final List<IconData> _icons = const [
    Icons.dashboard_rounded,
    Icons.people_alt_rounded,
    Icons.event_seat_rounded,
    Icons.group_rounded,
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
        backgroundColor: const Color(0xFF14141F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
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
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const NetworkImage('https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=1200'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withAlpha(179),
              BlendMode.darken,
            ),
          ),
        ),
        child: Column(
          children: [
            SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.admin_panel_settings, color: Colors.black, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Admin Panel',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.person, color: Colors.white),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminProfileScreen()),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      onPressed: _logout,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _screens[_selectedIndex],
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(179),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: (index) {
                  if (index < _screens.length) {
                    setState(() => _selectedIndex = index);
                  }
                },
                backgroundColor: Colors.transparent,
                elevation: 0,
                selectedItemColor: primaryColor,
                unselectedItemColor: Colors.white54,
                type: BottomNavigationBarType.fixed,
                items: List.generate(_titles.length, (index) {
                  return BottomNavigationBarItem(
                    icon: Icon(_icons[index], size: 24),
                    label: _titles[index],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}