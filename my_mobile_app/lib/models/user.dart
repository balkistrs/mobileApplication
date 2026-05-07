import 'dart:convert';

class AppUser {
  final int id;
  final String email;
  final String name;
  final List<String>? roles;
  final String? googleId;
  final String? photoUrl;
  final String? vote;

  AppUser({
    required this.id,
    required this.email,
    required this.name,
    this.roles,
    this.googleId,
    this.photoUrl,
    this.vote,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    // Handle roles safely
    List<String>? rolesList;
    
    if (json['roles'] != null) {
      if (json['roles'] is List) {
        rolesList = (json['roles'] as List)
            .map((role) => role is String ? role : role.toString())
            .toList();
      } else if (json['roles'] is String) {
        final rolesStr = json['roles'] as String;
        if (rolesStr.startsWith('[') && rolesStr.endsWith(']')) {
          try {
            final parsed = jsonDecode(rolesStr);
            if (parsed is List) {
              rolesList = parsed.map((e) => e.toString()).toList();
            } else {
              rolesList = [rolesStr];
            }
          } catch (_) {
            rolesList = [rolesStr];
          }
        } else {
          rolesList = [rolesStr];
        }
      } else {
        rolesList = [json['roles'].toString()];
      }
    }

    return AppUser(
      id: json['id'] ?? 0,
      email: json['email'] ?? '',
      name: json['name'] ?? (json['email']?.toString().split('@')[0] ?? ''),
      roles: rolesList ?? ['ROLE_CLIENT'],
      googleId: json['google_id']?.toString(),
      photoUrl: json['photo_url']?.toString(),
      vote: json['vote']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'roles': roles,
      'google_id': googleId,
      'photo_url': photoUrl,
      'vote': vote,
    };
  }

  bool hasRole(String role) {
    return roles?.contains(role) ?? false;
  }

  bool get isAdmin => hasRole('ROLE_ADMIN');
  bool get isChef => hasRole('ROLE_CHEF');
  bool get isServeur => hasRole('ROLE_SERVEUR');
  bool get isClient => hasRole('ROLE_CLIENT');

  @override
  String toString() {
    return 'AppUser(id: $id, email: $email, name: $name, roles: $roles)';
  }
}