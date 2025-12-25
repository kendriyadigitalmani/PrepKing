// lib/screens/profile/about_prepking_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

class AboutPrepKingScreen extends StatelessWidget {
  const AboutPrepKingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("About PrepKing"),
        backgroundColor: const Color(0xFF6C5CE7),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Lottie.asset(
                'assets/lottie/splash.json',
                width: 140,
                height: 140,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Image.asset(
                  'assets/images/logo.png',
                  width: 120,
                  height: 120,
                  errorBuilder: (_, __, ___) => const Icon(Icons.school, size: 100, color: Color(0xFF6C5CE7)),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              "PrepKing",
              style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: const Color(0xFF2D3436)),
            ),
            const SizedBox(height: 12),
            Text(
              "A modern learning platform built for students, by educators.",
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[700], height: 1.5),
            ),
            const SizedBox(height: 32),
            _buildInfoRow("Version", "1.0.0"),
            _buildInfoRow("Made in", "India 🇮🇳"),
            _buildInfoRow("Technology", "Flutter • Firebase • Riverpod"),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "PrepKing is committed to providing a distraction-free, ad-free, and safe learning environment for students across India.",
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            "$label: ",
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.grey[700]),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: const Color(0xFF2D3436)),
          ),
        ],
      ),
    );
  }
}