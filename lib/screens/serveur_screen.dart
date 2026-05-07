import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import 'profile_screen.dart';

class ServeurScreen extends StatefulWidget {
  const ServeurScreen({super.key});

  @override
  State<ServeurScreen> createState() => _ServeurScreenState();
}

class _ServeurScreenState extends State<ServeurScreen> with TickerProviderStateMixin {
  List<dynamic> _activeOrders = [];
  List<dynamic> _completedOrdersList = [];
  List<Map<String, dynamic>> _reservations = [];
  List<dynamic> _notifications = [];
  List<Map<String, dynamic>> _tables = [];
  bool _isLoading = true;
  int _notificationCount = 0;
  int _selectedTab = 0;
  Timer? _notificationTimer;
  
  // Statistiques
  int _activeOrdersCount = 0;
  int _completedOrdersCount = 0;
  int _pendingReservationsCount = 0;
  int _confirmedReservationsCount = 0;
  int _availableTablesCount = 0;
  int _occupiedTablesCount = 0;
  
  // Pour la sélection de table
  int? _selectedTableIdForReservation;
  
  // Animations
  late AnimationController _fadeAnimation;
  late Animation<double> _fadeIn;
  
  // NOCTURNE Colors
  final Color _primaryColor = const Color(0xFFDF8EFF);
  final Color _secondaryColor = const Color(0xFF00EEFC);
  final Color _surfaceColor = const Color(0xFF0E0E11);
  final Color _surfaceContainer = const Color(0xFF19191D);
  final Color _surfaceContainerHigh = const Color(0xFF1F1F23);
  final Color _onSurfaceVariant = const Color(0xFFACAAAE);
  final Color _successColor = const Color(0xFF2ECC71);
  final Color _warningColor = const Color(0xFFF39C12);
  final Color _errorColor = const Color(0xFFD73357);

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadAllData();
    _startPolling();
  }

  void _initAnimations() {
    _fadeAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(
      parent: _fadeAnimation,
      curve: Curves.easeIn,
    );
    _fadeAnimation.forward();
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _fadeAnimation.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    
    await Future.wait([
      _loadOrders(),
      _loadReservations(),
      _loadNotifications(),
      _loadTables(),
    ]);
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _startPolling() {
    _notificationTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        _loadOrders();
        _loadReservations();
        _loadNotifications();
        _loadTables();
      }
    });
  }

Future<void> _loadOrders() async {
  try {
    final allOrders = await context.read<AuthProvider>().getOrders();
    
    // Filtrer seulement les commandes avec statut "ready" (prêtes à être servies)
    final readyOrders = allOrders.where((o) {
      final status = o['status']?.toString().toLowerCase() ?? '';
      return status == 'ready';
    }).toList();
    
    // Compter les commandes terminées pour la statistique
    final completed = allOrders.where((o) {
      final status = o['status']?.toString().toLowerCase() ?? '';
      return status == 'completed' || status == 'served';
    }).toList();
    
    if (mounted) {
      setState(() {
        _activeOrders = readyOrders;  // Seulement les commandes prêtes
        _completedOrdersList = completed;
        _activeOrdersCount = readyOrders.length;
        _completedOrdersCount = completed.length;
      });
    }
    
    print('📊 Commandes prêtes: ${readyOrders.length}, terminées: ${completed.length}');
  } catch (e) {
    debugPrint('Error loading orders: $e');
  }
}

  Future<void> _loadTables() async {
    try {
      final auth = context.read<AuthProvider>();
      final token = auth.token;
      
      if (token == null) {
        print('❌ Pas de token');
        return;
      }
      
      print('🔄 Chargement des tables...');
      
      final response = await http.get(
        Uri.parse('${AuthProvider.baseUrl}/tables'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 30));
      
      print('📥 Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        List<dynamic> tables = [];
        
        if (data is Map<String, dynamic>) {
          tables = data['tables'] ?? data['data'] ?? [];
        } else if (data is List) {
          tables = data;
        }
        
        final normalizedTables = tables.map((table) {
          final isAvailableValue = table['is_available'];
          final isAvailableBool = isAvailableValue == true || 
                                  isAvailableValue == 1 || 
                                  isAvailableValue == '1';
          
          return {
            'id': table['id'] is int ? table['id'] : int.tryParse(table['id'].toString()) ?? 0,
            'name': table['name'] ?? 'Table ${table['id']}',
            'capacity': table['capacity'] is int ? table['capacity'] : int.tryParse(table['capacity'].toString()) ?? 2,
            'is_available': isAvailableBool,
          };
        }).toList();
        
        if (mounted) {
          setState(() {
            _tables = List<Map<String, dynamic>>.from(normalizedTables);
            _availableTablesCount = _tables.where((t) => t['is_available'] == true).length;
            _occupiedTablesCount = _tables.where((t) => t['is_available'] == false).length;
          });
          
          print('✅ Tables: $_availableTablesCount libres, $_occupiedTablesCount occupées');
        }
      } else {
        print('❌ Erreur HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ Error loading tables: $e');
    }
  }

  Future<void> _loadReservations() async {
    try {
      final auth = context.read<AuthProvider>();
      final token = auth.token;
      
      if (token == null) return;
      
      final response = await http.get(
        Uri.parse('${AuthProvider.baseUrl}/serveur/reservations'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        List<Map<String, dynamic>> reservationsData = [];
        
        if (data['success'] == true && data['data'] is List) {
          reservationsData = List<Map<String, dynamic>>.from(data['data']);
        }
        
        if (mounted) {
          setState(() {
            _reservations = reservationsData;
            _pendingReservationsCount = _reservations.where((r) => r['status'] == 'pending').length;
            _confirmedReservationsCount = _reservations.where((r) => r['status'] == 'confirmed').length;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading reservations: $e');
    }
  }

 // Dans serveur_screen.dart, modifiez la méthode _loadNotifications :

Future<void> _loadNotifications() async {
  try {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    
    if (token == null) {
      print('❌ Pas de token pour les notifications');
      return;
    }
    
    print('🔄 Chargement des notifications...');
    
    final response = await http.get(
      Uri.parse('${AuthProvider.baseUrl}/notifications'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
    ).timeout(const Duration(seconds: 15));
    
    print('📥 Notifications response status: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      List<dynamic> notifications = [];
      
      if (data['success'] == true && data['data'] is List) {
        notifications = data['data'];
      } else if (data is List) {
        notifications = data;
      } else if (data is Map && data['notifications'] is List) {
        notifications = data['notifications'];
      }
      
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _notificationCount = notifications.length;
        });
      }
      print('✅ Notifications chargées: ${notifications.length}');
    } else {
      print('❌ Erreur HTTP ${response.statusCode}: ${response.body}');
    }
  } catch (e) {
    print('❌ Error loading notifications: $e');
  }
}

  Future<void> _updateTableStatus(int tableId, bool isAvailable) async {
    try {
      final auth = context.read<AuthProvider>();
      final token = auth.token;
      
      if (token == null) return;
      
      print('🔄 Mise à jour table $tableId -> is_available=$isAvailable');
      
      final response = await http.put(
        Uri.parse('${AuthProvider.baseUrl}/tables/$tableId/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({'is_available': isAvailable}),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        setState(() {
          final index = _tables.indexWhere((t) => t['id'] == tableId);
          if (index != -1) {
            _tables[index]['is_available'] = isAvailable;
            _availableTablesCount = _tables.where((t) => t['is_available'] == true).length;
            _occupiedTablesCount = _tables.where((t) => t['is_available'] == false).length;
          }
        });
        
        await _loadTables();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isAvailable ? '✓ Table libérée' : '✓ Table occupée'),
              backgroundColor: isAvailable ? _successColor : _warningColor,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Exception: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de connexion: $e'),
            backgroundColor: _errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _confirmReservationWithTable(Map<String, dynamic> reservation) async {
    final freeTables = _tables.where((t) => t['is_available'] == true).toList();
    
    if (freeTables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune table libre disponible pour cette réservation'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _selectedTableIdForReservation = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateBottomSheet) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.6,
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
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Choisir une table',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(color: Colors.white24),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: freeTables.length,
                    itemBuilder: (context, index) {
                      final table = freeTables[index];
                      final isSelected = _selectedTableIdForReservation == table['id'];
                      return GestureDetector(
                        onTap: () {
                          setStateBottomSheet(() {
                            _selectedTableIdForReservation = table['id'];
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? _primaryColor.withValues(alpha: 0.2)
                                : _surfaceContainer,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected 
                                  ? _primaryColor 
                                  : Colors.white.withValues(alpha: 0.1),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: _successColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.table_restaurant,
                                  color: _successColor,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      table['name'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      'Capacité: ${table['capacity']} personnes',
                                      style: TextStyle(
                                        color: _onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle,
                                  color: _successColor,
                                  size: 24,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: _errorColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text('Annuler', style: TextStyle(color: _errorColor)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _selectedTableIdForReservation == null
                              ? null
                              : () async {
                                  Navigator.pop(context);
                                  await _sendConfirmationWithTable(
                                    reservation, 
                                    _selectedTableIdForReservation!
                                  );
                                  _selectedTableIdForReservation = null;
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _successColor,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Confirmer'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _sendConfirmationWithTable(Map<String, dynamic> reservation, int tableId) async {
    try {
      final auth = context.read<AuthProvider>();
      final token = auth.token;
      
      if (token == null) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _surfaceContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Confirmation en cours...'),
              ],
            ),
          ),
        ),
      );
      
      final response = await http.post(
        Uri.parse('${AuthProvider.baseUrl}/reservations/${reservation['id']}/confirm-with-table'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'table_id': tableId,
          'reservation_date': reservation['reservation_date'],
          'reservation_time': reservation['reservation_time'],
          'customer_email': reservation['email'] ?? '',
          'customer_name': reservation['name'] ?? 'Client',
        }),
      ).timeout(const Duration(seconds: 30));
      
      if (mounted) Navigator.pop(context);
      
      if (response.statusCode == 200) {
        await _updateTableStatus(tableId, false);
        await _loadReservations();
        await _loadTables();
        
        if (mounted) {
          final tableName = _getTableName(tableId);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Réservation confirmée et table $tableName assignée ! Un email a été envoyé au client.'),
              backgroundColor: _successColor,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        final errorData = json.decode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: ${errorData['error']}'),
              backgroundColor: _errorColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint('Error confirming reservation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de connexion: $e'),
            backgroundColor: _errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _getTableName(int tableId) {
    final table = _tables.firstWhere((t) => t['id'] == tableId, orElse: () => {});
    return table['name'] ?? 'Table $tableId';
  }

  Future<void> _updateReservationStatus(int id, String status) async {
    try {
      final auth = context.read<AuthProvider>();
      final token = auth.token;
      
      if (token == null) return;
      
      final response = await http.put(
        Uri.parse('${AuthProvider.baseUrl}/serveur/reservations/$id/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({'status': status}),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        await _loadReservations();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(status == 'confirmed' ? '✅ Réservation confirmée !' : '❌ Réservation rejetée'),
              backgroundColor: status == 'confirmed' ? _successColor : _errorColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating reservation: $e');
    }
  }

  Future<void> _markOrderAsDelivered(String orderId) async {
  try {
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    
    if (token == null) return;
    
    print('🔄 Marquage commande $orderId comme terminée...');
    
    final response = await http.patch(
      Uri.parse('${AuthProvider.baseUrl}/orders/$orderId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/merge-patch+json',
        'ngrok-skip-browser-warning': 'true',
        'Accept': 'application/json',
      },
      body: json.encode({'status': 'completed'}),
    ).timeout(const Duration(seconds: 30));
    
    print('📥 Response status: ${response.statusCode}');
    print('📥 Response body: ${response.body}');
    
    if (response.statusCode == 200) {
      // Recharger les commandes
      await _loadOrders();
      await _loadNotifications();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Commande marquée comme terminée !'),
            backgroundColor: Color(0xFF2ECC71),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      // Afficher l'erreur détaillée
      String errorMsg = 'Erreur ${response.statusCode}';
      try {
        final errorData = json.decode(response.body);
        errorMsg = errorData['error'] ?? errorData['message'] ?? errorMsg;
      } catch (_) {}
      
      print('❌ Erreur: $errorMsg');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $errorMsg'),
            backgroundColor: _errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  } catch (e) {
    print('❌ Exception: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de connexion: $e'),
          backgroundColor: _errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

  Future<void> _logout() async {
    final auth = context.read<AuthProvider>();
    await auth.logout();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final userName = auth.user?.name ?? auth.user?.email?.split('@')[0] ?? 'Server';
    final userPhoto = auth.user?.photoUrl;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(
                  'https://images.pexels.com/photos/260922/pexels-photo-260922.jpeg?auto=compress&cs=tinysrgb&w=1920&h=1080&dpr=2',
                ),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.6),
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
                  _surfaceColor.withValues(alpha: 0.8),
                  _surfaceColor,
                ],
                stops: const [0.0, 0.4, 0.8],
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              color: Colors.transparent,
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: Column(
                children: [
                  _buildHeader(userName, userPhoto, auth),
                  _buildStatsRow(),
                  const SizedBox(height: 20),
                  _buildTabSelector(),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _isLoading
                        ? _buildLoadingIndicator()
                        : IndexedStack(
                            index: _selectedTab,
                            children: [
                              _buildActiveOrdersList(),
                              _buildReservationsList(),
                              _buildTablesManagementView(),
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

  Widget _buildHeader(String userName, String? userPhoto, AuthProvider auth) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _primaryColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_primaryColor, _secondaryColor]),
                shape: BoxShape.circle,
                border: Border.all(color: _primaryColor, width: 2),
              ),
              child: ClipOval(
                child: userPhoto != null && userPhoto.isNotEmpty
                    ? Image.network(userPhoto, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white))
                    : const Icon(Icons.person, color: Colors.white, size: 28),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SERVER DASHBOARD',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 2, color: Colors.white70),
                ),
                Text('Welcome back, $userName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ),
          Stack(
            children: [
              IconButton(icon: Icon(Icons.notifications_none, color: _primaryColor, size: 28), onPressed: _showNotificationsDialog),
              if (_notificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text('$_notificationCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          IconButton(icon: Icon(Icons.refresh, color: _primaryColor, size: 28), onPressed: _loadAllData),
          IconButton(icon: Icon(Icons.logout, color: _errorColor, size: 28), onPressed: _logout),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildStatCard('Active', _activeOrdersCount, _warningColor, Icons.receipt_long),
          const SizedBox(width: 12),
          _buildStatCard('Completed', _completedOrdersCount, _successColor, Icons.check_circle),
          const SizedBox(width: 12),
          _buildStatCard('Pending', _pendingReservationsCount, _warningColor, Icons.hourglass_empty),
          const SizedBox(width: 12),
          _buildStatCard('Confirmed', _confirmedReservationsCount, _primaryColor, Icons.event_available),
          const SizedBox(width: 12),
          _buildStatCard('Free', _availableTablesCount, _successColor, Icons.table_restaurant),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_surfaceContainer.withValues(alpha: 0.8), _surfaceContainer.withValues(alpha: 0.5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(count.toString(), style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(color: _onSurfaceVariant, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _surfaceContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: _primaryColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          _buildTabButton('Orders', 0, Icons.receipt_long),
          _buildTabButton('Reservations', 1, Icons.event_seat),
          _buildTabButton('Tables', 2, Icons.table_restaurant),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index, IconData icon) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isSelected ? LinearGradient(colors: [_primaryColor, _primaryColor.withValues(alpha: 0.8)]) : null,
            borderRadius: BorderRadius.circular(36),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? Colors.black : _onSurfaceVariant, size: 18),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: isSelected ? Colors.black : _onSurfaceVariant, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _surfaceContainer.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _primaryColor.withValues(alpha: 0.3)),
            ),
            child: const CircularProgressIndicator(strokeWidth: 3, color: Color(0xFFDF8EFF)),
          ),
          const SizedBox(height: 16),
          Text('Loading dashboard...', style: TextStyle(color: _onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildActiveOrdersList() {
    if (_activeOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_outlined, size: 64, color: _onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No active orders', style: TextStyle(color: _onSurfaceVariant)),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _activeOrders.length,
      itemBuilder: (context, index) => _buildOrderCard(_activeOrders[index]),
    );
  }

  Widget _buildOrderCard(dynamic order) {
    final orderId = order['id']?.toString() ?? '?';
    final total = (order['total'] as num?)?.toDouble() ?? 0.0;
    final items = order['orderItems'] ?? [];
    final rawStatus = order['rawStatus'] ?? order['status'] ?? 'pending';
    
    String statusText = '';
    Color statusColor = _warningColor;
    
    switch (rawStatus.toLowerCase()) {
      case 'pending':
        statusText = 'EN ATTENTE';
        statusColor = _warningColor;
        break;
      case 'paid':
        statusText = 'PAYÉE';
        statusColor = _primaryColor;
        break;
      case 'preparing':
        statusText = 'EN PRÉPARATION';
        statusColor = Colors.orange;
        break;
      case 'ready':
        statusText = 'PRÊTE';
        statusColor = _successColor;
        break;
      default:
        statusText = rawStatus.toUpperCase();
        statusColor = _warningColor;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_surfaceContainer.withValues(alpha: 0.8), _surfaceContainer.withValues(alpha: 0.5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.receipt_long, color: statusColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Order #$orderId', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      Text('Total: ${total.toStringAsFixed(2)} DT', style: TextStyle(color: _onSurfaceVariant)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isNotEmpty) ...[
              ...items.take(2).map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item['name'] ?? 'Item', style: const TextStyle(color: Colors.white70))),
                    Text('x${item['quantity'] ?? 1}', style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              )),
              if (items.length > 2)
                Text('+ ${items.length - 2} autres articles', style: TextStyle(color: _onSurfaceVariant, fontSize: 11)),
            ],
            const SizedBox(height: 12),
            if (rawStatus.toLowerCase() == 'ready')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _markOrderAsDelivered(orderId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _successColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Mark as Delivered', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReservationsList() {
    final pending = _reservations.where((r) => r['status'] == 'pending').toList();
    
    if (pending.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: _onSurfaceVariant),
            const SizedBox(height: 16),
            Text('No pending reservations', style: TextStyle(color: _onSurfaceVariant)),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pending.length,
      itemBuilder: (context, index) => _buildReservationCard(pending[index]),
    );
  }

  Widget _buildReservationCard(Map<String, dynamic> reservation) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_surfaceContainer.withValues(alpha: 0.8), _surfaceContainer.withValues(alpha: 0.5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _warningColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: _warningColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                  child: Icon(Icons.person, color: _warningColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(reservation['name'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      Text(reservation['email'] ?? 'No email', style: TextStyle(color: _onSurfaceVariant)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: _warningColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: const Text('PENDING', style: TextStyle(color: Color(0xFFF39C12), fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(color: _surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        Icon(Icons.calendar_today, color: _primaryColor, size: 16),
                        const SizedBox(height: 4),
                        Text(_formatDate(reservation['reservation_date']), style: const TextStyle(color: Colors.white, fontSize: 12)),
                        const Text('Date', style: TextStyle(color: Color(0xFFACAAAE), fontSize: 10)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(color: _surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        Icon(Icons.access_time, color: _primaryColor, size: 16),
                        const SizedBox(height: 4),
                        Text(reservation['reservation_time'] ?? '--:--', style: const TextStyle(color: Colors.white, fontSize: 12)),
                        const Text('Time', style: TextStyle(color: Color(0xFFACAAAE), fontSize: 10)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(color: _surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        Icon(Icons.people, color: _primaryColor, size: 16),
                        const SizedBox(height: 4),
                        Text('${reservation['people'] ?? 1}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                        const Text('Guests', style: TextStyle(color: Color(0xFFACAAAE), fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _updateReservationStatus(reservation['id'], 'rejected'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _errorColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text('Reject', style: TextStyle(color: _errorColor)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _confirmReservationWithTable(reservation),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _successColor,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Confirm'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTablesManagementView() {
    if (_tables.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFFDF8EFF)),
            const SizedBox(height: 16),
            Text('Loading tables...', style: TextStyle(color: _onSurfaceVariant)),
          ],
        ),
      );
    }
    
    final available = _tables.where((t) => t['is_available'] == true).toList();
    final occupied = _tables.where((t) => t['is_available'] == false).toList();
    
    return RefreshIndicator(
      onRefresh: _loadTables,
      color: _primaryColor,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: _successColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.table_restaurant, color: _successColor, size: 18),
                      const SizedBox(width: 8),
                      Text('FREE TABLES (${available.length})', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _successColor, letterSpacing: 1)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (available.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: _surfaceContainer.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(20), border: Border.all(color: _successColor.withValues(alpha: 0.2))),
                    child: Column(
                      children: [
                        Icon(Icons.table_restaurant_outlined, color: _onSurfaceVariant, size: 48),
                        const SizedBox(height: 8),
                        Text('No free tables', style: TextStyle(color: _onSurfaceVariant)),
                      ],
                    ),
                  )
                else
                  ...available.map((table) => _buildTableCard(table)),
              ],
            ),
          ),
          if (occupied.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: _errorColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.table_restaurant, color: _errorColor, size: 18),
                        const SizedBox(width: 8),
                        Text('OCCUPIED TABLES (${occupied.length})', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _errorColor, letterSpacing: 1)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...occupied.map((table) => _buildTableCard(table)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTableCard(Map<String, dynamic> table) {
    final isAvailable = table['is_available'] == true;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_surfaceContainer.withValues(alpha: 0.8), _surfaceContainer.withValues(alpha: 0.5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isAvailable ? _successColor.withValues(alpha: 0.3) : _errorColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _updateTableStatus(table['id'], !isAvailable),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isAvailable ? [_successColor, _successColor.withValues(alpha: 0.7)] : [_errorColor, _errorColor.withValues(alpha: 0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: (isAvailable ? _successColor : _errorColor).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Icon(Icons.table_restaurant, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(table['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.people_outline, color: _onSurfaceVariant, size: 14),
                          const SizedBox(width: 4),
                          Text('Capacity: ${table['capacity']} persons', style: TextStyle(color: _onSurfaceVariant, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: isAvailable ? _successColor.withValues(alpha: 0.15) : _errorColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                  child: Text(isAvailable ? 'FREE' : 'OCCUPIED', style: TextStyle(color: isAvailable ? _successColor : _errorColor, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: (isAvailable ? _errorColor : _successColor).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                  child: Icon(isAvailable ? Icons.lock_open : Icons.lock, color: isAvailable ? _errorColor : _successColor, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showNotificationsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(color: _surfaceColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(
          children: [
            Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(gradient: LinearGradient(colors: [_primaryColor, _secondaryColor]), borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.notifications, color: Colors.black, size: 24)),
                  const SizedBox(width: 16),
                  const Text('Notifications', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Expanded(
              child: _notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off, size: 80, color: _onSurfaceVariant),
                          const SizedBox(height: 16),
                          Text('No notifications', style: TextStyle(color: _onSurfaceVariant)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final n = _notifications[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: _surfaceContainer, borderRadius: BorderRadius.circular(16), border: Border.all(color: _primaryColor.withValues(alpha: 0.2))),
                          child: Row(
                            children: [
                              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.info_outline, color: _primaryColor, size: 20)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(n['title'] ?? 'Notification', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                    Text(n['message'] ?? '', style: TextStyle(color: _onSurfaceVariant, fontSize: 12)),
                                  ],
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
                  style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                  child: const Text('Close'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}