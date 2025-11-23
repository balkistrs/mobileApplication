import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with TickerProviderStateMixin {
  int _selectedTabIndex = 0;
  late TabController _tabController;
  List<AppUser> _users = [];
  List<dynamic> _orders = [];
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  late AnimationController _chefAnimationController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    });
    
    _chefAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chefAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final users = await authProvider.getUsers();
      final orders = await authProvider.getOrders();
      
      debugPrint('Users loaded: ${users.length}');
      debugPrint('Orders loaded: ${orders.length}');
      if (orders.isNotEmpty) {
        debugPrint('First order keys: ${orders.first.keys}');
        debugPrint('First order: ${orders.first}');
      }
      
      setState(() {
        _users = users;
        _orders = orders;
        _calculateStats();
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _calculateStats() {
    final totalUsers = _users.length;
    final totalOrders = _orders.length;
    final pendingOrders = _orders.where((order) => order['status'] == 'pending').length;
    final completedOrders = _orders.where((order) => order['status'] == 'paid').length;

    setState(() {
      _stats = {
        'totalUsers': totalUsers,
        'totalOrders': totalOrders,
        'pendingOrders': pendingOrders,
        'completedOrders': completedOrders,
      };
    });
  }

Future<void> _deleteUser(AppUser user) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirmer la suppression'),
      content: Text('Êtes-vous sûr de vouloir supprimer l\'utilisateur ${user.email} ?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );

  if (confirmed == true && mounted) {
    try {
      setState(() => _isLoading = true);
      final success = await context.read<AuthProvider>().deleteUser(user.email);
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Utilisateur supprimé avec succès')),
          );
          await _loadData(); // Reload data after deletion
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Échec de la suppression - Utilisateur non trouvé ou erreur serveur')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
  Future<void> _editUser(AppUser user) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _EditUserDialog(user: user),
    );

    if (result != null && result.isNotEmpty && mounted) {
      try {
        final newEmail = result['email'] ?? user.email;
        final newRole = result['role'] ?? user.roles?.first ?? 'ROLE_CLIENT';
        
        final success = await context.read<AuthProvider>().updateUser(
          user.email, newEmail, newRole
        );
        
        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Utilisateur modifié avec succès')),
            );
            _loadData();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Échec de la modification')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
        }
      }
    }
  }

  Widget _buildStatsCard() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _StatCard(
          title: 'Utilisateurs',
          value: _stats['totalUsers']?.toString() ?? '0',
          subtitle: 'Total',
          icon: Icons.people,
          color: Colors.blue,
        ),
        _StatCard(
          title: 'Commandes',
          value: _stats['totalOrders']?.toString() ?? '0',
          subtitle: 'Total',
          icon: Icons.shopping_cart,
          color: Colors.green,
        ),
        _StatCard(
          title: 'En attente',
          value: _stats['pendingOrders']?.toString() ?? '0',
          subtitle: 'Commandes',
          icon: Icons.access_time,
          color: Colors.orange,
        ),
        _StatCard(
          title: 'Complétées',
          value: _stats['completedOrders']?.toString() ?? '0',
          subtitle: 'Commandes',
          icon: Icons.check_circle,
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildUsersTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_users.isEmpty) {
      return const Center(child: Text('Aucun utilisateur'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          return _UserCard(
            user: user,
            onEdit: () => _editUser(user),
            onDelete: () => _deleteUser(user),
          );
        },
      ),
    );
  }

  Widget _buildOrdersTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_orders.isEmpty) {
      return const Center(child: Text('Aucune commande'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index];
          return _OrderCard(order: order);
        },
      ),
    );
  }

  Widget _buildStatsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistiques du restaurant',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildStatsCard(),
            const SizedBox(height: 24),
            Text(
              'Répartition des rôles',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildRoleDistributionChart(),
            const SizedBox(height: 24),
            Text(
              'Statut des commandes',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildOrderStatusChart(),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleDistributionChart() {
    final roleCounts = {
      'Client': _users.where((u) => u.roles?.contains('ROLE_CLIENT') ?? false).length,
      'Chef': _users.where((u) => u.roles?.contains('ROLE_CHEF') ?? false).length,
      'Serveur': _users.where((u) => u.roles?.contains('ROLE_SERVEUR') ?? false).length,
      'Admin': _users.where((u) => u.roles?.contains('ROLE_ADMIN') ?? false).length,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: roleCounts.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.key,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                Text(
                  '${entry.value}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOrderStatusChart() {
    final statusCounts = {
      'pending': _orders.where((o) => o['status'] == 'pending').length,
      'paid': _orders.where((o) => o['status'] == 'paid').length,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: statusCounts.entries.map((entry) {
          Color statusColor = Colors.grey;
          switch (entry.key) {
            case 'pending':
              statusColor = Colors.orange;
              break;
            case 'paid':
              statusColor = Colors.green;
              break;
          }

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.key == 'pending' ? 'En attente' : 'Payée',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                Text(
                  '${entry.value}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _logout() async {
    try {
      await context.read<AuthProvider>().logout();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la déconnexion: $e')),
        );
      }
    }
  }

  Widget _buildChefAnimation() {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _chefAnimationController,
            builder: (context, child) {
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(_chefAnimationController.value * 2 * 3.14159),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.orange[700],
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.restaurant,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              );
            },
          ),
          
          Positioned(
            top: 5,
            left: 15,
            right: 15,
            child: AnimatedBuilder(
              animation: _chefAnimationController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, -2 * (_chefAnimationController.value - 0.5).abs()),
                  child: Container(
                    height: 15,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                );
              },
            ),
          ),
          
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(40),
                onTap: _showAddUserDialog,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    ).animate(
      onPlay: (controller) => controller.repeat(reverse: true),
    ).scale(
      duration: 1500.ms,
      begin: const Offset(0.9, 0.9),
      end: const Offset(1.1, 1.1),
    );
  }

  void _showAddUserDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un utilisateur'),
        content: const Text('Cette fonctionnalité sera bientôt disponible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Espace Administrateur'),
        backgroundColor: Colors.purple,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Actualiser',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Déconnexion',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Utilisateurs'),
            Tab(icon: Icon(Icons.shopping_cart), text: 'Commandes'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Statistiques'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUsersTab(),
          _buildOrdersTab(),
          _buildStatsTab(),
        ],
      ),
      floatingActionButton: _selectedTabIndex == 0
          ? _buildChefAnimation()
          : null,
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      )
    );
  }
}

class _UserCard extends StatelessWidget {
  final AppUser user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _UserCard({
    required this.user,
    required this.onEdit,
    required this.onDelete,
  });

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'ROLE_ADMIN':
        return 'Administrateur';
      case 'ROLE_CHEF':
        return 'Chef';
      case 'ROLE_SERVEUR':
        return 'Serveur';
      case 'ROLE_CLIENT':
        return 'Client';
      default:
        return role;
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'ROLE_ADMIN':
        return Colors.purple;
      case 'ROLE_CHEF':
        return Colors.orange;
      case 'ROLE_SERVEUR':
        return Colors.blue;
      case 'ROLE_CLIENT':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mainRole = user.roles?.isNotEmpty == true ? user.roles!.first : 'ROLE_CLIENT';
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(mainRole),
          child: Text(
            user.email[0].toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(user.email),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user.roles != null)
              Wrap(
                spacing: 4,
                children: user.roles!.map((role) => Chip(
                  label: Text(
                    _getRoleDisplayName(role),
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                  backgroundColor: _getRoleColor(role),
                  visualDensity: VisualDensity.compact,
                )).toList(),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: onEdit,
              tooltip: 'Modifier',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: onDelete,
              tooltip: 'Supprimer',
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;

  const _OrderCard({required this.order});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = order['status']?.toString() ?? 'pending';
    final total = order['total']?.toString() ?? '0.0';
    final createdAt = order['createdAt']?.toString() ?? '';
    final orderId = order['id']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(status),
          child: Text(
            orderId,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        title: Text('Commande #$orderId'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total: ${double.parse(total).toStringAsFixed(2)} €'),
            Text('Date: ${_formatDate(createdAt)}'),
          ],
        ),
        trailing: Chip(
          label: Text(
            status == 'paid' ? 'Payée' : 'En attente',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          backgroundColor: _getStatusColor(status),
        ),
      ),
    );
  }
}

class _EditUserDialog extends StatefulWidget {
  final AppUser user;

  const _EditUserDialog({required this.user});

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  late TextEditingController _emailController;
  late String _selectedRole;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.user.email);
    _selectedRole = widget.user.roles?.first ?? 'ROLE_CLIENT';
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifier l\'utilisateur'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedRole,
            items: const [
              DropdownMenuItem(value: 'ROLE_CLIENT', child: Text('Client')),
              DropdownMenuItem(value: 'ROLE_CHEF', child: Text('Chef')),
              DropdownMenuItem(value: 'ROLE_SERVEUR', child: Text('Serveur')),
              DropdownMenuItem(value: 'ROLE_ADMIN', child: Text('Administrateur')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedRole = value!;
              });
            },
            decoration: const InputDecoration(
              labelText: 'Rôle',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context, {
              'email': _emailController.text,
              'role': _selectedRole,
            });
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}