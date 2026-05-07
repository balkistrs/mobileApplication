// admin_users_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final Color primaryColor = const Color(0xFFFFB800);
  final Color backgroundColor = const Color(0xFF0A0A0F);
  final Color cardColor = const Color(0xFF14141F);

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      await context.read<UserProvider>().loadUsers();
    }
  }

  Future<void> _refreshUsers() async {
    await context.read<UserProvider>().loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshUsers,
          ),
        ],
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          if (userProvider.error?.contains('Token') ?? false) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.orange, size: 60),
                  const SizedBox(height: 16),
                  const Text(
                    'Token not available. Please reconnect.',
                    style: TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<AuthProvider>().logout();
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Reconnect'),
                  ),
                ],
              ),
            );
          }

          if (userProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.amber),
            );
          }

          if (userProvider.error != null) {
            return Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(25),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.withAlpha(76)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 50),
                    const SizedBox(height: 16),
                    Text(
                      userProvider.error!,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refreshUsers,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('RETRY'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (userProvider.users.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 80, color: Colors.white.withAlpha(51)),
                  const SizedBox(height: 16),
                  const Text(
                    'No users found',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshUsers,
            color: Colors.amber,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: userProvider.users.length,
              itemBuilder: (context, index) {
                final user = userProvider.users[index];
                return _buildUserCard(user, userProvider);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserCard(AppUser user, UserProvider userProvider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(25)),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.amber.withAlpha(25),
          child: Text(
            user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          user.name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          user.email,
          style: TextStyle(color: Colors.white.withAlpha(179), fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRoleChip(user.roles ?? []),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white70),
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditDialog(user, userProvider);
                } else if (value == 'delete') {
                  _deleteUser(context, user, userProvider);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: Colors.blue, size: 18),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red, size: 18),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(76),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('ID', user.id.toString()),
                _buildInfoRow('Email', user.email),
                _buildInfoRow('Roles', (user.roles ?? []).join(', ')),
                if (user.googleId != null) _buildInfoRow('Google ID', user.googleId!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleChip(List<String> roles) {
    Color chipColor = Colors.grey;
    String label = 'User';
    
    if (roles.contains('ROLE_ADMIN')) {
      chipColor = Colors.red;
      label = 'Admin';
    } else if (roles.contains('ROLE_CHEF')) {
      chipColor = Colors.blue;
      label = 'Chef';
    } else if (roles.contains('ROLE_SERVEUR')) {
      chipColor = Colors.green;
      label = 'Server';
    } else if (roles.contains('ROLE_DELIVERY')) {
      chipColor = Colors.purple;
      label = 'Delivery';
    } else {
      chipColor = Colors.amber;
      label = 'Client';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withAlpha(51),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor.withAlpha(128)),
      ),
      child: Text(
        label,
        style: TextStyle(color: chipColor, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(color: Colors.white.withAlpha(128), fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(AppUser user, UserProvider userProvider) {
    final nameController = TextEditingController(text: user.name);
    final emailController = TextEditingController(text: user.email);
    String selectedRole = 'client';
    
    if (user.roles?.contains('ROLE_ADMIN') ?? false) {
      selectedRole = 'admin';
    } else if (user.roles?.contains('ROLE_CHEF') ?? false) {
      selectedRole = 'chef';
    } else if (user.roles?.contains('ROLE_SERVEUR') ?? false) {
      selectedRole = 'serveur';
    } else if (user.roles?.contains('ROLE_DELIVERY') ?? false) {
      selectedRole = 'delivery';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: const Text('Edit User', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle: TextStyle(color: Colors.white.withAlpha(179)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(color: Colors.white.withAlpha(179)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedRole,
                style: const TextStyle(color: Colors.white),
                dropdownColor: cardColor,
                decoration: InputDecoration(
                  labelText: 'Role',
                  labelStyle: TextStyle(color: Colors.white.withAlpha(179)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('Administrator', style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(value: 'chef', child: Text('Chef', style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(value: 'serveur', child: Text('Server', style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(value: 'delivery', child: Text('Delivery', style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(value: 'client', child: Text('Client', style: TextStyle(color: Colors.white))),
                ],
                onChanged: (value) {
                  selectedRole = value!;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final roleMap = {
                'admin': 'ROLE_ADMIN',
                'chef': 'ROLE_CHEF',
                'serveur': 'ROLE_SERVEUR',
                'delivery': 'ROLE_DELIVERY',
                'client': 'ROLE_CLIENT',
              };
              
              final updated = await userProvider.updateUser(
                user.id,
                {
                  'name': nameController.text,
                  'email': emailController.text,
                  'role': roleMap[selectedRole] ?? 'ROLE_CLIENT',
                },
              );
              
              if (updated != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('User updated successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteUser(BuildContext context, AppUser user, UserProvider userProvider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        title: const Text('Confirm Delete', style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete ${user.name}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await userProvider.deleteUser(user.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}