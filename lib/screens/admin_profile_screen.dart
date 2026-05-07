import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../providers/auth_provider.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  late TextEditingController _emailController;
  late TextEditingController _nameController;
  bool _isProcessing = false;
  bool _isEditing = false;
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _emailController = TextEditingController(text: auth.user?.email ?? '');
    _nameController = TextEditingController(text: auth.user?.name ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (kIsWeb) {
      _showMessage('Image selection not available on web', Colors.orange);
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() => _profileImage = File(image.path));
        _showMessage('Photo selected successfully', Colors.green);
      }
    } catch (e) {
      _showMessage('Error: $e', Colors.red);
    }
  }

  Future<void> _saveProfile() async {
    final auth = context.read<AuthProvider>();
    final oldEmail = auth.user?.email ?? '';
    final newEmail = _emailController.text.trim();
    final newName = _nameController.text.trim();
    
    if (newEmail.isEmpty) {
      _showMessage('Email required', Colors.red);
      return;
    }

    setState(() => _isProcessing = true);
    
    try {
      final success = await auth.updateUser(oldEmail, newEmail, newName, '');
      if (success) {
        setState(() => _isEditing = false);
        _showMessage('Profile updated successfully', Colors.green);
      } else {
        _showMessage('Update failed', Colors.red);
      }
    } catch (e) {
      _showMessage('Error: ${e.toString()}', Colors.red);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showMessage(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildAvatar() {
    final auth = context.watch<AuthProvider>();
    
    return GestureDetector(
      onTap: _isEditing ? _pickImage : null,
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber.withAlpha(76), Colors.amber.withAlpha(25)],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.amber.withAlpha(128), width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withAlpha(76),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ClipOval(
              child: _getAvatarImage(auth),
            ),
          ),
          if (_isEditing)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.black, size: 20),
              ),
            ),
        ],
      ),
    );
  }

  Widget _getAvatarImage(AuthProvider auth) {
    if (!kIsWeb && _profileImage != null) {
      return Image.file(_profileImage!, fit: BoxFit.cover);
    } else if (auth.user?.photoUrl != null && auth.user!.photoUrl!.isNotEmpty) {
      return Image.network(
        auth.user!.photoUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.admin_panel_settings, size: 60, color: Colors.amber);
        },
      );
    } else {
      return const Icon(Icons.admin_panel_settings, size: 60, color: Colors.amber);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Logout', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to logout?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Logout')),
        ],
      ),
    );

    if (confirm == true) {
      final auth = context.read<AuthProvider>();
      await auth.logout();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        title: const Text('Admin Profile'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.black),
              onPressed: () => setState(() => _isEditing = true),
            ),
          if (_isEditing)
            IconButton(
              icon: _isProcessing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save, color: Colors.black),
              onPressed: _isProcessing ? null : _saveProfile,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildAvatar(),
            const SizedBox(height: 30),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(13),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withAlpha(25)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withAlpha(51),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.admin_panel_settings, color: Colors.amber),
                      ),
                      const SizedBox(width: 12),
                      const Text('Information', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildInfoRow('Email', _emailController.text, !_isEditing),
                  const SizedBox(height: 16),
                  _buildInfoRow('Name', _nameController.text, !_isEditing),
                  const SizedBox(height: 16),
                  _buildInfoRow('Role', 'Administrator', true),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_isEditing)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(13),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber.withAlpha(76)),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Edit Information', style: TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'New Name',
                        labelStyle: TextStyle(color: Colors.white.withAlpha(128)),
                        prefixIcon: const Icon(Icons.person, color: Colors.amber),
                        filled: true,
                        fillColor: Colors.black.withAlpha(76),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'New Email',
                        labelStyle: TextStyle(color: Colors.white.withAlpha(128)),
                        prefixIcon: const Icon(Icons.email, color: Colors.amber),
                        filled: true,
                        fillColor: Colors.black.withAlpha(76),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('LOGOUT'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isStatic) {
    return Row(
      children: [
        Text('$label: ', style: const TextStyle(color: Colors.white70)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: isStatic ? Colors.white : Colors.amber,
              fontWeight: isStatic ? FontWeight.normal : FontWeight.bold,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}