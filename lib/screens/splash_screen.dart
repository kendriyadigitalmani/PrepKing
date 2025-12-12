// lib/screens/splash_screen.dart
import 'dart:async';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _lottieController;

  @override
  void initState() {
    super.initState();
    _lottieController = AnimationController(vsync: this);

    // Delayed navigation with full auth & onboarding logic
    Future.delayed(const Duration(milliseconds: 3500), () async {
      if (!mounted) return;

      try {
        final prefs = await SharedPreferences.getInstance();
        final user = FirebaseAuth.instance.currentUser;
        final seenOnboarding = prefs.getBool('seenOnboarding') ?? false;

        String targetRoute;
        if (user != null) {
          targetRoute = seenOnboarding ? '/home' : '/onboarding';
        } else {
          targetRoute = '/login';
        }

        if (mounted) {
          context.go(targetRoute);
        }
      } catch (e) {
        // Fallback: go to login if something fails
        if (mounted) {
          context.go('/login');
        }
      }
    });
  }

  @override
  void dispose() {
    _lottieController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF6C5CE7),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Lottie with instant fallback
            Lottie.asset(
              'assets/lottie/splash.json',
              controller: _lottieController,
              onLoaded: (composition) {
                if (mounted) {
                  _lottieController
                    ..duration = composition.duration
                    ..forward()
                    ..repeat();
                }
              },
              width: 280,
              fit: BoxFit.contain,
              repeat: true,
              // Fallback shown immediately if asset fails to load
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
            const _DotsLoader(),
          ],
        ),
      ),
    );
  }
}

// Keep your beautiful bouncing dots loader (unchanged)
class _DotsLoader extends StatefulWidget {
  const _DotsLoader();
  @override
  State<_DotsLoader> createState() => _DotsLoaderState();
}

class _DotsLoaderState extends State<_DotsLoader> with TickerProviderStateMixin {
  late final List<AnimationController> _controllers = List.generate(3, (_) {
    return AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
  });

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
              boxShadow: [BoxShadow(color: Colors.white30, blurRadius: 8, spreadRadius: 2)],
            ),
          ),
        );
      }),
    );
  }
}