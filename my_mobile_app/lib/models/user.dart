class AppUser {
  final int id;
  final String email;
  final List<String>? roles;

  AppUser({
    required this.id,
    required this.email,
    this.roles,
  });

factory AppUser.fromJson(Map<String, dynamic> json) {
  return AppUser(
    id: int.tryParse(json['id'].toString()) ?? 0, // ← Conversion sécurisée
    email: json['email']?.toString() ?? '',
    roles: (json['roles'] as List<dynamic>?)?.map((role) => role.toString()).toList(),
  );
}

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'roles': roles,
    };
  }
}