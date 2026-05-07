import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb; // AJOUTER CET IMPORT
import '../providers/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TextEditingController _emailController;
  late TextEditingController _nameController;
  bool _isProcessing = false;
  bool _isEditing = false;
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _emailController = TextEditingController(text: auth.user?.email ?? '');
    _nameController = TextEditingController(text: auth.user?.name ?? '');
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La sélection d\'image n\'est pas disponible sur le web'),
          backgroundColor: Colors.orange,
        ),
      );
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
        setState(() {
          _profileImage = File(image.path);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo sélectionnée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _takePhoto() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La caméra n\'est pas disponible sur le web'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo prise avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showImagePickerDialog() {
    if (kIsWeb) {
      _showWebImagePicker();
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Photo de profil',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.amber),
              title: const Text('Choisir dans la galerie', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.amber),
              title: const Text('Prendre une photo', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _takePhoto();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showWebImagePicker() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pour changer votre photo, veuillez utiliser l\'application mobile'),
        duration: Duration(seconds: 3),
        backgroundColor: Colors.amber,
      ),
    );
  }

  Future<void> _saveProfile() async {
    final auth = context.read<AuthProvider>();
    final oldEmail = auth.user?.email ?? '';
    final newEmail = _emailController.text.trim();
    final newName = _nameController.text.trim();
    
    if (newEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email requis'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);
    
    try {
      final success = await auth.updateUser(
        oldEmail, 
        newEmail, 
        newName, 
        auth.selectedRole ?? ''
      );
      
      if (success) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil mis à jour avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Échec de la mise à jour');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Widget _buildAvatar() {
    final auth = context.watch<AuthProvider>();
    
    return GestureDetector(
      onTap: _isEditing ? _showImagePickerDialog : null,
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.amber.withOpacity(0.3),
                  Colors.amber.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.amber.withOpacity(0.5), width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.3),
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
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.black,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _getAvatarImage(AuthProvider auth) {
    // Pour le web, on utilise NetworkImage ou AssetImage, pas FileImage
    if (kIsWeb) {
      if (auth.user?.photoUrl != null && auth.user!.photoUrl!.isNotEmpty) {
        return Image.network(
          auth.user!.photoUrl!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.person_rounded,
              size: 60,
              color: Colors.amber,
            );
          },
        );
      } else {
        return const Icon(
          Icons.person_rounded,
          size: 60,
          color: Colors.amber,
        );
      }
    } else {
      // Pour mobile, on peut utiliser FileImage
      if (_profileImage != null) {
        return Image.file(
          _profileImage!,
          fit: BoxFit.cover,
        );
      } else if (auth.user?.photoUrl != null && auth.user!.photoUrl!.isNotEmpty) {
        return Image.network(
          auth.user!.photoUrl!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.person_rounded,
              size: 60,
              color: Colors.amber,
            );
          },
        );
      } else {
        return const Icon(
          Icons.person_rounded,
          size: 60,
          color: Colors.amber,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Profil',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: Colors.amber),
              onPressed: () => setState(() => _isEditing = true),
            ),
          if (_isEditing)
            TextButton.icon(
              onPressed: _isProcessing ? null : _saveProfile,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.amber,
                      ),
                    )
                  : const Icon(Icons.save_rounded, color: Colors.amber),
              label: Text(
                _isProcessing ? 'Enregistrement...' : 'Enregistrer',
                style: const TextStyle(color: Colors.amber),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildAvatar(),
              const SizedBox(height: 24),
              
              // Carte d'informations
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
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
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.person_outline, color: Colors.amber),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Informations personnelles',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Email
                    _buildInfoField(
                      label: 'Email',
                      icon: Icons.email_rounded,
                      controller: _emailController,
                      enabled: _isEditing,
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Nom
                    _buildInfoField(
                      label: 'Nom',
                      icon: Icons.person_rounded,
                      controller: _nameController,
                      enabled: _isEditing,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Carte des rôles
              if (auth.user?.roles != null && auth.user!.roles!.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
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
                              color: Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.admin_panel_settings, color: Colors.amber),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Rôles',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: auth.user!.roles!.map((role) {
                          String displayRole = role.replaceAll('ROLE_', '');
                          Color roleColor;
                          
                          switch (role) {
                            case 'ROLE_ADMIN':
                              roleColor = Colors.red;
                              break;
                            case 'ROLE_CHEF':
                              roleColor = Colors.orange;
                              break;
                            case 'ROLE_SERVEUR':
                              roleColor = Colors.blue;
                              break;
                            default:
                              roleColor = Colors.green;
                          }
                          
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: roleColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: roleColor.withOpacity(0.3)),
                            ),
                            child: Text(
                              displayRole,
                              style: TextStyle(
                                color: roleColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 30),
              
              // Boutons d'action
              if (!_isEditing)
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => setState(() => _isEditing = true),
                        icon: const Icon(Icons.edit_rounded),
                        label: const Text('MODIFIER LE PROFIL'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final authProvider = context.read<AuthProvider>();
                          await authProvider.logout();
                          if (mounted) {
                            Navigator.pushReplacementNamed(context, '/login');
                          }
                        },
                        icon: const Icon(Icons.logout_rounded, color: Colors.red),
                        label: const Text(
                          'DÉCONNEXION',
                          style: TextStyle(color: Colors.red),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required bool enabled,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: enabled ? Colors.black.withOpacity(0.3) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: enabled
                ? Border.all(color: Colors.amber.withOpacity(0.3))
                : null,
          ),
          child: TextFormField(
            controller: controller,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            enabled: enabled,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.amber, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}