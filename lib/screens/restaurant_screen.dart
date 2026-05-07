import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import 'order_tracking_screen.dart';
import 'chatbot_screen.dart';
import 'cart_screen.dart';
import 'face_detection_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';

class RestaurantScreen extends StatefulWidget {
  const RestaurantScreen({super.key});

  @override
  State<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends State<RestaurantScreen>
    with TickerProviderStateMixin {
  int _selectedCategoryIndex = 0;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _products = [];
  List<String> _categories = ['All Menu'];
  bool _isLoadingProducts = true;
  String? _productError;

  int _selectedNavIndex = 0;

  String? _userphotoUrl;
  String? _userName;
  List<Map<String, dynamic>> _userOrderHistory = [];
  List<Map<String, dynamic>> _topSellingProducts = [];

  // Position variables
  String _selectedAddress = '📍 Getting location...';
  bool _isLoadingLocation = false;
  bool _hasRequestedLocation = false;
  double? _currentLatitude;
  double? _currentLongitude;

  // Modern color scheme
  static const Color _primaryColor = Color(0xFFFFB800);
  static const Color _surfaceColor = Color(0xFFFAFAFA);
  static const Color _surfaceContainer = Color(0xFFFFFFFF);
  static const Color _surfaceContainerHigh = Color(0xFFF5F5F5);
  static const Color _outlineVariant = Color(0xFFE0E0E0);
  static const Color _textPrimary = Color(0xFF1A1A1A);
  static const Color _textSecondary = Color(0xFF666666);

  late AnimationController _gradientAnimation;
  late Animation<Alignment> _gradientBegin;
  late Animation<Alignment> _gradientEnd;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _initAnimations();
    _loadUserData();
    _loadUserOrderHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRequestLocation();
    });
  }

  void _initAnimations() {
    _gradientAnimation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    _gradientBegin = Tween<Alignment>(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).animate(CurvedAnimation(
      parent: _gradientAnimation,
      curve: Curves.easeInOut,
    ));

    _gradientEnd = Tween<Alignment>(
      begin: Alignment.bottomRight,
      end: Alignment.topLeft,
    ).animate(CurvedAnimation(
      parent: _gradientAnimation,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _checkAndRequestLocation() async {
    if (!kIsWeb) {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _selectedAddress = '📍 Location services disabled';
            _isLoadingLocation = false;
          });
          _showLocationPermissionDialog();
        }
        return;
      }
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _selectedAddress = '📍 Location permission denied';
          });
          _showLocationPermissionDialog();
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _selectedAddress = '📍 Location access denied';
        });
        _showLocationPermissionDialog();
      }
      return;
    }

    await _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _selectedAddress = '📍 Getting your location...';
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _selectedAddress = '📍 Location permission denied';
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _selectedAddress = '📍 Location access denied';
          _isLoadingLocation = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 10),
      );

      _currentLatitude = position.latitude;
      _currentLongitude = position.longitude;

      debugPrint('📍 Position: ${position.latitude}, ${position.longitude}');

      // Utiliser Nominatim API pour obtenir l'adresse (fonctionne sur web)
      String address = await _getAddressFromNominatim(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          if (address.isNotEmpty) {
            _selectedAddress = address;
          } else {
            _selectedAddress = '📍 Current location';
          }
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) {
        setState(() {
          _selectedAddress = '📍 Current location';
          _isLoadingLocation = false;
        });
      }
    }
  }

  // Méthode utilisant Nominatim API (gratuit, sans clé, fonctionne sur web)
  Future<String> _getAddressFromNominatim(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json'
        '&lat=$lat'
        '&lon=$lng'
        '&zoom=18'
        '&addressdetails=1'
      );
      
      final response = await http.get(
        url,
        headers: {'User-Agent': 'RestoApp/1.0'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['address'] != null) {
          final address = data['address'];
          List<String> parts = [];
          
          // Récupérer les parties de l'adresse
          if (address['road'] != null) parts.add(address['road']);
          else if (address['street'] != null) parts.add(address['street']);
          
          if (address['suburb'] != null) parts.add(address['suburb']);
          if (address['city'] != null) parts.add(address['city']);
          else if (address['town'] != null) parts.add(address['town']);
          else if (address['village'] != null) parts.add(address['village']);
          
          if (address['postcode'] != null) parts.add(address['postcode']);
          if (address['country'] != null) parts.add(address['country']);
          
          if (parts.isNotEmpty) {
            return '📍 ${parts.join(', ')}';
          }
        }
        
        // Fallback sur display_name
        if (data['display_name'] != null) {
          String displayName = data['display_name'];
          if (displayName.length > 50) {
            displayName = displayName.substring(0, 47) + '...';
          }
          return '📍 $displayName';
        }
      }
    } catch (e) {
      debugPrint('Nominatim error: $e');
    }
    
    return '';
  }

  Future<void> _refreshLocation() async {
    await _getCurrentLocation();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.gps_fixed, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              const Text('Location updated'),
            ],
          ),
          backgroundColor: _primaryColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _showLocationPermissionDialog() {
    if (_hasRequestedLocation) return;
    _hasRequestedLocation = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.location_on, color: _primaryColor, size: 28),
            const SizedBox(width: 12),
            Text(
              'Share Location',
              style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delivery_dining, size: 60, color: _primaryColor),
            const SizedBox(height: 16),
            Text(
              'To provide you with the best delivery experience, we need your current location.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _primaryColor.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.security, size: 16, color: _primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your location is only used to estimate delivery times',
                      style: TextStyle(color: _textSecondary, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _selectedAddress = '📍 Location not shared';
              });
            },
            child: Text('Later', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _getCurrentLocation();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Share Location'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadUserData() async {
    final auth = context.read<AuthProvider>();
    setState(() {
      _userName = auth.user?.email?.split('@')[0] ?? 'Guest';
      _userphotoUrl = auth.user?.photoUrl;
    });
  }

  Future<void> _loadUserOrderHistory() async {
    try {
      final auth = context.read<AuthProvider>();
      final token = auth.token;

      if (token == null) return;

      final response = await http.get(
        Uri.parse('${AuthProvider.baseUrl}/api/orders/user/ordersUser'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> orders = [];

        if (data['success'] == true && data['data'] != null) {
          if (data['data']['orders'] is List) {
            orders = data['data']['orders'];
          } else if (data['data'] is List) {
            orders = data['data'];
          }
        } else if (data is List) {
          orders = data;
        }

        if (mounted) {
          setState(() {
            _userOrderHistory = List<Map<String, dynamic>>.from(orders);
          });
          _generateTopSellingRecommendations();
        }
      }
    } catch (e) {
      debugPrint('Error loading order history: $e');
    }
  }

  void _generateTopSellingRecommendations() {
    if (_products.isEmpty) return;

    Map<int, int> productSalesCount = {};

    for (var order in _userOrderHistory) {
      final items = (order['orderItems'] ?? order['items'] ?? []) as List;
      for (var item in items) {
        if (item is Map<String, dynamic>) {
          final productId = int.tryParse(item['product_id']?.toString() ?? '0') ?? 0;
          if (productId > 0) {
            final quantity = (item['quantity'] ?? 1) as num;
            productSalesCount[productId] = (productSalesCount[productId] ?? 0) + quantity.toInt();
          }
        }
      }
    }

    if (productSalesCount.isEmpty) {
      setState(() {
        _topSellingProducts = _products.where((p) => p['populaire'] == true).take(4).toList();
      });
      return;
    }

    final sortedProductIds = productSalesCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    List<Map<String, dynamic>> topSellers = [];
    for (var entry in sortedProductIds) {
      final product = _products.firstWhere(
        (p) => int.tryParse(p['id'].toString()) == entry.key,
        orElse: () => {},
      );
      if (product.isNotEmpty && topSellers.length < 4) {
        topSellers.add(product);
      }
    }

    if (topSellers.length < 4) {
      final popularProducts = _products.where((p) =>
          p['populaire'] == true &&
          !topSellers.contains(p)).toList();
      for (var p in popularProducts) {
        if (topSellers.length < 4) {
          topSellers.add(p);
        }
      }
    }

    setState(() {
      _topSellingProducts = topSellers;
    });
  }

  Future<void> _loadProducts() async {
    try {
      setState(() {
        _isLoadingProducts = true;
        _productError = null;
      });

      final auth = context.read<AuthProvider>();

      if (auth.token == null) {
        setState(() {
          _isLoadingProducts = false;
        });
        return;
      }

      final products = await auth.getProducts();
      debugPrint('Products loaded: ${products.length}');

      for (var product in products) {
        if (product['description'] == null || product['description'].isEmpty) {
          product['description'] = 'Delicious dish prepared with fresh seasonal ingredients.';
        }
        product['rating'] = product['rating'] ?? 4.5;
        product['rating_count'] = product['rating_count'] ?? 0;
      }

      if (mounted) {
        final categories = <String>{'All Menu'};
        for (var product in products) {
          final category = product['category'] ?? 'Other';
          categories.add(category);
        }

        setState(() {
          _products = products;
          _categories = categories.toList();
          _isLoadingProducts = false;
        });

        _generateTopSellingRecommendations();
      }
    } catch (e) {
      debugPrint('Error loading products: $e');
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
          _productError = 'Error loading menu: $e';
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredProducts {
    return _products.where((product) {
      if (_selectedCategoryIndex != 0 && _selectedCategoryIndex < _categories.length &&
          product['category'] != _categories[_selectedCategoryIndex]) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        return product['name'].toLowerCase().contains(_searchQuery.toLowerCase());
      }
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> get _recommendedProducts {
    if (_topSellingProducts.isNotEmpty) {
      return _topSellingProducts;
    }
    return _products.where((p) => p['populaire'] == true).take(4).toList();
  }

  @override
  void dispose() {
    _gradientAnimation.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showAddressSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: _surfaceContainer,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Delivery Location',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            ListTile(
              leading: Icon(Icons.my_location, color: _primaryColor),
              title: const Text('Use my current location', style: TextStyle(color: _textPrimary)),
              subtitle: const Text('GPS - High precision', style: TextStyle(fontSize: 11, color: Color(0xFF666666))),
              trailing: _isLoadingLocation
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.check_circle, size: 18, color: _primaryColor),
              onTap: () async {
                Navigator.pop(ctx);
                await _refreshLocation();
              },
            ),
            
            const Divider(color: Color(0xFFE0E0E0)),
            
            ListTile(
              leading: Icon(Icons.refresh, color: _primaryColor),
              title: const Text('Refresh location', style: TextStyle(color: _textPrimary)),
              subtitle: const Text('Update your current position', style: TextStyle(fontSize: 11, color: Color(0xFF666666))),
              onTap: () async {
                Navigator.pop(ctx);
                await _refreshLocation();
              },
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getProductOptions(dynamic productId) async {
    try {
      final auth = context.read<AuthProvider>();
      final token = auth.token;

      if (token == null) return [];

      final response = await http.get(
        Uri.parse('${AuthProvider.baseUrl}/api/products/$productId/options'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error loading options: $e');
      return [];
    }
  }

  Future<void> _showProductDetails(Map<String, dynamic> product) async {
    final options = await _getProductOptions(product['id']);

    if (mounted) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) => _ProductDetailsSheet(
          product: product,
          options: options,
        ),
      );
    }
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: _surfaceColor,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(
                  'https://images.unsplash.com/photo-1504674900247-0877df9cc836?q=80&w=2070&auto=format&fit=crop',
                ),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withAlpha(50),
                  BlendMode.darken,
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  _surfaceColor.withAlpha(200),
                  _surfaceColor,
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(auth, cart),
                _buildHeroSection(),
                _buildCategoriesScroll(),
                Expanded(
                  child: IndexedStack(
                    index: _selectedNavIndex,
                    children: [
                      _buildMenuContent(),
                      _buildAIContent(),
                      const OrderTrackingScreen(showOnlyPaidOrders: false),
                      const ProfileScreen(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildFloatingButtons(),
          _buildBottomNavigation(),
        ],
      ),
    );
  }

  Widget _buildHeader(AuthProvider auth, CartProvider cart) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _surfaceContainer.withAlpha(242),
        border: const Border(
          bottom: BorderSide(color: _outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _navigateToProfile,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _surfaceContainerHigh,
                border: Border.all(color: _primaryColor.withAlpha(77), width: 1.5),
              ),
              child: ClipOval(
                child: _userphotoUrl != null && _userphotoUrl!.isNotEmpty
                  ? Image.network(
                      _userphotoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(Icons.person, color: _primaryColor, size: 20),
                    )
                  : Icon(Icons.person, color: _primaryColor, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SAVORIA',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: _primaryColor,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _primaryColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Welcome, ${_userName ?? 'Guest'}',
                        style: TextStyle(
                          fontSize: 10,
                          color: _textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Flexible(
            child: _buildLocationChip(),
          ),
          const SizedBox(width: 8),
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _surfaceContainerHigh,
                ),
                child: IconButton(
                  icon: Icon(Icons.notifications_outlined, color: _primaryColor, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                  ),
                ),
              ),
              Consumer<NotificationProvider>(
                builder: (context, notifProvider, _) {
                  if (notifProvider.unreadCount == 0) {
                    return const SizedBox.shrink();
                  }
                  return Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: _primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        notifProvider.unreadCount > 9 ? '9+' : notifProvider.unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(width: 4),
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _surfaceContainerHigh,
                ),
                child: IconButton(
                  icon: Icon(Icons.shopping_bag_outlined, color: _primaryColor, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CartScreen()),
                  ),
                ),
              ),
              if (cart.items.isNotEmpty)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: _primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      cart.items.length.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationChip() {
    return GestureDetector(
      onTap: _showAddressSelector,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: _surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _outlineVariant.withAlpha(128)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _isLoadingLocation
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFFFB800),
                    ),
                  )
                : Icon(
                    Icons.gps_fixed,
                    color: _primaryColor,
                    size: 16,
                  ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _selectedAddress,
                style: TextStyle(
                  fontSize: 11,
                  color: _textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.arrow_drop_down, color: _primaryColor, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    // ... (garde le code existant)
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _primaryColor.withAlpha(20),
            Colors.transparent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _primaryColor.withAlpha(51),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _primaryColor,
                  _primaryColor.withAlpha(204),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withAlpha(51),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded, color: Colors.white, size: 12),
                const SizedBox(width: 6),
                Text(
                  _userOrderHistory.isNotEmpty ? 'Personalized For You' : 'Most Ordered',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 10),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _userOrderHistory.isNotEmpty ? 'Welcome Back,\n$_userName' : 'Top Sellers\nThis Week',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _userOrderHistory.isNotEmpty 
                ? 'Here are our most popular dishes this week.'
                : 'Discover what everyone is loving right now.',
            style: const TextStyle(
              fontSize: 11,
              color: _textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesScroll() {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (ctx, i) => Padding(
          padding: const EdgeInsets.only(right: 10),
          child: _buildCategoryChip(i),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(int index) {
    final isSelected = _selectedCategoryIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategoryIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor : _surfaceContainerHigh,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? Colors.transparent : _outlineVariant.withAlpha(77),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _primaryColor.withAlpha(102),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Text(
          _categories[index],
          style: TextStyle(
            color: isSelected ? Colors.white : _textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  // ... (le reste du code pour _buildMenuContent, _buildProductCard, etc. reste identique)
  // Le reste du code est trop long mais vous gardez tout ce qui fonctionnait déjà
  // Je continue avec les widgets essentiels...
  
  Widget _buildMenuContent() {
    if (_isLoadingProducts) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFFB800)),
      );
    }

    if (_productError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(_productError!, style: const TextStyle(color: _textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProducts,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: _surfaceContainerHigh,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: _outlineVariant.withAlpha(51)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                style: TextStyle(color: _textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search menu...',
                  hintStyle: TextStyle(color: _textSecondary.withAlpha(128), fontSize: 13),
                  prefixIcon: Icon(Icons.search, color: _primaryColor, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ),
        if (_searchQuery.isEmpty && _recommendedProducts.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _primaryColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.trending_up, color: _primaryColor, size: 14),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Most Ordered Dishes',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _primaryColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_searchQuery.isEmpty && _recommendedProducts.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildLargeRecommendedCard(_recommendedProducts[0]),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildSmallCard(_recommendedProducts.length > 1 ? _recommendedProducts[1] : _recommendedProducts[0])),
                      const SizedBox(width: 10),
                      Expanded(child: _buildSmallCard(_recommendedProducts.length > 2 ? _recommendedProducts[2] : _recommendedProducts[0])),
                    ],
                  ),
                  if (_recommendedProducts.length > 3) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildSmallCard(_recommendedProducts[3])),
                        const SizedBox(width: 10),
                        Expanded(child: _buildSmallCard(_recommendedProducts.length > 4 ? _recommendedProducts[4] : _recommendedProducts[3])),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text(
                  'All Menu',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(left: 12),
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_primaryColor.withAlpha(77), Colors.transparent],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildProductCard(_filteredProducts[i]),
              ),
              childCount: _filteredProducts.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  // Ces méthodes doivent être gardées telles qu'elles étaient
  Widget _buildLargeRecommendedCard(Map<String, dynamic> product) {
    final rating = (product['rating'] as num?)?.toDouble() ?? 0.0;
    return GestureDetector(
      onTap: () => _showProductDetails(product),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
          image: DecorationImage(
            image: NetworkImage(product['image'] ?? 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=500'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black.withAlpha(77), BlendMode.darken),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withAlpha(128),
                Colors.black.withAlpha(204),
              ],
              stops: const [0.4, 0.7, 1.0],
            ),
          ),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _primaryColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_fire_department, color: Colors.white, size: 8),
                        SizedBox(width: 2),
                        Text('TOP SELLER', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product['name'],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      ...List.generate(5, (index) {
                        final starValue = index + 1;
                        if (rating >= starValue) {
                          return const Icon(Icons.star, size: 8, color: Color(0xFFFFD700));
                        } else if (rating >= starValue - 0.5) {
                          return const Icon(Icons.star_half, size: 8, color: Color(0xFFFFD700));
                        } else {
                          return const Icon(Icons.star_border, size: 8, color: Color(0xFFFFD700));
                        }
                      }),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 9, color: Colors.white70),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 2,
                        height: 2,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white54),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.timer, size: 8, color: Colors.white70),
                      const SizedBox(width: 2),
                      Text(
                        product['prep_time'] ?? '20 min',
                        style: const TextStyle(fontSize: 9, color: Colors.white70),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 2,
                        height: 2,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white54),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${(product['price'] as num).toDouble().toStringAsFixed(2)} DT',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _primaryColor,
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
    );
  }

  Widget _buildSmallCard(Map<String, dynamic> product) {
    final rating = (product['rating'] as num?)?.toDouble() ?? 0.0;
    return GestureDetector(
      onTap: () => _showProductDetails(product),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: _surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _outlineVariant.withAlpha(128)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                product['image'] ?? 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=500',
                width: 45,
                height: 45,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 45,
                  height: 45,
                  color: _surfaceContainerHigh,
                  child: Icon(Icons.fastfood, color: _primaryColor, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'],
                    style: const TextStyle(
                      color: _textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      ...List.generate(5, (index) {
                        final starValue = index + 1;
                        if (rating >= starValue) {
                          return const Icon(Icons.star, size: 8, color: Color(0xFFFFD700));
                        } else if (rating >= starValue - 0.5) {
                          return const Icon(Icons.star_half, size: 8, color: Color(0xFFFFD700));
                        } else {
                          return const Icon(Icons.star_border, size: 8, color: Color(0xFFFFD700));
                        }
                      }),
                      const SizedBox(width: 2),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 8, color: _textSecondary),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(product['price'] as num).toDouble().toStringAsFixed(2)} DT',
                        style: TextStyle(
                          color: _primaryColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          context.read<CartProvider>().addItem(
                            product['id'].toString(),
                            product['name'],
                            (product['price'] as num).toDouble(),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${product['name']} added'),
                              backgroundColor: _primaryColor,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: _primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add, color: Colors.white, size: 10),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    String description = product['description'] ?? '';
    String displayDescription = description;
    if (displayDescription.length > 120) {
      displayDescription = '${displayDescription.substring(0, 120)}...';
    }

    final rating = (product['rating'] as num?)?.toDouble() ?? 4.5;

    return GestureDetector(
      onTap: () => _showProductDetails(product),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _outlineVariant.withAlpha(128)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: Stack(
                children: [
                  Image.network(
                    product['image'] ?? 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=500',
                    width: 100,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 100,
                      height: 120,
                      color: _surfaceContainerHigh,
                      child: Icon(Icons.fastfood, color: _primaryColor, size: 30),
                    ),
                  ),
                  if (product['populaire'] == true)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _primaryColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Popular',
                          style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['name'],
                      style: const TextStyle(
                        color: _textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          final starValue = index + 1;
                          if (rating >= starValue) {
                            return const Icon(Icons.star, size: 12, color: Color(0xFFFFD700));
                          } else if (rating >= starValue - 0.5) {
                            return const Icon(Icons.star_half, size: 12, color: Color(0xFFFFD700));
                          } else {
                            return const Icon(Icons.star_border, size: 12, color: Color(0xFFFFD700));
                          }
                        }),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 10, color: _textSecondary),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.timer, size: 10, color: _textSecondary),
                        const SizedBox(width: 2),
                        Text(
                          product['prep_time'] ?? '20 min',
                          style: TextStyle(fontSize: 10, color: _textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      displayDescription,
                      style: TextStyle(fontSize: 10, color: _textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${(product['price'] as num).toDouble().toStringAsFixed(2)} DT',
                          style: TextStyle(
                            color: _primaryColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            context.read<CartProvider>().addItem(
                              product['id'].toString(),
                              product['name'],
                              (product['price'] as num).toDouble(),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${product['name']} added to cart'),
                                backgroundColor: _primaryColor,
                                duration: const Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add_shopping_cart, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _primaryColor.withAlpha(25),
            ),
            child: Icon(Icons.auto_awesome, size: 48, color: _primaryColor),
          ),
          const SizedBox(height: 20),
          Text(
            'AI Concierge',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _textPrimary, letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          Text(
            'Smart recommendations based on your mood',
            style: TextStyle(color: _textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: _primaryColor,
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withAlpha(102),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FaceDetectionScreen(
                      onMoodDetected: (mood, recommendations) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Mood detected: $mood'),
                            backgroundColor: _primaryColor,
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
              ),
              child: const Text('Scan Mood', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingButtons() {
    return Positioned(
      right: 16,
      bottom: 80,
      child: Column(
        children: [
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatbotScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _primaryColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withAlpha(102),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(Icons.chat_bubble, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _surfaceContainer.withAlpha(242),
          border: const Border(
            top: BorderSide(
              color: _outlineVariant,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.restaurant_menu, 'Menu', 0),
            _buildNavItem(Icons.smart_toy, 'AI', 1),
            _buildNavItem(Icons.receipt_long, 'Orders', 2),
            _buildNavItem(Icons.person, 'Profile', 3),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedNavIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedNavIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: isSelected
            ? BoxDecoration(
                color: _primaryColor,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: _primaryColor.withAlpha(77),
                    blurRadius: 10,
                  ),
                ],
              )
            : null,
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : _textSecondary,
              size: 18,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Product Details Bottom Sheet
class _ProductDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> product;
  final List<Map<String, dynamic>> options;

  const _ProductDetailsSheet({
    required this.product,
    this.options = const [],
  });

  @override
  State<_ProductDetailsSheet> createState() => _ProductDetailsSheetState();
}

class _ProductDetailsSheetState extends State<_ProductDetailsSheet> {
  final Map<int, bool> _selectedOptions = {};
  double _totalExtraPrice = 0.0;

  final Color _primaryColor = const Color(0xFFFFB800);
  final Color _surfaceColor = const Color(0xFFFFFFFF);
  final Color _textPrimary = const Color(0xFF1A1A1A);
  final Color _textSecondary = const Color(0xFF666666);

  void _toggleOption(int index, double price) {
    setState(() {
      if (_selectedOptions[index] == true) {
        _selectedOptions[index] = false;
        _totalExtraPrice -= price;
      } else {
        _selectedOptions[index] = true;
        _totalExtraPrice += price;
      }
    });
  }

  void _addToCartWithOptions() {
    final cart = Provider.of<CartProvider>(context, listen: false);

    List<String> selectedOptionNames = [];
    double optionsPrice = 0.0;

    _selectedOptions.forEach((index, isSelected) {
      if (isSelected && index < widget.options.length) {
        final option = widget.options[index];
        selectedOptionNames.add(option['name']);
        optionsPrice += (option['price'] as num).toDouble();
      }
    });

    String productName = widget.product['name'];
    if (selectedOptionNames.isNotEmpty) {
      productName = '${widget.product['name']} (+${selectedOptionNames.join(', ')})';
    }

    double finalPrice = (widget.product['price'] as num).toDouble() + optionsPrice;

    cart.addItem(
      widget.product['id'].toString(),
      productName,
      finalPrice,
    );

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '✨ ${widget.product['name']} added to cart',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (selectedOptionNames.isNotEmpty)
              Text(
                'With: ${selectedOptionNames.join(', ')}',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        backgroundColor: _primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final basePrice = (widget.product['price'] as num).toDouble();
    final totalPrice = basePrice + _totalExtraPrice;

    return Container(
      height: size.height * 0.85,
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      Image.network(
                        widget.product['image'] ?? 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=500',
                        height: 250,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 250,
                          color: const Color(0xFFF5F5F5),
                          child: const Center(
                            child: Icon(Icons.fastfood, color: Color(0xFFFFB800), size: 50),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, _surfaceColor],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                widget.product['name'],
                                style: TextStyle(
                                  color: _textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (_totalExtraPrice > 0)
                                  Text(
                                    '${basePrice.toStringAsFixed(2)} DT',
                                    style: TextStyle(
                                      color: _textSecondary,
                                      fontSize: 12,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                Text(
                                  '${totalPrice.toStringAsFixed(2)} DT',
                                  style: TextStyle(
                                    color: _primaryColor,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _primaryColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            widget.product['category'] ?? 'Gourmet',
                            style: TextStyle(color: _primaryColor, fontSize: 11),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Description',
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.product['description'] ?? 'Delicious dish prepared with fresh authentic ingredients.',
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            _buildInfoChip(Icons.timer, widget.product['prep_time'] ?? '20 min', 'Time'),
                            const SizedBox(width: 12),
                            _buildInfoChip(Icons.local_fire_department, '${widget.product['calories'] ?? '380'} kcal', 'Calories'),
                          ],
                        ),
                        if (widget.options.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Text(
                            'Add extras',
                            style: TextStyle(
                              color: _textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...widget.options.asMap().entries.map((entry) {
                            final index = entry.key;
                            final option = entry.value;
                            final isSelected = _selectedOptions[index] ?? false;
                            final optionPrice = (option['price'] as num).toDouble();
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: isSelected ? _primaryColor.withAlpha(25) : const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: InkWell(
                                onTap: () => _toggleOption(index, optionPrice),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSelected ? _primaryColor : const Color(0xFFE0E0E0),
                                            width: 2,
                                          ),
                                        ),
                                        child: isSelected
                                            ? Center(
                                                child: Container(
                                                  width: 10,
                                                  height: 10,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: _primaryColor,
                                                  ),
                                                ),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          option['name'],
                                          style: TextStyle(
                                            color: isSelected ? _primaryColor : _textPrimary,
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '+${optionPrice.toStringAsFixed(2)} DT',
                                        style: TextStyle(
                                          color: isSelected ? _primaryColor : _textSecondary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                          if (_totalExtraPrice > 0)
                            Container(
                              margin: const EdgeInsets.only(top: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _primaryColor.withAlpha(25),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total extras',
                                    style: TextStyle(color: _textSecondary, fontSize: 13),
                                  ),
                                  Text(
                                    '+${_totalExtraPrice.toStringAsFixed(2)} DT',
                                    style: TextStyle(
                                      color: _primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _addToCartWithOptions,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_shopping_cart, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Add to cart • ${totalPrice.toStringAsFixed(2)} DT',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: _primaryColor, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(color: _textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: TextStyle(color: _textSecondary, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}