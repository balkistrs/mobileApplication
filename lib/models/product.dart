class Product {
  final int id;
  final String name;
  final String? description;
  final double price;
  final String? imageUrl;
  final int categoryId;

  Product({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.imageUrl,
    required this.categoryId,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'],
      price: (json['price'] is num) ? (json['price'] as num).toDouble() : 0.0,
      imageUrl: json['imageUrl'] ?? json['image_url'],
      categoryId: json['category'] is Map ? 
          json['category']['id'] ?? 0 : 
          (json['categoryId'] ?? 0),
    );
  }
}
