import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';

class PaymentScreen extends StatefulWidget {
  final double totalAmount;
  const PaymentScreen({super.key, required this.totalAmount});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _cardHolderController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();
  final TextEditingController _tableNumberController = TextEditingController();

  bool _isProcessing = false;
  bool _isSuccess = false;
  bool _isD17Card = false;
  String? _errorMessage;
  int? _orderId;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // Liste des préfixes des cartes D17
  final List<String> _d17Prefixes = [
    '603747', // Carte D17 classique
    '589206', // Carte D17
    '6042',   // Carte électron D17
    '627414', // Autre carte D17
    '639388', // Carte D17
  ];

  @override
  void initState() {
    super.initState();
    _cardNumberController.addListener(_detectD17Card);
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _cardNumberController.removeListener(_detectD17Card);
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _tableNumberController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _detectD17Card() {
    final number = _cardNumberController.text.replaceAll(' ', '');
    bool detected = false;
    
    for (String prefix in _d17Prefixes) {
      if (number.startsWith(prefix)) {
        detected = true;
        break;
      }
    }
    
    if (mounted && detected != _isD17Card) {
      setState(() {
        _isD17Card = detected;
      });
    }
  }

  Future<int> _createOrder() async {
    try {
      final cartProvider = context.read<CartProvider>();
      final cartItems = cartProvider.items;
      final authProvider = context.read<AuthProvider>();

      final token = authProvider.token;
      if (token == null || token.isEmpty) {
        throw Exception('Session expirée. Veuillez vous reconnecter.');
      }

      final orderData = {
        'items': cartItems.map((i) => {
          'product_id': int.tryParse(i.id) ?? 0,
          'quantity': i.quantity,
        }).toList(),
        'table_number': int.tryParse(_tableNumberController.text.trim()) ?? 0,
      };

      debugPrint('📦 Création commande...');
      
      final response = await http.post(
        Uri.parse('${AuthProvider.baseUrl}/orderspayment'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode(orderData),
      ).timeout(const Duration(seconds: 30));

      debugPrint('📩 Status: ${response.statusCode}');
      debugPrint('📩 Body: ${response.body}');

      if (response.statusCode == 401) {
        throw Exception('Session expirée. Veuillez vous reconnecter.');
      }

      if (response.statusCode == 404) {
        throw Exception('Service de commande indisponible (404)');
      }

      if (response.statusCode >= 400) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Erreur serveur: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      
      if (!data['success']) {
        throw Exception(data['error'] ?? 'Erreur inconnue');
      }

      final orderId = data['data']['order_id'] ?? 0;
      if (orderId <= 0) {
        throw Exception('ID de commande invalide');
      }

      return orderId;
    } catch (e) {
      debugPrint('❌ Erreur création commande: $e');
      rethrow;
    }
  }

  Future<void> _initiateD17Payment(int orderId, String token) async {
    try {
      final paymentData = {
        'order_id': orderId,
        'amount': widget.totalAmount,
        'card_number': _cardNumberController.text.replaceAll(' ', ''),
        'card_holder': _cardHolderController.text,
        'expiry_date': _expiryController.text,
        'cvv': _cvvController.text,
      };

      debugPrint('💳 Initiation paiement D17...');
      
      final response = await http.post(
        Uri.parse('${AuthProvider.baseUrl}/payment/d17/initiate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode(paymentData),
      ).timeout(const Duration(seconds: 30));

      debugPrint('📩 Paiement D17 status: ${response.statusCode}');
      debugPrint('📩 Paiement D17 body: ${response.body}');

      if (response.statusCode == 401) {
        throw Exception('Session expirée. Veuillez vous reconnecter.');
      }

      if (response.statusCode >= 400) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Erreur de paiement: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      
      if (data['success'] == true) {
        // Paiement réussi directement
        setState(() {
          _isSuccess = true;
          _orderId = orderId;
        });
        
        // Vider le panier après paiement réussi
        context.read<CartProvider>().clear();
        
      } else {
        throw Exception(data['message'] ?? 'Échec du paiement D17');
      }
      
    } catch (e) {
      debugPrint('❌ Erreur paiement D17: $e');
      rethrow;
    }
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthProvider>();

    if (auth.token == null || auth.token!.isEmpty) {
      setState(() {
        _errorMessage = 'Session expirée. Veuillez vous reconnecter.';
        _isProcessing = false;
      });
      return;
    }

    try {
      // Étape 1: Créer la commande
      final orderId = await _createOrder();
      
      // Étape 2: Traiter le paiement selon le type de carte
      if (_isD17Card) {
        await _initiateD17Payment(orderId, auth.token!);
      } else {
        // Pour les cartes normales, simuler un paiement réussi
        await Future.delayed(const Duration(seconds: 1));
        setState(() {
          _isSuccess = true;
          _orderId = orderId;
        });
        
        // Vider le panier après paiement réussi
        context.read<CartProvider>().clear();
      }
      
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } finally {
      if (!_isSuccess && mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  String? _validateExpiryDate(String? value) {
    if (value == null || value.isEmpty) return 'Requis';
    if (value.length < 5) return 'Format MM/AA';
    
    final parts = value.split('/');
    if (parts.length != 2) return 'Format MM/AA';
    
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

  @override
  Widget build(BuildContext context) {
    if (_isSuccess) {
      return _buildSuccessScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: _isProcessing ? null : () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isD17Card ? Colors.green.withOpacity(0.2) : Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _isD17Card ? Icons.local_post_office : Icons.credit_card,
                color: _isD17Card ? Colors.green : Colors.amber,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _isD17Card ? 'Paiement D17' : 'Paiement sécurisé',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Carte de résumé du paiement
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _isD17Card 
                              ? [Colors.green.shade900, Colors.green.shade700]
                              : [Colors.amber.shade900, Colors.amber.shade700],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: (_isD17Card ? Colors.green : Colors.amber).withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Montant total',
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${widget.totalAmount.toStringAsFixed(2)} DT',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.lock_outline, color: Colors.white, size: 14),
                                const SizedBox(width: 4),
                                const Text(
                                  'Paiement sécurisé',
                                  style: TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),

                  // Message d'erreur si présent
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Bannière D17
                  if (_isD17Card)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.local_post_office, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Carte D17 détectée',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Paiement sécurisé via La Poste Tunisienne',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Formulaire de paiement
                  _buildTextField(
                    controller: _cardNumberController,
                    label: 'Numéro de carte',
                    icon: Icons.credit_card,
                    hint: '1234 5678 9012 3456',
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(16),
                      _CardNumberInputFormatter(),
                    ],
                    validator: (v) {
                      final cleaned = v?.replaceAll(' ', '') ?? '';
                      if (cleaned.isEmpty) return 'Numéro de carte requis';
                      if (cleaned.length != 16) return '16 chiffres requis';
                      return null;
                    },
                    suffixIcon: _isD17Card
                        ? Container(
                            margin: const EdgeInsets.all(12),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'D17',
                              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                            ),
                          )
                        : null,
                  ),

                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _tableNumberController,
                    label: 'Numéro de table',
                    icon: Icons.table_restaurant,
                    hint: 'Ex: 12',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Numéro de table requis';
                      if (int.tryParse(v) == null) return 'Numéro invalide';
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  _buildTextField(
                    controller: _cardHolderController,
                    label: 'Titulaire de la carte',
                    icon: Icons.person_outline,
                    hint: 'BALKIS TRABELSI',
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) => v?.isEmpty ?? true ? 'Nom du titulaire requis' : null,
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _expiryController,
                          label: 'Expiration',
                          icon: Icons.calendar_today_outlined,
                          hint: 'MM/AA',
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                            _CardExpiryInputFormatter(),
                          ],
                          validator: _validateExpiryDate,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          controller: _cvvController,
                          label: 'CVV',
                          icon: Icons.lock_outline,
                          hint: '123',
                          obscureText: true,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3)
                          ],
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'CVV requis';
                            if (v.length != 3) return '3 chiffres requis';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Bouton de paiement
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _processPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isD17Card ? Colors.green : Colors.amber,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isProcessing
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _isD17Card ? 'Traitement D17...' : 'Traitement...',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              _isD17Card 
                                ? '💰 Payer avec D17'
                                : '💰 Payer ${widget.totalAmount.toStringAsFixed(2)} DT',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Bouton Annuler
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _isProcessing ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _isD17Card ? Colors.green : Colors.amber, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Annuler',
                        style: TextStyle(
                          color: _isD17Card ? Colors.green : Colors.amber,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Message de sécurité
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_outline,
                            color: _isD17Card ? Colors.green : Colors.amber,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Paiement sécurisé SSL 256 bits',
                            style: TextStyle(color: Colors.white38, fontSize: 11),
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
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    bool obscureText = false,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            inputFormatters: inputFormatters,
            validator: validator,
            enabled: !_isProcessing,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white30),
              prefixIcon: Icon(icon, color: _isD17Card ? Colors.green : Colors.amber, size: 20),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    gradient: const RadialGradient(
                      colors: [Color(0xFF00C853), Color(0xFF00E676)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.5),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 80,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Paiement réussi !',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Commande #${_orderId ?? ''} confirmée',
                style: const TextStyle(color: Colors.white70, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Un email de confirmation vous a été envoyé',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Montant', style: TextStyle(color: Colors.white70)),
                        Text(
                          '${widget.totalAmount.toStringAsFixed(2)} DT',
                          style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Statut', style: TextStyle(color: Colors.white70)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Payé',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Table', style: TextStyle(color: Colors.white70)),
                        Text(
                          _tableNumberController.text,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '🏠 Retour à l\'accueil',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(' ', '');
    if (text.isEmpty) return newValue;
    
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(text[i]);
    }
    
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

class _CardExpiryInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll('/', '');
    if (text.isEmpty) return newValue;
    
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(text[i]);
    }
    
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}