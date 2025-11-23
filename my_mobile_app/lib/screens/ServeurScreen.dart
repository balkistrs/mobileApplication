import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../providers/auth_provider.dart';

class ServeurScreen extends StatefulWidget {
  const ServeurScreen({super.key});

  @override
  State<ServeurScreen> createState() => _ServeurScreenState();
}

class _ServeurScreenState extends State<ServeurScreen> {
  List<dynamic> _orders = [];
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  int _notificationCount = 0;
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _loadNotifications();
    _startNotificationPolling();
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  void _startNotificationPolling() {
    _notificationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadNotifications();
        _loadOrders();
      }
    });
  }

  void _showNotificationsDialog() {
    if (_notificationCount > 0) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Notifications'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _notifications.length,
              itemBuilder: (context, index) => ListTile(
                title: Text(_notifications[index]['message'] ?? 'Notification'),
                subtitle: Text(_notifications[index]['created_at'] ?? 'Date inconnue'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune nouvelle notification'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final notifications = await context.read<AuthProvider>().getNotifications();
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _notificationCount = notifications.length;
        });
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      // En cas d'erreur, initialiser avec une liste vide
      if (mounted) {
        setState(() {
          _notifications = [];
          _notificationCount = 0;
        });
      }
    }
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final orders = await context.read<AuthProvider>().getOrders();
      if (mounted) {
        setState(() => _orders = orders);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateOrderStatus(String orderId, String status) async {
    try {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.updateOrderStatus(orderId, status);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Statut mis à jour: ${_getStatusText(status)}'),
              backgroundColor: Colors.green,
            ),
          );
          
          setState(() {
            final index = _orders.indexWhere((order) => order['id'].toString() == orderId);
            if (index != -1) {
              _orders[index]['status'] = status;
              _orders[index]['updatedAt'] = DateTime.now().toString();
            }
          });
          
          _loadOrders();
          _loadNotifications();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Échec de la mise à jour'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.logout();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la déconnexion: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _decodeStatus(String status) {
    // Décoder les caractères Unicode
    String decoded = status.replaceAllMapped(
      RegExp(r'\\u([0-9a-fA-F]{4})'),
      (Match m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16))
    );
    
    // Mapping des statuts
    final statusMap = {
      'terminée': 'terminée',
      'payée': 'payée',
      'annulée': 'annulée',
      'en attente': 'en attente',
      'en préparation': 'en préparation',
      'prête': 'prête',
      'livrée': 'livrée',
      'completed': 'terminée',
      'paid': 'payée',
      'cancelled': 'annulée',
      'pending': 'en attente',
      'preparing': 'en préparation',
      'ready': 'prête',
      'delivered': 'livrée',
    };
    
    return statusMap[decoded] ?? decoded;
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    String orderId = order['id'].toString();
    String status = _decodeStatus(order['status'] ?? 'en attente');
    String user = order['user'] is String ? order['user'] : 'Client inconnu';
    double total = (order['total'] as num?)?.toDouble() ?? 0.0;
    
    String clientName = user;
    if (user.contains('/api/users/')) {
      clientName = 'Client #${user.split('/').last}';
    }

    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.access_time;
    
    switch (status) {
      case 'en attente':
        statusColor = Colors.orange;
        statusIcon = Icons.access_time;
        break;
      case 'en préparation':
        statusColor = Colors.blue;
        statusIcon = Icons.restaurant;
        break;
      case 'prête':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'livrée':
        statusColor = Colors.purple;
        statusIcon = Icons.delivery_dining;
        break;
      case 'annulée':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Commande #$orderId',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        _getStatusText(status),
                        style: const TextStyle(
                          color: Colors.white, 
                          fontWeight: FontWeight.w600
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.person, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Client: $clientName',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.attach_money, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Total: ${total.toStringAsFixed(2)} €',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            const Text(
              'Détails:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Créée le: ${order['createdAt'] ?? 'Date inconnue'}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            if (order['updatedAt'] != null)
              Text(
                'Modifiée le: ${order['updatedAt']}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            const SizedBox(height: 16),
            if (status == 'prête')
              Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _updateOrderStatus(orderId, 'livrée'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.delivery_dining, size: 18),
                    label: const Text('Marquer comme livrée'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'en attente': return 'En attente';
      case 'en préparation': return 'En préparation';
      case 'prête': return 'Prête à livrer';
      case 'livrée': return 'Livrée';
      case 'annulée': return 'Annulée';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Espace Serveur',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.deepOrange,
        elevation: 0,
        centerTitle: true,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications, color: Colors.white),
                onPressed: _showNotificationsDialog,
                tooltip: 'Notifications',
              ),
              if (_notificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    child: Text(
                      '$_notificationCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadOrders,
            tooltip: 'Rafraîchir',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.deepOrange),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Chargement des commandes...',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          : _orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.restaurant_menu,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Aucune commande en cours',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Les nouvelles commandes apparaîtront ici',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadOrders,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Actualiser'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadOrders,
                  color: Colors.deepOrange,
                  backgroundColor: Colors.white,
                  displacement: 40,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 16, bottom: 16),
                    itemCount: _orders.length,
                    itemBuilder: (context, index) => _buildOrderCard(_orders[index]),
                  ),
                ),
    );
  }
}