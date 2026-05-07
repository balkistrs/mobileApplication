import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final List<Map<String, dynamic>> _faqs = [
    {
      'question': 'How do I reset my password?',
      'answer': 'Go to the login screen and click "Forgot password". Enter your email address and we\'ll send you a reset link.',
    },
    {
      'question': 'How do I change my role?',
      'answer': 'Contact your restaurant administrator. Role changes must be approved by management.',
    },
    {
      'question': 'Can I use NOCTURNE on multiple devices?',
      'answer': 'Yes, you can log in from multiple devices, but simultaneous sessions may be limited.',
    },
    {
      'question': 'Is my data secure?',
      'answer': 'Yes, we use industry-standard encryption and security measures to protect your data.',
    },
    {
      'question': 'How do I contact support?',
      'answer': 'Email us at support@nocturne.com or call us at +33 1 23 45 67 89',
    },
  ];

  Future<void> _sendEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@nocturne.com',
      query: 'subject=NOCTURNE Support Request',
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open email app'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _callSupport() async {
    final Uri phoneUri = Uri(scheme: 'tel', path: '+33123456789');
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not make a call'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E11),
      appBar: AppBar(
        title: const Text(
          'Support Center',
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
          
          // Content
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with support info
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFDF8EFF).withOpacity(0.1),
                        const Color(0xFF00EEFC).withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFDF8EFF).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.support_agent,
                        color: Color(0xFFDF8EFF),
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Need Help?',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Our support team is available 24/7 to assist you',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Quick Contact Actions
                const Text(
                  'Contact Us',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDF8EFF),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildContactCard(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        description: 'support@nocturne.com',
                        color: const Color(0xFFDF8EFF),
                        onTap: _sendEmail,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildContactCard(
                        icon: Icons.phone_outlined,
                        label: 'Call',
                        description: '+33 1 23 45 67 89',
                        color: const Color(0xFF00EEFC),
                        onTap: _callSupport,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 40),
                
                // FAQ Section
                const Text(
                  'Frequently Asked Questions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDF8EFF),
                  ),
                ),
                const SizedBox(height: 16),
                ..._faqs.map((faq) => _buildFAQ(
                  question: faq['question'],
                  answer: faq['answer'],
                )),
                
                const SizedBox(height: 32),
                
                // Business Hours Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F1F23),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF48474B).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: const Color(0xFF00EEFC),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Business Hours',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF00EEFC),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow('Monday - Friday', '9:00 AM - 9:00 PM'),
                      const SizedBox(height: 8),
                      _buildInfoRow('Saturday', '10:00 AM - 6:00 PM'),
                      const SizedBox(height: 8),
                      _buildInfoRow('Sunday', 'Closed'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDF8EFF).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFDF8EFF).withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              color: const Color(0xFFDF8EFF),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Emergency support available 24/7',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withOpacity(0.6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Additional Resources
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F1F23),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF48474B).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Additional Resources',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF00EEFC),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildResourceLink(
                        icon: Icons.description_outlined,
                        title: 'User Guide',
                        onTap: () {
                          // TODO: Open user guide
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('User Guide coming soon'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildResourceLink(
                        icon: Icons.video_library_outlined,
                        title: 'Video Tutorials',
                        onTap: () {
                          // TODO: Open video tutorials
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Video Tutorials coming soon'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildResourceLink(
                        icon: Icons.forum_outlined,
                        title: 'Community Forum',
                        onTap: () {
                          // TODO: Open community forum
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Community Forum coming soon'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        },
                      ),
                    ],
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

  Widget _buildContactCard({
    required IconData icon,
    required String label,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F23),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQ({
    required String question,
    required String answer,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F23),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF48474B).withOpacity(0.3),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            question,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          iconColor: const Color(0xFFDF8EFF),
          collapsedIconColor: const Color(0xFFDF8EFF),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                answer,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildResourceLink({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.6), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 13,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withOpacity(0.4),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}