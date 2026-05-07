class NotificationModel {
  final int id;
  final String type;
  final String title;
  final String message;
  final int? orderId;
  bool isRead;
  final String createdAt;

  NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.orderId,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    // Gestion sécurisée des valeurs null
    int id = 0;
    if (json['id'] != null) {
      id = json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0;
    }

    String type = json['type']?.toString() ?? 'info';
    String title = json['title']?.toString() ?? 'Notification';
    String message = json['message']?.toString() ?? '';
    
    int? orderId;
    if (json['orderId'] != null) {
      orderId = json['orderId'] is int ? json['orderId'] : int.tryParse(json['orderId'].toString());
    } else if (json['order_id'] != null) {
      orderId = json['order_id'] is int ? json['order_id'] : int.tryParse(json['order_id'].toString());
    }
    
    bool isRead = false;
    if (json['isRead'] != null) {
      isRead = json['isRead'] == true;
    } else if (json['is_read'] != null) {
      isRead = json['is_read'] == true;
    }
    
    String createdAt = json['created_at']?.toString() ?? DateTime.now().toIso8601String();

    return NotificationModel(
      id: id,
      type: type,
      title: title,
      message: message,
      orderId: orderId,
      isRead: isRead,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'message': message,
      'orderId': orderId,
      'isRead': isRead,
      'created_at': createdAt,
    };
  }
}