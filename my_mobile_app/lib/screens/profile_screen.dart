import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _emailController;
  late TextEditingController _nameController;
  bool _isProcessing = false;

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

  Future<void> _saveProfile() async {
    final auth = context.read<AuthProvider>();
    final oldEmail = auth.user?.email ?? '';
    final newEmail = _emailController.text.trim();
    final newName = _nameController.text.trim();
    if (newEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email requis'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isProcessing = true);
    final success = await auth.updateUser(oldEmail, newEmail, newName, auth.selectedRole ?? '');
    setState(() => _isProcessing = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil mis à jour'), backgroundColor: Colors.green));
      // Note: AuthProvider.user is not updated locally here; app may need re-login to refresh user info.
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Échec mise à jour'), backgroundColor: Colors.red));
    }
  }

 

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: const Color(0xFF1A1A1A),
      ),
      backgroundColor: const Color(0xFF0A0A0A),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text('Email', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            TextField(
              controller: _emailController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Nom (local)', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Afficher un nom ',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
           
            const SizedBox(height: 16),
            if (auth.user != null) Text('Rôles: ${auth.user!.roles?.join(", ") ?? "-"}', style: const TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}
