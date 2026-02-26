import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'package:resto_app/screens/cart_screen.dart';
import 'package:resto_app/screens/profile_screen.dart';
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import 'order_tracking_screen.dart';

class RestaurantScreen extends StatefulWidget {
  const RestaurantScreen({super.key});

  @override
  State<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends State<RestaurantScreen>
    with TickerProviderStateMixin {
  int _selectedCategoryIndex = 0;
  int _currentTab = 0;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _products = [];
  List<String> _categories = ['Tous'];
  bool _isLoadingProducts = true;
  String? _productError;

  // Notifications
  List<dynamic> _notifications = [];
  int _notificationCount = 0;
  Timer? _notificationTimer;

  late AnimationController _animationController;
  late AnimationController _cartBounceController;
  Timer? _pollTimer;
  final Set<int> _seenOrderIds = {};
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<Map<String, dynamic>> get _filteredProducts {
    return _products.where((product) {
      // Filtre par catégorie
      if (_selectedCategoryIndex != 0 && _selectedCategoryIndex < _categories.length &&
          product['category'] != _categories[_selectedCategoryIndex]) {
        return false;
      }
      // Filtre par recherche
      if (_searchQuery.isNotEmpty) {
        return product['name'].toLowerCase().contains(_searchQuery.toLowerCase());
      }
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> get _popularProducts {
    return _products.where((p) => p['isPopular'] == true).toList();
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _cartBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _loadProducts();
    _loadNotifications();
    _startNotificationPolling();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartPolling());
  }

  Future<void> _loadProducts() async {
    try {
      setState(() {
        _isLoadingProducts = true;
        _productError = null;
      });
      
      final auth = context.read<AuthProvider>();
      final products = await auth.getProducts();
      
      if (mounted) {
        // Extraire les catégories uniques
        final categories = <String>{'Tous'};
        for (var product in products) {
          final category = product['category'] ?? 'Autre';
          categories.add(category);
        }
        
        setState(() {
          _products = products;
          _categories = categories.toList();
          _isLoadingProducts = false;
        });
        
        debugPrint('✅ Produits chargés: ${products.length}');
      }
    } catch (e) {
      debugPrint('❌ Error loading products: $e');
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
          _productError = 'Erreur de chargement: $e';
        });
      }
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final auth = context.read<AuthProvider>();
      final notifications = await auth.getUserNotifications();
      if (mounted) {
        // Filter for client-relevant notifications
        final clientNotifications = notifications.where((notif) {
          final type = notif['type'] ?? '';
          return type == 'order_status_changed';
        }).toList();
        
        setState(() {
          _notifications = clientNotifications;
          _notificationCount = clientNotifications.length;
        });
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }
  }

  void _startNotificationPolling() {
    _notificationTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        _loadNotifications();
      }
    });
  }

  void _showNotificationsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Color(0xFF0A0A0A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(Icons.notifications, color: Colors.amber, size: 24),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            if (_notifications.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off, size: 80, color: Colors.white.withOpacity(0.1)),
                      const SizedBox(height: 16),
                      Text(
                        'Aucune notification',
                        style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.5)),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
                    final title = notification['title'] ?? 'Mise à jour commande';
                    final message = notification['message'] ?? '';
                    final isRead = notification['isRead'] ?? false;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isRead 
                              ? Colors.white.withOpacity(0.05)
                              : Colors.amber.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.shopping_bag, color: Colors.amber, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  message,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  notification['createdAt'] ?? 'Date inconnue',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white.withOpacity(0.3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.amber,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text('Fermer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _maybeStartPolling() async {
    final auth = context.read<AuthProvider>();
    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await _localNotifications.initialize(initializationSettings);

    if (auth.user != null && (auth.user!.roles?.contains('chef') == true || auth.user!.roles?.contains('serveur') == true)) {
      // prime seen ids with existing orders
      try {
        final orders = await auth.getOrders();
        for (var o in orders) {
          try {
            final int id = int.tryParse(o['id'].toString()) ?? 0;
            if (id > 0) _seenOrderIds.add(id);
          } catch (_) {}
        }
      } catch (_) {}

      _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
        try {
          final latest = await auth.getOrders();
          for (var o in latest) {
            final int id = int.tryParse(o['id'].toString()) ?? 0;
            final String status = (o['status'] ?? '').toString();
            if (id > 0 && !_seenOrderIds.contains(id) && status == 'pending') {
              _seenOrderIds.add(id);
              // show notification and play sound
              await _showLocalNotification('Nouvelle commande', 'Commande #$id en attente');
              // play short sound (system default) - attempt to play remote short beep
              try {
                await _audioPlayer.play(UrlSource('https://actions.google.com/sounds/v1/alarms/alarm_clock.ogg'));
              } catch (_) {}
            }
          }
        } catch (e) {
          debugPrint('Polling error: $e');
        }
      });
    }
  }

  Future<void> _showLocalNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'orders_channel',
      'Order Notifications',
      channelDescription: 'Notifications for new orders',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await _localNotifications.show(0, title, body, platformChannelSpecifics, payload: 'order');
  }

  @override
  void dispose() {
    _animationController.dispose();
    _cartBounceController.dispose();
    _searchController.dispose();
    _pollTimer?.cancel();
    _notificationTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _animateCart() {
    _cartBounceController.reset();
    _cartBounceController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final auth = context.watch<AuthProvider>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Smart Resto Pro',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Bienvenue, ${auth.user?.email?.split('@')[0] ?? 'Client'}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: [
            // Notifications
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_none, color: Colors.amber, size: 28),
                  onPressed: _showNotificationsDialog,
                ),
                if (_notificationCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$_notificationCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Cart
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_bag_outlined, color: Colors.amber, size: 28),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CartScreen()),
                    );
                  },
                ),
                if (cart.items.isNotEmpty)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        cart.items.length.toString(),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Profile
            IconButton(
              icon: const Icon(Icons.person_outline, color: Colors.amber, size: 28),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
            ),
            // Logout
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.amber, size: 28),
              onPressed: () async {
                await auth.logout();
                if (mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
            ),
          ],
          bottom: TabBar(
            indicatorColor: Colors.amber,
            labelColor: Colors.amber,
            unselectedLabelColor: Colors.white.withOpacity(0.5),
            tabs: const [
              Tab(icon: Icon(Icons.menu_book), text: 'Menu'),
              Tab(icon: Icon(Icons.receipt_long), text: 'Commandes'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Menu Tab
            _isLoadingProducts
                ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                : _productError != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, color: Colors.red, size: 60),
                            const SizedBox(height: 16),
                            Text(
                              'Erreur de chargement',
                              style: TextStyle(color: Colors.white, fontSize: 18),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _productError!,
                              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadProducts,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                foregroundColor: Colors.black,
                              ),
                              child: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      )
                    : _buildMenuContent(),
            
            // Orders Tab
            OrderTrackingScreen(showOnlyPaidOrders: false),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuContent() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Search Bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Rechercher un plat...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  prefixIcon: const Icon(Icons.search, color: Colors.amber),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ),

        // Server Status
        SliverToBoxAdapter(
          child: _buildServerStatus(),
        ),

        // Popular Section
        if (_searchQuery.isEmpty && _selectedCategoryIndex == 0 && _popularProducts.isNotEmpty)
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildSectionTitle('Populaires', Icons.whatshot_rounded),
                ),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _popularProducts.length,
                    itemBuilder: (ctx, i) => _buildPopularCard(_popularProducts[i]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildSectionTitle('Tous les plats', Icons.restaurant_rounded),
                ),
              ],
            ),
          ),

        // Categories
        SliverToBoxAdapter(
          child: Container(
            height: 45,
            margin: const EdgeInsets.only(left: 16, bottom: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (ctx, i) => _buildCategoryChip(i),
            ),
          ),
        ),

        // Products List
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _buildProductCard(_filteredProducts[i]),
              childCount: _filteredProducts.length,
            ),
          ),
        ),

        // Empty state
        if (_filteredProducts.isEmpty)
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 60, color: Colors.white.withOpacity(0.2)),
                    const SizedBox(height: 16),
                    Text(
                      'Aucun produit trouvé',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.amber, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(int index) {
    final isSelected = _selectedCategoryIndex == index;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedCategoryIndex = index),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.amber : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.1),
              ),
            ),
            child: Text(
              _categories[index],
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopularCard(Map<String, dynamic> product) {
    return GestureDetector(
      onTap: () => _showProductDetails(product),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: Image.network(
                      product['image'] ?? 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=500',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[900],
                          child: const Icon(Icons.fastfood, color: Colors.amber, size: 40),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star, color: Colors.black, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            product['rating'].toString(),
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['name'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${product['price']} DT',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
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

  Widget _buildProductCard(Map<String, dynamic> product) {
    final cart = context.watch<CartProvider>();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showProductDetails(product),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Image
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.network(
                        product['image'] ?? 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=500',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[900],
                            child: const Icon(Icons.fastfood, color: Colors.amber, size: 30),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                product['name'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.star, color: Colors.amber, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    product['rating'].toString(),
                                    style: const TextStyle(
                                      color: Colors.amber,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.timer_rounded, color: Colors.white.withOpacity(0.3), size: 14),
                            const SizedBox(width: 4),
                            Text(
                              product['prepTime'] ?? '15-20 min',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${product['price']} DT',
                              style: const TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            ScaleTransition(
                              scale: _cartBounceController,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.amber,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.add_rounded, color: Colors.black),
                                  onPressed: () {
                                    cart.addItem(
                                      product['id'],
                                      product['name'],
                                      product['price'],
                                    );
                                    _animateCart();
                                    _showAddedToCartSnackbar(product['name']);
                                  },
                                  constraints: const BoxConstraints(
                                    minWidth: 40,
                                    minHeight: 40,
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
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
          ),
        ),
      ),
    );
  }

  Widget _buildServerStatus() {
    return FutureBuilder<bool>(
      future: context.read<AuthProvider>().testConnection(),
      builder: (context, snapshot) {
        final bool isConnected = snapshot.data ?? false;
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isConnected ? Colors.greenAccent : Colors.orangeAccent,
                  boxShadow: [
                    BoxShadow(
                      color: (isConnected ? Colors.greenAccent : Colors.orangeAccent).withOpacity(0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isConnected ? 'SYSTÈME ACTIF' : 'CONNEXION...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrdersContent() {
    return const OrderTrackingScreen(
      showOnlyPaidOrders: false,
    );
  }

  Widget _buildFloatingCartButton(CartProvider cart) {
    return ScaleTransition(
      scale: _cartBounceController,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CartScreen(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(30),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shopping_bag_rounded, color: Colors.black),
                  const SizedBox(width: 8),
                  Text(
                    '${cart.totalAmount.toStringAsFixed(2)} DT',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      cart.items.length.toString(),
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
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

  void _showProductDetails(Map<String, dynamic> product) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ProductDetailsSheet(product: product),
    );
  }

  void _showAddedToCartSnackbar(String productName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.black),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ajouté au panier',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    productName,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.amber,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// Bottom Sheet pour les détails du produit
class _ProductDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> product;

  const _ProductDetailsSheet({required this.product});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cart = Provider.of<CartProvider>(context, listen: false);

    return Container(
      height: size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
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
          
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image
                  Stack(
                    children: [
                      Image.network(
                        product['image'] ?? 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=500',
                        height: 250,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 250,
                            color: Colors.grey[900],
                            child: const Center(
                              child: Icon(Icons.fastfood, color: Colors.amber, size: 50),
                            ),
                          );
                        },
                      ),
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star, color: Colors.black, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                product['rating'].toString(),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nom et prix
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                product['name'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${product['price']} DT',
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Catégorie
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Text(
                            product['category'] ?? 'Non catégorisé',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Description
                        const Text(
                          'Description',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Préparé avec des ingrédients frais et de qualité. Temps de préparation : ${product['prepTime'] ?? '15-20 min'}.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        
                        const SizedBox(height: 30),
                        
                        // Bouton d'ajout
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () {
                              cart.addItem(
                                product['id'],
                                product['name'],
                                product['price'],
                              );
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${product['name']} ajouté au panier'),
                                  backgroundColor: Colors.amber,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: 8,
                            ),
                            child: const Text(
                              'Ajouter au panier',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
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
}