import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../providers/cart_provider.dart';
import '../providers/auth_provider.dart';
import '../models/cart_item.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  final List<Map<String, dynamic>> _conversationHistory = [];
  
  bool _isTyping = false;
  bool _isListening = false;
  bool _speechEnabled = false;
  String _currentIntent = 'welcome';
  Map<String, dynamic> _reservationData = {};
  int _orderStep = 0;
  
  late AnimationController _pulseAnimation;
  late AnimationController _fadeAnimation;
  
  stt.SpeechToText? _speech;
  String _lastWords = '';
  List<Map<String, dynamic>> _products = [];
  
  // 🔑 VOTRE CLÉ API MISTRAL AI
  final String _mistralApiKey = 'BfbdRXkQ7zIzYuXkslHRc2C2sETuvE3k';
  final bool _useMistral = true;      // ✅ Activer Mistral AI
  final bool _useLocalMode = false;    // ❌ Désactiver le mode local
  
  String _userName = '';
  String _userEmail = '';

  // 🎨 Palette Jaune et Blanc
  final Color _primaryColor = const Color(0xFFFFB800);
  final Color _secondaryColor = const Color(0xFFFFD54F);
  final Color _successColor = const Color(0xFF2ECC71);
  final Color _errorColor = const Color(0xFFD73357);
  final Color _surfaceColor = Colors.white;
  final Color _surfaceContainer = const Color(0xFFF8F8F8);
  final Color _textPrimary = const Color(0xFF1A1A1A);
  final Color _textSecondary = const Color(0xFF757575);
  final Color _borderColor = const Color(0xFFE0E0E0);

  final Map<String, String> _openingHours = {
    'Monday - Thursday': '11:00 AM - 10:00 PM',
    'Friday - Saturday': '11:00 AM - 11:00 PM',
    'Sunday': '12:00 PM - 9:00 PM',
  };

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _initAnimations();
    _initSpeech();
    _loadProducts();
    _addWelcomeMessage();
  }

  void _loadUserData() {
    final auth = context.read<AuthProvider>();
    final email = auth.user?.email ?? '';
    _userEmail = email;
    _userName = email.split('@')[0].isNotEmpty ? email.split('@')[0] : 'Guest';
  }

  void _initAnimations() {
    _pulseAnimation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    
    _fadeAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  void _addWelcomeMessage() {
    _addMessage(
      '✨ **Welcome $_userName!** ✨\n\nI am your AI Concierge powered by **Mistral AI**. I can answer all your questions about:\n\n• 🍽️ Menu and ingredients\n• 💰 Prices and promotions\n• 📅 Reservations and events\n• 🚚 Delivery and payment\n• 📍 Hours and location\n\n**Tap the microphone and ask me anything!** 🎤',
      isUser: false,
    );
  }

  Future<void> _loadProducts() async {
    try {
      final auth = context.read<AuthProvider>();
      final products = await auth.getProducts();
      setState(() {
        _products = List<Map<String, dynamic>>.from(products);
      });
    } catch (e) {
      _products = [
        {'id': '1', 'name': 'Truffle Obsidian Pie', 'price': 32, 'category': 'Main', 'popular': true},
        {'id': '2', 'name': 'Neon Garden Bowl', 'price': 24, 'category': 'Main', 'popular': true},
        {'id': '3', 'name': 'Violet Vapor Fizz', 'price': 18, 'category': 'Drink', 'popular': true},
        {'id': '4', 'name': 'Arctic Ember Salmon', 'price': 29, 'category': 'Main'},
        {'id': '5', 'name': 'Eclipse Cacao Tart', 'price': 16, 'category': 'Dessert'},
      ];
    }
  }

  Future<void> _initSpeech() async {
    try {
      var status = await Permission.microphone.request();
      if (status.isGranted) {
        _speech = stt.SpeechToText();
        bool available = await _speech!.initialize(
          onError: (error) {
            debugPrint('Speech error: $error');
            setState(() => _isListening = false);
            _addMessage('❌ Microphone error: ${error.errorMsg}', isUser: false);
          },
          onStatus: (status) {
            debugPrint('Speech status: $status');
            if (status == 'done' || status == 'notListening') {
              setState(() => _isListening = false);
              if (_lastWords.isNotEmpty && _lastWords != _messageController.text) {
                _sendMessage();
              }
            }
          },
        );
        setState(() => _speechEnabled = available);
        if (available) {
          debugPrint('✅ Speech recognition initialized');
        } else {
          debugPrint('❌ Speech recognition not available');
          _addMessage('🎤 Voice input is not available on this device.', isUser: false);
        }
      } else {
        debugPrint('❌ Microphone permission denied');
        _addMessage('🎤 Please grant microphone permission to use voice input.', isUser: false);
      }
    } catch (e) {
      debugPrint('Speech init error: $e');
      setState(() => _speechEnabled = false);
    }
  }

  void _listen() {
    if (!_speechEnabled || _speech == null) {
      _addMessage('🎤 Voice input is not available. Please type your message.', isUser: false);
      return;
    }
    
    if (!_isListening) {
      setState(() => _isListening = true);
      _lastWords = '';
      _speech!.listen(
        onResult: (result) {
          setState(() {
            _lastWords = result.recognizedWords;
            _messageController.text = _lastWords;
          });
          debugPrint('Recognized: $_lastWords');
        },
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 2),
        localeId: 'en_US',
        onSoundLevelChange: (level) {
          debugPrint('Sound level: $level');
        },
      );
    } else {
      setState(() => _isListening = false);
      _speech!.stop();
      if (_lastWords.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_messageController.text.isNotEmpty) {
            _sendMessage();
          }
        });
      }
    }
  }

  void _addMessage(String text, {required bool isUser, Map<String, dynamic>? metadata}) {
    setState(() {
      _messages.add({
        'text': text,
        'isUser': isUser,
        'time': DateTime.now(),
        'metadata': metadata,
      });
      _conversationHistory.add({'text': text, 'isUser': isUser, 'time': DateTime.now()});
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _submitReservationToApi(Map<String, dynamic> reservationData) async {
    try {
      final auth = context.read<AuthProvider>();
      final token = auth.token;
      if (token == null) throw Exception('You must be logged in to make a reservation.');
      final apiData = {
        'name': reservationData['name'],
        'email': _userEmail,
        'reservation_date': _formatDateForApi(reservationData['date']),
        'reservation_time': _formatTimeForApi(reservationData['time']),
        'people': int.parse(reservationData['people'].toString()),
      };
      debugPrint('📤 Sending reservation: $apiData');
      final response = await http.post(
        Uri.parse('${AuthProvider.baseUrl}/api/reservations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode(apiData),
      ).timeout(const Duration(seconds: 30));
      debugPrint('📥 Response: ${response.statusCode}');
      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('✅ Reservation saved: $data');
        return;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Error making reservation');
      }
    } catch (e) {
      debugPrint('❌ Reservation API error: $e');
      rethrow;
    }
  }

  String _formatDateForApi(String dateStr) {
    final parts = dateStr.split('/');
    if (parts.length == 3) {
      return '${parts[2]}-${parts[0].padLeft(2, '0')}-${parts[1].padLeft(2, '0')}';
    }
    return dateStr;
  }

  String _formatTimeForApi(String timeStr) {
    if (timeStr.contains('PM') || timeStr.contains('AM')) {
      final isPM = timeStr.contains('PM');
      String hourStr = timeStr.replaceAll('PM', '').replaceAll('AM', '').trim();
      var hourMin = hourStr.split(':');
      int hour = int.parse(hourMin[0]);
      if (isPM && hour != 12) hour += 12;
      if (!isPM && hour == 12) hour = 0;
      return '${hour.toString().padLeft(2, '0')}:${hourMin[1].padLeft(2, '0')}:00';
    } else {
      var parts = timeStr.split(':');
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}:00';
    }
  }

  // 🚀 APPEL À L'API MISTRAL AI
  Future<String> _callMistralAPI(String message) async {
    try {
      final url = 'https://api.mistral.ai/v1/chat/completions';
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_mistralApiKey',
        },
        body: jsonEncode({
          'model': 'mistral-tiny',
          'messages': [
            {
              'role': 'system',
              'content': '''You are a helpful restaurant concierge for "NOCTURNE", a high-end restaurant in Tunis.

Important information about NOCTURNE:
- Menu items: Truffle Obsidian Pie (32 DT), Neon Garden Bowl (24 DT), Violet Vapor Fizz (18 DT), Arctic Ember Salmon (29 DT), Eclipse Cacao Tart (16 DT)
- Delivery: 5 DT fee, 30-45 min, zone: 5km around the restaurant
- Hours: Mon-Thu 11AM-10PM, Fri-Sat 11AM-11PM, Sun 12PM-9PM
- Address: 123 Avenue de la Liberté, 1002 Tunis
- Payment: Credit card, cash, mobile payment (D17, E-dinar)

Be friendly, concise, and helpful. Keep responses short (under 150 words).'''
            },
            {
              'role': 'user',
              'content': message
            }
          ],
          'temperature': 0.7,
          'max_tokens': 200,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        debugPrint('Mistral API error: ${response.statusCode}');
        debugPrint('Response: ${response.body}');
        throw Exception('API error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Mistral error: $e');
      rethrow;
    }
  }

  Future<String> _generateIntelligentResponse(String message) async {
    final lowerMsg = message.toLowerCase().trim();
    
    // Gérer les intentions spécifiques localement pour plus de rapidité
    if (lowerMsg.contains('hello') || lowerMsg.contains('hi') || lowerMsg.contains('hey')) {
      return '✨ Hello $_userName! How can I help you today?\n\n• 🍽️ View the menu\n• 📅 Make a reservation\n• 💰 Check prices\n• 🚚 Delivery info\n• 📍 Location & hours';
    }
    if (lowerMsg.contains('menu')) return _getFullMenu();
    if (lowerMsg.contains('cart') || lowerMsg.contains('bag')) return _handleCart();
    if (lowerMsg.contains('reservation') || lowerMsg.contains('book') || lowerMsg.contains('table')) return _handleReservation();
    
    // Utiliser Mistral AI pour les questions complexes
    if (_useMistral && _mistralApiKey.isNotEmpty) {
      try {
        return await _callMistralAPI(message);
      } catch (e) {
        debugPrint('Mistral error, falling back to local: $e');
        return _getLocalResponse(message);
      }
    }
    
    return _getLocalResponse(message);
  }

  String _getLocalResponse(String message) {
    final lowerMsg = message.toLowerCase().trim();
    
    if (lowerMsg.contains('price') || lowerMsg.contains('cost') || lowerMsg.contains('how much')) {
      return _getPriceInfo(lowerMsg);
    }
    if (lowerMsg.contains('delivery') || lowerMsg.contains('deliver')) {
      return '🚚 **Delivery:** 5 DT fee, 30-45 min, 5km zone. Minimum order: 30 DT.';
    }
    if (lowerMsg.contains('hour') || lowerMsg.contains('open') || lowerMsg.contains('close')) {
      var buffer = '⏰ **Opening Hours:**\n\n';
      for (var entry in _openingHours.entries) {
        buffer += '• **${entry.key}** : ${entry.value}\n';
      }
      return buffer;
    }
    if (lowerMsg.contains('address') || lowerMsg.contains('where') || lowerMsg.contains('location')) {
      return '📍 **Location:** 123 Avenue de la Liberté, 1002 Tunis. Free parking available.';
    }
    if (lowerMsg.contains('pay') || lowerMsg.contains('card') || lowerMsg.contains('cash')) {
      return '💳 **Payment:** Credit card, Cash, Mobile payment (D17, E-dinar), Meal vouchers.';
    }
    if (lowerMsg.contains('contact') || lowerMsg.contains('phone') || lowerMsg.contains('email')) {
      return '📞 **Contact:** Phone: +216 XX XXX XXX | Email: contact@nocturne.restaurant';
    }
    if (lowerMsg.contains('thank')) {
      return 'You\'re welcome $_userName! 😊';
    }
    if (lowerMsg.contains('bye') || lowerMsg.contains('goodbye')) {
      return 'Goodbye $_userName! Come back soon! 🌙';
    }
    
    return '🤔 I can help with:\n\n• 🍽️ Menu & food\n• 💰 Prices\n• 🚚 Delivery\n• 📅 Reservations\n• 📍 Location & Hours\n• 💳 Payment\n\nWhat would you like to know?';
  }

  String _getPriceInfo(String question) {
    if (question.contains('truffle')) return '🍄 Truffle Obsidian Pie: 32 DT';
    if (question.contains('neon')) return '🥗 Neon Garden Bowl: 24 DT';
    if (question.contains('salmon')) return '🐟 Arctic Ember Salmon: 29 DT';
    return '📋 **Prices:** Main courses 24-38 DT. Truffle Obsidian Pie: 32 DT';
  }
  
  String _getFullMenu() {
    var buffer = '📋 **NOCTURNE MENU** 📋\n\n';
    buffer += '🍽️ **Main Courses:**\n';
    for (var product in _products) {
      if (product['category'] == 'Main') {
        buffer += '• ${product['name']} - ${product['price']} DT\n';
      }
    }
    buffer += '\n🍰 **Desserts:** Eclipse Cacao Tart - 16 DT\n';
    buffer += '\n🥤 **Drinks:** Violet Vapor Fizz - 18 DT\n';
    return buffer;
  }
  
  String _handleCart() {
    final cart = context.read<CartProvider>();
    if (cart.items.isEmpty) {
      return '🛒 **Your cart is empty.**\n\nAdd items from the menu! 🍽️';
    }
    var buffer = '🛒 **Your Cart:**\n\n';
    double total = 0;
    for (var item in cart.items) {
      final itemTotal = item.price * item.quantity;
      buffer += '• ${item.name} x${item.quantity} - ${itemTotal.toStringAsFixed(2)} DT\n';
      total += itemTotal;
    }
    buffer += '\n**Total: ${total.toStringAsFixed(2)} DT**';
    return buffer;
  }
  
  String _handleReservation() {
    _currentIntent = 'reservation';
    _orderStep = 1;
    return '📅 **Table Reservation**\n\nI\'ll help you make a reservation. What is your name?';
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    final userMessage = _messageController.text.trim();
    _messageController.clear();
    _lastWords = '';
    _addMessage(userMessage, isUser: true);
    setState(() => _isTyping = true);
    await Future.delayed(const Duration(milliseconds: 500));
    String response;
    if (_currentIntent == 'reservation') {
      if (_orderStep == 1) {
        _reservationData['name'] = userMessage;
        _orderStep = 2;
        response = 'Thank you ${_reservationData['name']}. What date? (Format: MM/DD/YYYY)';
      } else if (_orderStep == 2) {
        _reservationData['date'] = userMessage;
        _orderStep = 3;
        response = 'What time? (e.g., 7:30 PM)';
      } else if (_orderStep == 3) {
        _reservationData['time'] = userMessage;
        _orderStep = 4;
        response = 'How many people?';
      } else if (_orderStep == 4) {
        _reservationData['people'] = userMessage;
        setState(() => _isTyping = true);
        try {
          await _submitReservationToApi(_reservationData);
          response = '✅ **Reservation Confirmed!**\n\n📅 **Your Details:**\n• Name: ${_reservationData['name']}\n• Date: ${_reservationData['date']}\n• Time: ${_reservationData['time']}\n• People: ${_reservationData['people']}\n\n🎉 Thank you for choosing NOCTURNE! ✨';
        } catch (e) {
          response = '❌ **Sorry, we couldn\'t process your reservation.**\n\nPlease try again.';
        }
        _orderStep = 0;
        _currentIntent = 'welcome';
        setState(() => _isTyping = false);
      } else {
        response = await _generateIntelligentResponse(userMessage);
      }
    } else {
      response = await _generateIntelligentResponse(userMessage);
    }
    setState(() => _isTyping = false);
    _addMessage(response, isUser: false);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _pulseAnimation.dispose();
    _fadeAnimation.dispose();
    _speech?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceColor,
      appBar: AppBar(
        title: const Text('AI Concierge', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
        backgroundColor: _primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) => Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _successColor,
                      boxShadow: [
                        BoxShadow(
                          color: _successColor.withValues(alpha: 0.6),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'AI Concierge • Mistral AI',
                  style: TextStyle(
                    color: Color(0xFF757575),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
            ),
          ),
          
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _surfaceContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTypingDot(0),
                        const SizedBox(width: 4),
                        _buildTypingDot(150),
                        const SizedBox(width: 4),
                        _buildTypingDot(300),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _listen,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListening ? _errorColor : _primaryColor,
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: TextStyle(color: _textPrimary, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: _isListening ? '🎤 Listening...' : 'Ask me anything...',
                      hintStyle: TextStyle(
                        color: _isListening ? _errorColor.withValues(alpha: 0.7) : _textSecondary.withValues(alpha: 0.5),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    margin: const EdgeInsets.all(6),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isUser = message['isUser'];
    final text = message['text'];
    final time = message['time'] as DateTime;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _primaryColor,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.smart_toy,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUser ? _primaryColor : _surfaceContainer,
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(5),
                  bottomRight: isUser ? const Radius.circular(5) : const Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      color: isUser ? Colors.white : _textPrimary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: (isUser ? Colors.white : _textSecondary).withValues(alpha: 0.5),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 10),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _surfaceContainer,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.person,
                  color: Color(0xFF666666),
                  size: 18,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingDot(int delay) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0.5, end: 1.0),
      duration: Duration(milliseconds: 500 + delay),
      curve: Curves.easeInOut,
      builder: (context, double value, child) {
        return Container(
          width: 6 * value,
          height: 6 * value,
          decoration: const BoxDecoration(
            color: Color(0xFFFFB800),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}