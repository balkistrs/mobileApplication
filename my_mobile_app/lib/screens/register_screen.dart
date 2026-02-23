import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'dart:ui'; // Nécessaire pour l'effet de flou (BackdropFilter)
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
  String _serverError = '';
  String _selectedRole = 'ROLE_CLIENT';
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  // Liste des rôles disponibles
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

  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _testServerConnection();
    timeDilation = 1.2; // Légèrement ralenti pour plus d'élégance
  }

  @override
  void dispose() {
    _animationController.dispose();
    timeDilation = 1.0;
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    
    _animationController.forward();
  }

  // --- Logique d'inscription ---

  Future<void> _testServerConnection() async {
    setState(() { 
      _serverError = ''; 
      _isLoading = true; 
    });
    
    try {
      final connected = await context.read<AuthProvider>().testConnection();
      
      setState(() {
        _serverConnected = connected;
        _isLoading = false;
        if (!connected) _serverError = 'Liaison serveur interrompue. Vérifiez votre accès réseau.';
      });
    } catch (e) {
      if (mounted) {
        setState(() { 
          _serverConnected = false; 
          _isLoading = false; 
          _serverError = 'Erreur réseau critique.'; 
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_serverConnected) {
      setState(() => _serverError = 'Connexion serveur requise pour s\'inscrire.');
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      final result = await context.read<AuthProvider>().register(
        _emailController.text.trim(), 
        _passwordController.text,
        _selectedRole
      );
      
      if (!mounted) return;
      
      if (result['success'] == true) {
        _showSnackBar('Compte créé avec succès', Colors.green);
        Navigator.pop(context);
      } else {
        _showSnackBar(result['message'] ?? 'Inscription échouée', Colors.redAccent);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Erreur système : ${e.toString()}', Colors.redAccent);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg), 
        backgroundColor: color, 
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // --- Interface Design (identique à LoginScreen) ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F), // Noir profond organique
      body: Stack(
        children: [
          _buildParallaxBackground(),
          _buildMainOverlay(),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  _buildAnimatedLogo(),
                  const SizedBox(height: 24),
                  _buildAnimatedHeader(),
                  const SizedBox(height: 40),
                  _buildRegisterCard(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParallaxBackground() {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: NetworkImage('https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?q=80&w=2070&auto=format&fit=crop'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildMainOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            const Color(0xFF0F0F0F).withOpacity(0.9),
            const Color(0xFF0F0F0F),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedLogo() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.amber.withOpacity(0.2), width: 1),
          boxShadow: [
            BoxShadow(color: Colors.amber.withOpacity(0.05), blurRadius: 30, spreadRadius: 5)
          ],
        ),
        child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.amber, size: 45),
      ),
    );
  }

  Widget _buildAnimatedHeader() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          Text(
            'INSCRIPTION',
            style: TextStyle(
              letterSpacing: 3,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.amber.shade300,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Smart Resto Pro',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Container(height: 2, width: 30, color: Colors.amber),
        ],
      ),
    );
  }

  Widget _buildRegisterCard() {
    return SlideTransition(
      position: _slideAnimation,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildServerStatus(),
                  if (_serverError.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildErrorCard(),
                  ],
                  const SizedBox(height: 24),
                  _buildEmailField(),
                  const SizedBox(height: 16),
                  _buildPasswordField(),
                  const SizedBox(height: 16),
                  _buildConfirmPasswordField(),
                  const SizedBox(height: 20),
                  _buildRoleSelector(),
                  const SizedBox(height: 32),
                  _buildRegisterButton(),
                  const SizedBox(height: 20),
                  _buildLoginSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServerStatus() {
    return Row(
      children: [
        Container(
          width: 8, 
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _serverConnected ? Colors.greenAccent : Colors.orangeAccent,
            boxShadow: [
              BoxShadow(
                color: (_serverConnected ? Colors.greenAccent : Colors.orangeAccent).withOpacity(0.4),
                blurRadius: 6, 
                spreadRadius: 2
              )
            ]
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _serverConnected ? 'SYSTÈME OPÉRATIONNEL' : 'RECHERCHE DU SERVEUR...',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: Text(
        _serverError, 
        style: const TextStyle(color: Colors.redAccent, fontSize: 12)
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: _inputDecoration('Email Professionnel', Icons.email_outlined),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Email requis';
        }
        if (!value.contains('@') || !value.contains('.')) {
          return 'Email invalide';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: _inputDecoration('Mot de passe', Icons.lock_outline).copyWith(
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility, 
            color: Colors.amber.withOpacity(0.7), 
            size: 20
          ),
          onPressed: () {
            if (mounted) {
              setState(() => _obscurePassword = !_obscurePassword);
            }
          },
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Mot de passe requis';
        }
        if (value.length < 6) {
          return 'Minimum 6 caractères';
        }
        return null;
      },
    );
  }

  Widget _buildConfirmPasswordField() {
    return TextFormField(
      controller: _confirmPasswordController,
      obscureText: _obscureConfirmPassword,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: _inputDecoration('Confirmer mot de passe', Icons.lock_outline).copyWith(
        suffixIcon: IconButton(
          icon: Icon(
            _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, 
            color: Colors.amber.withOpacity(0.7), 
            size: 20
          ),
          onPressed: () {
            if (mounted) {
              setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
            }
          },
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Confirmation requise';
        }
        if (value != _passwordController.text) {
          return 'Les mots de passe ne correspondent pas';
        }
        return null;
      },
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.amber.withOpacity(0.8), size: 20),
      filled: true,
      fillColor: Colors.black.withOpacity(0.2),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14), 
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08))
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14), 
        borderSide: const BorderSide(color: Colors.amber, width: 1)
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 18),
    );
  }

  Widget _buildRoleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TYPE DE COMPTE',
          style: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 10,
            letterSpacing: 1.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected 
                      ? Colors.amber.withOpacity(0.1) 
                      : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        role['icon'],
                        color: isSelected ? Colors.amber : Colors.white.withOpacity(0.5),
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
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              role['description'],
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: Colors.amber,
                          size: 18,
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

  Widget _buildRegisterButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          if (_serverConnected) 
            BoxShadow(
              color: Colors.amber.withOpacity(0.25), 
              blurRadius: 20, 
              offset: const Offset(0, 4)
            )
        ],
      ),
      child: ElevatedButton(
        onPressed: (_serverConnected && !_isLoading && mounted) ? _submit : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amber,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24, 
                height: 24, 
                child: CircularProgressIndicator(
                  strokeWidth: 2.5, 
                  color: Colors.black
                )
              )
            : const Text(
                'CRÉER LE COMPTE', 
                style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.1)
              ),
      ),
    );
  }

  Widget _buildLoginSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Déjà membre ?', 
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)
        ),
        TextButton(
          onPressed: () {
            if (mounted) {
              Navigator.pop(context);
            }
          },
          child: const Text(
            'Se connecter', 
            style: TextStyle(
              color: Colors.amber, 
              fontWeight: FontWeight.bold, 
              fontSize: 13
            ),
          ),
        ),
      ],
    );
  }
}