// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isSigningIn = false;

  Future<void> _googleSignIn() async {
    if (_isSigningIn) return;
    setState(() => _isSigningIn = true);

    try {
      // 1. Trigger Google Sign-In (with optional scopes for future accessToken if needed)
      final googleUser = await GoogleSignIn.instance.authenticate(
        scopeHint: ['email', 'profile'], // Add scopes if you need accessToken later
      );

      if (googleUser == null) {
        if (mounted) setState(() => _isSigningIn = false);
        return;
      }

      // 2. Get authentication object
      final googleAuth = await googleUser.authentication;

      // 3. FIXED: Use only idToken (accessToken not available in v7.2.0 for auth)
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        debugPrint('ID token is null');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sign-in failed: Missing ID token')),
          );
        }
        return;
      }

      // 4. Firebase sign-in (only idToken needed)
      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
        // accessToken: null, // Optional; omit for basic Firebase auth
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      // 5. Save flag & navigate
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('seenOnboarding', true);

      if (mounted) context.go('/home');
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign-in failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  Future<void> _guestLogin() async {
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
              onPressed: _isSigningIn ? null : _googleSignIn,
              icon: _isSigningIn
                  ? const SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2),
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
              onPressed: _guestLogin,
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