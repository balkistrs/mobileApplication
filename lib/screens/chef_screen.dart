import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../providers/auth_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ChefScreen extends StatefulWidget {
  const ChefScreen({super.key});

  @override
  State<ChefScreen> createState() => _ChefScreenState();
}

class _ChefScreenState extends State<ChefScreen> with TickerProviderStateMixin {
  List<dynamic> _orders = [];
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  int _notificationCount = 0;
  Timer? _notificationTimer;
  late TabController _tabController;
  final Set<int> _playedNotificationIds = {};
  
  // NOCTURNE Colors
  final Color _primaryColor = const Color(0xFFDF8EFF);
  final Color _secondaryColor = const Color(0xFF00EEFC);
  final Color _accentColor = const Color(0xFFFFE66D);
  final Color _surfaceColor = const Color(0xFF0E0E11);
  final Color _surfaceContainer = const Color(0xFF19191D);
  final Color _surfaceContainerHigh = const Color(0xFF1F1F23);
  final Color _onSurfaceVariant = const Color(0xFFACAAAE);
  final Color _successColor = const Color(0xFF2ECC71);
  final Color _warningColor = const Color(0xFFF39C12);
  final Color _errorColor = const Color(0xFFD73357);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOrders();
    _loadNotifications();
    _startNotificationPolling();
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _startNotificationPolling() {
    _notificationTimer?.cancel();
    _notificationTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        _loadNotifications();
        _loadOrders();
      }
    });
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
        _showSnackBar('Erreur: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final notifications = await context.read<AuthProvider>().getUserNotifications();
      if (mounted) {
        final chefNotifications = notifications.where((notif) {
          final type = notif['type'] ?? '';
          return type == 'new_order';
        }).toList();
        
        final oldCount = _notificationCount;
        
        setState(() {
          _notifications = chefNotifications;
          _notificationCount = chefNotifications.length;
        });
        
        if (_notificationCount > oldCount && chefNotifications.isNotEmpty) {
          _showNewNotificationSnackBar(chefNotifications.first);
        }
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }
  }

  void _showNewNotificationSnackBar(Map<String, dynamic> notification) {
    String title = notification['title'] ?? 'Nouvelle commande';
    String message = notification['message'] ?? 'Une nouvelle commande a été reçue';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _successColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.restaurant, color: _successColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    message,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: _surfaceContainer,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'VOIR',
          textColor: _primaryColor,
          onPressed: _showNotificationsDialog,
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? _errorColor : _successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showNotificationsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_primaryColor, _secondaryColor],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(Icons.notifications, color: Colors.black, size: 24),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            if (_notifications.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off, size: 80, color: _onSurfaceVariant),
                      const SizedBox(height: 16),
                      Text(
                        'Aucune notification',
                        style: TextStyle(color: _onSurfaceVariant, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
                    final title = notification['title'] ?? 'Nouvelle commande';
                    final message = notification['message'] ?? '';
                    final isRead = notification['isRead'] ?? false;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _surfaceContainer,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isRead 
                              ? _onSurfaceVariant.withValues(alpha: 0.1)
                              : _primaryColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _successColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.restaurant, color: _successColor, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  message,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _primaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text('Fermer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


Future<void> _updateOrderStatus(String orderId, String newStatus) async {
  try {
    String apiStatus = _convertToEnglishStatus(newStatus);
    
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    
    if (token == null) {
      _showSnackBar('Token manquant', isError: true);
      return;
    }
    
    final response = await http.put(
      Uri.parse('${AuthProvider.baseUrl}/orders/$orderId/status'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'ngrok-skip-browser-warning': 'true',
      },
      body: json.encode({'status': apiStatus}),
    );
    
    if (response.statusCode == 200) {
      _showSnackBar('✓ Statut mis à jour: ${_getStatusText(newStatus)}');
      await _loadOrders();
      await _loadNotifications();
    } else {
      final errorData = json.decode(response.body);
      _showSnackBar('Erreur: ${errorData['error'] ?? 'Échec de la mise à jour'}', isError: true);
    }
  } catch (e) {
    _showSnackBar('Erreur: $e', isError: true);
  }
}



  String _convertToEnglishStatus(String frenchStatus) {
    switch (frenchStatus) {
      case 'en attente': return 'pending';
      case 'payée': return 'paid';
      case 'en préparation': return 'preparing';
      case 'prête': return 'ready';
      case 'livrée': return 'delivered';
      case 'terminée': return 'completed';
      case 'annulée': return 'cancelled';
      default: return frenchStatus.toLowerCase();
    }
  }

  void _showStatusChangeDialog(Map<String, dynamic> order) {
    String currentStatus = _normalizeStatus(order['status'] ?? 'paid');
    String orderId = order['id'].toString();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_primaryColor, _secondaryColor],
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(Icons.edit, color: Colors.black, size: 24),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Commande #$orderId',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Statut actuel: ${_getStatusText(currentStatus)}',
                      style: TextStyle(fontSize: 14, color: _onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(color: Colors.white10),
            const SizedBox(height: 16),
            
            _buildStatusOption(
              'En préparation',
              'Commencer la préparation',
              Icons.restaurant,
              Colors.blue,
              () {
                Navigator.pop(context);
                _updateOrderStatus(orderId, 'en préparation');
              },
              currentStatus != 'en préparation' && currentStatus != 'prête',
            ),
            const SizedBox(height: 12),
            
            _buildStatusOption(
              'Prête',
              'Marquer comme prête à servir',
              Icons.check_circle,
              _successColor,
              () {
                Navigator.pop(context);
                _updateOrderStatus(orderId, 'prête');
              },
              currentStatus == 'en préparation',
            ),
            
            // Note: Le chef ne peut PAS marquer comme terminée
            // Cette option est réservée au serveur
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOption(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onPressed,
    bool enabled, {
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: enabled ? _surfaceContainer : _surfaceContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: enabled ? color.withValues(alpha: 0.3) : _onSurfaceVariant.withValues(alpha: 0.1),
              width: enabled ? 1 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: enabled ? color.withValues(alpha: 0.1) : _onSurfaceVariant.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: enabled ? color : _onSurfaceVariant, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: enabled ? Colors.white : _onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: enabled ? _onSurfaceVariant : _onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              if (enabled)
                Icon(Icons.arrow_forward_ios, size: 16, color: color),
            ],
          ),
        ),
      ),
    );
  }

  List<dynamic> _getOrdersByStatus(String status) {
    return _orders.where((order) {
      String orderStatus = _normalizeStatus(order['status'] ?? 'paid');
      
      if (status == 'en préparation') {
        // Le chef voit les commandes en attente, payées ou en préparation
        return orderStatus == 'en attente' || orderStatus == 'payée' || orderStatus == 'en préparation';
      }
      
      if (status == 'livrée') {
        // Le chef voit les commandes prêtes
        return orderStatus == 'prête';
      }
      
      return orderStatus == status;
    }).toList();
  }

  Widget _buildModernOrderCard(Map<String, dynamic> order) {
    String status = _normalizeStatus(order['status'] ?? 'paid');
    String orderId = order['id'].toString();
    String user = order['user'] is String ? order['user'] : 'Client';
    double total = (order['total'] as num?)?.toDouble() ?? 0.0;
    
    Map<String, dynamic> statusConfig = _getStatusConfig(status);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: _surfaceContainer,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: statusConfig['color'].withValues(alpha: 0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showStatusChangeDialog(order),
          borderRadius: BorderRadius.circular(25),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: statusConfig['color'].withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(statusConfig['icon'], color: statusConfig['color'], size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Commande #$orderId',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              user,
                              style: TextStyle(
                                fontSize: 12,
                                color: _onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusConfig['color'].withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusConfig['text'],
                        style: TextStyle(
                          color: statusConfig['color'],
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                if (order['orderItems'] != null && order['orderItems'] is List && order['orderItems'].isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var item in (order['orderItems'] as List).take(3))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: statusConfig['color'],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${item['product']?['name'] ?? item['name'] ?? 'Article'}',
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  'x${item['quantity'] ?? 1}',
                                  style: TextStyle(
                                    color: statusConfig['color'],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if ((order['orderItems'] as List).length > 3)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '+ ${(order['orderItems'] as List).length - 3} autre(s)',
                              style: TextStyle(
                                fontSize: 11,
                                color: statusConfig['color'],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 16),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${total.toStringAsFixed(2)} DT',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time, size: 12, color: _onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            _formatTime(order['createdAt']),
                            style: TextStyle(
                              fontSize: 11,
                              color: _onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _showStatusChangeDialog(order),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: statusConfig['color'],
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: Text(
                      'Modifier le statut',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _getStatusConfig(String status) {
    switch (status) {
      case 'en attente':
      case 'payée':
        return {
          'color': _warningColor,
          'icon': Icons.pending_actions,
          'text': 'En attente',
        };
      case 'en préparation':
        return {
          'color': Colors.blue,
          'icon': Icons.restaurant,
          'text': 'En préparation',
        };
      case 'prête':
        return {
          'color': _successColor,
          'icon': Icons.check_circle,
          'text': 'Prête',
        };
      default:
        return {
          'color': _onSurfaceVariant,
          'icon': Icons.help_outline,
          'text': status,
        };
    }
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '--:--';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '--:--';
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'paid': return 'Payée';
      case 'pending': return 'En attente';
      case 'preparing': return 'En préparation';
      case 'ready': return 'Prête';
      case 'delivered': return 'Livrée';
      case 'completed': return 'Terminée';
      case 'cancelled': return 'Annulée';
      default: return status;
    }
  }

  String _normalizeStatus(String status) {
    switch (status) {
      case 'paid': return 'payée';
      case 'pending': return 'en attente';
      case 'preparing': return 'en préparation';
      case 'ready': return 'prête';
      case 'delivered': return 'livrée';
      case 'completed': return 'terminée';
      case 'cancelled': return 'annulée';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chef Cuisinier',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            Text(
              'Gestion des commandes',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none, color: Colors.black, size: 28),
                onPressed: _showNotificationsDialog,
              ),
              if (_notificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$_notificationCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black, size: 28),
            onPressed: () {
              _loadOrders();
              _loadNotifications();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black, size: 28),
            onPressed: _logout,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.black,
          indicatorWeight: 3,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black.withValues(alpha: 0.5),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(icon: Icon(Icons.restaurant, size: 20), text: 'En préparation'),
            Tab(icon: Icon(Icons.delivery_dining, size: 20), text: 'À livrer'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Chargement des commandes...',
                    style: TextStyle(
                      fontSize: 16,
                      color: _onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOrdersList('en préparation', Icons.restaurant, 'Aucune commande en préparation'),
                _buildOrdersList('livrée', Icons.delivery_dining, 'Aucune commande à livrer'),
              ],
            ),
    );
  }

  Widget _buildOrdersList(String status, IconData icon, String emptyMessage) {
    final filteredOrders = _getOrdersByStatus(status);
    
    if (filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: _surfaceContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 80, color: _onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Text(
              emptyMessage,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Les commandes apparaîtront ici automatiquement',
              style: TextStyle(
                fontSize: 14,
                color: _onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                _loadOrders();
                _loadNotifications();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Actualiser', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadOrders();
        await _loadNotifications();
      },
      color: _primaryColor,
      backgroundColor: _surfaceColor,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: filteredOrders.length,
        itemBuilder: (context, index) => _buildModernOrderCard(filteredOrders[index]),
      ),
    );
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
        _showSnackBar('Erreur lors de la déconnexion: $e', isError: true);
      }
    }
  }
}