// lib/screens/login_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isSigningIn = false;

  Future<void> _handleGoogleSignIn() async {
    if (_isSigningIn) return;
    setState(() => _isSigningIn = true);

    try {
      // NEW v7+: Check if full authenticate is supported, then trigger UI flow
      if (await GoogleSignIn.instance.supportsAuthenticate()) {
        await GoogleSignIn.instance.authenticate();
        // authenticate() triggers authenticationEvents – handled globally in main.dart or a provider
        // No need to await tokens here; the event listener will handle Firebase sign-in
      } else {
        // Fallback for platforms without support (rare)
        debugPrint('Authenticate not supported on this platform');
      }
    } catch (e) {
      debugPrint('Google Auth Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign-in failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  Future<void> _guestLogin(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signInAnonymously();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('seenOnboarding', true);
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Guest login failed")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF6C5CE7),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElasticIn(
              child: Text(
                'Welcome to PrepKing',
                style: GoogleFonts.poppins(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 80),
            ElevatedButton.icon(
              onPressed: _isSigningIn ? null : _handleGoogleSignIn,
              icon: _isSigningIn
                  ? const SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(
                  color: Colors.red,
                  strokeWidth: 2,
                ),
              )
                  : const Icon(Icons.g_mobiledata, size: 34, color: Colors.red),
              label: Text(
                _isSigningIn ? 'Signing In...' : 'Continue with Google',
                style: GoogleFonts.poppins(fontSize: 18),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
            const SizedBox(height: 40),
            Text('or', style: GoogleFonts.poppins(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _guestLogin(context),
              child: Text(
                'Continue as Guest',
                style: GoogleFonts.poppins(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8E44AD),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                  side: const BorderSide(color: Colors.white, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Continue as guest to explore features. Your progress will be saved locally.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}