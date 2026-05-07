class Category {
  final int id;
  final String name;
  final int restaurantId;

  Category({
    required this.id,
    required this.name,
    required this.restaurantId,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      restaurantId: json['restaurant'] is Map ? 
          (json['restaurant']['id'] ?? 0) : 
          (json['restaurantId'] ?? 0),
    );
  }
}
