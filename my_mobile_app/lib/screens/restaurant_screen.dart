import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:resto_app/screens/payment.dart';
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import 'order_tracking.dart'; // Nouvelle page pour le suivi des commandes

class RestaurantScreen extends StatefulWidget {
  const RestaurantScreen({super.key});

  @override
  State<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends State<RestaurantScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  int _currentTab = 0; // 0: Menu, 1: Mes Commandes
  final List<String> _categories = ['Tous', 'Pizzas', 'Burgers', 'Salades', 'Desserts'];
  final List<Map<String, dynamic>> _products = [
    {'id': '1', 'name': 'Pizza Margherita', 'price': 25.0, 'category': 'Pizzas', 'image': 'https://images.unsplash.com/photo-1513104890138-7c749659a591?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=80'},
    {'id': '2', 'name': 'Pizza Pepperoni', 'price': 28.0, 'category': 'Pizzas', 'image': 'https://images.unsplash.com/photo-1628840042765-356cda07504e?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=80'},
    {'id': '3', 'name': 'Burger Classique', 'price': 18.0, 'category': 'Burgers', 'image': 'https://images.unsplash.com/photo-1553979459-d2229ba7433b?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=80'},
    {'id': '4', 'name': 'Burger Double', 'price': 22.0, 'category': 'Burgers', 'image': 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=80'},
    {'id': '5', 'name': 'Salade César', 'price': 15.0, 'category': 'Salades', 'image': 'https://images.unsplash.com/photo-1546793665-c74683f339c1?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=80'},
    {'id': '6', 'name': 'Tiramisu', 'price': 12.0, 'category': 'Desserts', 'image': 'https://images.unsplash.com/photo-1571877227200-a0d98ea607e9?ixlib=rb-4.0.3&auto=format&fit=crop&w=500&q=80'},
  ];

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  List<Map<String, dynamic>> get _filteredProducts {
    if (_selectedIndex == 0) return _products;
    final category = _categories[_selectedIndex];
    return _products.where((p) => p['category'] == category).toList();
  }

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _animationController.forward();
    timeDilation = 1.3;
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

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Colors.black,
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
          Column(
            children: [
              // AppBar personnalisée
              Container(
                padding: const EdgeInsets.fromLTRB(16, 40, 16, 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _build3DText(
                      _currentTab == 0 ? 'Menu du Restaurant' : 'Mes Commandes',
                      fontSize: 24,
                      color: Colors.amber,
                      shadowColor: Colors.orange,
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.shopping_bag,
                            color: _currentTab == 1 ? Colors.amber : Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _currentTab = 1;
                            });
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.restaurant_menu,
                            color: _currentTab == 0 ? Colors.amber : Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _currentTab = 0;
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout, color: Colors.amber),
                          onPressed: () {
                            auth.logout();
                            Navigator.pushReplacementNamed(context, '/login');
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Affichage conditionnel selon l'onglet
              if (_currentTab == 0) ...[
                // Catégories avec effet 3D
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (ctx, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: ChoiceChip(
                        label: Text(
                          _categories[i],
                          style: TextStyle(
                            color: _selectedIndex == i ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        selected: _selectedIndex == i,
                        onSelected: (_) => setState(() => _selectedIndex = i),
                        selectedColor: Colors.amber,
                        backgroundColor: Colors.black.withOpacity(0.5),
                        side: BorderSide(color: Colors.amber.withOpacity(0.5)),
                        elevation: 4,
                        shadowColor: Colors.amber.withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Liste des produits
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: ListView.builder(
                      itemCount: _filteredProducts.length,
                      itemBuilder: (ctx, i) {
                        final product = _filteredProducts[i];
                        return _buildProductCard(product, cart);
                      },
                    ),
                  ),
                ),
              ] else ...[
                // Page de suivi des commandes
                Expanded(
                  child: OrderTrackingScreen(), // Nouveau composant pour le suivi
                ),
              ],
            ],
          ),
        ],
      ),
      
      // Bottom Bar avec effet 3D (seulement visible dans l'onglet Menu)
      bottomNavigationBar: _currentTab == 0 ? Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withOpacity(0.2),
              blurRadius: 15,
              spreadRadius: 3,
              offset: const Offset(0, -2),
            ),
          ],
          border: Border(
            top: BorderSide(
              color: Colors.amber.withOpacity(0.3),
              width: 1,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _build3DText(
                'Total: ${cart.totalAmount.toStringAsFixed(2)} DT',
                fontSize: 18,
                color: Colors.amber,
                shadowColor: Colors.orange,
              ),
              ElevatedButton(
                onPressed: cart.totalAmount > 0 ? () {
                  Navigator.push(
                  context,
                   MaterialPageRoute(
                   builder: (_) => PaymentScreen(totalAmount: cart.totalAmount),
                   ),
                  );
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 8,
                  shadowColor: Colors.amber.withOpacity(0.5),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text(
                  'Commander',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ) : null,
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, CartProvider cart) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.amber.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Image du produit
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: NetworkImage(product['image']),
                      fit: BoxFit.cover,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black,
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Détails du produit
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['name'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product['category'],
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${product['price']} DT',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Bouton d'ajout au panier
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add_shopping_cart,
                      color: Colors.black,
                      size: 24,
                    ),
                  ),
                  onPressed: () {
                    cart.addItem(
                      product['id'], 
                      product['name'], 
                      product['price']
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${product['name']} ajouté au panier'),
                        duration: const Duration(seconds: 2),
                        backgroundColor: Colors.amber,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}