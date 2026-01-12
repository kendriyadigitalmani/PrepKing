// lib/providers/app_init_provider.dart
import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/app_version_validator.dart';
import '../core/utils/network_utils.dart';
import '../core/utils/user_preferences.dart';
import '../models/app_settings.dart';
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
    // FIXED: Guard against duplicate Firebase initialization
    final firebaseFuture = (Firebase.apps.isEmpty)
        ? Firebase.initializeApp().catchError((e) {
      developer.log('Firebase initialization failed: $e');
      throw Exception('Firebase init failed: $e');
    })
        : Future.value(Firebase.app());

    final appSettingsFuture = ref.read(appSettingsProvider.future).catchError((e) {
      developer.log('App settings fetch failed: $e');
      throw Exception('App settings fetch failed: $e');
    });

    // 3️⃣ WAIT FOR BOTH TO COMPLETE IN PARALLEL
    final List<dynamic> results = await Future.wait([firebaseFuture, appSettingsFuture]);

    // results[0] = FirebaseApp (from firebaseFuture)
    // results[1] = AppSettings (from appSettingsFuture)
    final AppSettings settings = results[1] as AppSettings;

    // 4️⃣ VERSION VALIDATION — If update required, throw specific exception
    final updateRequired = await AppVersionValidator.isUpdateRequired(settings);
    if (updateRequired) {
      developer.log('Update required detected');
      throw Exception('UPDATE_REQUIRED');
    }

    // 5️⃣ LOAD LOCAL PREFERENCES (e.g., onboarding seen flag)
    final prefs = UserPreferences();
    await prefs.hasSeenOnboarding(); // Just ensure it's loaded

    // 6️⃣ IF USER IS LOGGED IN, FETCH THEIR DETAILS FROM BACKEND
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      developer.log('User logged in, fetching profile data');
      try {
        await ref.read(currentUserProvider.future);
      } catch (e) {
        developer.log('User fetch failed during init: $e');
        // Critical recovery: if backend user is missing (401/404), sign out Firebase
        // This prevents getting stuck on splash with an invalid session
        if (e is Exception && e.toString().contains('401')) {
          developer.log('Backend user not found (401) → signing out Firebase');
          await FirebaseAuth.instance.signOut();
        } else if (e is Exception && e.toString().contains('404')) {
          developer.log('Backend user not found (404) → signing out Firebase');
          await FirebaseAuth.instance.signOut();
        }
        // Re-throw to show error dialog in splash (user can retry)
        rethrow;
      }
    }

    // All checks passed → app is ready for navigation
    developer.log('App initialization completed successfully');
  } catch (e, stack) {
    developer.log('App init failed: $e\n$stack');
    rethrow; // Let the error bubble up to the splash screen listener
  }
});