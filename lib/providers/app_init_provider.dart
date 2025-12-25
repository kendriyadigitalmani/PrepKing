// lib/providers/app_init_provider.dart
import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/app_version_validator.dart';
import '../core/utils/network_utils.dart';
import '../core/utils/user_preferences.dart';
import 'app_settings_provider.dart';
import 'user_provider.dart';

/// This provider completes ONLY when the app is fully ready to proceed.
/// It handles:
/// - Network check
/// - Parallel Firebase init + App Settings fetch
/// - Version validation (throws UPDATE_REQUIRED if needed)
/// - Local preferences loading
/// - User session fetch (if logged in)
final appInitProvider = FutureProvider<void>((ref) async {
  try {
    // 1️⃣ CHECK NETWORK FIRST (critical for all subsequent operations)
    final hasInternet = await NetworkUtils.hasInternet();
    if (!hasInternet) {
      developer.log('No internet connection detected during app init');
      throw Exception('NO_NETWORK');
    }

    // 2️⃣ START BOTH FIREBASE INITIALIZATION AND APP SETTINGS FETCH IN PARALLEL
    // This ensures no blocking — splash animation runs smoothly
    final firebaseFuture = Firebase.initializeApp().catchError((e) {
      developer.log('Firebase initialization failed: $e');
      throw Exception('Firebase init failed: $e');
    });

    final appSettingsFuture = ref.read(appSettingsProvider.future).catchError((e) {
      developer.log('App settings fetch failed: $e');
      throw Exception('App settings fetch failed: $e');
    });

    // 3️⃣ WAIT FOR APP SETTINGS FIRST — REQUIRED FOR VERSION CHECK
    final settings = await appSettingsFuture;

    // 4️⃣ VERSION VALIDATION — If update required, throw specific exception
    final updateRequired = await AppVersionValidator.isUpdateRequired(settings);
    if (updateRequired) {
      developer.log('Update required detected');
      throw Exception('UPDATE_REQUIRED');
    }

    // 5️⃣ NOW WAIT FOR FIREBASE TO FINISH INITIALIZING (if not already done)
    await firebaseFuture;

    // 6️⃣ LOAD LOCAL PREFERENCES (e.g., onboarding seen flag)
    final prefs = UserPreferences();
    await prefs.hasSeenOnboarding(); // Just ensure it's loaded

    // 7️⃣ IF USER IS LOGGED IN, FETCH THEIR DETAILS FROM BACKEND
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      developer.log('User logged in, fetching profile data');
      await ref.read(currentUserProvider.future);
    }

    // All checks passed → app is ready for navigation
    developer.log('App initialization completed successfully');
  } catch (e, stack) {
    developer.log('App init failed: $e\n$stack');
    rethrow; // Let the error bubble up to the splash screen listener
  }
});