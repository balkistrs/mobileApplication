import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
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
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Palette Jaune et Blanc
  final Color _primaryColor = const Color(0xFFFFB800);
  final Color _secondaryColor = const Color(0xFFFFD54F);
  final Color _accentColor = const Color(0xFFFFA000);
  final Color _successColor = const Color(0xFF2ECC71);
  final Color _errorColor = const Color(0xFFD73357);
  final Color _textPrimary = const Color(0xFF1A1A1A);
  final Color _textSecondary = const Color(0xFF666666);
  final Color _cardColor = Colors.white.withValues(alpha: 0.95);
  final Color _surfaceColor = Colors.transparent;
  final Color _surfaceElevated = Colors.white.withOpacity(0.9);
  final Color _onSurfaceVariant = const Color(0xFF757575);

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

  Future<void> _saveProfile() async {
    final auth = context.read<AuthProvider>();
    final oldEmail = auth.user?.email ?? '';
    final newEmail = _emailController.text.trim();
    final newName = _nameController.text.trim();
    
    if (newEmail.isEmpty) {
      _showSnackBar('Email required', _errorColor);
      return;
    }

    setState(() => _isProcessing = true);
    
    try {
      final success = await auth.updateUser(oldEmail, newEmail, newName, '');
      if (success) {
        setState(() => _isEditing = false);
        _showSnackBar('Profile updated successfully', _successColor);
      } else {
        throw Exception('Update failed');
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', _errorColor);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _getAvatarUrl(AuthProvider auth) {
    if (auth.user?.photoUrl != null && auth.user!.photoUrl!.isNotEmpty) {
      return auth.user!.photoUrl!;
    }
    final name = auth.user?.name ?? auth.user?.email?.split('@')[0] ?? 'User';
    return 'https://ui-avatars.com/api/?background=FFB800&color=fff&size=128&name=${Uri.encodeComponent(name)}&bold=true&rounded=true';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final userName = auth.user?.name ?? auth.user?.email?.split('@')[0] ?? 'Guest';
    final userEmail = auth.user?.email ?? '';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Fond transparent
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.98),
                    Colors.white.withOpacity(0.95),
                  ],
                ),
              ),
            ),
          ),
          
          // Légères ombres décoratives
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _primaryColor.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _secondaryColor.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    
                    // Header avec bouton retour
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
                          ),
                        ),
                        const Spacer(),
                        if (!_isEditing)
                          Container(
                            decoration: BoxDecoration(
                              color: _primaryColor,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: IconButton(
                              onPressed: () => setState(() => _isEditing = true),
                              icon: const Icon(Icons.edit_rounded, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Avatar
                    Stack(
                      children: [
                        Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: _primaryColor.withValues(alpha: 0.3),
                                blurRadius: 25,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: ClipOval(
                              child: Image.network(
                                _getAvatarUrl(auth),
                                fit: BoxFit.cover,
                                width: 130,
                                height: 130,
                                errorBuilder: (_, __, ___) => Container(
                                  color: _primaryColor,
                                  child: const Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 5,
                          right: 5,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: _successColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: const Icon(Icons.check, size: 12, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // User name
                    Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        userEmail,
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Carte d'informations personnelles
                    _buildWhiteCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader(
                            icon: Icons.person_outline_rounded,
                            title: 'Personal Information',
                            color: _primaryColor,
                          ),
                          const SizedBox(height: 24),
                          _buildInfoField(
                            label: 'Email Address',
                            icon: Icons.email_outlined,
                            controller: _emailController,
                            enabled: _isEditing,
                          ),
                          const SizedBox(height: 20),
                          _buildInfoField(
                            label: 'Full Name',
                            icon: Icons.person_outline,
                            controller: _nameController,
                            enabled: _isEditing,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Carte des rôles
                    if (auth.user?.roles != null && auth.user!.roles!.isNotEmpty)
                      _buildWhiteCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                              icon: Icons.admin_panel_settings_rounded,
                              title: 'Roles & Permissions',
                              color: _primaryColor,
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: auth.user!.roles!.map((role) {
                                String displayRole = role.replaceAll('ROLE_', '');
                                return _buildRoleChip(displayRole);
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 32),
                    
                    // Action buttons
                    if (!_isEditing) ...[
                      _buildYellowButton(
                        label: 'EDIT PROFILE',
                        icon: Icons.edit_rounded,
                        onPressed: () => setState(() => _isEditing = true),
                      ),
                      const SizedBox(height: 12),
                      _buildOutlineButton(
                        label: 'SIGN OUT',
                        icon: Icons.logout_rounded,
                        onPressed: () async => _showLogoutDialog(auth),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: _buildOutlineButton(
                              label: 'CANCEL',
                              icon: Icons.close_rounded,
                              onPressed: () => setState(() => _isEditing = false),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildYellowButton(
                              label: 'SAVE CHANGES',
                              icon: Icons.check_rounded,
                              onPressed: _isProcessing ? null : _saveProfile,
                              isLoading: _isProcessing,
                            ),
                          ),
                        ],
                      ),
                    ],
                    
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhiteCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: child,
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
      ],
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
            color: _textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: enabled ? _primaryColor.withValues(alpha: 0.4) : Colors.transparent,
            ),
          ),
          child: TextFormField(
            controller: controller,
            style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 15),
            enabled: enabled,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: _primaryColor, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleChip(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: _primaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, color: _primaryColor, size: 14),
          const SizedBox(width: 6),
          Text(
            role,
            style: TextStyle(
              color: _primaryColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYellowButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return Container(
      height: 54,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: [_primaryColor, _secondaryColor],
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildOutlineButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFD73357)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: _errorColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                letterSpacing: 0.5,
                color: _errorColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLogoutDialog(AuthProvider auth) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: _errorColor),
            const SizedBox(width: 12),
            const Text('Sign Out', style: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: Color(0xFF666666)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF757575))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _errorColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await auth.logout();
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }
}