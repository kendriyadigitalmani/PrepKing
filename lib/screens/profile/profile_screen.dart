// lib/screens/profile/profile_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../../widgets/profile_menu_tile.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.grey),
            onPressed: () => context.push('/profile/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(currentUserProvider);
        },
        child: userAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text("Failed to load profile", style: GoogleFonts.poppins()),
                TextButton(
                  onPressed: () => ref.refresh(currentUserProvider),
                  child: const Text("Retry"),
                ),
              ],
            ),
          ),
          data: (user) {
            if (user == null) {
              return Center(
                child: Text("No user data found", style: GoogleFonts.poppins(fontSize: 18)),
              );
            }

            return ListView(
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                // ─── Profile Header ───
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 64,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: user.profilePicture != null
                            ? NetworkImage(user.profilePicture!)
                            : (FirebaseAuth.instance.currentUser?.photoURL != null
                            ? NetworkImage(FirebaseAuth.instance.currentUser!.photoURL!)
                            : null),
                        child: user.profilePicture == null && FirebaseAuth.instance.currentUser?.photoURL == null
                            ? const Icon(Icons.person, size: 80, color: Colors.grey)
                            : null,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        user.name,
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2D3436),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        user.email,
                        style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]),
                      ),
                      if (user.mobile != null && user.mobile!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          user.mobile!,
                          style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[500]),
                        ),
                      ],
                      const SizedBox(height: 32),

                      // ─── Stats Row ───
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStat("${user.coins}", "Coins", 'assets/lottie/coin.json'),
                          _buildStat("${user.streak}", "Day Streak", 'assets/lottie/fire.json'),
                          _buildStat("0", "Certificates", 'assets/lottie/trophy.json'), // Will be real soon
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ─── Menu Section ───
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      ProfileMenuTile(
                        icon: Icons.person_outline,
                        title: "Edit Profile",
                        onTap: () => context.push('/profile/edit'),
                      ),
                      const Divider(height: 1),
                      ProfileMenuTile(
                        icon: Icons.card_membership_outlined,
                        title: "My Certificates",
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/profile/certificates'),
                      ),
                      const Divider(height: 1),
                      ProfileMenuTile(
                        icon: Icons.history,
                        title: "Quiz History",
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/profile/history'),
                      ),
                      const Divider(height: 1),
                      ProfileMenuTile(
                        icon: Icons.emoji_events_outlined,
                        title: "Leaderboard Rank",
                        trailing: Text(
                          "#--", // Will fetch real rank later
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF6C5CE7)),
                        ),
                        onTap: () => context.go('/leaderboard'),
                      ),
                      const Divider(height: 1),
                      ProfileMenuTile(
                        icon: Icons.wallet,
                        title: "Coin Store",
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/coins/store'),
                      ),
                      const Divider(height: 1),
                      ProfileMenuTile(
                        icon: Icons.help_outline,
                        title: "Help & Support",
                        onTap: () => context.push('/support'),
                      ),
                      const Divider(height: 1),
                      ProfileMenuTile(
                        icon: Icons.info_outline,
                        title: "About PrepKing",
                        onTap: () => context.push('/about'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // ─── Logout Button ───
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => _showLogoutDialog(context),
                    child: Text(
                      "Logout",
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStat(String value, String label, String lottieAsset) {
    return Column(
      children: [
        Lottie.asset(lottieAsset, height: 60, fit: BoxFit.contain),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2D3436),
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Logout", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text("Are you sure you want to logout?", style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.grey[700])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              FirebaseAuth.instance.signOut();
              context.go('/login');
            },
            child: Text("Logout", style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}