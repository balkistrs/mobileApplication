import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

// Page de détails du produit
class ProductDetailScreen extends StatelessWidget {
  final Map<String, dynamic> product;
  final Color moodColor;

  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.moodColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E11),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            floating: false,
            pinned: true,
            backgroundColor: Colors.black,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      moodColor.withValues(alpha: 0.3),
                      const Color(0xFF0E0E11),
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.restaurant,
                    size: 100,
                    color: moodColor.withValues(alpha: 0.5),
                  ),
                ),
              ),
              title: Text(
                product['name'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Prix
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [moodColor, moodColor.withValues(alpha: 0.7)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.attach_money, color: Colors.black),
                        const SizedBox(width: 8),
                        Text(
                          '${product['price']} DT',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Description
                  const Text(
                    'Description',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: moodColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _getDescription(product['name']),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Ingrédients
                  const Text(
                    'Ingredients',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _getIngredients(product['name']).map((ingredient) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: moodColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: moodColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          ingredient,
                          style: TextStyle(
                            color: moodColor,
                            fontSize: 12,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Valeurs nutritionnelles
                  const Text(
                    'Nutritional values',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _buildNutritionRow('Calories', '${(product['price'] * 0.5).toInt()} kcal', moodColor),
                        _buildNutritionRow('Proteins', '${(product['price'] * 0.08).toInt()}g', moodColor),
                        _buildNutritionRow('Carbs', '${(product['price'] * 0.12).toInt()}g', moodColor),
                        _buildNutritionRow('Fats', '${(product['price'] * 0.1).toInt()}g', moodColor),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Bouton ajouter au panier
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final cart = context.read<CartProvider>();
                        cart.addItem(
                          product['id'].toString(),
                          product['name'],
                          product['price'],
                        );
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✨ ${product['name']} added to cart'),
                            backgroundColor: moodColor,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: moodColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Add to Cart',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getDescription(String name) {
    final descriptions = {
      'Poulet Braisé': 'Free-range chicken braised to perfection with house spices, served with a flavorful sauce and homemade fries. A generous and comforting dish.',
      'Thieboudienne': 'The national Senegalese dish: rice with fresh fish, simmered vegetables and spicy tomato sauce. A true culinary journey.',
      'Mafé': 'Tender beef stew in a creamy peanut sauce, served with white rice. A classic of West African cuisine.',
      'Yassa Poulet': 'Chicken marinated in lemon and caramelized onions, grilled and served with rice. An explosion of sweet and sour flavors.',
      'Attiéké Poisson': 'Attiéké (cassava semolina) served with grilled fish, onions and fresh tomatoes. Fresh and light.',
      'Aloko': 'Fried plantains, served with a homemade spicy sauce. Perfect as a side dish or snack.',
      'Brochettes de Bœuf': 'Spice-marinated beef skewers, grilled over wood fire. Served with grilled vegetables and sauce.',
      'Jus de Bissap': 'Refreshing hibiscus flower juice, slightly sweetened. Perfect to quench your thirst.',
      'Glace artisanale': 'Homemade ice cream with tropical fruits (mango, pineapple, coconut). Made without preservatives.',
    };
    return descriptions[name] ?? 'A delicious dish prepared with fresh, quality ingredients.';
  }

  List<String> _getIngredients(String name) {
    final ingredients = {
      'Poulet Braisé': ['Free-range chicken', 'House spices', 'Onions', 'Garlic', 'Lemon', 'Olive oil', 'Fries'],
      'Thieboudienne': ['Fresh fish', 'Rice', 'Tomatoes', 'Onions', 'Carrots', 'Cabbage', 'Parsley', 'Spices'],
      'Mafé': ['Beef', 'Peanut paste', 'Tomatoes', 'Onions', 'Carrots', 'Rice', 'Spices'],
      'Yassa Poulet': ['Chicken', 'Onions', 'Lemon', 'Mustard', 'Oil', 'Rice', 'Chili'],
      'Attiéké Poisson': ['Attiéké', 'Grilled fish', 'Tomatoes', 'Onions', 'Lemon', 'Chili'],
      'Aloko': ['Plantains', 'Palm oil', 'Onions', 'Chili', 'Salt'],
      'Brochettes de Bœuf': ['Beef', 'Spices', 'Bell peppers', 'Onions', 'Sauce', 'Grilled vegetables'],
      'Jus de Bissap': ['Hibiscus flowers', 'Cane sugar', 'Water', 'Mint', 'Ginger'],
      'Glace artisanale': ['Fresh milk', 'Cream', 'Tropical fruits', 'Sugar', 'Vanilla'],
    };
    return ingredients[name] ?? ['Fresh ingredients', 'House spices', 'Artisanal preparation'];
  }
}

// Carte produit moderne
class ModernProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final Color moodColor;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  const ModernProductCard({
    super.key,
    required this.product,
    required this.moodColor,
    required this.onTap,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.05),
              Colors.white.withValues(alpha: 0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: moodColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            // Image et badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          moodColor.withValues(alpha: 0.2),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.restaurant,
                        size: 80,
                        color: moodColor.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: moodColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${product['price']} DT',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Contenu
            Padding(
              padding: const EdgeInsets.all(16),
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
                  const SizedBox(height: 8),
                  Text(
                    product['reason'],
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Note
                      Row(
                        children: [
                          const Icon(Icons.star, color: Color(0xFFFFD700), size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '4.8',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.timer, color: Colors.white54, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '20-25 min',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      // Bouton ajouter
                      GestureDetector(
                        onTap: onAddToCart,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: moodColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add_shopping_cart,
                            color: Colors.black,
                            size: 20,
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
    );
  }
}

// Screen principal
class FaceDetectionScreen extends StatefulWidget {
  final Function(String mood, Map<String, dynamic> recommendations) onMoodDetected;
  const FaceDetectionScreen({super.key, required this.onMoodDetected});

  @override
  State<FaceDetectionScreen> createState() => _FaceDetectionScreenState();
}

class _FaceDetectionScreenState extends State<FaceDetectionScreen> with TickerProviderStateMixin {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isScanning = true;
  bool _isDetecting = false;
  
  String _detectedMood = '';
  String _moodEmoji = '';
  Color _moodColor = const Color(0xFFFFB800);
  String _moodMessage = '';
  List<Map<String, dynamic>> _recommendations = [];
  double _confidence = 0.0;
  
  late AnimationController _pulseAnimation;
  late Animation<double> _pulseAnimationValue;
  
  // ⚠️ CHANGE THIS URL BASED ON YOUR SETUP
  // For web browser: http://localhost:5000
  // For emulator: http://10.0.2.2:5000
  // For physical device: http://YOUR_COMPUTER_IP:5000
  final String pythonServerUrl = 'http://localhost:5000'; // ← CHANGE THIS
  
  final Color _primaryColor = const Color(0xFFFFB800); // ✅ ADD THIS LINE
  final Color _secondaryColor = const Color(0xFFFFD54F);
  final Color _surfaceColor = const Color(0xFF0E0E11);
  
  @override
  void initState() {
    super.initState();
    _initCamera();
    _initAnimation();
  }

  void _initAnimation() {
    _pulseAnimation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimationValue = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseAnimation, curve: Curves.easeInOut),
    );
  }

  Future<void> _initCamera() async {
    try {
      var cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) return;

      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) _captureAndDetect();
        });
      }
    } catch (e) {
      print('Camera error: $e');
      _showError();
    }
  }

  Future<void> _captureAndDetect() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      _showError();
      return;
    }
    
    setState(() {
      _isDetecting = true;
    });

    try {
      final XFile picture = await _cameraController!.takePicture();
      
      Uint8List imageBytes;
      if (kIsWeb) {
        imageBytes = await picture.readAsBytes();
      } else {
        final File file = File(picture.path);
        imageBytes = await file.readAsBytes();
      }
      
      final base64Image = base64Encode(imageBytes);
      
      print('📸 Sending photo to server: $pythonServerUrl/detect_mood');
      
      final response = await http.post(
        Uri.parse('$pythonServerUrl/detect_mood'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image': 'data:image/jpeg;base64,$base64Image'}),
      ).timeout(const Duration(seconds: 45));

      print('📥 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          final String emotion = data['emotion'] ?? 'neutral';
          final double confidence = (data['confidence'] ?? 0.7).toDouble();
          final String message = data['message'] ?? '';
          final List<dynamic> recommendations = data['recommendations'] ?? [];
          
          setState(() {
            _detectedMood = _capitalize(emotion);
            _moodEmoji = _getEmoji(emotion);
            _moodColor = _getColor(emotion);
            _moodMessage = message;
            _confidence = confidence;
            _recommendations = recommendations.map((rec) => {
              'id': rec['id'].toString(),
              'name': rec['name'].toString(),
              'price': (rec['price'] as num).toDouble(),
              'reason': rec['reason'].toString(),
            }).toList();
            _isScanning = false;
            _isDetecting = false;
          });
          
          print('🎉 Emotion detected: $emotion (${(confidence*100).toInt()}%)');
          print('🍽️ ${_recommendations.length} recommendations');
        } else {
          print('❌ Detection failed');
          _showError();
        }
      } else {
        print('❌ Status code: ${response.statusCode}');
        _showError();
      }
    } catch (e) {
      print('❌ Exception: $e');
      _showError();
    } finally {
      setState(() {
        _isDetecting = false;
      });
    }
  }

  String _capitalize(String s) => s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s;
  
  String _getEmoji(String emotion) {
    const emojis = {
      'happy': '😊', 
      'sad': '😔', 
      'angry': '😠', 
      'surprise': '😲', 
      'neutral': '😐',
      'fear': '😨',
      'disgust': '😖'
    };
    return emojis[emotion] ?? '😐';
  }
  
  Color _getColor(String emotion) {
    switch(emotion) {
      case 'happy': return const Color(0xFFFFB800);
      case 'sad': return const Color(0xFF00EEFC);
      case 'angry': return const Color(0xFFFF6E84);
      case 'surprise': return const Color(0xFFFFD700);
      case 'fear': return const Color(0xFF9B59B6);
      case 'disgust': return const Color(0xFF2ECC71);
      default: return const Color(0xFFFFB800);
    }
  }

  void _showError() {
    setState(() {
      _detectedMood = 'Error';
      _moodEmoji = '⚠️';
      _moodMessage = 'Please try again';
      _isScanning = false;
      _isDetecting = false;
    });
  }

  void _addToCart(Map<String, dynamic> product) {
    context.read<CartProvider>().addItem(product['id'], product['name'], product['price']);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✨ ${product['name']} added to cart'), 
        backgroundColor: _secondaryColor, 
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _rescan() {
    setState(() {
      _isScanning = true;
      _recommendations = [];
      _detectedMood = '';
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _captureAndDetect();
    });
  }

  void _confirmMood() {
    widget.onMoodDetected(_detectedMood, {
      'recommendations': _recommendations,
      'emoji': _moodEmoji,
      'color': _moodColor,
      'confidence': _confidence,
    });
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _pulseAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceColor,
      body: Stack(
        children: [
          if (_isCameraInitialized)
            Positioned.fill(child: CameraPreview(_cameraController!)),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent, 
                    Colors.black.withValues(alpha: 0.4), 
                    Colors.black.withValues(alpha: 0.8)
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 40, 
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5), 
                          shape: BoxShape.circle
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const Spacer(),
                      if (!_isScanning && _recommendations.isNotEmpty)
                        GestureDetector(
                          onTap: _rescan,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5), 
                              borderRadius: BorderRadius.circular(20)
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.refresh, color: Colors.white, size: 16), 
                                SizedBox(width: 6), 
                                Text('Rescan', style: TextStyle(color: Colors.white))
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Spacer(),
                if (_isScanning)
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, _) => Container(
                      width: 180 * _pulseAnimationValue.value,
                      height: 180 * _pulseAnimationValue.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [BoxShadow(color: _primaryColor.withValues(alpha: 0.4), blurRadius: 30)],
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 40, 
                              height: 40, 
                              child: CircularProgressIndicator(
                                strokeWidth: 2, 
                                color: Colors.white
                              )
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _isDetecting ? 'Analyzing your face...' : 'Look at the camera', 
                              style: const TextStyle(color: Colors.white)
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: _moodColor.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Text(_moodEmoji, style: const TextStyle(fontSize: 36)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _detectedMood, 
                                style: TextStyle(
                                  color: _moodColor, 
                                  fontSize: 18, 
                                  fontWeight: FontWeight.bold
                                )
                              ),
                              Text(
                                _moodMessage, 
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8), 
                                  fontSize: 12
                                )
                              ),
                              if (_confidence > 0) 
                                Text(
                                  'Confidence: ${(_confidence * 100).toInt()}%', 
                                  style: TextStyle(
                                    color: _moodColor.withValues(alpha: 0.6), 
                                    fontSize: 10
                                  )
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                if (!_isScanning && _recommendations.isNotEmpty)
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _recommendations.length,
                      itemBuilder: (context, index) {
                        final product = _recommendations[index];
                        return ModernProductCard(
                          product: product,
                          moodColor: _moodColor,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProductDetailScreen(
                                  product: product,
                                  moodColor: _moodColor,
                                ),
                              ),
                            );
                          },
                          onAddToCart: () => _addToCart(product),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}