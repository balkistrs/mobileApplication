class ReviewModel {
  final String id;
  final String userId;
  final String userName;
  final String? userPhoto;
  final String orderId;
  final double rating;
  final String comment;
  final List<String>? images;
  final DateTime createdAt;
  final String? response;

  ReviewModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhoto,
    required this.orderId,
    required this.rating,
    required this.comment,
    this.images,
    required this.createdAt,
    this.response,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? 'Anonymous',
      userPhoto: json['userPhoto'],
      orderId: json['orderId']?.toString() ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      comment: json['comment'] ?? '',
      images: json['images'] != null ? List<String>.from(json['images']) : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      response: json['response'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userPhoto': userPhoto,
      'orderId': orderId,
      'rating': rating,
      'comment': comment,
      'images': images,
      'createdAt': createdAt.toIso8601String(),
      'response': response,
    };
  }
}