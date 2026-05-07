import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/auth_provider.dart';
import '../models/user.dart';

class AdminTeamManagementScreen extends StatefulWidget {
  const AdminTeamManagementScreen({super.key});

  @override
  State<AdminTeamManagementScreen> createState() => _AdminTeamManagementScreenState();
}

class _AdminTeamManagementScreenState extends State<AdminTeamManagementScreen> with SingleTickerProviderStateMixin {
  final Color _primaryColor = const Color(0xFFFFB800);
  final Color _backgroundColor = const Color(0xFF0A0A0F);
  final Color _cardColor = const Color(0xFF14141F);
  
  List<AppUser> _teamMembers = [];
  bool _isLoading = true;
  String? _error;
  String? _selectedTeamMemberId;
  Map<String, dynamic>? _selectedMemberStats;
  
  late TabController _tabController;
  
  final List<String> _roles = ['ROLE_CHEF', 'ROLE_SERVEUR', 'ROLE_DELIVERY'];
  final Map<String, String> _roleIcons = {
    'ROLE_CHEF': '👨‍🍳',
    'ROLE_SERVEUR': '🛎️',
    'ROLE_DELIVERY': '🚚',
  };
  final Map<String, String> _roleNames = {
    'ROLE_CHEF': 'Chef',
    'ROLE_SERVEUR': 'Server',
    'ROLE_DELIVERY': 'Delivery',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTeamMembers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTeamMembers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    final auth = context.read<AuthProvider>();
    
    if (auth.token == null) {
      setState(() {
        _error = 'Not authenticated. Please login again.';
        _isLoading = false;
      });
      return;
    }
    
    try {
      final response = await http.get(
        Uri.parse('${AuthProvider.baseUrl}/api/admin/users'),
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final List<dynamic> usersData = data['data']['users'] ?? [];
          final allUsers = usersData.map((u) => AppUser.fromJson(u)).toList();
          
          setState(() {
            _teamMembers = allUsers.where((u) {
              final roles = u.roles ?? [];
              return roles.any((r) => _roles.contains(r));
            }).toList();
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = data['error'] ?? 'Failed to load team members';
            _isLoading = false;
          });
        }
      } else if (response.statusCode == 401) {
        setState(() {
          _error = 'Session expired. Please login again.';
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Server error: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Connection error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _showTeamMemberStats(AppUser user) async {
    setState(() {
      _selectedTeamMemberId = user.id.toString();
      _selectedMemberStats = null;
    });
    
    final auth = context.read<AuthProvider>();
    
    try {
      final response = await http.get(
        Uri.parse('${AuthProvider.baseUrl}/api/admin/users/${user.id}/stats'),
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _selectedMemberStats = data['data'];
          });
          if (mounted) {
            _showStatsDialog(user, data['data']);
          }
        } else {
          _showSnackBar(data['error'] ?? 'Failed to load stats', Colors.red);
        }
      } else if (response.statusCode == 404) {
        _showSnackBar('Stats endpoint not configured yet', Colors.orange);
        _showSimpleStatsDialog(user);
      } else {
        _showSnackBar('Failed to load stats (${response.statusCode})', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    } finally {
      setState(() {
        _selectedTeamMemberId = null;
      });
    }
  }
  
  void _showSimpleStatsDialog(AppUser user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: _primaryColor.withAlpha(25),
              child: Text(user.name[0].toUpperCase(), style: TextStyle(color: _primaryColor)),
            ),
            const SizedBox(width: 12),
            Text('${user.name}\'s Statistics', style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSimpleStatItem('Role', _roleNames[_getUserRole(user)] ?? 'Unknown', Icons.work),
              const Divider(color: Colors.grey),
              const SizedBox(height: 8),
              Text(
                'Order Statistics',
                style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildSimpleStatItem('Total Orders', 'N/A', Icons.shopping_bag),
              _buildSimpleStatItem('Completed Orders', 'N/A', Icons.check_circle),
              _buildSimpleStatItem('Completion Rate', 'N/A', Icons.percent),
              const SizedBox(height: 12),
              Text(
                'Performance Metrics',
                style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (user.roles?.contains('ROLE_CHEF') ?? false) ...[
                _buildSimpleStatItem('Avg Prep Time', 'N/A', Icons.timer),
                _buildSimpleStatItem('Dishes Prepared', 'N/A', Icons.kitchen),
              ],
              if (user.roles?.contains('ROLE_SERVEUR') ?? false) ...[
                _buildSimpleStatItem('Tables Served', 'N/A', Icons.table_restaurant),
                _buildSimpleStatItem('Avg Service Time', 'N/A', Icons.timer),
                _buildSimpleStatItem('Customer Rating', 'N/A', Icons.star),
              ],
              if (user.roles?.contains('ROLE_DELIVERY') ?? false) ...[
                _buildSimpleStatItem('Total Deliveries', 'N/A', Icons.local_shipping),
                _buildSimpleStatItem('Avg Delivery Time', 'N/A', Icons.timer),
                _buildSimpleStatItem('Delivery Rating', 'N/A', Icons.star),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _buildSimpleStatItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  void _showStatsDialog(AppUser user, Map<String, dynamic> stats) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _primaryColor.withAlpha(51)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _primaryColor.withAlpha(25),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: _primaryColor.withAlpha(25),
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: _primaryColor,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            user.email,
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildStatsCard(
                        title: 'Performance Summary',
                        icon: Icons.assessment,
                        color: Colors.blue,
                        children: [
                          _buildStatItem('Total Orders', stats['total_orders']?.toString() ?? '0'),
                          _buildStatItem('Completed Orders', stats['completed_orders']?.toString() ?? '0'),
                          _buildStatItem('Cancelled Orders', stats['cancelled_orders']?.toString() ?? '0'),
                          _buildStatItem('Success Rate', '${stats['success_rate']?.toStringAsFixed(1) ?? '0'}%'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (user.roles?.contains('ROLE_CHEF') ?? false)
                        _buildStatsCard(
                          title: 'Kitchen Performance',
                          icon: Icons.kitchen,
                          color: Colors.orange,
                          children: [
                            _buildStatItem('Avg Prep Time', '${stats['avg_prep_time']?.toStringAsFixed(1) ?? '0'} min'),
                            _buildStatItem('Dishes Prepared', stats['dishes_prepared']?.toString() ?? '0'),
                            _buildStatItem('On-Time Rate', '${stats['on_time_rate']?.toStringAsFixed(1) ?? '0'}%'),
                          ],
                        ),
                      if (user.roles?.contains('ROLE_SERVEUR') ?? false)
                        _buildStatsCard(
                          title: 'Service Performance',
                          icon: Icons.room_service,
                          color: Colors.green,
                          children: [
                            _buildStatItem('Tables Served', stats['tables_served']?.toString() ?? '0'),
                            _buildStatItem('Avg Service Time', '${stats['avg_service_time']?.toStringAsFixed(1) ?? '0'} min'),
                            _buildStatItem('Customer Rating', '${stats['avg_rating']?.toStringAsFixed(1) ?? '0'} ⭐'),
                          ],
                        ),
                      if (user.roles?.contains('ROLE_DELIVERY') ?? false)
                        _buildStatsCard(
                          title: 'Delivery Performance',
                          icon: Icons.delivery_dining,
                          color: Colors.purple,
                          children: [
                            _buildStatItem('Total Deliveries', stats['total_deliveries']?.toString() ?? '0'),
                            _buildStatItem('Avg Delivery Time', '${stats['avg_delivery_time']?.toStringAsFixed(1) ?? '0'} min'),
                            _buildStatItem('Distance Covered', '${stats['total_distance']?.toStringAsFixed(1) ?? '0'} km'),
                            _buildStatItem('Delivery Rating', '${stats['delivery_rating']?.toStringAsFixed(1) ?? '0'} ⭐'),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatsCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
  
  Widget _buildStatItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _getUserRole(AppUser user) {
    if (user.roles?.contains('ROLE_CHEF') ?? false) return 'ROLE_CHEF';
    if (user.roles?.contains('ROLE_SERVEUR') ?? false) return 'ROLE_SERVEUR';
    if (user.roles?.contains('ROLE_DELIVERY') ?? false) return 'ROLE_DELIVERY';
    return '';
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _addTeamMember(String email, String password, String name, String role) async {
    final auth = context.read<AuthProvider>();
    
    try {
      final response = await http.post(
        Uri.parse('${AuthProvider.baseUrl}/api/admin/users/create'),
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: json.encode({
          'email': email,
          'password': password,
          'name': name,
          'role': role,
        }),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        await _loadTeamMembers();
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _deleteTeamMember(int userId) async {
    final auth = context.read<AuthProvider>();
    
    try {
      final response = await http.delete(
        Uri.parse('${AuthProvider.baseUrl}/api/admin/users/$userId'),
        headers: {
          'Authorization': 'Bearer ${auth.token}',
          'ngrok-skip-browser-warning': 'true',
        },
      );
      
      if (response.statusCode == 200) {
        await _loadTeamMembers();
      }
    } catch (e) {
      // Handle error silently
    }
  }

  void _showAddMemberDialog() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final nameController = TextEditingController();
    String selectedRole = 'ROLE_CHEF';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: _cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primaryColor.withAlpha(51),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.person_add, color: _primaryColor),
                ),
                const SizedBox(width: 12),
                const Text('Add Team Member', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      prefixIcon: Icon(Icons.person_outline, color: _primaryColor),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[800]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _primaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      prefixIcon: Icon(Icons.email_outlined, color: _primaryColor),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[800]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _primaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    style: const TextStyle(color: Colors.white),
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Temporary Password',
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      prefixIcon: Icon(Icons.lock_outline, color: _primaryColor),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[800]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _primaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    style: const TextStyle(color: Colors.white),
                    dropdownColor: _cardColor,
                    decoration: InputDecoration(
                      labelText: 'Role',
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      prefixIcon: Icon(Icons.work_outline, color: _primaryColor),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[800]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _primaryColor),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'ROLE_CHEF', child: Text('👨‍🍳 Chef')),
                      DropdownMenuItem(value: 'ROLE_SERVEUR', child: Text('🛎️ Server')),
                      DropdownMenuItem(value: 'ROLE_DELIVERY', child: Text('🚚 Delivery')),
                    ],
                    onChanged: (value) {
                      setStateDialog(() => selectedRole = value!);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isEmpty || emailController.text.isEmpty || passwordController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
                    return;
                  }
                  Navigator.pop(context);
                  
                  await _addTeamMember(emailController.text, passwordController.text, nameController.text, selectedRole);
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${_roleNames[selectedRole]} added!'), backgroundColor: Colors.green),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Add Member'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(AppUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Team Member', style: TextStyle(color: Colors.white)),
        content: Text('Remove ${user.name} from the team?', style: TextStyle(color: Colors.grey[400])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Remove')),
        ],
      ),
    );
    
    if (confirm == true) {
      await _deleteTeamMember(user.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.name} removed'), backgroundColor: Colors.green),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Team Management'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.person_add_alt_1), onPressed: _showAddMemberDialog),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadTeamMembers),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.restaurant), text: 'Chefs'),
            Tab(icon: Icon(Icons.room_service), text: 'Servers'),
            Tab(icon: Icon(Icons.delivery_dining), text: 'Delivery'),
          ],
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFB800)))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                      const SizedBox(height: 16),
                      Text(_error!, style: TextStyle(color: Colors.grey[400])),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadTeamMembers, style: ElevatedButton.styleFrom(backgroundColor: _primaryColor), child: const Text('Retry')),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: _roles.map((role) => _buildTeamList(role)).toList(),
                ),
    );
  }

  Widget _buildTeamList(String role) {
    final members = _teamMembers.where((u) => u.roles?.contains(role) ?? false).toList();
    final roleIcon = _roleIcons[role] ?? '👤';
    final roleName = _roleNames[role] ?? role;
    
    if (members.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(roleIcon, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('No $roleName members yet', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
            const SizedBox(height: 8),
            Text('Tap + to add a new team member', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: members.length,
      itemBuilder: (context, index) {
        final user = members[index];
        final isLoading = _selectedTeamMemberId == user.id.toString();
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _cardColor.withAlpha(204),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[800]!),
          ),
          child: ListTile(
            leading: CircleAvatar(
              radius: 28,
              backgroundColor: _primaryColor.withAlpha(38),
              child: Text(user.name[0].toUpperCase(), style: TextStyle(color: _primaryColor, fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            title: Text(user.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(user.email, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: _primaryColor.withAlpha(38), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(roleIcon, style: const TextStyle(fontSize: 10)),
                      const SizedBox(width: 4),
                      Text(roleName, style: TextStyle(color: _primaryColor, fontSize: 10, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.bar_chart, color: Colors.blue),
                  onPressed: isLoading ? null : () => _showTeamMemberStats(user),
                  tooltip: 'View Statistics',
                ),
                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => _showDeleteConfirmation(user)),
              ],
            ),
          ),
        );
      },
    );
  }
}