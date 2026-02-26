class Restaurant {
  final int id;
  final String name;
  final String? imageUrl;
  final double rating;
  final String deliveryTime;
  final String? description;

  Restaurant({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.rating,
    required this.deliveryTime,
    this.description,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      imageUrl: json['imageUrl'] ?? json['image_url'],
      rating: (json['rating'] is num) ? (json['rating'] as num).toDouble() : 0.0,
      deliveryTime: json['deliveryTime'] ?? json['delivery_time'] ?? '',
      description: json['description'],
    );
  }
}
