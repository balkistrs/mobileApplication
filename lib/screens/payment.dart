import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:ui';
import 'package:geolocator/geolocator.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import 'receipt_screen.dart';

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
  final TextEditingController _deliveryAddressController = TextEditingController();

  bool _isProcessing = false;
  bool _isSuccess = false;
  bool _isD17Card = false;
  String? _errorMessage;
  int? _orderId;
  String _userName = '';
  List<Map<String, dynamic>> _cartItems = [];

  String _orderType = 'dine_in';
  List<Map<String, dynamic>> _availableTables = [];
  int? _selectedTableId;
  bool _isLoadingTables = true;
  bool _isLoadingAddress = false;

  // Delivery fee constant
  static const double DELIVERY_FEE = 5.0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late AnimationController _glowAnimation;
  late Animation<double> _glowValue;

  final Color _primaryColor = const Color(0xFF003366);
  final Color _secondaryColor = const Color(0xFFD4AF37);
  final Color _surfaceColor = Colors.white;
  final Color _surfaceContainerLow = const Color(0xFFFAFAFA);
  final Color _onSurfaceVariant = const Color(0xFF6B6B6B);
  final Color _errorColor = const Color(0xFFD32F2F);
  final Color _successColor = const Color(0xFF2E7D32);

  final List<String> _d17Prefixes = [
    '603747', '589206', '6042', '627414', '639388',
    '5892', '6037', '6042', '6274', '6393',
  ];

  // Getter for subtotal (without delivery fee)
  double get _subtotal {
    if (_orderType == 'delivery') {
      return widget.totalAmount - DELIVERY_FEE;
    }
    return widget.totalAmount;
  }

  // Getter for final total (subtotal + delivery fee if applicable)
  double get _finalTotal {
    if (_orderType == 'delivery') {
      return _subtotal + DELIVERY_FEE;
    }
    return _subtotal;
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadCartItems();
    _cardNumberController.addListener(_detectD17Card);
    _fetchAvailableTables();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeIn);
    _scaleAnimation = CurvedAnimation(parent: _animationController, curve: Curves.elasticOut);
    _animationController.forward();

    _glowAnimation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _glowValue = Tween<double>(begin: 0.2, end: 0.5).animate(
      CurvedAnimation(parent: _glowAnimation, curve: Curves.easeInOut),
    );
  }

  void _loadCartItems() {
    final cart = context.read<CartProvider>();
    _cartItems = cart.items.map((item) => {
      'name': item.name,
      'quantity': item.quantity,
      'price': item.price,
    }).toList();
  }

  void _loadUserData() {
    final auth = context.read<AuthProvider>();
    final email = auth.user?.email ?? '';
    _userName = email.split('@')[0].toUpperCase();
    if (_userName.isEmpty) _userName = 'GUEST';
    _cardHolderController.text = _userName;
  }

  Future<void> _fetchAvailableTables() async {
    setState(() => _isLoadingTables = true);
    
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    
    if (token == null || token.isEmpty) {
      setState(() => _isLoadingTables = false);
      return;
    }

    try {
      final url = '${AuthProvider.baseUrl}/api/tables';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Map<String, dynamic>> tables = [];
        
        if (data['success'] == true && data['data'] is List) {
          tables = List<Map<String, dynamic>>.from(data['data']);
        } else if (data is List) {
          tables = List<Map<String, dynamic>>.from(data);
        } else if (data['tables'] is List) {
          tables = List<Map<String, dynamic>>.from(data['tables']);
        }
        
        tables = tables.where((t) {
          var isAvailable = t['is_available'];
          return isAvailable == 1 || isAvailable == true || isAvailable == '1';
        }).toList();
        
        setState(() {
          _availableTables = tables;
          _isLoadingTables = false;
        });
      } else {
        setState(() => _isLoadingTables = false);
      }
    } catch (e) {
      setState(() => _isLoadingTables = false);
    }
  }

  Future<String> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1'
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'RestoApp/1.0'
      }).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['display_name'] != null) {
          String address = data['display_name'];
          if (address.length > 80) {
            address = address.substring(0, 77) + '...';
          }
          return address;
        }
      }
    } catch (e) {
      debugPrint('Nominatim error: $e');
    }
    return '📍 ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  Future<void> _getCurrentLocationAddress() async {
    setState(() => _isLoadingAddress = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable location services')),
        );
        setState(() => _isLoadingAddress = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied')),
          );
          setState(() => _isLoadingAddress = false);
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() {
        _deliveryAddressController.text = '📍 ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      });
      
      String address = await _getAddressFromCoordinates(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          _deliveryAddressController.text = address;
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
      setState(() => _isLoadingAddress = false);
    }
  }

  Widget _buildOrderTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ORDER TYPE',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: _primaryColor),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _orderType,
              isExpanded: true,
              style: TextStyle(color: Colors.grey.shade800, fontSize: 14),
              dropdownColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              items: const [
                DropdownMenuItem(value: 'dine_in', child: Text('🍽️ Dine In')),
                DropdownMenuItem(value: 'delivery', child: Text('🚚 Delivery (+5 DT)')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _orderType = value;
                    if (_orderType == 'delivery') _selectedTableId = null;
                  });
                }
              },
            ),
          ),
        ),
        if (_orderType == 'delivery')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _secondaryColor.withAlpha(51),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, size: 14, color: _secondaryColor),
                  const SizedBox(width: 4),
                  Text(
                    'Delivery fee: 5 DT',
                    style: TextStyle(fontSize: 11, color: _secondaryColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTableDropdown() {
    if (_orderType != 'dine_in') return const SizedBox.shrink();

    if (_isLoadingTables) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TABLE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: _primaryColor)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: _surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
            child: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ],
      );
    }

    if (_availableTables.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TABLE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: _primaryColor)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(color: _surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text('No tables available', style: TextStyle(color: _onSurfaceVariant)),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SELECT A TABLE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: _primaryColor)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedTableId,
              isExpanded: true,
              style: TextStyle(color: Colors.grey.shade800, fontSize: 14),
              dropdownColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              hint: Text('Select a table', style: TextStyle(color: _onSurfaceVariant)),
              items: _availableTables.map((table) {
                final id = table['id'];
                final name = table['name'] ?? 'Table $id';
                final capacity = table['capacity'] ?? '?';
                return DropdownMenuItem<int>(value: id, child: Text('$name (capacity $capacity)'));
              }).toList(),
              onChanged: (value) => setState(() => _selectedTableId = value),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryAddress() {
    if (_orderType != 'delivery') return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DELIVERY ADDRESS',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: _primaryColor),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _deliveryAddressController,
                label: '',
                icon: Icons.location_on,
                hint: 'Enter your address...',
                validator: (v) => _orderType == 'delivery' && (v == null || v.isEmpty) ? 'Address required' : null,
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _getCurrentLocationAddress,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _isLoadingAddress
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(Icons.my_location, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _cardNumberController.removeListener(_detectD17Card);
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _deliveryAddressController.dispose();
    _animationController.dispose();
    _glowAnimation.dispose();
    super.dispose();
  }

  void _detectD17Card() {
    final number = _cardNumberController.text.replaceAll(' ', '');
    bool detected = _d17Prefixes.any((prefix) => number.startsWith(prefix));
    if (mounted && detected != _isD17Card) setState(() => _isD17Card = detected);
  }

  Future<int> _createOrder() async {
    try {
      final cartProvider = context.read<CartProvider>();
      final cartItems = cartProvider.items;
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.token;
      if (token == null || token.isEmpty) throw Exception('Session expired');

      final orderData = {
        'items': cartItems.map((i) => {
          'product_id': int.tryParse(i.id) ?? 0,
          'quantity': i.quantity,
        }).toList(),
        'order_type': _orderType,
        'payment_method': _isD17Card ? 'D17' : 'Credit Card',
      };

      if (_orderType == 'dine_in' && _selectedTableId != null) {
        orderData['table_id'] = _selectedTableId!;
      }
      if (_orderType == 'delivery') {
        orderData['delivery_address'] = _deliveryAddressController.text.trim();
      }

      final response = await http.post(
        Uri.parse('${AuthProvider.baseUrl}/api/orderspayment'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode(orderData),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 401) throw Exception('Session expired');
      if (response.statusCode == 404) throw Exception('Order service unavailable');
      if (response.statusCode >= 400) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Server error ${response.statusCode}');
      }

      final data = json.decode(response.body);
      if (!data['success']) throw Exception(data['error'] ?? 'Unknown error');

      final orderId = data['data']['order_id'] ?? 0;
      if (orderId <= 0) throw Exception('Invalid order ID');
      return orderId;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _processD17Payment(int orderId, String token) async {
    try {
      final paymentData = {'order_id': orderId, 'amount': _finalTotal};

      final response = await http.post(
        Uri.parse('${AuthProvider.baseUrl}/api/payment/d17/initiate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
          'Accept': 'application/json',
        },
        body: json.encode(paymentData),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 401) throw Exception('Session expired');
      if (response.statusCode >= 400) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Payment error ${response.statusCode}');
      }

      final data = json.decode(response.body);
      if (data['success'] == true) {
        setState(() => _isSuccess = true);
        context.read<CartProvider>().clear();
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ReceiptScreen(
                orderId: orderId,
                totalAmount: _finalTotal,
                tableNumber: _selectedTableId ?? 0,
                items: _cartItems,
                paymentMethod: 'D17 Card',
                orderDate: DateTime.now(),
                deliveryFee: _orderType == 'delivery' ? DELIVERY_FEE : 0,
              ),
            ),
          );
        }
      } else {
        throw Exception(data['message'] ?? 'Payment failed');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_orderType == 'dine_in' && _selectedTableId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a table'), backgroundColor: Color(0xFFD32F2F)),
      );
      return;
    }
    if (_orderType == 'delivery' && _deliveryAddressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a delivery address'), backgroundColor: Color(0xFFD32F2F)),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthProvider>();
    if (auth.token == null || auth.token!.isEmpty) {
      setState(() {
        _errorMessage = 'Session expired';
        _isProcessing = false;
      });
      return;
    }

    try {
      final orderId = await _createOrder();
      _orderId = orderId;
      await _processD17Payment(orderId, auth.token!);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: _errorColor),
        );
      }
    } finally {
      if (mounted && !_isSuccess) setState(() => _isProcessing = false);
    }
  }

  String? _validateExpiryDate(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    if (value.length < 5) return 'Format MM/YY';
    final parts = value.split('/');
    if (parts.length != 2) return 'Format MM/YY';
    final month = int.tryParse(parts[0]) ?? 0;
    final year = int.tryParse(parts[1]) ?? 0;
    if (month < 1 || month > 12) return 'Invalid month';
    final now = DateTime.now();
    final currentYear = now.year % 100;
    final currentMonth = now.month;
    if (year < currentYear || (year == currentYear && month < currentMonth)) return 'Card expired';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isSuccess) return _buildSuccessScreen();

    return Scaffold(
      backgroundColor: _surfaceColor,
      appBar: AppBar(
        backgroundColor: _surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: _isProcessing ? null : () => Navigator.pop(context),
        ),
        title: const Text(
          'Payment',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: _isD17Card ? _buildD17Card() : _buildCreditCard(),
              ),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOrderTypeDropdown(),
                    const SizedBox(height: 20),
                    _buildTableDropdown(),
                    _buildDeliveryAddress(),
                    if (_orderType == 'dine_in') const SizedBox(height: 20),
                    _buildTextField(
                      controller: _cardNumberController,
                      label: 'Card Number',
                      icon: Icons.credit_card,
                      hint: '0000 0000 0000 0000',
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(16), _CardNumberInputFormatter()],
                      validator: (v) {
                        final cleaned = v?.replaceAll(' ', '') ?? '';
                        if (cleaned.isEmpty) return 'Card number required';
                        if (cleaned.length != 16) return '16 digits required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _expiryController,
                            label: 'Expiry Date',
                            icon: Icons.calendar_today_outlined,
                            hint: 'MM/YY',
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4), _CardExpiryInputFormatter()],
                            validator: _validateExpiryDate,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTextField(
                            controller: _cvvController,
                            label: 'CVV',
                            icon: Icons.lock_outline,
                            hint: '•••',
                            obscureText: true,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                            validator: (v) => v == null || v.isEmpty ? 'CVV required' : (v.length != 3 ? '3 digits required' : null),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: _cardHolderController,
                      label: 'Card Holder',
                      icon: Icons.person_outline,
                      hint: _userName.isNotEmpty ? _userName : 'Card holder name',
                      textCapitalization: TextCapitalization.characters,
                      validator: (v) => v?.isEmpty ?? true ? 'Card holder name required' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _buildSummaryCard(),
              const SizedBox(height: 24),
              AnimatedBuilder(
                animation: _glowAnimation,
                builder: (context, child) {
                  return Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: _primaryColor.withAlpha((0.2 * _glowValue.value).toInt()),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _processPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isProcessing
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(
                              _isD17Card ? 'Pay with D17' : 'Pay Now',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline, size: 14, color: _onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      'Secure Payment',
                      style: TextStyle(color: _onSurfaceVariant, fontSize: 12),
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

  Widget _buildCreditCard() {
    String cardHolderName = _cardHolderController.text.isEmpty ? _userName : _cardHolderController.text;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 20, spreadRadius: 2)],
      ),
      child: Stack(
        children: [
          Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A2A3A), Color(0xFF0F1A24)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CREDIT CARD',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1, color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 40,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(Icons.credit_card, color: Colors.black87, size: 20),
                        ),
                      ],
                    ),
                    const Text(
                      'VISA',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Text(
                  _cardNumberController.text.isEmpty ? '**** **** **** ****' : _cardNumberController.text,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 2, color: Colors.white),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Card Holder', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1, color: Colors.white70)),
                        Text(cardHolderName.isEmpty ? 'GUEST' : cardHolderName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Expires', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1, color: Colors.white70)),
                        Text(_expiryController.text.isEmpty ? 'MM/YY' : _expiryController.text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildD17Card() {
    String cardHolderName = _cardHolderController.text.isEmpty ? _userName : _cardHolderController.text;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _secondaryColor.withAlpha(51), blurRadius: 20, spreadRadius: 2)],
      ),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF003366), Color(0xFF001F4D)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _secondaryColor.withAlpha(128), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _secondaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text('D17', style: TextStyle(color: Color(0xFF003366), fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('LA POSTE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1, color: _secondaryColor)),
                          const Text('TUNISIENNE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w500, color: Colors.white70)),
                        ],
                      ),
                    ],
                  ),
                  Text('D17', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _secondaryColor)),
                ],
              ),
              const SizedBox(height: 30),
              Text(
                _cardNumberController.text.isEmpty ? '**** **** **** 0000' : _cardNumberController.text,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 2, color: Colors.white, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CARD HOLDER', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1, color: _secondaryColor)),
                      Text(cardHolderName.isEmpty ? 'GUEST' : cardHolderName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('EXPIRES', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1, color: _secondaryColor)),
                      Text(_expiryController.text.isEmpty ? 'MM/YY' : _expiryController.text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal', style: TextStyle(color: _onSurfaceVariant, fontSize: 14)),
              Text('${_subtotal.toStringAsFixed(2)} DT', style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
          // Show delivery fee only for delivery orders
          if (_orderType == 'delivery') ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('Delivery Fee', style: TextStyle(color: _onSurfaceVariant, fontSize: 14)),
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _secondaryColor.withAlpha(26),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('+5 DT', style: TextStyle(color: _secondaryColor, fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                Text('${DELIVERY_FEE.toStringAsFixed(2)} DT', style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
          const SizedBox(height: 16),
          const Divider(color: Colors.grey),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total to Pay', style: TextStyle(color: _primaryColor, fontSize: 16, fontWeight: FontWeight.w700)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_finalTotal.toStringAsFixed(2)} DT',
                    style: TextStyle(color: _primaryColor, fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  if (_orderType == 'delivery')
                    Text(
                      'Incl. delivery',
                      style: TextStyle(color: _onSurfaceVariant, fontSize: 10),
                    ),
                ],
              ),
            ],
          ),
        ],
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Text(
            label.toUpperCase(),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: _primaryColor),
          ),
        if (label.isNotEmpty) const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            style: const TextStyle(color: Colors.black87, fontSize: 14),
            inputFormatters: inputFormatters,
            validator: validator,
            enabled: !_isProcessing,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: _onSurfaceVariant.withAlpha(128)),
              prefixIcon: Icon(icon, color: _primaryColor, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              errorStyle: TextStyle(color: _errorColor, fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: _surfaceColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _successColor,
                    boxShadow: [BoxShadow(color: _successColor.withAlpha(77), blurRadius: 20)],
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 50),
                ),
              ),
              const SizedBox(height: 32),
              const Text('Payment Successful!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.black87)),
              const SizedBox(height: 12),
              Text(
                'Order #${_orderId ?? ''} confirmed',
                style: TextStyle(color: _primaryColor, fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'A confirmation email has been sent to you',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal', style: TextStyle(color: Colors.black54)),
                        Text('${_subtotal.toStringAsFixed(2)} DT', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    if (_orderType == 'delivery') ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Delivery Fee', style: TextStyle(color: Colors.black54)),
                          Text('${DELIVERY_FEE.toStringAsFixed(2)} DT', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Paid', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                        Text('${_finalTotal.toStringAsFixed(2)} DT', style: TextStyle(color: _primaryColor, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Status', style: TextStyle(color: Colors.black54)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(color: _successColor, borderRadius: BorderRadius.circular(20)),
                          child: const Text('Paid', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Type', style: TextStyle(color: Colors.black54)),
                        Text(_orderType == 'dine_in' ? '🍽️ Dine In' : '🚚 Delivery'),
                      ],
                    ),
                    if (_orderType == 'dine_in' && _selectedTableId != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Table', style: TextStyle(color: Colors.black54)),
                          Text('$_selectedTableId'),
                        ],
                      ),
                    ],
                    if (_orderType == 'delivery' && _deliveryAddressController.text.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Address', style: TextStyle(color: Colors.black54)),
                          const SizedBox(width: 12),
                          Expanded(child: Text(_deliveryAddressController.text, textAlign: TextAlign.right)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Back to Home', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
    return TextEditingValue(text: buffer.toString(), selection: TextSelection.collapsed(offset: buffer.length));
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
    return TextEditingValue(text: buffer.toString(), selection: TextSelection.collapsed(offset: buffer.length));
  }
}