import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/auth_provider.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  int _selectedPeriod = 30;
  String? _connectionError;

  final Color _primaryColor = const Color(0xFFFFB800);
  final Color _errorColor = const Color(0xFFD73357);
  final Color _cardColor = Colors.white.withAlpha(13);
  final Color _cardBorderColor = Colors.white.withAlpha(25);

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _connectionError = null;
    });
    
    try {
      final auth = context.read<AuthProvider>();
      final token = auth.token;
      
      if (token == null) {
        setState(() {
          _connectionError = 'Session expired. Please login again.';
          _isLoading = false;
        });
        return;
      }

      final url = '${AuthProvider.baseUrl}/api/admin/dashboard/stats?days=$_selectedPeriod';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _stats = data['data'];
            _isLoading = false;
          });
        } else {
          setState(() {
            _connectionError = data['error'] ?? 'Failed to load data';
            _isLoading = false;
          });
        }
      } else if (response.statusCode == 401) {
        setState(() {
          _connectionError = 'Session expired. Please login again.';
          _isLoading = false;
        });
      } else {
        setState(() {
          _connectionError = 'Server error: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _connectionError = 'Connection error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFFB800)));
    }

    if (_connectionError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: _errorColor),
            const SizedBox(height: 16),
            Text(_connectionError!, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadStats,
              style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStats,
      color: _primaryColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildPeriodSelector(),
            const SizedBox(height: 16),
            _buildKPIGrid(),
            const SizedBox(height: 16),
            _buildMonthlyRevenueList(),
            const SizedBox(height: 16),
            _buildCustomerRatings(),
            const SizedBox(height: 16),
            _buildTopRatedMenu(),
            const SizedBox(height: 16),
            _buildDeliveryPerformance(),
            const SizedBox(height: 16),
            _buildCustomerReviews(),
            const SizedBox(height: 16),
            _buildDeliveryReports(),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _cardBorderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: _selectedPeriod,
            dropdownColor: const Color(0xFF2A2A2A),
            underline: const SizedBox(),
            style: const TextStyle(color: Colors.white),
            items: const [
              DropdownMenuItem(value: 7, child: Text('7 days')),
              DropdownMenuItem(value: 15, child: Text('15 days')),
              DropdownMenuItem(value: 30, child: Text('30 days')),
              DropdownMenuItem(value: 90, child: Text('90 days')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedPeriod = value);
                _loadStats();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildKPIGrid() {
    final revenue = _stats['revenue'] ?? {};
    final totalOrders = _stats['total_orders'] ?? 0;
    final newUsers = _stats['new_users'] ?? 0;
    final avgOrder = _stats['average_order_value'] ?? 0;
    
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: [
        _buildKPI('Total Revenue', revenue['formatted'] ?? '0 DT', Icons.trending_up, Colors.green),
        _buildKPI('Total Orders', totalOrders.toString(), Icons.shopping_bag, Colors.blue),
        _buildKPI('New Users', newUsers.toString(), Icons.people, Colors.orange),
        _buildKPI('Avg Order', '${avgOrder.toStringAsFixed(2)} DT', Icons.shopping_cart, Colors.purple),
      ],
    );
  }

  Widget _buildKPI(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorderColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(color: Color.fromARGB(255, 255, 255, 255), fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyRevenueList() {
    final monthlyData = _stats['monthly_revenue'] ?? {};
    
    if (monthlyData.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final entries = monthlyData.entries.toList();
    double maxValue = 0;
    for (var entry in entries) {
      if (entry.value > maxValue) {
        maxValue = entry.value;
      }
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primaryColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.trending_up, color: _primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Monthly Revenue',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...entries.map((entry) {
            final percentage = maxValue > 0 ? (entry.value / maxValue) : 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 50,
                    child: Text(
                      _formatMonth(entry.key.toString()),
                      style: const TextStyle(color: Color.fromARGB(255, 255, 255, 255), fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.grey[800]!.withAlpha(128),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: FractionallySizedBox(
                        widthFactor: percentage,
                        child: Container(
                          decoration: BoxDecoration(
                            color: _primaryColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 80,
                    child: Text(
                      '${entry.value.toStringAsFixed(0)} DT',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  String _formatMonth(String monthStr) {
    try {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      if (monthStr.length >= 7) {
        final monthNum = int.parse(monthStr.substring(5, 7));
        return months[monthNum - 1];
      }
      return monthStr;
    } catch (e) {
      return monthStr;
    }
  }

  Widget _buildCustomerRatings() {
    final ratings = _stats['customer_ratings'] ?? {};
    
    if (ratings.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.star, color: Colors.amber, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Customer Ratings',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildRating('5 ⭐', ratings['5_star'] ?? 0, Colors.green),
              _buildRating('4 ⭐', ratings['4_star'] ?? 0, Colors.lightGreen),
              _buildRating('3 ⭐', ratings['3_star'] ?? 0, Colors.orange),
              _buildRating('2 ⭐', ratings['2_star'] ?? 0, Colors.deepOrange),
              _buildRating('1 ⭐', ratings['1_star'] ?? 0, Colors.red),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: (ratings['average'] ?? 0) / 5,
            backgroundColor: Colors.grey[800]!.withAlpha(128),
            color: Colors.amber,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Average: ${(ratings['average'] ?? 0).toStringAsFixed(1)} / 5.0',
              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRating(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(color: Color.fromARGB(255, 255, 255, 255), fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildTopRatedMenu() {
    final topMenu = _stats['top_rated_menu'] ?? [];
    
    if (topMenu.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.restaurant_menu, color: Colors.green, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Top Rated Menu Items',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...topMenu.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item['name'] ?? 'Unknown',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      item['rating']?.toStringAsFixed(1) ?? '0',
                      style: const TextStyle(color: Colors.amber),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${item['total_orders'] ?? 0} orders',
                    style: const TextStyle(color: Colors.green, fontSize: 10),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildDeliveryPerformance() {
    final delivery = _stats['delivery_performance'] ?? {};
    
    if (delivery.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delivery_dining, color: Colors.purple, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Delivery Performance',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _buildDeliveryMetric('Avg Time', '${delivery['avg_time']?.toStringAsFixed(0) ?? 0} min', Icons.timer, Colors.orange),
              _buildDeliveryMetric('On-Time Rate', '${delivery['on_time_rate']?.toStringAsFixed(1) ?? 0}%', Icons.check_circle, Colors.green),
              _buildDeliveryMetric('Total', delivery['total']?.toString() ?? '0', Icons.local_shipping, Colors.blue),
              _buildDeliveryMetric('Rating', '${delivery['avg_rating']?.toStringAsFixed(1) ?? 0} ⭐', Icons.star, Colors.amber),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryMetric(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(51),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: const TextStyle(color: Color.fromARGB(255, 255, 255, 255), fontSize: 10),
          ),
        ],
      ),
    );
  }

  // Widget pour afficher les commentaires des clients
  Widget _buildCustomerReviews() {
    final reviews = _stats['customer_reviews'] ?? [];
    
    if (reviews.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.comment, color: Colors.blue, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Customer Reviews',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...reviews.take(5).map((review) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(51),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.amber.withAlpha(51),
                        child: Text(
                          (review['user_name'] ?? '?')[0].toUpperCase(),
                          style: const TextStyle(color: Colors.amber, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          review['user_name'] ?? 'Anonymous',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            review['rating']?.toString() ?? '0',
                            style: const TextStyle(color: Colors.amber, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    review['comment'] ?? '',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    review['product_name'] ?? '',
                    style: TextStyle(color: Colors.grey[600], fontSize: 10),
                  ),
                ],
              ),
            ),
          )),
        ],
      ),
    );
  }

  // Widget pour afficher les rapports des livreurs
  Widget _buildDeliveryReports() {
    final deliveryReports = _stats['delivery_reports'] ?? [];
    
    if (deliveryReports.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.pedal_bike, color: Colors.deepPurple, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Delivery Personnel Reports',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...deliveryReports.map((report) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(51),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.deepPurple.withAlpha(51),
                      child: Text(
                        (report['delivery_person_name'] ?? '?')[0].toUpperCase(),
                        style: const TextStyle(color: Colors.deepPurple, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        report['delivery_person_name'] ?? 'Unknown',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${report['success_rate'] ?? 0}%',
                        style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildReportMetric(
                        'Deliveries', 
                        (report['total_deliveries'] ?? 0).toString(),
                        Icons.local_shipping,
                        Colors.blue
                      ),
                    ),
                    Expanded(
                      child: _buildReportMetric(
                        'Completed', 
                        (report['completed_deliveries'] ?? 0).toString(),
                        Icons.check_circle,
                        Colors.green
                      ),
                    ),
                    Expanded(
                      child: _buildReportMetric(
                        'Avg Time', 
                        '${report['avg_delivery_time'] ?? 0} min',
                        Icons.timer,
                        Colors.orange
                      ),
                    ),
                    Expanded(
                      child: _buildReportMetric(
                        'Rating', 
                        '${report['avg_rating'] ?? 0} ⭐',
                        Icons.star,
                        Colors.amber
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildReportMetric(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(color: Color.fromARGB(255, 255, 255, 255), fontSize: 8),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}