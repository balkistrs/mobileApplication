import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/notification_provider.dart';
import '../providers/auth_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with SingleTickerProviderStateMixin {
  // Couleurs (Palette jaune)
  final Color _primaryColor = const Color(0xFFFFB800);
  final Color _backgroundColor = const Color(0xFF0A0A0F);
  final Color _surfaceColor = const Color(0xFF14141F);
  final Color _cardColor = const Color(0xFF1A1A24);
  final Color _textSecondary = const Color(0xFFA0A0B0);

  // Audio player
  late AudioPlayer _audioPlayer;
  bool _hasPlayedBell = false;
  int _previousUnreadCount = 0;
  
  // Animation controller pour la cloche
  late AnimationController _shakeController;
  
  // URL du son de cloche depuis Internet
  final String _bellSoundUrl = 'https://www.soundjay.com/misc/sounds/bell-ringing-05.mp3';
  final String _bellSoundUrlAlt = 'https://actions.google.com/sounds/667/cartoon-bell-ring.mp3';

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
    _initAnimation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotifications();
    });
  }

  Future<void> _initAudioPlayer() async {
    _audioPlayer = AudioPlayer();
    
    // Configurer pour jouer même en mode silencieux (optionnel)
    await _audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
  }

  void _initAnimation() {
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  Future<void> _playBellSound() async {
    try {
      print('🔔 Playing bell sound from internet...');
      
      // Animation de secouement
      _shakeController.forward().then((_) => _shakeController.reset());
      
      // Essayer de jouer le son depuis l'URL
      await _audioPlayer.play(UrlSource(_bellSoundUrl));
      
    } catch (e) {
      print('Error playing bell sound: $e');
      // Essayer URL alternative
      try {
        await _audioPlayer.play(UrlSource(_bellSoundUrlAlt));
      } catch (e2) {
        print('Fallback sound also failed: $e2');
      }
    }
  }

  Future<void> _loadNotifications() async {
    final notifProvider = Provider.of<NotificationProvider>(context, listen: false);
    await notifProvider.fetchNotifications();
    
    // Jouer le son si de nouvelles notifications non lues
    final unreadCount = notifProvider.notifications.where((n) => !n.isRead).length;
    
    if (unreadCount > _previousUnreadCount && !_hasPlayedBell) {
      _playBellSound();
      _hasPlayedBell = true;
      // Réinitialiser après 3 secondes
      Future.delayed(const Duration(seconds: 3), () {
        _hasPlayedBell = false;
      });
    }
    _previousUnreadCount = unreadCount;
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _markAsRead(int id) async {
    final notifProvider = Provider.of<NotificationProvider>(context, listen: false);
    await notifProvider.markAsRead(id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notification marked as read'), duration: Duration(seconds: 1), backgroundColor: Color(0xFF2ECC71)),
    );
  }

  Future<void> _deleteNotification(int id) async {
    final notifProvider = Provider.of<NotificationProvider>(context, listen: false);
    await notifProvider.deleteNotification(id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notification deleted'), duration: Duration(seconds: 1), backgroundColor: Color(0xFFD73357)),
    );
  }

  Future<void> _markAllAsRead() async {
    final notifProvider = Provider.of<NotificationProvider>(context, listen: false);
    await notifProvider.markAllAsRead();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All notifications marked as read'), duration: Duration(seconds: 1), backgroundColor: Color(0xFF2ECC71)),
    );
  }

  Future<void> _deleteAllNotifications() async {
    final notifProvider = Provider.of<NotificationProvider>(context, listen: false);
    await notifProvider.deleteAllNotifications();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All notifications deleted'), duration: Duration(seconds: 1), backgroundColor: Color(0xFFD73357)),
    );
  }

  // Widget pour la cloche animée
  Widget _buildAnimatedBell(int unreadCount) {
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _shakeController.value * 0.3 * (DateTime.now().millisecondsSinceEpoch % 2 == 0 ? 1 : -1),
          child: child,
        );
      },
      child: IconButton(
        icon: Icon(
          unreadCount > 0 ? Icons.notifications_active : Icons.notifications,
          color: unreadCount > 0 ? Colors.red : Colors.black,
        ),
        onPressed: () {
          _playBellSound();
        },
        tooltip: 'Test sound',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifProvider = Provider.of<NotificationProvider>(context);
    final notifications = notifProvider.notifications;
    final isLoading = notifProvider.isLoading;
    final unreadCount = notifications.where((n) => !n.isRead).length;

    // Jouer le son automatiquement quand il y a des notifications non lues au chargement
    if (unreadCount > 0 && !_hasPlayedBell && !isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_hasPlayedBell) {
          _playBellSound();
          _hasPlayedBell = true;
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Notifications', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            if (unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        backgroundColor: _primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          // Icône de cloche animée
          _buildAnimatedBell(unreadCount),
          if (notifications.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.done_all, color: Colors.black),
              onPressed: _markAllAsRead,
              tooltip: 'Mark all as read',
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.black),
              onPressed: _deleteAllNotifications,
              tooltip: 'Delete all',
            ),
          ],
        ],
      ),
      backgroundColor: _backgroundColor,
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFB800)),
            )
          : notifications.isEmpty
              ? _buildEmptyState()
              : _buildNotificationsList(notifications),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'No notifications yet',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'When something new arrives, you\'ll find it here.',
                  style: TextStyle(
                    color: Color(0xFFA0A0B0),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: Icon(
                Icons.notifications_none,
                size: 96,
                color: _primaryColor.withOpacity(0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(List<dynamic> notifications) {
    return RefreshIndicator(
      onRefresh: _loadNotifications,
      color: _primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notif = notifications[index];
          return _buildNotificationCard(notif);
        },
      ),
    );
  }

  Widget _buildNotificationCard(dynamic notification) {
    final isRead = notification.isRead;
    final statusColor = isRead ? _textSecondary : _primaryColor;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRead ? Colors.white.withOpacity(0.08) : statusColor.withOpacity(0.3),
        ),
        boxShadow: isRead
            ? null
            : [
                BoxShadow(
                  color: statusColor.withOpacity(0.15),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (!isRead) {
              _markAsRead(notification.id);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon with bell animation for unread
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    !isRead ? Icons.notifications_active : _getIconForType(notification.type),
                    color: statusColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: isRead ? FontWeight.normal : FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFFFB800),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notification.message,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatDate(notification.createdAt),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // Delete button
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white.withOpacity(0.4), size: 20),
                  onPressed: () => _deleteNotification(notification.id),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'order_status_changed':
        return Icons.receipt_long;
      case 'new_order':
        return Icons.shopping_bag;
      case 'payment_success':
        return Icons.payment;
      case 'reservation_confirmed':
        return Icons.event_available;
      default:
        return Icons.notifications;
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 7) {
        return '${date.day}/${date.month}/${date.year}';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return dateStr;
    }
  }
}