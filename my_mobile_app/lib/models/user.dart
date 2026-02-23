class AppUser {
  final int id;
  final String email;
  final String? name;
  final List<String>? roles;
  final String? vote;

  AppUser({
    required this.id,
    required this.email,
    this.name,
    this.roles,
    this.vote,
  });

factory AppUser.fromJson(Map<String, dynamic> json) {
  return AppUser(
    id: int.tryParse(json['id'].toString()) ?? 0, // ← Conversion sécurisée
    email: json['email']?.toString() ?? '',
    name: json['name']?.toString() ?? json['username']?.toString(),
    roles: (json['roles'] as List<dynamic>?)?.map((role) => role.toString()).toList(),
    vote: json['vote']?.toString(),
  );
}

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'roles': roles,
      'vote': vote,
    };
  }
}