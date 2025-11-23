import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';

class PaymentScreen extends StatefulWidget {
  final double totalAmount;
  const PaymentScreen({super.key, required this.totalAmount});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _cardHolderController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();
  bool _isProcessing = false;
  String? localToken;
  String selectedCardType = '';

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadToken();
    
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
              BoxShadow(
                blurRadius: 10,
                color: shadowColor,
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
              BoxShadow(
                blurRadius: 20,
                color: color,
                offset: const Offset(0, 0),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _loadToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      localToken = prefs.getString('token');
      setState((){});
    } catch (e) {
      debugPrint('Error loading token: $e');
    }
  }

  Future<String?> _getEffectiveToken(AuthProvider authProvider) async {
    if (authProvider.token != null && authProvider.token!.isNotEmpty) {
      return authProvider.token;
    }
    
    if (localToken != null && localToken!.isNotEmpty) {
      return localToken;
    }
    
    await _loadToken();
    return localToken;
  }

Future<int> _createOrder() async {
  try {
    final cartProvider = context.read<CartProvider>();
    final cartItems = cartProvider.items;
    final authProvider = context.read<AuthProvider>();
    
    final effectiveToken = await _getEffectiveToken(authProvider);
    
    if (effectiveToken == null || effectiveToken.isEmpty) {
      throw Exception('Token non disponible');
    }
    
    final headers = {
      'Content-Type': 'application/json; charset=UTF-8', 
      'Accept': 'application/json', 
      'Authorization': 'Bearer $effectiveToken' // Make sure this is included
    };
    
    // DON'T send user_id - let Symfony get it from the token
    final orderData = {
      'items': cartItems.map((i) => {
        'product_id': int.tryParse(i.id) ?? 0,
        'quantity': i.quantity,
      }).toList(),
    };
    
    debugPrint('Creating order with data: ${json.encode(orderData)}');
    
    // Make sure you're calling the correct endpoint
    final res = await http.post(
      Uri.parse('https://1cc7227c8427.ngrok-free.app/api/orderspayment'), 
      headers: headers, 
      body: json.encode(orderData)
    );
    debugPrint('Order creation response: ${res.statusCode} ${res.body}');
    
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Échec de création de commande: ${res.statusCode} ${res.body}');
    }
    
    final responseData = json.decode(res.body);
    
    final dynamic orderIdValue = responseData['order_id'];
    final int orderId;
    
    if (orderIdValue is int) {
      orderId = orderIdValue;
    } else if (orderIdValue is String) {
      orderId = int.tryParse(orderIdValue) ?? 0;
    } else {
      debugPrint('Invalid order_id type: ${orderIdValue.runtimeType}');
      debugPrint('Full response: ${res.body}');
      throw Exception('Format de réponse invalide: id manquant ou incorrect');
    }
    
    if (orderId <= 0) {
      throw Exception('ID de commande invalide');
    }
    
    cartProvider.clear();
    return orderId;
    
  } catch (e) {
    debugPrint('Error creating order: $e');
    rethrow;
  }
}

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isProcessing = true);
    final auth = context.read<AuthProvider>();
    
    final effectiveToken = await _getEffectiveToken(auth);

    if (effectiveToken == null || effectiveToken.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session expirée. Reconnectez-vous.'), 
            backgroundColor: Colors.red
          )
        );
        setState(() => _isProcessing = false);
      }
      return;
    }

    if (mounted) {
      showDialog(
        context: context, 
        barrierDismissible: false, 
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent, 
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.amber)),
                  SizedBox(height: 16),
                  Text('Traitement du paiement...', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    try {
      final orderId = await _createOrder();
      
      if (orderId <= 0) {
        throw Exception('ID de commande invalide');
      }
      
      await _updateOrderStatus(orderId, 'paid', effectiveToken);
      
      if (mounted) {
        Navigator.of(context).pop();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OrderConfirmationScreen(orderId: orderId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'), 
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          )
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _updateOrderStatus(int orderId, String status, String token) async {
    try {
      if (orderId <= 0) {
        throw Exception('ID de commande invalide pour la mise à jour du statut');
      }
      
      final headers = {
        'Content-Type': 'application/json; charset=UTF-8', 
        'Accept': 'application/json', 
        'Authorization': 'Bearer $token'
      };
      
      final statusData = {
        'status': status
      };
      
      final res = await http.patch(
        Uri.parse('https://1cc7227c8427.ngrok-free.app/api/orders/$orderId/status'), 
        headers: headers, 
        body: json.encode(statusData)
      );
      
      debugPrint('Order status update response: ${res.statusCode} ${res.body}');
      
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('Échec de mise à jour du statut: ${res.statusCode} ${res.body}');
      }
      
      debugPrint('Order status updated to $status');
      
    } catch (e) {
      debugPrint('Error updating order status: $e');
      rethrow;
    }
  }

  void _detectCardType(String number) {
    final cleaned = number.replaceAll(' ', '');
    if (cleaned.startsWith('4')) {
      setState(() => selectedCardType = 'Visa');
    } else if (cleaned.startsWith('5')) {
      setState(() => selectedCardType = 'MasterCard');
    } else if (cleaned.startsWith('34') || cleaned.startsWith('37')) {
      setState(() => selectedCardType = 'American Express');
    } else if (cleaned.startsWith('6')) {
      setState(() => selectedCardType = 'Discover');
    } else {
      setState(() => selectedCardType = '');
    }
  }

  String? _validateExpiryDate(String? value) {
    if (value == null || value.isEmpty) return 'Veuillez entrer la date';
    if (value.length < 5) return 'Format: MM/AA';
    final parts = value.split('/');
    if (parts.length != 2) return 'Format: MM/AA';
    final month = int.tryParse(parts[0]) ?? 0;
    final year = int.tryParse(parts[1]) ?? 0;
    if (month < 1 || month > 12) return 'Mois invalide';
    final now = DateTime.now();
    final currentYear = now.year % 100;
    final currentMonth = now.month;
    if (year < currentYear || (year == currentYear && month < currentMonth)) {
      return 'Carte expirée';
    }
    return null;
  }

  Widget _buildCardIcon(String type) {
    switch (type) {
      case 'Visa':
        return const Icon(Icons.credit_card, color: Colors.blue, size: 24);
      case 'MasterCard':
        return const Icon(Icons.credit_card, color: Colors.orange, size: 24);
      case 'American Express':
        return const Icon(Icons.credit_card, color: Colors.green, size: 24);
      case 'Discover':
        return const Icon(Icons.credit_card, color: Colors.purple, size: 24);
      default:
        return const Icon(Icons.credit_card, color: Colors.grey, size: 24);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.amber,
        title: const Text('Paiement Sécurisé'),
      ),
      body: Stack(
        children: [
          // Background avec effet de profondeur
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(
                  'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?ixlib=rb-4.0.3&auto=format&fit=crop&w=2070&q=80',
                ),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black,
                  BlendMode.darken,
                ),
              ),
            ),
          ),
          
          // Overlay de dégradé
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black,
                  Colors.black,
                  Colors.black,
                ],
              ),
            ),
          ),
          
          // Contenu principal
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: [
                      // Montant total avec effet 3D
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.amber),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.amber,
                              blurRadius: 20,
                              spreadRadius: 2,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Montant Total', 
                              style: TextStyle(fontSize: 18, color: Colors.white70)
                            ),
                            const SizedBox(height: 10),
                            _build3DText(
                              '${widget.totalAmount.toStringAsFixed(2)} DT',
                              fontSize: 32,
                              color: Colors.amber,
                              shadowColor: Colors.orange,
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Titre avec effet 3D
                      _build3DText(
                        'Informations de Carte Bancaire', 
                        fontSize: 20,
                        color: Colors.white,
                        shadowColor: Colors.black,
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Formulaire de paiement
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.amber),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.amber,
                              blurRadius: 15,
                              spreadRadius: 2,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              // Numéro de carte avec détection de type
                              TextFormField(
                                controller: _cardNumberController,
                                decoration: InputDecoration(
                                  labelText: 'Numéro de Carte',
                                  labelStyle: const TextStyle(color: Colors.white70),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Colors.amber),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Colors.amber),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Colors.amber),
                                  ),
                                  filled: true,
                                  fillColor: Colors.black,
                                  prefixIcon: const Icon(Icons.credit_card, color: Colors.amber),
                                  suffixIcon: selectedCardType.isNotEmpty 
                                    ? _buildCardIcon(selectedCardType)
                                    : null,
                                ),
                                style: const TextStyle(color: Colors.white),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly, 
                                  LengthLimitingTextInputFormatter(19), 
                                  _CardNumberInputFormatter()
                                ],
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Veuillez entrer un numéro de carte';
                                  final cleanedValue = value.replaceAll(' ', '');
                                  if (cleanedValue.length < 16) return 'Le numéro de carte doit avoir 16 chiffres';
                                  return null;
                                },
                                onChanged: _detectCardType,
                              ),
                              
                              const SizedBox(height: 20),
                              
                              // Titulaire de la carte
                              TextFormField(
                                controller: _cardHolderController,
                                decoration: InputDecoration(
                                  labelText: 'Titulaire de la Carte',
                                  labelStyle: const TextStyle(color: Colors.white70),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Colors.amber),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Colors.amber),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Colors.amber),
                                  ),
                                  filled: true,
                                  fillColor: Colors.black,
                                  prefixIcon: const Icon(Icons.person, color: Colors.amber),
                                ),
                                style: const TextStyle(color: Colors.white),
                                validator: (v) => (v == null || v.isEmpty) ? 'Veuillez entrer le nom du titulaire' : null,
                              ),
                              
                              const SizedBox(height: 20),
                              
                              // Date d'expiration et CVV
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _expiryController,
                                      decoration: InputDecoration(
                                        labelText: 'Date d\'Expiration (MM/AA)',
                                        labelStyle: const TextStyle(color: Colors.white70),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Colors.amber),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Colors.amber),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Colors.amber),
                                        ),
                                        filled: true,
                                        fillColor: Colors.black,
                                        prefixIcon: const Icon(Icons.calendar_today, color: Colors.amber),
                                      ),
                                      style: const TextStyle(color: Colors.white),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly, 
                                        LengthLimitingTextInputFormatter(4), 
                                        _CardExpiryInputFormatter()
                                      ],
                                      validator: _validateExpiryDate,
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _cvvController,
                                      decoration: InputDecoration(
                                        labelText: 'CVV',
                                        labelStyle: const TextStyle(color: Colors.white70),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Colors.amber),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Colors.amber),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: const BorderSide(color: Colors.amber),
                                        ),
                                        filled: true,
                                        fillColor: Colors.black,
                                        prefixIcon: const Icon(Icons.lock, color: Colors.amber),
                                      ),
                                      style: const TextStyle(color: Colors.white),
                                      keyboardType: TextInputType.number,
                                      obscureText: true,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly, 
                                        LengthLimitingTextInputFormatter(3)
                                      ],
                                      validator: (v) => (v == null || v.length < 3) ? 'Le CVV doit avoir 3 chiffres' : null,
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 30),
                              
                              // Bouton de paiement
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: _isProcessing 
                                  ? const Center(
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation(Colors.amber),
                                      ),
                                    )
                                  : ElevatedButton(
                                      onPressed: _processPayment,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.amber,
                                        foregroundColor: Colors.black,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 8,
                                        shadowColor: Colors.amber,
                                        textStyle: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      child: const Text('Payer Maintenant'),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final newText = newValue.text;
    if (newText.isEmpty) return newValue;
    final buffer = StringBuffer();
    for (int i = 0; i < newText.length; i++) {
      buffer.write(newText[i]);
      if ((i + 1) % 4 == 0 && i != newText.length - 1) buffer.write(' ');
    }
    return TextEditingValue(
      text: buffer.toString(), 
      selection: TextSelection.collapsed(offset: buffer.length)
    );
  }
}

class _CardExpiryInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final newText = newValue.text;
    if (newText.isEmpty) return newValue;
    final buffer = StringBuffer();
    for (int i = 0; i < newText.length; i++) {
      buffer.write(newText[i]);
      if (i == 1 && newText.length > 2) buffer.write('/');
    }
    return TextEditingValue(
      text: buffer.toString(), 
      selection: TextSelection.collapsed(offset: buffer.length)
    );
  }
}

class OrderConfirmationScreen extends StatelessWidget {
  final int orderId;

  const OrderConfirmationScreen({super.key, required this.orderId});

  Widget _build3DText(String text, {double fontSize = 24, Color color = Colors.white, Color shadowColor = Colors.black}) {
    return Stack(
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color= shadowColor,
              shadows: [
              BoxShadow(
                blurRadius: 10,
                color: shadowColor,
                offset: const Offset(2, 2),
              ),
            ],
          ),
        ),
        
        Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: color,
            shadows: [
              BoxShadow(
                blurRadius: 20,
                color: color,
                offset: const Offset(0, 0),
              ),
            ],
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
        foregroundColor: Colors.green,
        title: const Text('Confirmation'),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(
                  'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?ixlib=rb-4.0.3&auto=format&fit=crop&w=2070&q=80',
                ),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black,
                  BlendMode.darken,
                ),
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black,
                  Colors.black,
                  Colors.black,
                ],
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.green),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.green,
                      blurRadius: 20,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 100,
                    ),
                    const SizedBox(height: 24),
                    _build3DText(
                      'Commande Confirmée!',
                      fontSize: 28,
                      color: Colors.green,
                      shadowColor: Colors.greenAccent,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Votre commande #$orderId a été traitée avec succès.',
                      style: const TextStyle(fontSize: 18, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Merci pour votre achat!',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.popUntil(context, (route) => route.isFirst);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Retour à l\'accueil',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}