import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/auth_provider.dart';

class OrderTrackingScreen extends StatefulWidget {
  final bool showOnlyPaidOrders;
  
  const OrderTrackingScreen({
    Key? key,
    this.showOnlyPaidOrders = false,
  }) : super(key: key);

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Getter to return ALL orders without filtering
  List<Map<String, dynamic>> get _filteredOrders {
    return _orders;
  }

  Future<void> _loadUserOrders() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final token = auth.token;

      if (token == null) {
        setState(() {
          _errorMessage = 'Non authentifié';
          _isLoading = false;
        });
        return;
      }

      debugPrint('🔄 Chargement des commandes avec token: ${token.substring(0, min(20, token.length))}...');
      
      final response = await http.get(
        Uri.parse('${AuthProvider.baseUrl}/orders?user=me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'ngrok-skip-browser-warning': 'true',
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Délai d\'attente dépassé. Veuillez vérifier votre connexion.'),
      );

      debugPrint('📩 Response status: ${response.statusCode}');
      debugPrint('📩 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        
        List<dynamic> ordersList = [];
        
        // Gérer différents formats de réponse
        if (data is List) {
          ordersList = data;
        } else if (data is Map && data['success'] == true) {
          ordersList = data['data']?['orders'] ?? data['orders'] ?? [];
        } else if (data is Map && data['data'] is List) {
          ordersList = data['data'];
        } else if (data is Map && data['orders'] is List) {
          ordersList = data['orders'];
        }
        
        debugPrint('📊 Total commandes reçues: ${ordersList.length}');
        
        // Normaliser les données
        final normalizedOrders = ordersList.map((order) {
          Map<String, dynamic> orderMap = order is Map<String, dynamic> 
              ? order 
              : Map<String, dynamic>.from(order);
          
          if (!orderMap.containsKey('createdAt') && orderMap.containsKey('created_at')) {
            orderMap['createdAt'] = orderMap['created_at'];
          }
          
          if (!orderMap.containsKey('orderItems')) {
            orderMap['orderItems'] = [];
          }
          
          return orderMap;
        }).toList();
        
        // Filtrer pour ne garder que les commandes de l'utilisateur 80 (vous)
        final userOrders = normalizedOrders.where((order) {
          final userStr = order['user']?.toString() ?? '';
          return userStr.contains('/api/users/80');
        }).toList();
        
        debugPrint('📊 Commandes après filtre (user 80): ${userOrders.length}');
        
        setState(() {
          _orders = List<Map<String, dynamic>>.from(userOrders);
          _isLoading = false;
        });
        
        debugPrint('✅ ${_orders.length} commandes chargées avec succès');
      } else if (response.statusCode == 401) {
        setState(() {
          _errorMessage = 'Session expirée. Veuillez vous reconnecter.';
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Erreur serveur: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur: $e');
      setState(() {
        _errorMessage = 'Erreur de connexion: ${e.toString()}. Vérifiez votre connexion Internet.';
        _isLoading = false;
      });
    }
  }

  int min(int a, int b) => a < b ? a : b;

  String _getStatusText(String status) {
    switch (status) {
      case 'pending': return 'En attente';
      case 'paid': return 'Payée';
      case 'preparing': return 'En préparation';
      case 'ready': return 'Prête';
      case 'completed': return 'Terminée';
      case 'cancelled': return 'Annulée';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'paid': return Colors.blue;
      case 'preparing': return Colors.amber;
      case 'ready': return Colors.green;
      case 'completed': return Colors.grey;
      case 'cancelled': return Colors.red;
      default: return Colors.white;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending': return Icons.hourglass_empty_rounded;
      case 'paid': return Icons.payment_rounded;
      case 'preparing': return Icons.restaurant_rounded;
      case 'ready': return Icons.check_circle_rounded;
      case 'completed': return Icons.done_all_rounded;
      case 'cancelled': return Icons.cancel_rounded;
      default: return Icons.receipt_rounded;
    }
  }

  String _getEstimatedReadyTime(Map<String, dynamic> order) {
    if (order['status'] == 'completed' || order['status'] == 'ready') {
      return 'Prête';
    }
    
    try {
      String? dateStr = order['createdAt'] ?? order['created_at'];
      if (dateStr == null || dateStr.isEmpty) return '--';
      
      final createdAt = DateTime.parse(dateStr);
      final now = DateTime.now();
      final elapsedMinutes = now.difference(createdAt).inMinutes;
      const estimatedPrepTime = 18;
      final remainingMinutes = estimatedPrepTime - elapsedMinutes;
      
      if (remainingMinutes <= 0) return 'Prête bientôt';
      if (remainingMinutes < 1) return '< 1 min';
      return '~${remainingMinutes} min';
    } catch (e) {
      return '--';
    }
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _OrderDetailsSheet(order: order),
    );
  }

  Widget _build3DText(String text, {double fontSize = 24, Color color = Colors.white, Color shadowColor = Colors.black}) {
    return Stack(
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = shadowColor,
            shadows: const [BoxShadow(blurRadius: 10, offset: Offset(2, 2))],
          ),
        ),
        Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: color,
            shadows: [BoxShadow(blurRadius: 20, color: color)],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            _errorMessage,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final orders = _filteredOrders;
    debugPrint('🔍 Affichage de ${orders.length} commandes');

    return Column(
      children: [
        // Barre de recherche
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Rechercher une commande...',
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

        // Liste des commandes
        Expanded(
          child: orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_rounded,
                        size: 80,
                        color: Colors.white.withOpacity(0.1),
                      ),
                      const SizedBox(height: 16),
                      _build3DText(
                        widget.showOnlyPaidOrders
                            ? 'Aucune commande payée'
                            : 'Aucune commande trouvée',
                        fontSize: 20,
                        color: Colors.amber,
                        shadowColor: Colors.orange,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.showOnlyPaidOrders
                            ? 'Les commandes que vous avez payées apparaîtront ici'
                            : 'Vos commandes apparaîtront ici',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.withOpacity(0.3)),
                        boxShadow: const [
                          BoxShadow(color: Colors.amber, blurRadius: 10, spreadRadius: 2),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showOrderDetails(order),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(order['status'] ?? '').withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              _getStatusIcon(order['status'] ?? ''),
                                              color: _getStatusColor(order['status'] ?? ''),
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                _build3DText(
                                                  'Commande #${order['id'] ?? '?'}',
                                                  fontSize: 16,
                                                  color: Colors.amber,
                                                  shadowColor: Colors.orange,
                                                ),
                                                if (order['createdAt'] != null)
                                                  Text(
                                                    _formatDate(order['createdAt']),
                                                    style: TextStyle(
                                                      color: Colors.white.withOpacity(0.5),
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(order['status'] ?? '').withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: _getStatusColor(order['status'] ?? '')),
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            _getStatusText(order['status'] ?? ''),
                                            style: TextStyle(
                                              color: _getStatusColor(order['status'] ?? ''),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                          // Show vote stars if user has voted
                                          if ((order['status'] == 'completed' || order['status'] == 'livré') && 
                                              Provider.of<AuthProvider>(context, listen: false).user?.vote != null &&
                                              (int.tryParse(Provider.of<AuthProvider>(context, listen: false).user!.vote ?? '0') ?? 0) > 0)
                                            ...[
                                              const SizedBox(width: 8),
                                              Row(
                                                children: List.generate(
                                                  int.tryParse(Provider.of<AuthProvider>(context, listen: false).user!.vote ?? '0') ?? 0,
                                                  (i) => const Padding(
                                                    padding: EdgeInsets.only(right: 2),
                                                    child: Icon(Icons.star_rounded, size: 12, color: Colors.orange),
                                                  ),
                                                ),
                                              ),
                                            ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                
                                // Aperçu des articles
                                if (order['orderItems'] != null && order['orderItems'] is List)
                                  ...(order['orderItems'] as List).take(2).map<Widget>((item) {
                                    final product = item['product'] ?? {};
                                    final itemName = product['name']?.toString() ?? 'Produit inconnu';
                                    final itemQuantity = item['quantity'] ?? 1;
                                    final itemPrice = product['price'] ?? 0.0;
                                    
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.restaurant_menu, size: 14, color: Colors.amber),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '$itemName x$itemQuantity',
                                              style: const TextStyle(color: Colors.white, fontSize: 13),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Text(
                                            '${(itemPrice * itemQuantity).toStringAsFixed(2)} DT',
                                            style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                
                                if ((order['orderItems'] as List?) != null && (order['orderItems'] as List).length > 2)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      '+ ${(order['orderItems'] as List).length - 2} autre(s) article(s)',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                
                                const SizedBox(height: 12),
                                
                                // Temps estimé
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.green.withOpacity(0.5)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.schedule_rounded, size: 16, color: Colors.green),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Prête dans: ',
                                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                                      ),
                                      Text(
                                        _getEstimatedReadyTime(order),
                                        style: const TextStyle(color: Colors.green, fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(height: 12),
                                
                                // Total et actions
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Total',
                                          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                                        ),
                                        Text(
                                          '${(order['total'] ?? 0.0).toStringAsFixed(2)} DT',
                                          style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    
                                    Row(
                                      children: [
                                        // Vote button (only for delivered orders)
                                        if (order['status'] == 'completed' || order['status'] == 'livré')
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.orange.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: IconButton(
                                              icon: const Icon(Icons.star_rate_rounded, color: Colors.orange),
                                              onPressed: () => _showVoteDialog(order),
                                              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                            ),
                                          ),
                                        const SizedBox(width: 8),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: IconButton(
                                            icon: const Icon(Icons.timeline, color: Colors.blue),
                                            onPressed: () => _showTrackingDialog(order),
                                            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }
  void _showVoteDialog(Map<String, dynamic> order) {
    int selectedStars = int.tryParse(Provider.of<AuthProvider>(context, listen: false).user?.vote ?? '0') ?? 0;
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(
            children: [
              const Icon(Icons.star_rounded, color: Colors.orange, size: 40),
              const SizedBox(height: 12),
              const Text(
                'Évaluer votre commande',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 4),
              Text(
                'Commande #${order['id']}',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final isFilled = index < selectedStars;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () => setState(() => selectedStars = index + 1),
                      child: Icon(
                        Icons.star_rounded,
                        size: 48,
                        color: isFilled ? Colors.orange : Colors.white.withOpacity(0.2),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              Text(
                selectedStars > 0 ? '$selectedStars étoile${selectedStars > 1 ? 's' : ''}' : 'Sélectionnez une note',
                style: TextStyle(
                  color: selectedStars > 0 ? Colors.orange : Colors.white.withOpacity(0.5),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: selectedStars > 0
                  ? () async {
                      Navigator.pop(ctx);
                      final auth = Provider.of<AuthProvider>(context, listen: false);
                      final success = await auth.submitVote(selectedStars);
                      
                      if (success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Merci! Vous avez voté $selectedStars étoile${selectedStars > 1 ? 's' : ''}'),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      } else if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Erreur lors de l\'enregistrement du vote'),
                            backgroundColor: Colors.red,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedStars > 0 ? Colors.orange : Colors.white.withOpacity(0.2),
                disabledBackgroundColor: Colors.white.withOpacity(0.2),
              ),
              child: const Text(
                'Valider',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
  void _showTrackingDialog(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Row(
          children: [
            Icon(Icons.timeline, color: Colors.amber),
            const SizedBox(width: 8),
            const Text('Suivi de commande', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTrackingStep(
              'Commande confirmée',
              order['createdAt'] ?? 'Date inconnue',
              order['status'] != 'pending' && order['status'] != 'cancelled',
            ),
            _buildTrackingStep(
              'Paiement reçu',
              'Payée le ${_formatDate(order['createdAt'])}',
              order['status'] == 'paid' || order['status'] == 'preparing' || order['status'] == 'ready' || order['status'] == 'completed',
            ),
            _buildTrackingStep(
              'Préparation en cours',
              'Environ 15-20 min',
              order['status'] == 'preparing' || order['status'] == 'ready' || order['status'] == 'completed',
            ),
            _buildTrackingStep(
              'Prête pour retrait/livraison',
              'Préparation terminée',
              order['status'] == 'ready' || order['status'] == 'completed',
            ),
            _buildTrackingStep(
              'Terminée',
              order['status'] == 'completed' ? _formatDate(order['updatedAt']) : 'En attente',
              order['status'] == 'completed',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingStep(String title, String time, bool isCompleted) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted ? Colors.green : Colors.white.withOpacity(0.1),
            ),
            child: isCompleted ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isCompleted ? Colors.white : Colors.white.withOpacity(0.5),
                    fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                Text(
                  time,
                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Edit Order Bottom Sheet
// Order Details Bottom Sheet
class _OrderDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> order;

  const _OrderDetailsSheet({required this.order});

  String _getStatusText(String status) {
    switch (status) {
      case 'pending': return 'En attente';
      case 'paid': return 'Payée';
      case 'preparing': return 'En préparation';
      case 'ready': return 'Prête';
      case 'completed': return 'Terminée';
      case 'cancelled': return 'Annulée';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'paid': return Colors.blue;
      case 'preparing': return Colors.amber;
      case 'ready': return Colors.green;
      case 'completed': return Colors.grey;
      case 'cancelled': return Colors.red;
      default: return Colors.white;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending': return Icons.hourglass_empty_rounded;
      case 'paid': return Icons.payment_rounded;
      case 'preparing': return Icons.restaurant_rounded;
      case 'ready': return Icons.check_circle_rounded;
      case 'completed': return Icons.done_all_rounded;
      case 'cancelled': return Icons.cancel_rounded;
      default: return Icons.receipt_rounded;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year} à ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Container(
      height: size.height * 0.8,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
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
                    color: _getStatusColor(order['status'] ?? '').withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    _getStatusIcon(order['status'] ?? ''),
                    color: _getStatusColor(order['status'] ?? ''),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Commande #${order['id'] ?? '?'}',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _formatDate(order['createdAt']),
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order['status'] ?? '').withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _getStatusColor(order['status'] ?? '')),
                  ),
                  child: Text(
                    _getStatusText(order['status'] ?? ''),
                    style: TextStyle(color: _getStatusColor(order['status'] ?? ''), fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: (order['orderItems'] as List?)?.length ?? 0,
              itemBuilder: (ctx, index) {
                final items = order['orderItems'] as List;
                final item = items[index];
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.restaurant_menu, color: Colors.amber),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['product']?['name']?.toString() ?? 'Produit inconnu',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${(item['product']?['price'] ?? 0.0).toStringAsFixed(2)} DT',
                              style: const TextStyle(color: Colors.amber, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'x${item['quantity'] ?? 1}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 20),
                      Text(
                        '${((item['product']?['price'] ?? 0.0) * (item['quantity'] ?? 1)).toStringAsFixed(2)} DT',
                        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(
                      '${(order['total'] ?? 0.0).toStringAsFixed(2)} DT',
                      style: const TextStyle(color: Colors.amber, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Divider(height: 30, color: Colors.white24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: const Text('Fermer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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