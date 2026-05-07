import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ReceiptScreen extends StatefulWidget {
  final int orderId;
  final double totalAmount;
  final int tableNumber;
  final List<Map<String, dynamic>> items;
  final String paymentMethod;
  final DateTime orderDate;
  final double deliveryFee;

  const ReceiptScreen({
    super.key,
    required this.orderId,
    required this.totalAmount,
    required this.tableNumber,
    required this.items,
    required this.paymentMethod,
    required this.orderDate,
    this.deliveryFee = 0,
  });

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  bool _isSharing = false;

  double get _subtotal {
    if (widget.deliveryFee > 0) {
      return widget.totalAmount - widget.deliveryFee;
    }
    return widget.totalAmount;
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(2)} DT';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _generateReceiptText() {
    final buffer = StringBuffer();
    
    buffer.writeln('=' * 50);
    buffer.writeln('              NOCTURNE RESTAURANT');
    buffer.writeln('=' * 50);
    buffer.writeln('        123 Avenue de la Liberté, Tunis');
    buffer.writeln('              Tel: +216 XX XXX XXX');
    buffer.writeln('=' * 50);
    buffer.writeln();
    buffer.writeln('ORDER RECEIPT');
    buffer.writeln('-' * 50);
    buffer.writeln('Order #: ${widget.orderId.toString().padLeft(6, '0')}');
    buffer.writeln('Date: ${_formatDate(widget.orderDate)}');
    buffer.writeln('Table: ${widget.tableNumber}');
    buffer.writeln('Payment: ${widget.paymentMethod}');
    buffer.writeln('-' * 50);
    buffer.writeln();
    buffer.writeln('ITEMS');
    buffer.writeln('-' * 50);
    
    for (var item in widget.items) {
      final itemTotal = item['price'] * item['quantity'];
      buffer.writeln('${item['name']} x${item['quantity']}');
      buffer.writeln('  ${itemTotal.toStringAsFixed(2)} DT');
      buffer.writeln();
    }
    
    buffer.writeln('-' * 50);
    buffer.writeln('Subtotal: ${_formatCurrency(_subtotal)}');
    
    if (widget.deliveryFee > 0) {
      buffer.writeln('Delivery Fee: ${_formatCurrency(widget.deliveryFee)}');
    }
    
    buffer.writeln('=' * 50);
    buffer.writeln('TOTAL: ${_formatCurrency(widget.totalAmount)}');
    buffer.writeln('=' * 50);
    buffer.writeln();
    buffer.writeln('Thank you for your order!');
    buffer.writeln('We hope to see you again soon at NOCTURNE');
    buffer.writeln();
    buffer.writeln('--- Keep this receipt ---');
    
    return buffer.toString();
  }

  Future<void> _shareReceipt() async {
    setState(() {
      _isSharing = true;
    });

    try {
      final receiptText = _generateReceiptText();
      
      // Save to temporary file
      final directory = await getTemporaryDirectory();
      final fileName = 'receipt_${widget.orderId}_${DateTime.now().millisecondsSinceEpoch}.txt';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsString(receiptText);

      // Share the file
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'NOCTURNE Restaurant - Order Receipt #${widget.orderId.toString().padLeft(6, '0')}\nTotal: ${_formatCurrency(widget.totalAmount)}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt shared successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sharing receipt: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing receipt: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Order Receipt'),
        backgroundColor: const Color(0xFFFFB800),
        foregroundColor: Colors.black,
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: _isSharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share),
            onPressed: _isSharing ? null : _shareReceipt,
            tooltip: 'Share Receipt',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Restaurant Header
            Center(
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB800),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'N',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'NOCTURNE RESTAURANT',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '123 Avenue de la Liberté, Tunis',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const Text(
                    'Tel: +216 XX XXX XXX',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            
            const Divider(height: 32, thickness: 1),
            
            // Order Information
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoColumn('Order #', '${widget.orderId.toString().padLeft(6, '0')}'),
                _buildInfoColumn('Date', _formatDate(widget.orderDate)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoColumn('Table', widget.tableNumber.toString()),
                _buildInfoColumn('Payment', widget.paymentMethod),
              ],
            ),
            
            const Divider(height: 32, thickness: 1),
            
            // Items List
            const Text(
              'ITEMS',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFFFFB800),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            ...widget.items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${item['name']} x${item['quantity']}',
                      style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
                    ),
                  ),
                  Text(
                    '${(item['price'] * item['quantity']).toStringAsFixed(2)} DT',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A)),
                  ),
                ],
              ),
            )),
            
            const Divider(height: 32, thickness: 1),
            
            // Price Summary
            _buildPriceRow('Subtotal', _formatCurrency(_subtotal)),
            if (widget.deliveryFee > 0) ...[
              const SizedBox(height: 8),
              _buildPriceRow('Delivery Fee', _formatCurrency(widget.deliveryFee)),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                  bottom: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TOTAL',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFB800),
                    ),
                  ),
                  Text(
                    _formatCurrency(widget.totalAmount),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFB800),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Thank You Message
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB800).withAlpha(26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Text(
                      'Thank you for your order!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'We hope to see you again soon at NOCTURNE',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            Center(
              child: Text(
                '--- Keep this receipt ---',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Back to Home Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB800),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('BACK TO HOME', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
        ),
      ],
    );
  }

  Widget _buildPriceRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A))),
      ],
    );
  }
}