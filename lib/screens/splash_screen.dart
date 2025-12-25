// lib/screens/splash_screen.dart
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/app_init_provider.dart';
import '../core/utils/user_preferences.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the initialization state
    final initAsync = ref.watch(appInitProvider);

    // Listen for completion or specific errors
    ref.listen(appInitProvider, (previous, next) {
      next.whenOrNull(
        data: (_) async {
          // Initialization successful → decide next route
          final prefs = UserPreferences();
          final seenOnboarding = await prefs.hasSeenOnboarding();
          final user = FirebaseAuth.instance.currentUser;

          if (!seenOnboarding) {
            context.go('/onboarding');
          } else if (user == null) {
            context.go('/login');
          } else {
            context.go('/home');
          }
        },
        error: (error, stack) {
          final errorMsg = error.toString();

          // No Internet Connection
          if (errorMsg.contains('NO_NETWORK')) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Text(
                  'No Internet Connection',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
                content: Text(
                  'Network not available.\nPlease check your internet connection and try again.',
                  style: GoogleFonts.poppins(),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ref.invalidate(appInitProvider); // Retry
                    },
                    child: Text(
                      'Retry',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF6C5CE7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          // Update Required
          else if (errorMsg.contains('UPDATE_REQUIRED')) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Text(
                  'Update Required',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
                content: Text(
                  'A new version of PrepKing is available.\nPlease update to continue using the app.',
                  style: GoogleFonts.poppins(),
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      final uri = Uri.parse(
                        'https://play.google.com/store/apps/details?id=com.dube.prepking',
                      );
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Text(
                      'UPDATE NOW',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF6C5CE7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          // Any other unexpected error
          else {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Text(
                  'Something Went Wrong',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
                content: Text(
                  'Failed to initialize the app.\nPlease try again.',
                  style: GoogleFonts.poppins(),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ref.invalidate(appInitProvider);
                    },
                    child: Text(
                      'Retry',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF6C5CE7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        },
      );
    });

    // Safety timeout in case initialization takes too long
    Future.delayed(const Duration(seconds: 12), () {
      if (context.mounted && initAsync.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Taking longer than expected...',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => ref.invalidate(appInitProvider),
            ),
          ),
        );
      }
    });

    // === BEAUTIFUL SPLASH UI (100% PRESERVED) ===
    return Scaffold(
      backgroundColor: const Color(0xFF6C5CE7),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/lottie/splash.json',
              width: 280,
              fit: BoxFit.contain,
              repeat: true,
              errorBuilder: (context, error, stackTrace) {
                return Column(
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      width: 180,
                      height: 180,
                      errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.school, size: 100, color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    const CircularProgressIndicator(color: Colors.white),
                  ],
                );
              },
            ),
            const SizedBox(height: 50),
            FadeInDown(
              duration: const Duration(milliseconds: 1000),
              child: Text(
                'PrepKing',
                style: GoogleFonts.poppins(
                  fontSize: 52,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                  shadows: const [
                    Shadow(color: Colors.black26, offset: Offset(0, 4), blurRadius: 10),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FadeInUp(
              duration: const Duration(milliseconds: 1200),
              delay: const Duration(milliseconds: 400),
              child: Text(
                'Master Any Exam. Anytime. Anywhere.',
                style: GoogleFonts.poppins(fontSize: 18, color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 120),
            if (initAsync.isLoading) const _DotsLoader(),
          ],
        ),
      ),
    );
  }
}

/// Beautiful bouncing dots loader (exactly as in your original code)
class _DotsLoader extends StatefulWidget {
  const _DotsLoader();

  @override
  State<_DotsLoader> createState() => _DotsLoaderState();
}

class _DotsLoaderState extends State<_DotsLoader> with TickerProviderStateMixin {
  late final List<AnimationController> _controllers = List.generate(
    3,
        (_) => AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true),
  );

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) _controllers[i].forward();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.4, end: 1.4).animate(
            CurvedAnimation(parent: _controllers[i], curve: Curves.easeInOut),
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.white30, blurRadius: 8, spreadRadius: 2),
              ],
            ),
          ),
        );
      }),
    );
  }
}