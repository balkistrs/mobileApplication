import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import '../providers/auth_provider.dart';
import 'ChefScreen.dart';
import 'ServeurScreen.dart';
import 'restaurant_screen.dart';
import 'admin_screen.dart';
import 'register_screen.dart';
import 'qr_scanner_wrapper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'asmatrabelsi@gmail.com');
  final _passwordController = TextEditingController(text: '02340169');
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _serverConnected = false;
  String _serverError = '';
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _testServerConnection();
    
    // Effet de parallaxe pour le background
    timeDilation = 1.5;
  }

  @override
  void dispose() {
    _animationController.dispose();
    timeDilation = 1.0;
    super.dispose();
  }

  void _initializeAnimations() {
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
  }

  Future<void> _testServerConnection() async {
    try {
      setState(() {
        _serverError = '';
        _isLoading = true;
      });
      
      final connected = await context.read<AuthProvider>().testConnection();
      
      setState(() {
        _serverConnected = connected;
        _isLoading = false;
        if (!connected) {
          _serverError = 'Impossible de se connecter au serveur. '
                         'Vérifiez votre connexion internet.';
        }
      });
      
      if (connected) {
        await _tryAutoLogin();
      }
    } catch (e) {
      debugPrint('Connection test failed: $e');
      setState(() {
        _serverConnected = false;
        _isLoading = false;
        _serverError = 'Erreur de connexion: ${e.toString()}';
      });
    }
  }

  Future<void> _tryAutoLogin() async {
    try {
      await context.read<AuthProvider>().tryAutoLogin();
      final authProvider = context.read<AuthProvider>();
      if (authProvider.isAuth && mounted) {
        _redirectToAppropriateScreen(authProvider);
      }
    } catch (e) {
      debugPrint('Auto login failed: $e');
    }
  }

  void _redirectToAppropriateScreen(AuthProvider authProvider) {
    final route = authProvider.getRedirectRoute();
    
    switch (route) {
      case '/chef':
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (_) => const ChefScreen())
        );
        break;
      case '/serveur':
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (_) => const ServeurScreen())
        );
        break;
      case '/client':
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (_) => const RestaurantScreen())
        );
        break;
      case '/admin':
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (_) => const AdminScreen())
        );
        break;
      default:
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (_) => const RestaurantScreen())
        );
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
      final result = await context.read<AuthProvider>().login(
        _emailController.text.trim(), 
        _passwordController.text
      );
      
      if (!mounted) return;
      
      if (result['success'] == true) {
        final authProvider = context.read<AuthProvider>();
        _redirectToAppropriateScreen(authProvider);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Identifiants invalides'),
            backgroundColor: Colors.red
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de connexion: ${e.toString()}'),
            backgroundColor: Colors.red
          )
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showQRScanner() async {
    final result = await QRScannerWrapper.scanQRCode(context);
    if (result != null) {
      // Remplir automatiquement les champs avec les données scannées
      if (result.containsKey('email')) {
        _emailController.text = result['email']!;
      }
      if (result.containsKey('password')) {
        _passwordController.text = result['password']!;
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Identifiants importés avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background avec effet 3D et parallaxe
          _buildParallaxBackground(),
          
          // Overlay sombre pour améliorer la lisibilité
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.black.withOpacity(0.5),
                  Colors.black.withOpacity(0.3),
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
                const SizedBox(height: 60),
                
                // Header avec effet 3D
                _buildAnimatedHeader(),
                
                const SizedBox(height: 40),

                // Bouton de scan QR code
                _buildQRScanButton(),

                const SizedBox(height: 20),

                // Carte de connexion avec effet 3D
                _buildLoginCard(),
              ],
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
          image: NetworkImage(
            'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=2070&q=80',
          ),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black,
            BlendMode.darken,
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedHeader() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _build3DText(
                'Content de vous',
                fontSize: 32,
                color: Colors.white,
              ),
              _build3DText(
                'revoir',
                fontSize: 36,
                color: Colors.amber,
                shadowColor: Colors.orange,
              ),
              const SizedBox(height: 8),
              Text(
                'Connectez-vous à votre compte',
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
    );
  }

  Widget _buildQRScanButton() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _showQRScanner,
              icon: const Icon(Icons.qr_code_scanner, size: 24),
              label: const Text(
                'Scanner le QR Code',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[800],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 8,
                shadowColor: Colors.blue.withOpacity(0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard() {
    return SlideTransition(
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
                  
                  // Error message if any
                  if (_serverError.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildErrorCard(),
                  ],
                  
                  const SizedBox(height: 24),

                  // Email field
                  _buildEmailField(),
                  const SizedBox(height: 20),

                  // Password field
                  _buildPasswordField(),
                  const SizedBox(height: 28),

                  // Login button
                  _buildLoginButton(),
                  const SizedBox(height: 24),

                  // Register section
                  _buildRegisterSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _build3DText(
    String text, {
    double fontSize = 24,
    Color color = Colors.white,
    Color shadowColor = Colors.black,
  }) {
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
              icon: const Icon(Icons.refresh, color: Colors.amber, size: 20),
              onPressed: _testServerConnection,
              tooltip: 'Réessayer la connexion',
            ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
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

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Email',
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
        prefixIcon: const Icon(Icons.email, color: Colors.amber),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Email requis';
        if (!value.contains('@')) return 'Email invalide';
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Mot de passe',
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
        prefixIcon: const Icon(Icons.lock, color: Colors.amber),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility : Icons.visibility_off,
            color: Colors.amber,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      validator: (value) => 
          (value == null || value.isEmpty) ? 'Mot de passe requis' : null,
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
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
            : Text(_serverConnected ? 'Se connecter' : 'Serveur indisponible'),
      ),
    );
  }

  Widget _buildRegisterSection() {
    return Column(
      children: [
        const Divider(color: Colors.grey),
        const SizedBox(height: 16),
        Text(
          'Nouveau ici ?',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _serverConnected ? () => Navigator.push(
              context, 
              MaterialPageRoute(builder: (_) => const RegisterScreen())
            ) : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.amber,
              side: BorderSide(
                color: _serverConnected ? Colors.amber : Colors.grey,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Créer un compte'),
          ),
        ),
      ],
    );
  }
}