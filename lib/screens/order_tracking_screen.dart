import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';

class OrderTrackingScreen extends StatefulWidget {
  final bool showOnlyPaidOrders;
  
  const OrderTrackingScreen({
    Key? key,
    this.showOnlyPaidOrders = false,
  }) : super(key: key);

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  
  late AnimationController _pulseAnimation;
  late Animation<double> _pulseValue;
  
  // Couleurs (Palette jaune)
  final Color _primaryColor = const Color(0xFFFFB800);
  final Color _backgroundColor = const Color(0xFF0A0A0F);
  final Color _surfaceColor = const Color(0xFF14141F);
  final Color _cardColor = const Color(0xFF1A1A24);
  final Color _textSecondary = const Color(0xFFA0A0B0);
  final Color _successColor = const Color(0xFF2ECC71);
  final Color _warningColor = const Color(0xFFF39C12);
  final Color _errorColor = const Color(0xFFD73357);

  @override
  void initState() {
    super.initState();
    _loadUserOrders();
    _initAnimations();
  }
  
  void _initAnimations() {
    _pulseAnimation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseValue = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseAnimation, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pulseAnimation.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredOrders {
    if (_searchQuery.isEmpty) return _orders;
    return _orders.where((order) {
      final id = order['id']?.toString() ?? '';
      return id.contains(_searchQuery);
    }).toList();
  }

  Future<void> _loadUserOrders() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final token = auth.token;

      if (token == null) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Not authenticated';
            _isLoading = false;
          });
        }
        return;
      }
      
      final response = await http.get(
        Uri.parse('${AuthProvider.baseUrl}/api/orders/user/ordersUser'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final dynamic jsonResponse = json.decode(response.body);
        List<dynamic> ordersList = [];
        
        if (jsonResponse is List) {
          ordersList = jsonResponse;
        } else if (jsonResponse is Map<String, dynamic>) {
          if (jsonResponse['success'] == true) {
            final data = jsonResponse['data'];
            if (data is List) ordersList = data;
            else if (data is Map && data['orders'] is List) ordersList = data['orders'];
          } else if (jsonResponse['orders'] is List) {
            ordersList = jsonResponse['orders'];
          } else if (jsonResponse['data'] is List) {
            ordersList = jsonResponse['data'];
          }
        }
        
        final List<Map<String, dynamic>> transformedOrders = [];
        
        for (var order in ordersList) {
          if (order is Map<String, dynamic>) {
            List<dynamic> items = order['orderItems'] ?? order['items'] ?? [];
            
            final List<Map<String, dynamic>> transformedItems = [];
            for (var item in items) {
              if (item is Map<String, dynamic>) {
                transformedItems.add({
                  'name': item['name'] ?? item['product']?['name'] ?? 'Product',
                  'price': (item['price'] ?? item['product']?['price'] ?? 0).toDouble(),
                  'quantity': (item['quantity'] ?? 1).toInt(),
                });
              }
            }
            
            transformedOrders.add({
              'id': order['id'] ?? 0,
              'status': order['status'] ?? 'pending',
              'total': (order['total'] as num?)?.toDouble() ?? 0.0,
              'createdAt': order['createdAt'] ?? order['created_at'] ?? '',
              'orderItems': transformedItems,
              'rated': order['rating'] != null && order['rating'] > 0,
              'userRating': order['rating'],
              'review': order['review'],
            });
          }
        }
        
        setState(() {
          _orders = transformedOrders;
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        setState(() {
          _errorMessage = 'Session expired. Please login again.';
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Server error: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending': return 'Pending';
      case 'paid': return 'Paid';
      case 'preparing': return 'Preparing';
      case 'ready': return 'Ready';
      case 'delivered': return 'Delivered';  // ✅ Ajouté

      case 'completed': return 'Completed';
      case 'cancelled': return 'Cancelled';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return _warningColor;
      case 'paid': return _primaryColor;
      case 'preparing': return _warningColor;
      case 'ready': return _successColor;
      case 'delivered': return _successColor;  // ✅ Ajouté

      case 'completed': return _successColor;
      case 'cancelled': return _errorColor;
      default: return _textSecondary;
    }
  }

  String _getEstimatedTime(Map<String, dynamic> order) {
    if (order['status'] == 'completed') return 'Delivered';
    if (order['status'] == 'ready') return 'Ready for pickup';
    
    try {
      String? dateStr = order['createdAt'];
      if (dateStr == null || dateStr.isEmpty) return '--';
      final createdAt = DateTime.parse(dateStr);
      final now = DateTime.now();
      final elapsed = now.difference(createdAt).inMinutes;
      const prepTime = 22;
      final remaining = prepTime - elapsed;
      
      if (remaining <= 0) return 'Ready soon';
      if (remaining < 1) return '< 1 min';
      return '$remaining min';
    } catch (e) {
      return '--';
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _OrderDetailsSheet(
        order: order,
        onRatingSubmitted: _loadUserOrders,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseValue.value,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _primaryColor,
                    ),
                    child: const Icon(Icons.restaurant_menu, color: Colors.black, size: 30),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Loading your orders...',
              style: TextStyle(color: _textSecondary),
            ),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: _errorColor),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadUserOrders,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final orders = _filteredOrders;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('My Orders', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
        backgroundColor: _primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: _primaryColor.withOpacity(0.3)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search order...',
                  hintStyle: TextStyle(color: _textSecondary.withOpacity(0.5)),
                  prefixIcon: Icon(Icons.search, color: _primaryColor),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: _textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ),
          ),
          
          // Orders List
          Expanded(
            child: orders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_rounded,
                          size: 80,
                          color: _textSecondary.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No orders found',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your orders will appear here',
                          style: TextStyle(color: _textSecondary),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _loadUserOrders,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                          child: const Text('Refresh'),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadUserOrders,
                    color: _primaryColor,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: orders.length,
                      itemBuilder: (context, index) => _buildOrderCard(orders[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);
    final canRate = status == 'completed' || status == 'ready' || status == 'delivered';;
    final hasRated = order['rated'] == true || (order['userRating'] != null && order['userRating'] > 0);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showOrderDetails(order),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.receipt_long_rounded,
                            color: statusColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order #${order['id']}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              _formatDate(order['createdAt']),
                              style: TextStyle(
                                color: _textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        _getStatusText(status).toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                if (order['orderItems'] != null && (order['orderItems'] as List).isNotEmpty)
                  ...(order['orderItems'] as List).take(2).map<Widget>((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _primaryColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${item['name']} x${item['quantity']}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${(item['price'] * item['quantity']).toStringAsFixed(2)} DT',
                            style: TextStyle(
                              color: _primaryColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                
                if (order['orderItems'] != null && (order['orderItems'] as List).length > 2)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+ ${(order['orderItems'] as List).length - 2} more items',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                
                const SizedBox(height: 16),
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule_rounded, color: _primaryColor, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Estimated Arrival:',
                        style: TextStyle(color: _textSecondary, fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getEstimatedTime(order),
                        style: TextStyle(
                          color: _primaryColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total',
                          style: TextStyle(color: _textSecondary, fontSize: 11),
                        ),
                        Text(
                          '${(order['total'] ?? 0).toStringAsFixed(2)} DT',
                          style: TextStyle(
                            color: _primaryColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    
                    if (canRate && !hasRated)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _primaryColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.star, color: Colors.black, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Rate',
                              style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      
                    if (hasRated)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _primaryColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star, color: Color(0xFFFFD700), size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${order['userRating']}/5',
                              style: TextStyle(color: _primaryColor, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Order Details Bottom Sheet
class _OrderDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> order;
  final VoidCallback onRatingSubmitted;

  const _OrderDetailsSheet({
    required this.order,
    required this.onRatingSubmitted,
  });

  @override
  State<_OrderDetailsSheet> createState() => _OrderDetailsSheetState();
}

class _OrderDetailsSheetState extends State<_OrderDetailsSheet> {
  int _selectedRating = 0;
  final TextEditingController _reviewController = TextEditingController();
  bool _isSubmitting = false;
  bool _hasSubmitted = false;

  final Color _primaryColor = const Color(0xFFFFB800);
  final Color _backgroundColor = const Color(0xFF0A0A0F);
  final Color _cardColor = const Color(0xFF1A1A24);
  final Color _textSecondary = const Color(0xFFA0A0B0);
  final Color _successColor = const Color(0xFF2ECC71);
  final Color _warningColor = const Color(0xFFF39C12);
  final Color _errorColor = const Color(0xFFD73357);

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return _warningColor;
      case 'paid': return _primaryColor;
      case 'preparing': return _warningColor;
      case 'ready': return _successColor;
      case 'completed': return _successColor;
      case 'cancelled': return _errorColor;
      default: return _textSecondary;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending': return 'Pending';
      case 'paid': return 'Paid';
      case 'preparing': return 'Preparing';
      case 'ready': return 'Ready';
      case 'completed': return 'Completed';
      case 'cancelled': return 'Cancelled';
      default: return status;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }

  Future<void> _submitRating() async {
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating'), backgroundColor: Color(0xFFF39C12)),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final token = auth.token;

      final response = await http.post(
        Uri.parse('${AuthProvider.baseUrl}/api/orders/${widget.order['id']}/rating'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'rating': _selectedRating,
          'review': _reviewController.text.trim(),
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _hasSubmitted = true;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your review!'), backgroundColor: Color(0xFF2ECC71)),
        );
        
        widget.onRatingSubmitted();
        
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context);
        });
      } else {
        throw Exception('Failed to submit rating');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: _errorColor),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final status = widget.order['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);
    final canRate = status == 'completed' || status == 'ready' || status == 'delivered';;
    final hasRated = widget.order['rated'] == true || (widget.order['userRating'] != null && widget.order['userRating'] > 0);

    return Container(
      height: size.height * 0.85,
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor.withOpacity(0.15),
                  ),
                  child: Icon(
                    status == 'completed' ? Icons.check_circle : Icons.receipt_long_rounded,
                    color: statusColor,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  canRate ? 'Order Ready' : 'Order Confirmed',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Order #${widget.order['id']}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // Info Cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DATE',
                          style: TextStyle(
                            color: _primaryColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatDate(widget.order['createdAt']),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOTAL',
                          style: TextStyle(
                            color: _primaryColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(widget.order['total'] ?? 0).toStringAsFixed(2)} DT',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.restaurant_menu, color: Color(0xFFFFB800), size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Order Details',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getStatusText(status).toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Items List
                    ...(widget.order['orderItems'] as List).map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _primaryColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.fastfood, color: Color(0xFFFFB800), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['name'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    'x${item['quantity']}',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${(item['price'] * item['quantity']).toStringAsFixed(2)} DT',
                              style: TextStyle(
                                color: _primaryColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    
                    const Divider(color: Colors.white10),
                    
                    // Total
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${(widget.order['total'] ?? 0).toStringAsFixed(2)} DT',
                            style: TextStyle(
                              color: _primaryColor,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Rating Section
                    if (canRate && !hasRated && !_hasSubmitted) ...[
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 16),
                      const Text(
                        'Rate Your Experience',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return IconButton(
                            onPressed: () {
                              setState(() {
                                _selectedRating = index + 1;
                              });
                            },
                            icon: Icon(
                              index < _selectedRating ? Icons.star : Icons.star_border,
                              color: const Color(0xFFFFD700),
                              size: 32,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _reviewController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Your review (optional)',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                          filled: true,
                          fillColor: _backgroundColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitRating,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Submit Review', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],

                    if (hasRated) ...[
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 16),
                      const Text(
                        'Your Review',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ...List.generate(5, (index) {
                            return Icon(
                              index < (widget.order['userRating'] ?? 0) ? Icons.star : Icons.star_border,
                              color: const Color(0xFFFFD700),
                              size: 20,
                            );
                          }),
                        ],
                      ),
                      if (widget.order['review'] != null && widget.order['review'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            widget.order['review'],
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          
          // Close Button
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Close', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}