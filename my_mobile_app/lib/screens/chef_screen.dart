import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../providers/auth_provider.dart';

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
  final Set<int> _playedNotificationIds = {}; // Pour éviter de rejouer les mêmes sons
  
  // Couleurs modernes
  final Color primaryColor = const Color(0xFFFF6B6B);
  final Color secondaryColor = const Color(0xFF4ECDC4);
  final Color accentColor = const Color(0xFFFFE66D);
  final Color darkColor = const Color(0xFF2C3E50);
  final Color successColor = const Color(0xFF6BFF6B);
  final Color warningColor = const Color(0xFFFFB347);
  final Color dangerColor = const Color(0xFFFF6B6B);

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
    _notificationTimer?.cancel(); // Annuler l'ancien timer s'il existe
    _notificationTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        _loadNotifications(); // Charger d'abord les notifications
        _loadOrders(); // Puis recharger les commandes
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
// In _loadNotifications method, change the filter to only show 'new_order'
Future<void> _loadNotifications() async {
  try {
    final notifications = await context.read<AuthProvider>().getUserNotifications();
    if (mounted) {
      // Filter to show ONLY new orders for chef
      final chefNotifications = notifications.where((notif) {
        final type = notif['type'] ?? '';
        // Chef only sees new orders
        return type == 'new_order';
      }).toList();
      
      // Vérifier les nouvelles notifications
      final oldCount = _notificationCount;
      
      setState(() {
        _notifications = chefNotifications;
        _notificationCount = chefNotifications.length;
      });
      
      // Si de nouvelles notifications arrivent, afficher un message
      if (_notificationCount > oldCount && chefNotifications.isNotEmpty) {
        _showNewNotificationSnackBar(chefNotifications.first);
      }
    }
  } catch (e) {
    debugPrint('Error loading notifications: $e');
  }
}
  void _showNewNotificationSnackBar(Map<String, dynamic> notification) {
    String title = notification['title'] ?? 'Nouvelle notification';
    String message = notification['message'] ?? '';
    String type = notification['type'] ?? 'info';
    
    Color snackColor = primaryColor;
    if (type == 'new_order') {
      snackColor = successColor;
    } else if (type == 'order_status_changed') {
      snackColor = secondaryColor;
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  type == 'new_order' ? Icons.shopping_cart : Icons.notifications,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(message),
          ],
        ),
        backgroundColor: snackColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Voir',
          textColor: Colors.white,
          onPressed: _showNotificationsDialog,
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? dangerColor : successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
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
                        colors: [primaryColor, accentColor],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(Icons.notifications, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
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
                      Icon(Icons.notifications_off, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'Aucune notification',
                        style: TextStyle(fontSize: 16, color: Colors.grey[500]),
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
                    final type = notification['type'] ?? 'info';
                    final title = notification['title'] ?? 'Notification';
                    final message = notification['message'] ?? '';
                    final isRead = notification['isRead'] ?? false;
                    
                    Color notificationColor = primaryColor;
                    IconData notificationIcon = Icons.notifications;
                    
                    if (type == 'new_order') {
                      notificationColor = successColor;
                      notificationIcon = Icons.shopping_cart;
                    } else if (type == 'order_status_changed') {
                      notificationColor = secondaryColor;
                      notificationIcon = Icons.update;
                    } else if (type == 'order_ready_for_delivery') {
                      notificationColor = warningColor;
                      notificationIcon = Icons.delivery_dining;
                    }
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isRead 
                              ? [Colors.grey[50]!, Colors.white]
                              : [notificationColor.withValues(alpha: 0.05), Colors.white],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isRead 
                              ? Colors.grey[200]! 
                              : notificationColor.withValues(alpha: 0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: notificationColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(notificationIcon, color: notificationColor, size: 20),
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
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  message,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  notification['created_at'] ?? 'Date inconnue',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[400],
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
                                color: notificationColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          PopupMenuButton(
                            icon: const Icon(Icons.more_vert, size: 18),
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                child: const Text('Marquer comme lu'),
                                onTap: () async {
                                  final notifId = _safeParseId(notification['id']);
                                  final success = await context.read<AuthProvider>()
                                      .markNotificationAsRead(notifId);
                                  if (success) {
                                    _loadNotifications();
                                  }
                                },
                              ),
                              PopupMenuItem(
                                child: const Text('Supprimer'),
                                onTap: () async {
                                  final notifId = _safeParseId(notification['id']);
                                  final success = await context.read<AuthProvider>()
                                      .deleteNotification(notifId);
                                  if (success) {
                                    _loadNotifications();
                                  }
                                },
                              ),
                            ],
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
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 0,
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
      final success = await authProvider.updateOrderStatus(orderId, apiStatus);
      
      if (mounted) {
        if (success) {
          _showSnackBar('✓ Statut mis à jour: ${_getStatusText(newStatus)}');
          
          setState(() {
            final index = _orders.indexWhere((order) => order['id'].toString() == orderId);
            if (index != -1) {
              _orders[index]['status'] = apiStatus;
              _orders[index]['updatedAt'] = DateTime.now().toString();
            }
          });
          
          _loadOrders();
        } else {
          _showSnackBar('Échec de la mise à jour', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Erreur: $e', isError: true);
      }
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
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
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
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, accentColor],
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(Icons.edit, color: Colors.white, size: 24),
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
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Statut actuel: ${_getStatusText(currentStatus)}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            
            // Options de statut
            _buildStatusOption(
              'En préparation',
              'Commencer la préparation',
              Icons.restaurant,
              Colors.blue,
              () {
                Navigator.pop(context);
                _updateOrderStatus(orderId, 'en préparation');
              },
              currentStatus != 'en préparation' && currentStatus != 'prête' && currentStatus != 'terminée',
            ),
            const SizedBox(height: 12),
            
            _buildStatusOption(
              'Prête',
              'Marquer comme prête à livrer',
              Icons.check_circle,
              successColor,
              () {
                Navigator.pop(context);
                _updateOrderStatus(orderId, 'prête');
              },
              currentStatus == 'en préparation',
            ),
            const SizedBox(height: 12),
            
            _buildStatusOption(
              'Terminée',
              'Marquer comme terminée',
              Icons.done_all,
              secondaryColor,
              () {
                Navigator.pop(context);
                _updateOrderStatus(orderId, 'terminée');
              },
              currentStatus == 'prête',
            ),
            const SizedBox(height: 12),
            
            if (currentStatus != 'annulée' && currentStatus != 'terminée')
              _buildStatusOption(
                'Annuler',
                'Annuler cette commande',
                Icons.cancel,
                dangerColor,
                () {
                  Navigator.pop(context);
                  _updateOrderStatus(orderId, 'annulée');
                },
                true,
                isDestructive: true,
              ),
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
            gradient: enabled
                ? LinearGradient(
                    colors: isDestructive
                        ? [color.withValues(alpha: 0.1), Colors.white]
                        : [color.withValues(alpha: 0.05), Colors.white],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            border: Border.all(
              color: enabled ? color.withValues(alpha: 0.3) : Colors.grey[300]!,
              width: enabled ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: enabled ? color.withValues(alpha: 0.1) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  icon, 
                  color: enabled ? color : Colors.grey[400], 
                  size: 24
                ),
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
                        color: enabled ? darkColor : Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: enabled ? Colors.grey[600] : Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
              if (enabled)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.arrow_forward, size: 16, color: color),
                ),
            ],
          ),
        ),
      ),
    );
  }

List<dynamic> _getOrdersByStatus(String status) {
  return _orders.where((order) {
    String orderStatus = _normalizeStatus(order['status'] ?? 'paid');
    
    // Pour l'onglet "En préparation", afficher les commandes en attente, payées ou en préparation
    if (status == 'en préparation') {
      return orderStatus == 'en attente' || orderStatus == 'payée' || orderStatus == 'en préparation';
    }
    
    // Pour l'onglet "À livrer", afficher les commandes prêtes
    if (status == 'livrée') {
      return orderStatus == 'prête';
    }
    
    return orderStatus == status;
  }).toList();
}
// Méthode utilitaire pour parser les IDs en toute sécurité
int _safeParseId(dynamic id) {
  if (id == null) return 0;
  if (id is int) return id;
  if (id is String) {
    // Essayer de parser directement
    final parsed = int.tryParse(id);
    if (parsed != null) return parsed;
    
    // Si c'est un format comme "/api/users/1", extraire le dernier chiffre
    final parts = id.split('/');
    final lastPart = parts.last;
    return int.tryParse(lastPart) ?? 0;
  }
  return 0;
}
  Widget _buildModernOrderCard(Map<String, dynamic> order) {
    String status = _normalizeStatus(order['status'] ?? 'paid');
    String orderId = order['id'].toString();
    String user = order['user'] is String ? order['user'] : 'Client inconnu';
    double total = (order['total'] as num?)?.toDouble() ?? 0.0;
    
    String clientName = user;
    if (user.contains('/api/users/')) {
      clientName = 'Client #${user.split('/').last}';
    }

    Map<String, dynamic> statusConfig = _getStatusConfig(status);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            statusConfig['color'].withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: statusConfig['color'].withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
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
                // En-tête avec badge de statut
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
                          child: Icon(
                            statusConfig['icon'],
                            color: statusConfig['color'],
                            size: 20,
                          ),
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
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                            Text(
                              clientName,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: statusConfig['color'].withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: statusConfig['color'].withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusConfig['icon'], size: 14, color: statusConfig['color']),
                          const SizedBox(width: 6),
                          Text(
                            statusConfig['text'],
                            style: TextStyle(
                              color: statusConfig['color'],
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Articles avec design moderne
                if (order['orderItems'] != null && order['orderItems'] is List && order['orderItems'].isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: statusConfig['color'].withValues(alpha: 0.05),
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
                                    style: const TextStyle(fontSize: 14),
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
                                fontSize: 12,
                                color: statusConfig['color'],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 16),
                
                // Informations supplémentaires
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Total
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: statusConfig['color'].withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.attach_money, size: 16, color: Color(0xFF2C3E50)),
                          const SizedBox(width: 4),
                          Text(
                            '${total.toStringAsFixed(2)} DT',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Heure
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            _formatTime(order['createdAt']),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Bouton d'action
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _showStatusChangeDialog(order),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: statusConfig['color'],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.edit, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Modifier le statut',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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
          'color': warningColor,
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
          'color': successColor,
          'icon': Icons.check_circle,
          'text': 'Prête',
        };
      case 'livrée':
        return {
          'color': secondaryColor,
          'icon': Icons.delivery_dining,
          'text': 'À livrer',
        };
   
      default:
        return {
          'color': Colors.grey,
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
      case 'en attente': return 'En attente';
      case 'payée': return 'Payée';
      case 'en préparation': return 'En préparation';
      case 'prête': return 'Prête';
      case 'livrée': return 'À livrer';
      case 'completed': return 'Terminée';
      case 'terminée': return 'Terminée';
      case 'annulée': return 'Annulée';
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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryColor, accentColor],
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
                color: Colors.white,
              ),
            ),
            Text(
              'Gestion des commandes',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none, color: Colors.white, size: 28),
                onPressed: _showNotificationsDialog,
                tooltip: 'Notifications',
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
            icon: const Icon(Icons.refresh, color: Colors.white, size: 28),
            onPressed: () {
              _loadOrders();
              _loadNotifications();
            },
            tooltip: 'Rafraîchir',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white, size: 28),
            onPressed: _logout,
            tooltip: 'Déconnexion',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.5),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(
              icon: Icon(Icons.restaurant, size: 20),
              text: 'En préparation',
            ),
            Tab(
              icon: Icon(Icons.delivery_dining, size: 20),
              text: 'À livrer',
            ),
        
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
                      color: primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B6B)),
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Chargement des commandes...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 80,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                emptyMessage,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Les commandes apparaîtront ici automatiquement',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  _loadOrders();
                  _loadNotifications();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Actualiser', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadOrders();
        await _loadNotifications();
      },
      color: primaryColor,
      backgroundColor: Colors.white,
      displacement: 40,
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