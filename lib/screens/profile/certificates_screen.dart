// lib/screens/profile/certificates_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/user_provider.dart';
import '../../providers/certificate_provider.dart';

class CertificatesScreen extends ConsumerWidget {
  const CertificatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value!;
    final certs = ref.watch(certificatesProvider(user.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Certificates"),
        backgroundColor: const Color(0xFF6C5CE7),
        foregroundColor: Colors.white,
      ),
      body: certs.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF6C5CE7))),
        error: (_, __) => const Center(child: Text("Failed to load certificates")),
        data: (list) => list.isEmpty
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.workspace_premium, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              Text("No certificates yet", style: GoogleFonts.poppins(fontSize: 18)),
              const SizedBox(height: 8),
              Text("Complete courses to earn certificates!", style: TextStyle(color: Colors.grey)),
            ],
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (_, i) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const Icon(Icons.workspace_premium, color: Color(0xFF6C5CE7)),
              title: Text(list[i]['title'] ?? 'Certificate', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              subtitle: Text("Issued on: ${list[i]['issued_on'] ?? 'N/A'}", style: GoogleFonts.poppins(fontSize: 13)),
            ),
          ),
        ),
      ),
    );
  }
}