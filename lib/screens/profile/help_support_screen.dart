// lib/screens/profile/help_support_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@prepking.in',
      queryParameters: const {'subject': 'PrepKing Support Request'},
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
    // Removed context-dependent SnackBar to avoid 'Undefined name context' error
    // Failure is usually silent (no email app installed)
  }

  Future<void> _launchWhatsApp() async {
    const String phoneNumber = '6266072809'; // Indian number
    const String message = 'Hello PrepKing Support, I need help with...';
    final String encodedMessage = Uri.encodeComponent(message);

    final Uri whatsappUri = Uri.parse(
      'https://wa.me/$phoneNumber?text=$encodedMessage',
    );

    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback to WhatsApp Web
      final Uri webUri = Uri.parse(
        'https://web.whatsapp.com/send?phone=$phoneNumber&text=$encodedMessage',
      );
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
      // Removed context-dependent SnackBar to avoid 'Undefined name context' error
      // Failure is handled gracefully
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Help & Support"),
        backgroundColor: const Color(0xFF6C5CE7),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            Center(
              child: Lottie.asset(
                'assets/lottie/help.json',
                width: 160,
                height: 160,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.help_outline,
                  size: 120,
                  color: Color(0xFF6C5CE7),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Email Support
            _buildSupportCard(
              icon: Icons.email_outlined,
              title: "Email Support",
              subtitle: "support@prepking.in",
              onTap: _launchEmail,
              accentColor: const Color(0xFF6C5CE7),
            ),
            const SizedBox(height: 16),

            // WhatsApp Support
            _buildSupportCard(
              icon: Icons.chat,
              title: "WhatsApp Support",
              subtitle: "+91 62660 72809",
              onTap: _launchWhatsApp,
              accentColor: const Color(0xFF25D366), // WhatsApp green
            ),
            const SizedBox(height: 16),

            // Frequently Asked Questions
            _buildSupportCard(
              icon: Icons.help_outline,
              title: "Frequently Asked Questions",
              subtitle: "Find answers to common questions",
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("FAQ section coming soon!")),
                );
              },
              accentColor: const Color(0xFF6C5CE7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color accentColor = const Color(0xFF6C5CE7),
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: accentColor, size: 28),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 18),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      ),
    );
  }
}