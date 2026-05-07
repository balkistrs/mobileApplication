import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E11),
      appBar: AppBar(
        title: const Text(
          'Terms of Service',
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
                    color: const Color(0xFF00EEFC).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF00EEFC).withOpacity(0.3),
                    ),
                  ),
                  child: const Text(
                    'Effective: March 2026',
                    style: TextStyle(
                      color: Color(0xFF00EEFC),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                _buildSection(
                  title: 'Agreement to Terms',
                  content: 'By accessing or using NOCTURNE ("the Application"), you agree to be bound by these Terms of Service. If you disagree with any part of the terms, you may not access the Application.',
                ),
                
                const SizedBox(height: 24),
                
                _buildSection(
                  title: 'Description of Service',
                  content: 'NOCTURNE is a smart restaurant concierge application that provides:',
                  bulletPoints: [
                    'Personalized dining recommendations',
                    'Menu curation based on preferences',
                    'Order management and tracking',
                    'Real-time communication with restaurant staff',
                    'Table reservations and waitlist management',
                  ],
                ),
                
                const SizedBox(height: 24),
                
                _buildSection(
                  title: 'User Accounts',
                  content: 'To use certain features, you must create an account. You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account.',
                  bulletPoints: [
                    'You must be at least 18 years old to create an account',
                    'You agree to provide accurate and complete information',
                    'You are responsible for all activity on your account',
                    'We reserve the right to suspend or terminate accounts for violations',
                  ],
                ),
                
                const SizedBox(height: 24),
                
                _buildSection(
                  title: 'User Conduct',
                  content: 'You agree not to use the Application to:',
                  bulletPoints: [
                    'Violate any applicable laws or regulations',
                    'Infringe upon intellectual property rights',
                    'Harass, abuse, or harm other users',
                    'Impersonate any person or entity',
                    'Interfere with or disrupt the Application\'s functionality',
                    'Attempt to gain unauthorized access to the Application',
                  ],
                ),
                
                const SizedBox(height: 24),
                
                _buildSection(
                  title: 'Intellectual Property',
                  content: 'The Application and its original content, features, and functionality are owned by NOCTURNE and are protected by international copyright, trademark, patent, trade secret, and other intellectual property laws.',
                ),
                
                const SizedBox(height: 24),
                
                _buildSection(
                  title: 'Payment Terms',
                  content: 'Certain features may require payment. All payments are processed securely. You agree to pay all charges incurred by you or any users of your account at the prices in effect when such charges are incurred.',
                  bulletPoints: [
                    'Subscription fees are billed in advance',
                    'Refunds are provided according to our refund policy',
                    'We reserve the right to change pricing with notice',
                    'You are responsible for all taxes associated with your purchases',
                  ],
                ),
                
                const SizedBox(height: 24),
                
                _buildSection(
                  title: 'Termination',
                  content: 'We may terminate or suspend your account immediately, without prior notice or liability, for any reason whatsoever, including without limitation if you breach the Terms.',
                ),
                
                const SizedBox(height: 24),
                
                _buildSection(
                  title: 'Limitation of Liability',
                  content: 'To the fullest extent permitted by law, NOCTURNE shall not be liable for any indirect, incidental, special, consequential, or punitive damages, including without limitation, loss of profits, data, use, goodwill, or other intangible losses.',
                ),
                
                const SizedBox(height: 24),
                
                _buildSection(
                  title: 'Changes to Terms',
                  content: 'We reserve the right to modify or replace these Terms at any time. If a revision is material, we will try to provide at least 30 days notice prior to any new terms taking effect.',
                ),
                
                const SizedBox(height: 24),
                
                _buildSection(
                  title: 'Contact Information',
                  content: 'For questions about these Terms, please contact us at:',
                  bulletPoints: [
                    'Email: legal@nocturne.com',
                    'Address: 123 Gastronomy Avenue, Paris, France',
                  ],
                ),
                
                const SizedBox(height: 32),
                
                // Acceptance
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00EEFC).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF00EEFC).withOpacity(0.2),
                    ),
                  ),
                  child: const Text(
                    'By using NOCTURNE, you acknowledge that you have read, understood, and agree to be bound by these Terms of Service.',
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
            color: Color(0xFF00EEFC),
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
                    color: Color(0xFFDF8EFF),
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