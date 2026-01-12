// lib/screens/splash_screen.dart
import 'dart:async';
import 'dart:io' show Platform; // Added for platform detection

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import '../providers/app_init_provider.dart';
import '../providers/app_settings_provider.dart';
import '../core/utils/user_preferences.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _hasHandledResult = false;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    // Remove native splash after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });

    // Safety timeout
    _timeoutTimer = Timer(const Duration(seconds: 12), () {
      final initAsync = ref.read(appInitProvider);
      if (mounted && initAsync.isLoading) {
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
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _showNoNetworkDialog() {
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
              _hasHandledResult = false;
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

  void _showUpdateRequiredDialog() async {
    // Default official Play Store URL
    String targetUrl = 'https://play.google.com/store/apps/details?id=online.prepking';

    // On Android: ALWAYS use Play Store URL (even if server provides something else)
    // This ensures full compliance with Google Play policy — no risk of sideloading
    if (Platform.isAndroid) {
      final appSettingsAsync = ref.read(appSettingsProvider);
      appSettingsAsync.whenData((settings) {
        // Allow server-provided Play Store URL only if it's a valid Play Store link (e.g., for tracking)
        final serverUrl = settings.appStoreUrl?.trim();
        if (serverUrl != null &&
            serverUrl.isNotEmpty &&
            serverUrl.contains('play.google.com/store/apps/details')) {
          targetUrl = serverUrl;
        }
        // apkUrl is completely ignored on Android — required for Play Store compliance
      });
    } else {
      // On iOS or other platforms: allow App Store URL from server
      final appSettingsAsync = ref.read(appSettingsProvider);
      appSettingsAsync.whenData((settings) {
        if (settings.appStoreUrl != null && settings.appStoreUrl!.trim().isNotEmpty) {
          targetUrl = settings.appStoreUrl!.trim();
        }
      });
    }

    final uri = Uri.parse(targetUrl);

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
          'A new version of PrepKing is available on Google Play.\nPlease update to continue.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open the store')),
                  );
                }
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

  void _showGenericErrorDialog(String errorMsg) {
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
          errorMsg.contains('Exception')
              ? errorMsg.replaceFirst('Exception: ', '')
              : 'Failed to initialize the app.\nPlease try again.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _hasHandledResult = false;
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

  @override
  Widget build(BuildContext context) {
    final initAsync = ref.watch(appInitProvider);

    ref.listen<AsyncValue<void>>(appInitProvider, (previous, next) {
      if (_hasHandledResult) return;

      next.whenOrNull(
        data: (_) async {
          _hasHandledResult = true;
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
        error: (err, _) {
          _hasHandledResult = true;
          final errorMsg = err.toString();

          if (errorMsg.contains('NO_NETWORK')) {
            _showNoNetworkDialog();
          } else if (errorMsg.contains('UPDATE_REQUIRED')) {
            _showUpdateRequiredDialog();
          } else {
            _showGenericErrorDialog(errorMsg);
          }
        },
      );
    });

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