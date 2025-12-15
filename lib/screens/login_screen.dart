// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Add these imports
import '../core/utils/user_preferences.dart';
import '../core/services/api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // if not already imported

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isSigningIn = false;

  Future<void> _googleSignIn() async {
    if (_isSigningIn) return;
    setState(() => _isSigningIn = true);

    try {
      final googleUser = await GoogleSignIn.instance.authenticate(
        scopeHint: ['email', 'profile'],
      );

      if (googleUser == null) {
        if (mounted) setState(() => _isSigningIn = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
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

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final firebaseId = userCredential.user?.uid;

      if (firebaseId == null) {
        throw Exception('Firebase UID is missing after sign-in');
      }

      // ✅ STEP 1: Fetch user from backend by firebaseId
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.get('/user', query: {'firebaseid': firebaseId});

      final userData = response['data'] as Map<String, dynamic>?;

      final prefs = UserPreferences();

      if (userData != null) {
        // ✅ STEP 2: User exists → save full data
        await prefs.saveUserData(
          userId: userData['id'] as int,
          firebaseId: userData['firebase_id'] as String,
          name: userData['name'] as String,
          email: userData['email'] as String,
          isFirstTime: false,
          isGuest: false,
        );
      } else {
        // ✅ STEP 3: New user → create on backend and save
        final newUserResponse = await apiService.post('/user', {
          'firebase_id': firebaseId,
          'name': googleUser.displayName ?? 'User',
          'email': googleUser.email,
          'role': 'student', // or whatever default
        });

        final createdUser = newUserResponse['data'] as Map<String, dynamic>;
        await prefs.saveUserData(
          userId: createdUser['id'] as int,
          firebaseId: createdUser['firebase_id'] as String,
          name: createdUser['name'] as String,
          email: createdUser['email'] as String,
          isFirstTime: true,
          isGuest: false,
        );
      }

      // Mark onboarding as seen (optional if already handled in saveUserData)
      await prefs.getUserData(); // just to confirm

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
      final userCredential = await FirebaseAuth.instance.signInAnonymously();
      final firebaseId = userCredential.user?.uid;

      if (firebaseId == null) throw Exception('Guest login failed: no Firebase UID');

      // Guest users don’t go to backend (or optionally create later)
      final prefs = UserPreferences();
      await prefs.saveGuestData(firebaseId: firebaseId);

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