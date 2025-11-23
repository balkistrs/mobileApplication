import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import '../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _serverConnected = false;
  String _selectedRole = 'ROLE_CLIENT';
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  String _serverError = '';

  // Liste des rôles disponibles avec les types demandés
  final List<Map<String, dynamic>> _roles = [
    {
      'value': 'ROLE_CLIENT',
      'label': 'Client',
      'description': 'Utilisateur standard du restaurant',
      'icon': Icons.person,
    },
    {
      'value': 'ROLE_CHEF',
      'label': 'Chef',
      'description': 'Cuisinier préparant les commandes',
      'icon': Icons.restaurant_menu,
    },
    {
      'value': 'ROLE_SERVEUR',
      'label': 'Serveur',
      'description': 'Personnel de service en salle',
      'icon': Icons.local_cafe,
    },
    {
      'value': 'ROLE_ADMIN',
      'label': 'Administrateur',
      'description': 'Gestionnaire complet du système',
      'icon': Icons.admin_panel_settings,
    },
  ];

  @override
  void initState() {
    super.initState();
    _testServerConnection();
    
    // Configuration des animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
      ),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 0.8, curve: Curves.elasticOut),
      ),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );
    
    _animationController.forward();
    timeDilation = 1.5;
  }

  @override
  void dispose() {
    _animationController.dispose();
    timeDilation = 1.0;
    super.dispose();
  }

  Future<void> _testServerConnection() async {
    setState(() {
      _serverError = '';
      _isLoading = true;
    });
    
    try {
      final connected = await context.read<AuthProvider>().testConnection();
      setState(() => _serverConnected = connected);
      
      if (!connected && mounted) {
        setState(() {
          _serverError = 'Impossible de se connecter au serveur. Vérifiez votre connexion Internet.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _serverError = 'Erreur de connexion: ${e.toString()}';
          _serverConnected = false;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_serverConnected) {
      setState(() {
        _serverError = 'Veuillez attendre que la connexion au serveur soit établie.';
      });
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      debugPrint('🔄 Attempting registration...');
      debugPrint('Email: ${_emailController.text.trim()}');
      debugPrint('Role: $_selectedRole');
      
      final result = await context.read<AuthProvider>().register(
        _emailController.text.trim(), 
        _passwordController.text, 
        _selectedRole
      );
      
      if (result['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Compte créé avec succès'), 
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          )
        );
        Navigator.pop(context);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Inscription échouée'), 
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          )
        );
      }
    } catch (e) {
      debugPrint('❌ Registration error: $e');
      if (mounted) {
        String errorMessage = 'Erreur lors de l\'inscription';
        
        if (e.toString().contains('Failed to fetch') || 
            e.toString().contains('ClientException')) {
          errorMessage = 'Impossible de se connecter au serveur. Vérifiez votre connexion Internet et réessayez.';
          setState(() {
            _serverConnected = false;
          });
        } else if (e.toString().contains('Timeout')) {
          errorMessage = 'Le serveur met trop de temps à répondre. Veuillez réessayer.';
        } else if (e.toString().contains('SocketException')) {
          errorMessage = 'Problème de connexion réseau. Vérifiez votre connexion Internet.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage), 
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          )
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _build3DText(String text, {double fontSize = 24, Color color = Colors.white, Color shadowColor = Colors.black}) {
    return Stack(
      children: [
        // Ombre portée pour effet 3D
        Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = shadowColor,
            shadows: [
              Shadow(
                blurRadius: 10,
                color: shadowColor.withOpacity(0.5),
                offset: const Offset(2, 2),
              ),
            ],
          ),
        ),
        // Texte principal
        Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: color,
            shadows: [
              Shadow(
                blurRadius: 20,
                color: color.withOpacity(0.3),
                offset: const Offset(0, 0),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServerStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _serverConnected 
          ? Colors.green.withOpacity(0.2) 
          : Colors.orange.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _serverConnected 
            ? Colors.green.withOpacity(0.5) 
            : Colors.orange.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          _isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(
                    _serverConnected ? Colors.green : Colors.orange,
                  ),
                ),
              )
            : Icon(
                _serverConnected ? Icons.check_circle : Icons.warning,
                color: _serverConnected ? Colors.green : Colors.orange,
                size: 20,
              ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _serverConnected 
                ? 'Connecté au serveur' 
                : 'Connexion en cours...',
              style: TextStyle(
                color: _serverConnected ? Colors.green : Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (!_serverConnected)
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.amber, size: 20),
              onPressed: _testServerConnection,
              tooltip: 'Réessayer la connexion',
            ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    if (_serverError.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[300], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _serverError,
              style: TextStyle(color: Colors.red[300], fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[400]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.amber.withOpacity(0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.amber.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.amber),
        ),
        filled: true,
        fillColor: Colors.black.withOpacity(0.4),
        prefixIcon: Icon(icon, color: Colors.amber),
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Type de compte',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withOpacity(0.3)),
          ),
          child: Column(
            children: _roles.map((role) {
              final bool isSelected = _selectedRole == role['value'];
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedRole = role['value'];
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected 
                      ? Colors.amber.withOpacity(0.2) 
                      : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected 
                        ? Colors.amber.withOpacity(0.5) 
                        : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        role['icon'],
                        color: isSelected ? Colors.amber : Colors.grey[400],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              role['label'],
                              style: TextStyle(
                                color: isSelected ? Colors.amber : Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              role['description'],
                              style: TextStyle(
                                color: isSelected 
                                  ? Colors.amber.withOpacity(0.8) 
                                  : Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: Colors.amber,
                          size: 20,
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.amber,
        title: const Text('Inscription'),
      ),
      body: Stack(
        children: [
          // Background avec effet 3D
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: const NetworkImage(
                  'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=2070&q=80',
                ),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.8),
                  BlendMode.darken,
                ),
              ),
            ),
          ),
          
          // Overlay de dégradé
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.8),
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.4),
                ],
              ),
            ),
          ),
          
          // Contenu principal
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                
                // Header avec effet 3D
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _build3DText(
                            'Créez votre',
                            fontSize: 32,
                            color: Colors.white,
                          ),
                          _build3DText(
                            'compte',
                            fontSize: 36,
                            color: Colors.amber,
                            shadowColor: Colors.orange,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Rejoignez notre communauté',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[300],
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),

                // Carte d'inscription avec effet 3D
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.amber.withOpacity(0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.1),
                              blurRadius: 20,
                              spreadRadius: 2,
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              spreadRadius: 1,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              // Server status indicator
                              _buildServerStatus(),
                              
                              // Error message
                              if (_serverError.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                _buildErrorCard(),
                              ],
                              
                              const SizedBox(height: 24),

                              // Email field
                              _buildTextField(
                                controller: _emailController,
                                label: 'Email',
                                icon: Icons.email,
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Email requis';
                                  if (!v.contains('@')) return 'Email invalide';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),

                              // Password field
                              _buildTextField(
                                controller: _passwordController,
                                label: 'Mot de passe',
                                icon: Icons.lock,
                                obscureText: _obscurePassword,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                    color: Colors.amber,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                validator: (v) => (v == null || v.length < 6) ? 'Au moins 6 caractères' : null,
                              ),
                              const SizedBox(height: 20),

                              // Confirm password field
                              _buildTextField(
                                controller: _confirmPasswordController,
                                label: 'Confirmer mot de passe',
                                icon: Icons.lock_outline,
                                obscureText: _obscureConfirmPassword,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                                    color: Colors.amber,
                                  ),
                                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                ),
                                validator: (v) => v != _passwordController.text ? 'Les mots de passe ne correspondent pas' : null,
                              ),
                              const SizedBox(height: 20),

                              // Role selector
                              _buildRoleSelector(),
                              const SizedBox(height: 28),

                              // Register button
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: (_serverConnected && !_isLoading) ? _submit : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _serverConnected ? Colors.amber : Colors.grey,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 8,
                                    shadowColor: Colors.amber.withOpacity(0.5),
                                    textStyle: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation(Colors.black),
                                          ),
                                        )
                                      : Text(_serverConnected ? 'Créer le compte' : 'Serveur indisponible'),
                                ),
                              ),
                              
                              if (!_serverConnected) ...[
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: _testServerConnection,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.amber,
                                      side: const BorderSide(color: Colors.amber),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text('Réessayer la connexion'),
                                  ),
                                ),
                              ],
                              
                              const SizedBox(height: 24),
                              const Divider(color: Colors.grey),
                              const SizedBox(height: 16),
                              
                              // Login link
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Déjà un compte ? ',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => Navigator.pop(context),
                                    child: Text(
                                      'Se connecter',
                                      style: TextStyle(
                                        color: Colors.amber,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}