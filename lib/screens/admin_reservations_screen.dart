// screens/admin/admin_reservations_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/auth_provider.dart';

class AdminReservationsScreen extends StatefulWidget {
  const AdminReservationsScreen({super.key});

  @override
  State<AdminReservationsScreen> createState() => _AdminReservationsScreenState();
}

class _AdminReservationsScreenState extends State<AdminReservationsScreen> {
  List<Map<String, dynamic>> _reservations = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedFilter = 0; // 0: all, 1: pending, 2: confirmed, 3: expired
  
  final Color _primaryColor = const Color(0xFFFFB800);
  final Color _surfaceContainer = const Color(0xFF19191D);
  final Color _onSurfaceVariant = const Color(0xFFACAAAE);
  final Color _successColor = const Color(0xFF2ECC71);
  final Color _warningColor = const Color(0xFFF39C12);
  final Color _errorColor = const Color(0xFFD73357);

  final List<String> _filters = ['All', 'Pending', 'Confirmed', 'Expired'];

  @override
  void initState() {
    super.initState();
    _loadReservations();
  }

  Future<void> _loadReservations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final auth = context.read<AuthProvider>();
      final token = auth.token;
      
      if (token == null) {
        setState(() {
          _errorMessage = 'Not authenticated. Please login again.';
          _isLoading = false;
        });
        return;
      }
      
      // CORRECTION: Ajouter /api/ dans l'URL
      final url = '${AuthProvider.baseUrl}/api/admin/reservations';
      debugPrint('📅 Loading reservations from: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 15));
      
      debugPrint('📡 Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _reservations = List<Map<String, dynamic>>.from(data['data'] ?? []);
            _isLoading = false;
          });
          debugPrint('✅ Loaded ${_reservations.length} reservations');
        } else {
          setState(() {
            _errorMessage = data['error'] ?? 'Failed to load reservations';
            _isLoading = false;
          });
        }
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
      debugPrint('❌ Error loading reservations: $e');
      setState(() {
        _errorMessage = 'Network error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateReservationStatus(int id, String status) async {
    try {
      final auth = context.read<AuthProvider>();
      final token = auth.token;
      
      if (token == null) {
        _showSnackBar('Authentication error', _errorColor);
        return;
      }
      
      // CORRECTION: Ajouter /api/ dans l'URL
      final url = '${AuthProvider.baseUrl}/api/admin/reservations/$id/status';
      debugPrint('🔄 Updating reservation #$id to status: $status at $url');
      
      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({'status': status}),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _loadReservations();
          _showSnackBar(
            status == 'confirmed' 
              ? 'Reservation confirmed!' 
              : 'Reservation rejected!',
            _successColor
          );
        } else {
          _showSnackBar(data['error'] ?? 'Failed to update', _errorColor);
        }
      } else {
        _showSnackBar('Failed to update (${response.statusCode})', _errorColor);
      }
    } catch (e) {
      debugPrint('❌ Error updating reservation: $e');
      _showSnackBar('Error: ${e.toString()}', _errorColor);
    }
  }

  Future<void> _deleteReservation(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Reservation', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Delete this reservation? This cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        final auth = context.read<AuthProvider>();
        final token = auth.token;
        
        if (token == null) {
          _showSnackBar('Authentication error', _errorColor);
          return;
        }
        
        // CORRECTION: Ajouter /api/ dans l'URL
        final url = '${AuthProvider.baseUrl}/api/admin/reservations/$id';
        debugPrint('🗑️ Deleting reservation #$id at $url');
        
        final response = await http.delete(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'ngrok-skip-browser-warning': 'true',
          },
        ).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200 || response.statusCode == 204) {
          _loadReservations();
          _showSnackBar('Reservation deleted', _successColor);
        } else {
          _showSnackBar('Failed to delete', _errorColor);
        }
      } catch (e) {
        debugPrint('❌ Error deleting reservation: $e');
        _showSnackBar('Error: ${e.toString()}', _errorColor);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredReservations {
    if (_selectedFilter == 0) return _reservations;
    if (_selectedFilter == 1) return _reservations.where((r) => r['status'] == 'pending').toList();
    if (_selectedFilter == 2) return _reservations.where((r) => r['status'] == 'confirmed').toList();
    return _reservations.where((r) => r['status'] == 'expired' || r['status'] == 'rejected').toList();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return 'N/A';
    if (timeStr.length >= 5) {
      return timeStr.substring(0, 5);
    }
    return timeStr;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return _warningColor;
      case 'confirmed': return _successColor;
      case 'expired': return _errorColor;
      case 'rejected': return _errorColor;
      default: return _onSurfaceVariant;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending': return 'Pending';
      case 'confirmed': return 'Confirmed';
      case 'expired': return 'Expired';
      case 'rejected': return 'Rejected';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primaryColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.event_seat_rounded, color: _primaryColor, size: 24),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Reservations Management',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.refresh, color: _primaryColor),
                  onPressed: _loadReservations,
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_filters.length, (index) {
                  final isSelected = _selectedFilter == index;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedFilter = index),
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? _primaryColor : _surfaceContainer,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: isSelected ? Colors.transparent : _onSurfaceVariant.withAlpha(76),
                        ),
                      ),
                      child: Text(
                        _filters[index],
                        style: TextStyle(
                          color: isSelected ? Colors.black : _onSurfaceVariant,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFB800)))
                : _errorMessage != null
                    ? _buildErrorWidget()
                    : _filteredReservations.isEmpty
                        ? _buildEmptyWidget()
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredReservations.length,
                            itemBuilder: (context, index) {
                              final r = _filteredReservations[index];
                              return _buildReservationCard(r);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  int _getFilterCount(int filterIndex) {
    if (filterIndex == 0) return _reservations.length;
    if (filterIndex == 1) return _reservations.where((r) => r['status'] == 'pending').length;
    if (filterIndex == 2) return _reservations.where((r) => r['status'] == 'confirmed').length;
    return _reservations.where((r) => r['status'] == 'expired' || r['status'] == 'rejected').length;
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: _errorColor),
          const SizedBox(height: 16),
          Text(_errorMessage!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadReservations,
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 64, color: _onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            _selectedFilter == 0 ? 'No reservations found' : 'No ${_filters[_selectedFilter].toLowerCase()} reservations',
            style: TextStyle(color: _onSurfaceVariant, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildReservationCard(Map<String, dynamic> reservation) {
    final status = reservation['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _surfaceContainer.withAlpha(153),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withAlpha(76)),
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
                    color: statusColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.person, color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reservation['name'] ?? 'Unknown',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      Text(
                        reservation['email'] ?? 'No email',
                        style: TextStyle(color: _onSurfaceVariant, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withAlpha(76)),
                  ),
                  child: Text(
                    _getStatusText(status),
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildDetailItem(Icons.calendar_today, _formatDate(reservation['reservation_date']), 'Date')),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailItem(Icons.access_time, _formatTime(reservation['reservation_time']), 'Time')),
                const SizedBox(width: 12),
                Expanded(child: _buildDetailItem(Icons.people, '${reservation['people'] ?? 1}', 'Guests')),
              ],
            ),
            if (status == 'pending') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _updateReservationStatus(reservation['id'], 'rejected'),
                      style: OutlinedButton.styleFrom(side: BorderSide(color: _errorColor)),
                      child: Text('Reject', style: TextStyle(color: _errorColor)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _updateReservationStatus(reservation['id'], 'confirmed'),
                      style: ElevatedButton.styleFrom(backgroundColor: _successColor),
                      child: const Text('Confirm'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _deleteReservation(reservation['id']),
                  style: OutlinedButton.styleFrom(side: BorderSide(color: _errorColor)),
                  child: Text('Delete', style: TextStyle(color: _errorColor)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F23),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: _primaryColor, size: 16),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          Text(label, style: TextStyle(color: _onSurfaceVariant, fontSize: 10)),
        ],
      ),
    );
  }
}