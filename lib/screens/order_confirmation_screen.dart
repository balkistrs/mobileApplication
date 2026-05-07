import 'package:flutter/material.dart';
import 'dart:ui';

class OrderConfirmationScreen extends StatelessWidget {
  final int orderId;
  final double totalAmount;
  final int tableNumber;
  final String orderNumber;

  const OrderConfirmationScreen({
    super.key, 
    required this.orderId,
    this.totalAmount = 0.0,
    this.tableNumber = 0,
    this.orderNumber = '',
  });

  @override
  Widget build(BuildContext context) {
    // NOCTURNE Colors
    final Color primaryColor = const Color(0xFFDF8EFF);
    final Color secondaryColor = const Color(0xFF00EEFC);
    final Color surfaceColor = const Color(0xFF0E0E11);
    final Color surfaceContainer = const Color(0xFF19191D);
    final Color surfaceContainerHigh = const Color(0xFF1F1F23);
    final Color onSurfaceVariant = const Color(0xFFACAAAE);
    final String displayOrderId = orderNumber.isNotEmpty ? orderNumber : 'NCT-${orderId.toString().padLeft(4, '0')}';

    return Scaffold(
      backgroundColor: surfaceColor,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [surfaceColor, surfaceContainer],
              ),
            ),
          ),
          
          // Ambient light leaks - CORRIGÉ: retiré blurRadius de BoxDecoration
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.2),
                    blurRadius: 120,
                    spreadRadius: 0,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                color: secondaryColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: secondaryColor.withValues(alpha: 0.1),
                    blurRadius: 150,
                    spreadRadius: 0,
                  ),
                ],
              ),
            ),
          ),
          
          // Noise overlay
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: Image.network(
                'https://lh3.googleusercontent.com/aida-public/AB6AXuBi69aOjupVc4mkhMQp8hV3NusPqpSDUEYYBkGvbf1MKydO4t9Iok6OKqroK130BKkHkojn1KItZyKgEKt1x451kIvUjqkOox6ltYYwN_ZCAxfja63ya-QrDf-CDoAt4wwrdKUE2PFMdQ3oTM_PC_yjImxu4LEbOsi2rihXF9BHPr77BPVH6a9KDeVbuJ7Q0YjvuklUcIuZpaef9ZRkSQHFQXE-IuyqzzBVlihrL912nowh80N9fGOlVfQsnTQp2RroGopXbCTXdQzk',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 60),
                    
                    // Success animation
                    TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0.8, end: 1.0),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.elasticOut,
                      builder: (context, double scale, child) {
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.4),
                                  blurRadius: 50,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.black,
                              size: 60,
                            ),
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Title
                    const Text(
                      'Order Confirmed',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your sensory experience is being prepared.',
                      style: TextStyle(
                        color: onSurfaceVariant,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Stats grid
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: surfaceContainer.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: secondaryColor.withValues(alpha: 0.2)),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'ETA',
                                  style: TextStyle(
                                    color: secondaryColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  '25',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'mins',
                                  style: TextStyle(
                                    color: onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: surfaceContainer.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Order ID',
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  displayOrderId,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Chef's selection card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: secondaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.restaurant,
                              color: Color(0xFF00EEFC),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Chef\'s Selection',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Molecular Degustation Set',
                                  style: TextStyle(
                                    color: onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: secondaryColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: secondaryColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: secondaryColor,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'Live',
                                  style: TextStyle(
                                    color: Color(0xFF00EEFC),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Action buttons
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.popUntil(context, (route) => route.isFirst);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'Back to Home',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton(
                        onPressed: () {
                          // View receipt logic
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: onSurfaceVariant.withValues(alpha: 0.3)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'View Digital Receipt',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Map backdrop
                    Container(
                      height: 100,
                      margin: const EdgeInsets.only(bottom: 20),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Opacity(
                          opacity: 0.2,
                          child: Image.network(
                            'https://lh3.googleusercontent.com/aida-public/AB6AXuBRvjk1JcArf02RP1AQLPyGqPB2x9WSTlAwRFwJqLJx1-O3oJTkJOEmR-jSpRXw8vb1R9qZSG-dRjS3SDGL7C-CP9nOQxEahv_ZmuKIyKKVkSv3E41Gw6PhModS7Is7mhWhLf2YPW96EOMMOAIyOvq-EXsHPXufVZsbXM0U-3zAHfGJ7JImt86y3eC5sWa_A7jMuuOVLw9pLYF1rW36mMnIJ_YudWUPZ8aeStsxjmCmW3vDylB1bhgaspa5b3pwts5L9Bs1zgobNpqr',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}