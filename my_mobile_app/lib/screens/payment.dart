import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';

class PaymentScreen extends StatefulWidget {
  final double totalAmount;
  const PaymentScreen({super.key, required this.totalAmount});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _cardHolderController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();
  final TextEditingController _tableNumberController = TextEditingController();

  bool _isProcessing = false;
  bool isD17Card = false;
  String? paymentUrl;
  bool showExternalPayment = false;

  // Liste des préfixes des cartes D17 (à ajuster selon les vrais préfixes)
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
    // Ajouter un listener pour détecter automatiquement quand on colle un numéro
    _cardNumberController.addListener(_detectD17Card);
  }

  @override
  void dispose() {
    _cardNumberController.removeListener(_detectD17Card);
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _tableNumberController.dispose();
    super.dispose();
  }

  Future<int> _createOrder() async {
    try {
      final cartProvider = context.read<CartProvider>();
      final cartItems = cartProvider.items;
      final authProvider = context.read<AuthProvider>();

      final token = authProvider.token;
      if (token == null || token.isEmpty) throw Exception('Token manquant');

      final orderData = {
        'items': cartItems.map((i) => {
              'product_id': int.tryParse(i.id) ?? 0,
              'quantity': i.quantity,
            }).toList(),
        // table number is required and sent as integer
        'table_number': int.tryParse(_tableNumberController.text.trim()) ?? 0,
      };

      debugPrint('📦 Création commande...');
      final res = await http.post(
        Uri.parse('${AuthProvider.baseUrl}/orderspayment'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode(orderData),
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('Erreur: ${res.statusCode}');
      }

      final data = json.decode(res.body);
      final orderId = data['order_id'] ?? 0;
      if (orderId <= 0) throw Exception('ID invalide');

      return orderId;
    } catch (e) {
      debugPrint('❌ Erreur création: $e');
      rethrow;
    }
  }

  Future<void> _updateOrderStatus(int orderId, String status, String token) async {
    try {
      final res = await http.patch(
        Uri.parse('${AuthProvider.baseUrl}/orders/$orderId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({'status': status}),
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode >= 400) throw Exception('Erreur: ${res.statusCode}');
    } catch (e) {
      debugPrint('❌ Erreur status: $e');
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

      final response = await http.post(
        Uri.parse('${AuthProvider.baseUrl}/payment/d17/initiate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode(paymentData),
      ).timeout(const Duration(seconds: 30));

      debugPrint('D17 payment response: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['payment_url'] != null) {
          final url = Uri.parse(data['payment_url']);
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
            await Future.delayed(const Duration(seconds: 5));
            await _checkPaymentStatus(orderId, token);
          } else {
            throw Exception('Impossible d\'ouvrir l\'URL de paiement');
          }
        } else if (data['success'] == true) {
          await _updateOrderStatus(orderId, 'paid', token);
          await _finalizePayment(orderId, token);
        } else {
          throw Exception(data['message'] ?? 'Échec du paiement D17');
        }
      } else {
        throw Exception('Erreur de paiement: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error initiating D17 payment: $e');
      rethrow;
    }
  }

  Future<void> _checkPaymentStatus(int orderId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('${AuthProvider.baseUrl}/orders/$orderId'),
        headers: {
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'paid') {
          await _updateOrderStatus(orderId, 'paid', token);
          await _finalizePayment(orderId, token);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('En attente de confirmation du paiement...'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking payment status: $e');
    }
  }

  Future<void> _finalizePayment(int orderId, String token) async {
    try {
      context.read<CartProvider>().clear();

      if (!mounted) return;
      
      Navigator.pop(context);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderConfirmationScreen(orderId: orderId, isD17Card: isD17Card),
        ),
      );
    } catch (e) {
      debugPrint('Error finalizing payment: $e');
      rethrow;
    }
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);
    final auth = context.read<AuthProvider>();

    if (auth.token == null || auth.token!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Session expirée'), backgroundColor: Colors.red),
      );
      setState(() => _isProcessing = false);
      return;
    }

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
              border: Border.all(color: isD17Card ? Colors.green : Colors.amber, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isD17Card) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Image.network(
                      'https://upload.wikimedia.org/wikipedia/commons/thumb/1/13/Logo-poste-tunisienne.jpg/800px-Logo-poste-tunisienne.jpg',
                      height: 60,
                      errorBuilder: (_, __, ___) => const Icon(Icons.local_post_office, color: Colors.green, size: 50),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.amber)),
                const SizedBox(height: 16),
                Text(
                  isD17Card ? '⏳ Redirection vers le paiement sécurisé D17...' : '⏳ Traitement du paiement...',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final orderId = await _createOrder();
      
      if (isD17Card) {
        await _initiateD17Payment(orderId, auth.token!);
      } else {
        await _updateOrderStatus(orderId, 'paid', auth.token!);
        await _finalizePayment(orderId, auth.token!);
      }
      
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ ${e.toString()}'), backgroundColor: Colors.red),
        );
        setState(() => _isProcessing = false);
      }
    }
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
    
    // Pour la démonstration, on peut aussi détecter avec un numéro factice
    // À enlever en production
    if (number == '1234567899999999') {
      detected = true;
    }
    
    if (mounted && detected != isD17Card) {
      setState(() {
        isD17Card = detected;
      });
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
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Row(
          children: [
            if (isD17Card) 
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.local_post_office, color: Colors.white, size: 20),
              ),
            const SizedBox(width: 8),
            Text(
              isD17Card ? 'Paiement D17' : 'Paiement Sécurisé',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Carte de montant avec logo D17 si détecté
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isD17Card 
                        ? [Colors.green.shade900, Colors.green.shade700]
                        : [Colors.amber.shade900, Colors.amber.shade700],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (isD17Card ? Colors.green : Colors.amber).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
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
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (isD17Card)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Image.network(
                          'https://upload.wikimedia.org/wikipedia/commons/thumb/1/13/Logo-poste-tunisienne.jpg/800px-Logo-poste-tunisienne.jpg',
                          height: 40,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.local_post_office, 
                            color: Colors.green, 
                            size: 40,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),

              // Bannière D17 si détecté
              if (isD17Card)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green, width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.local_post_office, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Carte D17 détectée',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Paiement sécurisé via La Poste Tunisienne',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              const Text('Numéro de carte',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _cardNumberController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '1234 5678 9012 3456',
                  hintStyle: const TextStyle(color: Colors.white30),
                  prefixIcon: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isD17Card ? Colors.green.withOpacity(0.2) : Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isD17Card ? Icons.local_post_office : Icons.credit_card,
                      color: isD17Card ? Colors.green : Colors.amber,
                      size: 20,
                    ),
                  ),
                  suffixIcon: isD17Card
                      ? Container(
                          margin: const EdgeInsets.all(8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'D17',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isD17Card ? Colors.green.withOpacity(0.3) : Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isD17Card ? Colors.green : Colors.amber, width: 2),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 16),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(16),
                  _CardNumberInputFormatter(),
                ],
                validator: (v) {
                  final cleaned = v?.replaceAll(' ', '') ?? '';
                  if (cleaned.length != 16) return '16 chiffres requis';
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Table number input
              const Text('Numéro de table',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _tableNumberController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Ex: 12',
                  hintStyle: const TextStyle(color: Colors.white30),
                  prefixIcon: Icon(Icons.table_restaurant, color: isD17Card ? Colors.green : Colors.amber),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isD17Card ? Colors.green.withOpacity(0.3) : Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isD17Card ? Colors.green : Colors.amber, width: 2),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                ),
                style: const TextStyle(color: Colors.white),
                validator: (v) {
                  // Table number is REQUIRED
                  if (v == null || v.isEmpty) return 'Numéro de table requis';
                  if (int.tryParse(v) == null) return 'Numéro invalide';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              const Text('Titulaire de la carte',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _cardHolderController,
                decoration: InputDecoration(
                  hintText: 'BALKIS TRABELSI',
                  hintStyle: const TextStyle(color: Colors.white30),
                  prefixIcon: Icon(
                    Icons.person_outline,
                    color: isD17Card ? Colors.green : Colors.amber,
                    size: 20,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isD17Card ? Colors.green.withOpacity(0.3) : Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isD17Card ? Colors.green : Colors.amber, width: 2),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                ),
                style: const TextStyle(color: Colors.white ),
                textCapitalization: TextCapitalization.characters,
                validator: (v) => v?.isEmpty ?? true ? 'Requis' : null,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Date d\'expiration',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _expiryController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'MM/AA',
                            hintStyle: const TextStyle(color: Colors.white30),
                            prefixIcon: Icon(
                              Icons.calendar_today_outlined,
                              color: isD17Card ? Colors.green : Colors.amber,
                              size: 18,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: isD17Card ? Colors.green.withOpacity(0.3) : Colors.white12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: isD17Card ? Colors.green : Colors.amber, width: 2),
                            ),
                            filled: true,
                            fillColor: const Color(0xFF1A1A1A),
                          ),
                          style: const TextStyle(color: Colors.white),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                            _CardExpiryInputFormatter(),
                          ],
                          validator: _validateExpiryDate,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('CVV',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _cvvController,
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '123',
                            hintStyle: const TextStyle(color: Colors.white30),
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: isD17Card ? Colors.green : Colors.amber,
                              size: 18,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: isD17Card ? Colors.green.withOpacity(0.3) : Colors.white12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: isD17Card ? Colors.green : Colors.amber, width: 2),
                            ),
                            filled: true,
                            fillColor: const Color(0xFF1A1A1A),
                          ),
                          style: const TextStyle(color: Colors.white),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3)
                          ],
                          validator: (v) => v?.length != 3 ? 'CVV invalide' : null,
                        ),
                      ],
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
                    backgroundColor: isD17Card ? Colors.green : Colors.amber,
                    foregroundColor: Colors.black,
                    elevation: 4,
                    shadowColor: (isD17Card ? Colors.green : Colors.amber).withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isProcessing
                        ? 'Traitement en cours...'
                        : isD17Card 
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
                    side: BorderSide(color: isD17Card ? Colors.green : Colors.amber, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Annuler',
                    style: TextStyle(
                      color: isD17Card ? Colors.green : Colors.amber,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Message de sécurité
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      color: isD17Card ? Colors.green : Colors.amber,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Paiement sécurisé SSL 256 bits',
                      style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
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

class OrderConfirmationScreen extends StatelessWidget {
  final int orderId;
  final bool isD17Card;

  const OrderConfirmationScreen({
    super.key, 
    required this.orderId,
    this.isD17Card = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isD17Card) ...[
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green.withOpacity(0.2),
                  ),
                  child: Image.network(
                    'https://upload.wikimedia.org/wikipedia/commons/thumb/1/13/Logo-poste-tunisienne.jpg/800px-Logo-poste-tunisienne.jpg',
                    height: 60,
                    errorBuilder: (_, __, ___) => const Icon(Icons.local_post_office, color: Colors.green, size: 60),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle, 
                  color: Colors.green.withOpacity(0.2),
                ),
                child: const Icon(Icons.check_circle, size: 80, color: Colors.green),
              ),
              const SizedBox(height: 24),
              const Text(
                '✅ Commande Confirmée!',
                style: TextStyle(
                  color: Colors.white, 
                  fontSize: 24, 
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Commande #$orderId',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7), 
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isD17Card 
                    ? 'Paiement D17 effectué avec succès'
                    : 'Un email de confirmation vous a été envoyé',
                style: const TextStyle(color: Colors.white38, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '🏠 Retour à l\'accueil',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
