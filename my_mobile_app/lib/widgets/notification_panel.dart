import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/auth_provider.dart';

class NotificationPanel extends StatefulWidget {
  const NotificationPanel({super.key});

  @override
  State<NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends State<NotificationPanel> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  late Future<List<Map<String, dynamic>>> _notificationsFuture;
  final Set<int> _playedSounds = {}; // Ajout de 'final'

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _loadNotifications() {
    final auth = context.read<AuthProvider>();
    _notificationsFuture = auth.getUserNotifications(); // Changé de getNotifications à getUserNotifications
  }

  void _playNotificationSound() async {
    try {
      await _audioPlayer.play(
        AssetSource('sounds/notification.mp3'),
        volume: 1.0,
      );
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  void _deleteNotification(int notifId) async {
    final auth = context.read<AuthProvider>();
    final deleted = await auth.deleteNotification(notifId);
    
    if (deleted) {
      setState(() {
        _loadNotifications();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _notificationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: const Text(
              'Aucune notification',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          );
        }

        final notifications = snapshot.data!;
        
        // Jouer un son pour les nouvelles notifications
        for (var notif in notifications) {
          final notifId = notif['id'] as int;
          if (!_playedSounds.contains(notifId)) {
            _playedSounds.add(notifId);
            _playNotificationSound();
          }
        }

        return ListView.builder(
          shrinkWrap: true,
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notif = notifications[index];
            final notifId = notif['id'] as int;
            final type = notif['type'] as String? ?? 'info';
            final title = notif['title'] as String? ?? 'Notification';
            final message = notif['message'] as String? ?? '';
            final isRead = notif['isRead'] as bool? ?? false;

            Color borderColor = Colors.blue;
            IconData iconData = Icons.info;

            if (type == 'new_order') {
              borderColor = Colors.green;
              iconData = Icons.shopping_cart;
            } else if (type == 'order_status_changed') {
              borderColor = Colors.orange;
              iconData = Icons.update;
            } else if (type == 'order_ready_for_delivery') {
              borderColor = Colors.purple;
              iconData = Icons.local_shipping;
            }

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: borderColor, width: 4)),
                color: isRead ? Colors.grey[100] : Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                leading: Icon(iconData, color: borderColor),
                title: Text(
                  title,
                  style: TextStyle(
                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Text(message),
                trailing: PopupMenuButton(
                  itemBuilder: (context) => [
                    if (!isRead)
                      PopupMenuItem(
                        child: const Text('Marquer comme lu'),
                        onTap: () async {
                          await context.read<AuthProvider>()
                              .markNotificationAsRead(notifId);
                          setState(() {
                            _loadNotifications();
                          });
                        },
                      ),
                    PopupMenuItem(
                      child: const Text('Supprimer'),
                      onTap: () {
                        _deleteNotification(notifId);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}