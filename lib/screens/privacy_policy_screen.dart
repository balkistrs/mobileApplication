import 'package:flutter/material.dart';
import 'dart:ui';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E11),
      appBar: AppBar(
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF19191D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0E0E11),
                  const Color(0xFF19191D),
                ],
              ),
            ),
          ),
          
          // Decorative elements
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: const Color(0xFFDF8EFF).withOpacity(0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: const Color(0xFF00EEFC).withOpacity(0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          
          // Content
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Last updated
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDF8EFF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFDF8EFF).withOpacity(0.3),
                    ),
                  ),
                  child: const Text(
                    'Last updated: March 2026',
                    style: TextStyle(
                      color: Color(0xFFDF8EFF),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Introduction
                _buildSection(
                  title: 'Introduction',
                  content: 'Welcome to NOCTURNE ("we," "our," or "us"). We are committed to protecting your personal information and your right to privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our application.',
                ),
                
                const SizedBox(height: 24),
                
                _buildSection(
                  title: 'Information We Collect',
                  content: 'We collect personal information that you voluntarily provide to us when you register for an account, express an interest in obtaining information about us or our products and services, or otherwise contact us.',
                  bulletPoints: [
                    'Personal Data: Name, email address, phone number, and professional role',
                    'Usage Data: Information about how you use our application',
                    'Device Information: Device type, operating system, and unique device identifiers',
                  ],
                ),
                
                const SizedBox(height: 24),
                
                _buildSection(
                  title: 'How We Use Your Information',
                  content: 'We use the information we collect or receive:',
                  bulletPoints: [
                    'To facilitate account creation and authentication',
                    'To send administrative information to you',
                    'To respond to user inquiries and offer support',
                    'To personalize your experience with the concierge service',
                    'To monitor and analyze usage patterns and trends',
                  ],
                ),
                
                const SizedBox(height: 24),
                
                _buildSection(
                  title: 'Data Security',
                  content: 'We have implemented appropriate technical and organizational security measures designed to protect the security of any personal information we process. However, despite our safeguards and efforts to secure your information, no electronic transmission over the Internet or information storage technology can be guaranteed to be 100% secure.',
                ),
                
                const SizedBox(height: 24),
                
                _buildSection(
                  title: 'Your Privacy Rights',
                  content: 'Depending on your location, you may have certain rights regarding your personal information:',
                  bulletPoints: [
                    'Right to access - Request a copy of your personal data',
                    'Right to rectification - Correct inaccurate information',
                    'Right to erasure - Request deletion of your data',
                    'Right to data portability - Receive your data in a structured format',
                    'Right to withdraw consent - At any time',
                  ],
                ),
                
                const SizedBox(height: 24),
                
                _buildSection(
                  title: 'Cookies and Tracking Technologies',
                  content: 'We may use cookies and similar tracking technologies to track activity on our service and store certain information. You can instruct your browser to refuse all cookies or to indicate when a cookie is being sent.',
                ),
                
                const SizedBox(height: 24),
                
                _buildSection(
                  title: 'Contact Us',
                  content: 'If you have questions or comments about this policy, you may contact us at:',
                  bulletPoints: [
                    'Email: privacy@nocturne.com',
                    'Address: 123 Gastronomy Avenue, Paris, France',
                    'Phone: +33 1 23 45 67 89',
                  ],
                ),
                
                const SizedBox(height: 32),
                
                // Acceptance
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDF8EFF).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFDF8EFF).withOpacity(0.2),
                    ),
                  ),
                  child: const Text(
                    'By using NOCTURNE, you acknowledge that you have read and understood this Privacy Policy.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String content,
    List<String>? bulletPoints,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFFDF8EFF),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.8),
            height: 1.5,
          ),
        ),
        if (bulletPoints != null) ...[
          const SizedBox(height: 12),
          ...bulletPoints.map((point) => Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '•',
                  style: TextStyle(
                    color: Color(0xFF00EEFC),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    point,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.7),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ],
    );
  }
}