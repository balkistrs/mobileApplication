// admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import '../providers/auth_provider.dart';
import 'admin_profile_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  int _selectedPeriod = 30;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      if (auth.token == null) return;

      final response = await http.get(
        Uri.parse('${AuthProvider.baseUrl}/admin/dashboard/stats?days=$_selectedPeriod'),
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() => _stats = data['data']);
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement stats: $e');
    } finally {
      setState(() => _isLoading = false);
    }
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
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        title: const Text('Tableau de Bord Admin'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.date_range),
            onSelected: (days) {
              setState(() => _selectedPeriod = days);
              _loadStats();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 7, child: Text('7 jours')),
              const PopupMenuItem(value: 15, child: Text('15 jours')),
              const PopupMenuItem(value: 30, child: Text('30 jours')),
              const PopupMenuItem(value: 90, child: Text('90 jours')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
          ),
          // Bouton profil admin
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminProfileScreen()),
            ),
          ),
          // Bouton déconnexion
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final revenue = _stats['revenue'] ?? {};
    final period = _stats['period'] ?? {};
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Période
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Période: ${period['start_date'] ?? 'N/A'} - ${period['end_date'] ?? 'N/A'}',
              style: const TextStyle(color: Colors.white70),
            ),
          ),

          // Cartes KPI
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            children: [
              _buildKpiCard(
                title: 'REVENU TOTAL',
                value: revenue['formatted'] ?? '0 DT',
                icon: Icons.trending_up,
                color: Colors.green,
              ),
              _buildKpiCard(
                title: 'COMMANDES',
                value: (_stats['total_orders'] ?? 0).toString(),
                icon: Icons.shopping_bag,
                color: Colors.blue,
              ),
              _buildKpiCard(
                title: 'NOUVEAUX MEMBRES',
                value: (_stats['new_users'] ?? 0).toString(),
                icon: Icons.people,
                color: Colors.orange,
              ),
              _buildKpiCard(
                title: 'PANIER MOYEN',
                value: '${(_stats['average_order_value'] ?? 0).toStringAsFixed(2)} DT',
                icon: Icons.shopping_cart,
                color: Colors.purple,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Top produits
          _buildTopProducts(),

          const SizedBox(height: 24),

          // Commandes par statut
          _buildOrdersByStatus(),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProducts() {
    final products = _stats['top_products'] as List? ?? [];
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🍽️ PLATS LES PLUS DEMANDÉS',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (products.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Aucune donnée disponible',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            )
          else
            ...products.take(5).map((p) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      p['name'] ?? 'Plat inconnu',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${p['total_quantity'] ?? 0}',
                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    p['revenue_formatted'] ?? '0 DT',
                    style: const TextStyle(color: Colors.green),
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }

  Widget _buildOrdersByStatus() {
    final ordersByStatus = _stats['orders_by_status'] as Map? ?? {};
    
    if (ordersByStatus.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📦 COMMANDES PAR STATUT',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...ordersByStatus.entries.map((entry) {
            final status = entry.key;
            final count = entry.value;
            Color color = Colors.grey;
            String label = status;
            
            switch (status) {
              case 'pending': color = Colors.orange; label = 'En attente'; break;
              case 'paid': color = Colors.green; label = 'Payée'; break;
              case 'preparing': color = Colors.blue; label = 'Préparation'; break;
              case 'ready': color = Colors.purple; label = 'Prête'; break;
              case 'completed': color = Colors.teal; label = 'Terminée'; break;
            }
            
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(label, style: const TextStyle(color: Colors.white))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                    child: Text(count.toString(), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}