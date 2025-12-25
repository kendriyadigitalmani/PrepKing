// lib/screens/profile/profile_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lottie/lottie.dart';
import '../../core/utils/user_preferences.dart';
import '../../models/user_model.dart';
import '../../providers/user_progress_merged_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/profile_menu_tile.dart';

// Shared GoogleSignIn instance
final GoogleSignIn googleSignIn = GoogleSignIn();

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => _buildLoadingScreen(),
      error: (err, stack) => _ProfileError(
        onRetry: () => ref.invalidate(currentUserProvider),
      ),
      data: (user) {
        if (user == null) {
          return _NotLoggedInView();
        }
        return _ProfileContent(
          user: user,
          onLogout: () => _showLogoutDialog(context, ref),
        );
      },
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset('assets/lottie/loading.json', width: 100, height: 100),
            const SizedBox(height: 16),
            Text(
              'Loading your profile...',
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLogoutDialog(BuildContext context, WidgetRef ref) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Logout", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          "Are you sure you want to logout?\nYour progress is saved.",
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.grey[700])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text("Logout", style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !context.mounted) return;

    try {
      // Firebase sign-out
      await FirebaseAuth.instance.signOut();

      // Google sign-out (if applicable)
      try {
        if (await googleSignIn.isSignedIn()) {
          await googleSignIn.signOut();
        }
      } catch (e) {
        debugPrint("Google sign out error: $e");
      }

      // Clear local prefs
      await UserPreferences().clearAll();

      // Invalidate providers
      ref.read(refreshUserDataProvider)();
      ref.invalidate(currentUserProvider);
      ref.invalidate(userWithProgressProvider);

      // Navigate to login
      if (context.mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            context.go('/login');
          }
        });
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// ─── Error State ───────────────────────────────────────
class _ProfileError extends StatelessWidget {
  final VoidCallback onRetry;
  const _ProfileError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text("Failed to load profile", style: GoogleFonts.poppins()),
            TextButton(
              onPressed: onRetry,
              child: const Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Not Logged In State ───────────────────────────────
class _NotLoggedInView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("No user logged in", style: GoogleFonts.poppins(fontSize: 18)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => context.go('/login'),
              child: Text("Go to Login", style: GoogleFonts.poppins()),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Main Profile Content ───────────────────────────────
class _ProfileContent extends StatelessWidget {
  final UserModel user;
  final VoidCallback onLogout;

  const _ProfileContent({
    required this.user,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
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
          final ref = ProviderScope.containerOf(context, listen: false);
          ref.invalidate(currentUserProvider);
          ref.invalidate(userWithProgressProvider);
        },
        child: ListView(
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
                        ? CachedNetworkImageProvider(user.profilePicture!)
                        : (FirebaseAuth.instance.currentUser?.photoURL != null
                        ? CachedNetworkImageProvider(FirebaseAuth.instance.currentUser!.photoURL!)
                        : null),
                    child: (user.profilePicture == null &&
                        FirebaseAuth.instance.currentUser?.photoURL == null)
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
                      _buildStat("0", "Certificates", 'assets/lottie/trophy.json'),
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
                      "#--",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF6C5CE7)),
                    ),
                    onTap: () => context.go('/leaderboard'),
                  ),
                  const Divider(height: 1),
                  ProfileMenuTile(
                    icon: Icons.wallet,
                    title: "Coin Store",
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/profile/coins'), // ← Changed
                  ),
                  const Divider(height: 1),
                  ProfileMenuTile(
                    icon: Icons.help_outline,
                    title: "Help & Support",
                    trailing: const Icon(Icons.chevron_right), // Added trailing for consistency
                    onTap: () => context.push('/profile/help'), // ← Changed
                  ),
                  const Divider(height: 1),
                  ProfileMenuTile(
                    icon: Icons.info_outline,
                    title: "About PrepKing",
                    trailing: const Icon(Icons.chevron_right), // Added trailing for consistency
                    onTap: () => context.push('/profile/about'), // ← Changed
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
                onPressed: onLogout,
                child: Text(
                  "Logout",
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  static Widget _buildStat(String value, String label, String lottieAsset) {
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
}