class Order {
  final int id;
  final String status;
  final double total;
  final String user;
  final List<dynamic> orderItems;
  final String createdAt;
  final String updatedAt;

  Order({
    required this.id,
    required this.status,
    required this.total,
    required this.user,
    required this.orderItems,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: int.parse(json['id'].toString()), // Conversion en int
      status: json['status'] as String,
      total: (json['total'] as num).toDouble(),
      user: json['user'] as String,
      orderItems: json['orderItems'] as List<dynamic>,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id.toString(), // Conversion en string pour l'envoi
      'status': status,
      'total': total,
      'user': user,
      'orderItems': orderItems,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
