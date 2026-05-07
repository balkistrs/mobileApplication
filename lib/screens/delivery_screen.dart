import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import 'profile_screen.dart';

class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  List<Map<String, dynamic>> _availableOrders = [];
  List<Map<String, dynamic>> _myAcceptedOrders = [];
  List<Map<String, dynamic>> _deliveredOrders = [];
  bool _loading = true;
  bool _loadingLocation = true;
  
  // Tab selection
  int _selectedTab = 0; // 0: Active, 1: Available, 2: History
  
  // Geolocation
  Position? _currentPosition;
  String _currentAddress = 'Waiting for location...';
  String _currentStreet = '';
  StreamSubscription<Position>? _positionStream;
  
  // Statistics
  int _totalDeliveries = 0;
  int _completedDeliveries = 0;
  double _averageDeliveryTime = 0.0;
  
  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // Problem report
  final TextEditingController _problemController = TextEditingController();
  Map<int, String> _orderProblems = {};

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _fetchAllData();
  }

  // ==================== FORMATAGE DU TEMPS ====================
  
  String _formatDeliveryTime(int minutes) {
    if (minutes <= 0) return '0 min';
    
    if (minutes < 60) {
      return '$minutes min';
    } else {
      int hours = minutes ~/ 60;
      int remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '$hours h';
      } else {
        return '$hours h $remainingMinutes min';
      }
    }
  }

  String _formatAverageTime(double minutes) {
    if (minutes <= 0) return '--';
    
    if (minutes < 60) {
      return '${minutes.toStringAsFixed(0)} min';
    } else {
      int hours = (minutes / 60).floor();
      double remainingMinutes = minutes % 60;
      if (remainingMinutes < 1) {
        return '$hours h';
      } else {
        return '$hours h ${remainingMinutes.toStringAsFixed(0)} min';
      }
    }
  }

  // ==================== GEOLOCATION AVEC ADRESSE TEXTE ====================
  
  Future<void> _initializeLocation() async {
    await _getCurrentLocation();
    _startLocationTracking();
  }

  Future<String> _getAddressFromCoordinates(double lat, double lng) async {
    // Utiliser une API gratuite pour obtenir l'adresse en texte
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1'
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'SmartDeliveryApp/1.0'
      }).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['address'] != null) {
          final address = data['address'];
          final List<String> parts = [];
          
          // Récupérer les parties de l'adresse
          if (address['road'] != null) parts.add(address['road']);
          else if (address['street'] != null) parts.add(address['street']);
          
          if (address['suburb'] != null) parts.add(address['suburb']);
          else if (address['neighbourhood'] != null) parts.add(address['neighbourhood']);
          
          if (address['city'] != null) parts.add(address['city']);
          else if (address['town'] != null) parts.add(address['town']);
          else if (address['village'] != null) parts.add(address['village']);
          
          if (address['country'] != null && !parts.contains(address['country'])) {
            parts.add(address['country']);
          }
          
          if (parts.isNotEmpty) {
            return parts.join(', ');
          }
        }
        if (data['display_name'] != null) {
          String displayName = data['display_name'];
          if (displayName.length > 50) {
            displayName = displayName.substring(0, 47) + '...';
          }
          return displayName;
        }
      }
    } catch (e) {
      debugPrint('Nominatim error: $e');
    }
    
    // Fallback: retourner les coordonnées
    return '📍 ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    
    try {
      setState(() => _loadingLocation = true);
      
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _currentAddress = '📍 Please enable GPS';
            _currentStreet = 'GPS off';
            _loadingLocation = false;
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _currentAddress = '🔒 Permission denied';
              _currentStreet = 'No permission';
              _loadingLocation = false;
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _currentAddress = '🚫 Permission permanently denied';
            _currentStreet = 'No permission';
            _loadingLocation = false;
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _currentAddress = '📍 Getting address...';
          _currentStreet = '📍 Loading...';
        });
        
        // Obtenir l'adresse en texte
        final address = await _getAddressFromCoordinates(position.latitude, position.longitude);
        if (mounted) {
          setState(() {
            _currentAddress = address;
            // Extraire une version courte pour l'affichage compact
            if (address.contains(',')) {
              _currentStreet = address.split(',').first;
              if (_currentStreet.length > 25) {
                _currentStreet = '${_currentStreet.substring(0, 22)}...';
              }
            } else {
              _currentStreet = address.length > 25 ? '${address.substring(0, 22)}...' : address;
            }
          });
        }
      }
      _updateDeliveryLocation(position.latitude, position.longitude);
      
    } catch (e) {
      debugPrint('Location error: $e');
      if (mounted) {
        setState(() {
          _currentAddress = '⚠️ Location error';
          _currentStreet = 'Error';
          _loadingLocation = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loadingLocation = false);
      }
    }
  }

  void _startLocationTracking() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 50, // Moins fréquent pour économiser les appels API
    );
    
    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position? position) async {
      if (position != null && mounted) {
        if (mounted) {
          setState(() {
            _currentPosition = position;
          });
          final address = await _getAddressFromCoordinates(position.latitude, position.longitude);
          if (mounted) {
            setState(() {
              _currentAddress = address;
              if (address.contains(',')) {
                _currentStreet = address.split(',').first;
                if (_currentStreet.length > 25) {
                  _currentStreet = '${_currentStreet.substring(0, 22)}...';
                }
              } else {
                _currentStreet = address.length > 25 ? '${address.substring(0, 22)}...' : address;
              }
            });
          }
        }
        _updateDeliveryLocation(position.latitude, position.longitude);
      }
    });
  }

  Future<void> _updateDeliveryLocation(double lat, double lng) async {
    final auth = context.read<AuthProvider>();
    await auth.updateDeliveryLocation(lat, lng);
  }

  // ==================== API CALLS ====================
  
  Future<void> _fetchAllData() async {
    await Future.wait([
      _fetchOrders(),
      _fetchStats(),
      _fetchDeliveredOrders(),
    ]);
  }

  Future<void> _fetchStats() async {
    final auth = context.read<AuthProvider>();
    try {
      final response = await http.get(
        Uri.parse('${AuthProvider.baseUrl}/delivery/stats'),
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'ngrok-skip-browser-warning': 'true',
        },
      );
      
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _totalDeliveries = data['data']['total_deliveries'] ?? 0;
            _completedDeliveries = data['data']['completed_deliveries'] ?? 0;
            _averageDeliveryTime = (data['data']['avg_delivery_time'] ?? 0).toDouble();
          });
        }
      }
    } catch (e) {
      debugPrint('Stats error: $e');
    }
  }

  Future<void> _fetchDeliveredOrders() async {
    final auth = context.read<AuthProvider>();
    try {
      final response = await http.get(
        Uri.parse('${AuthProvider.baseUrl}/delivery/orders?status=completed'),
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 15));
      
      if (mounted && response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> ordersData = data['data'] ?? [];
        setState(() {
          _deliveredOrders = ordersData.map((e) => Map<String, dynamic>.from(e)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching delivered orders: $e');
    }
  }

  Future<void> _fetchOrders() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    if (token == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final response = await http.get(
        Uri.parse('${AuthProvider.baseUrl}/delivery/orders'),
        headers: {
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 15));
      if (mounted && response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> ordersData = data['data'] ?? [];
        final available = <Map<String, dynamic>>[];
        final myAccepted = <Map<String, dynamic>>[];
        
        for (var order in ordersData) {
          final orderMap = Map<String, dynamic>.from(order);
          final deliveryPersonId = orderMap['delivery_person_id'];
          final status = orderMap['status'];
          
          if (status == 'delivered' || status == 'completed') {
            continue;
          }
          
          if (deliveryPersonId == auth.userId) {
            myAccepted.add(orderMap);
          } else if (deliveryPersonId == null) {
            available.add(orderMap);
          }
        }
        
        setState(() {
          _availableOrders = available;
          _myAcceptedOrders = myAccepted;
        });
      }
    } catch (e) {
      debugPrint('Error fetching orders: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _acceptOrder(Map<String, dynamic> order) async {
    final auth = context.read<AuthProvider>();
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delivery_dining, color: Colors.blue, size: 28),
            SizedBox(width: 10),
            Text('Accept Delivery'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Text(
              'Order #${order['id']}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, size: 16),
                      const SizedBox(width: 8),
                      Text(order['customer_name'] ?? 'Customer'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          order['customer_address'] ?? 'Address not specified',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.attach_money, size: 16),
                      const SizedBox(width: 8),
                      Text('${order['total']} DT'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Accept', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    setState(() => _loading = true);
    
    try {
      final response = await http.post(
        Uri.parse('${AuthProvider.baseUrl}/delivery/orders/${order['id']}/accept'),
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200 && mounted) {
        setState(() {
          final orderIndex = _availableOrders.indexWhere((o) => o['id'] == order['id']);
          if (orderIndex != -1) {
            final acceptedOrder = Map<String, dynamic>.from(_availableOrders[orderIndex]);
            _myAcceptedOrders.insert(0, acceptedOrder);
            _availableOrders.removeAt(orderIndex);
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text('Order accepted!'),
              ],
            ),
            backgroundColor: Colors.blue,
          ),
        );
        
        await _fetchOrders();
        await _fetchStats();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reportProblem(Map<String, dynamic> order) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text('Report a Problem'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Text(
              'Order #${order['id']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _problemController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Describe the problem...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _problemController.clear();
              Navigator.pop(ctx, false);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final problemText = _problemController.text.trim();
              if (problemText.isNotEmpty) {
                setState(() {
                  _orderProblems[order['id']] = problemText;
                });
                _problemController.clear();
              }
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Send Report', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (result == true) {
      final problemText = _orderProblems[order['id']] ?? '';
      if (problemText.isNotEmpty) {
        await _sendProblemReport(order['id'], problemText);
      }
    }
  }

  Future<void> _sendProblemReport(int orderId, String problem) async {
    final auth = context.read<AuthProvider>();
    
    setState(() => _loading = true);
    
    try {
      final response = await http.post(
        Uri.parse('${AuthProvider.baseUrl}/delivery/report-problem'),
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'order_id': orderId,
          'problem': problem,
          'delivery_person_id': auth.userId,
        }),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 10),
                  Text('Problem reported!'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _callCustomer(String phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number not available')),
      );
      return;
    }
    
    final url = 'tel:$phoneNumber';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot make call')),
      );
    }
  }

  Future<void> _markAsDelivered(Map<String, dynamic> order) async {
    final auth = context.read<AuthProvider>();
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Text('Confirm Delivery'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Text(
              'Order #${order['id']}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, size: 16),
                      const SizedBox(width: 8),
                      Text(order['customer_name'] ?? 'Customer'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          order['customer_address'] ?? 'Address not specified',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    setState(() => _loading = true);
    
    try {
      final response = await http.post(
        Uri.parse('${AuthProvider.baseUrl}/delivery/orders/${order['id']}/deliver'),
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        final deliveryTime = data['data']['delivery_time_minutes'] ?? 0;
        
        setState(() {
          _myAcceptedOrders.removeWhere((o) => o['id'] == order['id']);
          
          final deliveredOrder = Map<String, dynamic>.from(order);
          deliveredOrder['delivered_at'] = DateTime.now().toIso8601String();
          deliveredOrder['delivery_time_minutes'] = deliveryTime;
          _deliveredOrders.insert(0, deliveredOrder);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Text('Order delivered in ${_formatDeliveryTime(deliveryTime)}!'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
        
        _fetchOrders();
        _fetchStats();
        _fetchDeliveredOrders();
        
      } else {
        throw Exception('Error confirming delivery');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openMap(String address) async {
    if (address == null || address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Address not available')),
      );
      return;
    }
    
    final encodedAddress = Uri.encodeComponent(address);
    final url = 'https://www.google.com/maps/search/?api=1&query=$encodedAddress';
    
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please install Google Maps')),
        );
      }
    }
  }

  // ==================== GETTERS ====================
  
  List<Map<String, dynamic>> get _filteredAvailableOrders {
    if (_searchQuery.isEmpty) return _availableOrders;
    return _availableOrders.where((order) {
      final address = order['customer_address']?.toLowerCase() ?? '';
      final id = order['id'].toString();
      return address.contains(_searchQuery.toLowerCase()) ||
          id.contains(_searchQuery);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredMyOrders {
    if (_searchQuery.isEmpty) return _myAcceptedOrders;
    return _myAcceptedOrders.where((order) {
      final address = order['customer_address']?.toLowerCase() ?? '';
      final id = order['id'].toString();
      return address.contains(_searchQuery.toLowerCase()) ||
          id.contains(_searchQuery);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredHistoryOrders {
    if (_searchQuery.isEmpty) return _deliveredOrders;
    return _deliveredOrders.where((order) {
      final address = order['customer_address']?.toLowerCase() ?? '';
      final id = order['id'].toString();
      return address.contains(_searchQuery.toLowerCase()) ||
          id.contains(_searchQuery);
    }).toList();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _searchController.dispose();
    _problemController.dispose();
    super.dispose();
  }

  // ==================== BUILD ====================
  
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final userName = auth.user?.name?.split(' ').first ?? 'Delivery';
    final currentHour = DateTime.now().hour;
    String greeting;
    
    if (currentHour < 12) {
      greeting = '🌅 Good Morning';
    } else if (currentHour < 18) {
      greeting = '☀️ Good Afternoon';
    } else {
      greeting = '🌙 Good Evening';
    }
    
    String displayAddress = _currentStreet.isNotEmpty ? _currentStreet : _currentAddress;
    if (displayAddress.length > 20) {
      displayAddress = '${displayAddress.substring(0, 17)}...';
    }
    
    String avgTimeText = _averageDeliveryTime > 0 
        ? _formatAverageTime(_averageDeliveryTime)
        : '--';
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Header moderne avec dégradé
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFFD4A017), const Color(0xFFF5A623)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Première ligne: Titre et icônes
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.delivery_dining, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Smart Delivery',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.refresh, color: Colors.white),
                              onPressed: () async {
                                await _fetchAllData();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Data refreshed')),
                                  );
                                }
                              },
                              tooltip: 'Refresh',
                            ),
                            IconButton(
                              icon: const Icon(Icons.person_outline, color: Colors.white),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ProfileScreen()),
                              ),
                              tooltip: 'Profile',
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Deuxième ligne: Position (maintenant en texte)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, size: 16, color: Colors.white.withOpacity(0.9)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _loadingLocation ? 'Loading position...' : _currentAddress,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.9),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!_loadingLocation)
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
                              onPressed: _getCurrentLocation,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Corps principal
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: const NetworkImage(
                    'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=1600',
                  ),
                  fit: BoxFit.cover,
                  opacity: 0.08,
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  
                  // Statistics cards
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildStatCard('🎯', 'Total', '$_totalDeliveries', Colors.blue),
                        const SizedBox(width: 12),
                        _buildStatCard('✅', 'Completed', '$_completedDeliveries', Colors.green),
                        const SizedBox(width: 12),
                        _buildStatCard('⏱️', 'Avg Time', avgTimeText, Colors.orange),
                      ],
                    ),
                  ),
                  
                  // Greeting
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4A017).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(Icons.pedal_bike, color: Color(0xFFD4A017), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$greeting, $userName !',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'You have ${_myAcceptedOrders.length} active delivery${_myAcceptedOrders.length != 1 ? 's' : ''}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // TABS BUTTONS
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildTabButton('📦 Active', 0, _myAcceptedOrders.length),
                        const SizedBox(width: 12),
                        _buildTabButton('🆕 Available', 1, _availableOrders.length),
                        const SizedBox(width: 12),
                        _buildTabButton('📜 History', 2, _deliveredOrders.length),
                      ],
                    ),
                  ),
                  
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: '🔍 Search orders...',
                        prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 18),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        isDense: true,
                      ),
                    ),
                  ),
                  
                  // Content based on selected tab
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _selectedTab == 0
                            ? _myAcceptedOrders.isEmpty
                                ? _buildEmptyState('No active deliveries')
                                : RefreshIndicator(
                                    onRefresh: _fetchOrders,
                                    child: ListView.builder(
                                      padding: const EdgeInsets.all(16),
                                      itemCount: _filteredMyOrders.length,
                                      itemBuilder: (ctx, i) => _buildAcceptedOrderCard(_filteredMyOrders[i]),
                                    ),
                                  )
                            : _selectedTab == 1
                                ? _availableOrders.isEmpty
                                    ? _buildEmptyState('No orders available')
                                    : RefreshIndicator(
                                        onRefresh: _fetchOrders,
                                        child: ListView.builder(
                                          padding: const EdgeInsets.all(16),
                                          itemCount: _filteredAvailableOrders.length,
                                          itemBuilder: (ctx, i) => _buildAvailableOrderCard(_filteredAvailableOrders[i]),
                                        ),
                                      )
                                : _deliveredOrders.isEmpty
                                    ? _buildEmptyState('No delivery history')
                                    : RefreshIndicator(
                                        onRefresh: _fetchDeliveredOrders,
                                        child: ListView.builder(
                                          padding: const EdgeInsets.all(16),
                                          itemCount: _filteredHistoryOrders.length,
                                          itemBuilder: (ctx, i) => _buildHistoryCard(_filteredHistoryOrders[i]),
                                        ),
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

  // ==================== WIDGETS ====================
  
  Widget _buildTabButton(String title, int index, int count) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedTab = index;
          _searchQuery = '';
          _searchController.clear();
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFD4A017) : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: const Color(0xFFD4A017).withOpacity(0.3),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFD4A017).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              count > 0 ? '$title ($count)' : title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isSelected ? Colors.white : const Color(0xFFD4A017),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delivery_dining, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableOrderCard(Map<String, dynamic> order) {
    final items = order['items'] as List? ?? [];
    final total = (order['total'] ?? 0).toDouble();
    final phoneNumber = order['customer_phone']?.toString() ?? '';
    final hasPhone = phoneNumber.isNotEmpty && phoneNumber != 'null' && phoneNumber != '';
    final createdAt = order['created_at'] != null 
        ? DateFormat('HH:mm').format(DateTime.parse(order['created_at']))
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4A017).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shopping_bag, color: Color(0xFFD4A017), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Order #${order['id']}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              createdAt,
                              style: const TextStyle(fontSize: 9, color: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        order['customer_name'] ?? 'Customer',
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Available', style: TextStyle(fontSize: 9, color: Colors.orange)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    order['customer_address'] ?? 'Address not specified',
                    style: TextStyle(color: Colors.grey[700], fontSize: 11),
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            if (hasPhone) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _callCustomer(phoneNumber),
                child: Row(
                  children: [
                    Icon(Icons.phone, size: 12, color: Colors.green[600]),
                    const SizedBox(width: 4),
                    Text(
                      phoneNumber,
                      style: TextStyle(color: Colors.green[600], fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
            if (items.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 2,
                children: items.take(2).map<Widget>((item) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${item['quantity']}× ${item['name']}',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${total.toStringAsFixed(2)} DT',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.green,
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _acceptOrder(order),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Accept', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcceptedOrderCard(Map<String, dynamic> order) {
    final items = order['items'] as List? ?? [];
    final total = (order['total'] ?? 0).toDouble();
    final phoneNumber = order['customer_phone']?.toString() ?? '';
    final hasPhone = phoneNumber.isNotEmpty && phoneNumber != 'null' && phoneNumber != '';
    final hasProblem = _orderProblems.containsKey(order['id']);
    final createdAt = order['created_at'] != null 
        ? DateFormat('HH:mm').format(DateTime.parse(order['created_at']))
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: hasProblem ? Colors.orange[50] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.green.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delivery_dining, color: Colors.green, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Order #${order['id']}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              createdAt,
                              style: const TextStyle(fontSize: 9, color: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        order['customer_name'] ?? 'Customer',
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hourglass_empty, size: 8, color: Colors.green),
                      SizedBox(width: 2),
                      Text('Delivering', style: TextStyle(fontSize: 9, color: Colors.green)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    order['customer_address'] ?? 'Address not specified',
                    style: TextStyle(color: Colors.grey[700], fontSize: 11),
                    maxLines: 2,
                  ),
                ),
              ],
            ),
            if (hasPhone) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.phone, size: 12, color: Colors.green[600]),
                  const SizedBox(width: 4),
                  Text(
                    phoneNumber,
                    style: TextStyle(color: Colors.green[600], fontSize: 11),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    onPressed: () => _callCustomer(phoneNumber),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      minimumSize: const Size(50, 24),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Call', style: TextStyle(fontSize: 10)),
                  ),
                ],
              ),
            ],
            if (items.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 2,
                children: items.take(2).map<Widget>((item) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${item['quantity']}× ${item['name']}',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${total.toStringAsFixed(2)} DT',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.green,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.warning_amber,
                        color: hasProblem ? Colors.orange : Colors.grey[400],
                        size: 18,
                      ),
                      onPressed: () => _reportProblem(order),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 4),
                    ElevatedButton.icon(
                      onPressed: () => _markAsDelivered(order),
                      icon: const Icon(Icons.check_circle, size: 14),
                      label: const Text('Delivered', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            InkWell(
              onTap: () => _openMap(order['customer_address'] ?? ''),
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map, size: 12, color: Colors.blue[400]),
                    const SizedBox(width: 4),
                    Text(
                      'Open in Maps',
                      style: TextStyle(fontSize: 10, color: Colors.blue[400]),
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

  Widget _buildHistoryCard(Map<String, dynamic> order) {
    final total = (order['total'] ?? 0).toDouble();
    final deliveredAt = order['delivered_at'] != null 
        ? DateFormat('dd/MM/yy • HH:mm').format(DateTime.parse(order['delivered_at']))
        : 'Date not recorded';
    final createdAt = order['created_at'] != null
        ? DateFormat('HH:mm').format(DateTime.parse(order['created_at']))
        : '';
    
    String deliveryTime = '';
    if (order['delivery_time_minutes'] != null) {
      final minutes = (order['delivery_time_minutes'] as num).toInt();
      deliveryTime = _formatDeliveryTime(minutes);
    } else if (order['created_at'] != null && order['delivered_at'] != null) {
      try {
        final created = DateTime.parse(order['created_at']);
        final delivered = DateTime.parse(order['delivered_at']);
        final minutes = delivered.difference(created).inMinutes;
        deliveryTime = _formatDeliveryTime(minutes);
      } catch (e) {}
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.check_circle, color: Colors.green, size: 18),
        ),
        title: Row(
          children: [
            Text(
              'Order #${order['id']}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const Spacer(),
            Text(
              createdAt,
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              'Delivered $deliveredAt',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            if (deliveryTime.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.timer, size: 12, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    'Delivery time: $deliveryTime',
                    style: const TextStyle(fontSize: 10, color: Colors.orange),
                  ),
                ],
              ),
            const SizedBox(height: 4),
            Text(
              '${total.toStringAsFixed(2)} DT',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.green),
            ),
          ],
        ),
        trailing: const Icon(Icons.history, color: Colors.grey, size: 16),
        isThreeLine: true,
        dense: true,
      ),
    );
  }
}