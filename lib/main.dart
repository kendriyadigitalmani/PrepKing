// lib/main.dart — UPDATED WITH OPTIMIZED INITIALIZATION
import 'dart:async';
import 'dart:convert';
import 'package:animate_do/animate_do.dart';
import 'package:confetti/confetti.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── SCREENS ─────────────────────
import 'screens/home/home_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/quizzes/quizzes_screen.dart';
import 'screens/quizzes/quiz_detail_screen.dart';
import 'screens/quizzes/standard_quiz_player_screen.dart';
import 'screens/quizzes/instant_quiz_player_screen.dart';
import 'screens/quizzes/quiz_result_screen.dart';
import 'screens/quizzes/quiz_review_screen.dart';
import 'screens/splash_screen.dart';        // ← Only this one (GOOD)
import 'screens/onboarding_screen.dart';    // ← Clean separate file

// ── PLACEHOLDER SCREENS ─────────────────────
class CoursesScreen extends StatelessWidget {
  const CoursesScreen({super.key});
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('COURSES')),
    body: const Center(child: Text('COURSES', style: TextStyle(fontSize: 32, color: Color(0xFF6C5CE7), fontWeight: FontWeight.bold))),
  );
}

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('LEADERBOARD')),
    body: const Center(child: Text('LEADERBOARD', style: TextStyle(fontSize: 32, color: Color(0xFF6C5CE7), fontWeight: FontWeight.bold))),
  );
}

// ── PROFILE SUB-SCREENS ─────────────────────
class CertificatesScreen extends StatelessWidget {
  const CertificatesScreen({super.key});
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("My Certificates"), leading: BackButton(onPressed: () => context.pop())),
    body: const Center(child: Text("Certificates Loading Soon...", style: TextStyle(fontSize: 20))),
  );
}

class QuizHistoryScreen extends StatelessWidget {
  const QuizHistoryScreen({super.key});
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("Quiz History"), leading: BackButton(onPressed: () => context.pop())),
    body: const Center(child: Text("Your Past Attempts", style: TextStyle(fontSize: 20))),
  );
}

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("Edit Profile"), leading: BackButton(onPressed: () => context.pop())),
    body: const Center(child: Text("Update Name & Mobile", style: TextStyle(fontSize: 20))),
  );
}

class ProfileSettingsScreen extends StatelessWidget {
  const ProfileSettingsScreen({super.key});
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text("Settings"), leading: BackButton(onPressed: () => context.pop())),
    body: const Center(child: Text("Notifications • Theme • Privacy", style: TextStyle(fontSize: 20))),
  );
}

// ── MAIN ─────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Add a small delay to ensure native splash shows
  await Future.delayed(const Duration(milliseconds: 100));

  await Firebase.initializeApp();

  runApp(const ProviderScope(child: PrepKingApp()));
}

// In your main.dart file, update this function:

// Load only essential services to speed up startup
Future<void> _minimumInitialization() async {
  // Only initialize Firebase - other things can load later
  await Firebase.initializeApp();

  // Load shared preferences asynchronously in background
  // Using Future.microtask to run in background
  Future.microtask(() async {
    await SharedPreferences.getInstance();
  });
}

// ── PROVIDERS ─────────────────────
final googleSignInProvider = Provider((ref) => GoogleSignIn());
final authProvider = Provider((ref) => FirebaseAuth.instance);
final authStateProvider = StreamProvider<User?>((ref) => ref.watch(authProvider).authStateChanges());
final sharedPrefsProvider = FutureProvider<SharedPreferences>((ref) => SharedPreferences.getInstance());

// ── ROUTER (Works perfectly with Splash → Login/Onboarding → Home) ─────────────────────
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStateProvider);
  final prefsFuture = ref.watch(sharedPrefsProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final prefs = prefsFuture.value;
      final loggedIn = auth.value != null;
      final seenOnboarding = prefs?.getBool('seenOnboarding') ?? false;
      final atSplash = state.matchedLocation == '/splash';

      if (atSplash) {
        if (loggedIn) return seenOnboarding ? '/home' : '/onboarding';
        return '/login';
      }

      if (!loggedIn && !state.matchedLocation.startsWith('/login') && !atSplash) {
        return '/login';
      }
      if (loggedIn && state.matchedLocation == '/login') return '/home';

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),

      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(path: '/home', pageBuilder: (_, __) => const NoTransitionPage(child: HomeScreen())),
          GoRoute(path: '/courses', pageBuilder: (_, __) => const NoTransitionPage(child: CoursesScreen())),
          GoRoute(path: '/quizzes', pageBuilder: (_, __) => const NoTransitionPage(child: QuizzesScreen())),
          GoRoute(path: '/leaderboard', pageBuilder: (_, __) => const NoTransitionPage(child: LeaderboardScreen())),
          GoRoute(
            path: '/profile',
            pageBuilder: (_, __) => const NoTransitionPage(child: ProfileScreen()),
            routes: [
              GoRoute(path: 'certificates', builder: (_, __) => const CertificatesScreen()),
              GoRoute(path: 'history', builder: (_, __) => const QuizHistoryScreen()),
              GoRoute(path: 'edit', builder: (_, __) => const EditProfileScreen()),
              GoRoute(path: 'settings', builder: (_, __) => const ProfileSettingsScreen()),
            ],
          ),
        ],
      ),

      // Quiz Flow
      GoRoute(path: '/quizzes/detail', builder: (context, state) => QuizDetailScreen(quiz: state.extra as Map<String, dynamic>)),
      GoRoute(path: '/q/:slug', builder: (context, state) {
        final slug = state.pathParameters['slug']!;
        return Scaffold(/* Deep link loading screen */);
      }),
      GoRoute(path: '/quizzes/instant-player', builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return InstantQuizPlayerScreen(quiz: extra['quiz'], attemptId: extra['attempt_id']);
      }),
      GoRoute(path: '/quizzes/standard-player', builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return StandardQuizPlayerScreen(quiz: extra['quiz'], attemptId: extra['attempt_id']);
      }),
      GoRoute(path: '/quizzes/result', builder: (context, state) => QuizResultScreen(result: state.extra as Map<String, dynamic>)),
      GoRoute(path: '/quiz-review', builder: (context, state) => QuizReviewScreen(reviewData: state.extra)),
    ],
  );
});

// ── APP ─────────────────────
class PrepKingApp extends ConsumerWidget {
  const PrepKingApp({super.key});
  @override Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'PrepKing',
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(routerProvider),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C5CE7)),
        useMaterial3: true,
        fontFamily: GoogleFonts.poppins().fontFamily,
      ),
    );
  }
}

// ── MAIN SCAFFOLD (Bottom Navigation) ─────────────────────
class MainScaffold extends ConsumerStatefulWidget {
  final Widget child;
  const MainScaffold({super.key, required this.child});
  @override ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _currentIndex = 0;
  final List<String> _locations = ['/home', '/courses', '/quizzes', '/leaderboard', '/profile'];
  DateTime? _lastBackPressTime;

  Future<bool> _onWillPop() async {
    final now = DateTime.now();
    if (_currentIndex != 0) return true;
    if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Press back again to exit', style: GoogleFonts.poppins()), backgroundColor: const Color(0xFF6C5CE7)),
      );
      return false;
    }
    return true;
  }

  @override Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: widget.child,
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (i) {
              setState(() => _currentIndex = i);
              context.go(_locations[i]);
            },
            type: BottomNavigationBarType.fixed,
            selectedItemColor: const Color(0xFF6C5CE7),
            unselectedItemColor: Colors.grey,
            selectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.menu_book_rounded), label: 'Courses'),
              BottomNavigationBarItem(icon: Icon(Icons.quiz_rounded), label: 'Quizzes'),
              BottomNavigationBarItem(icon: Icon(Icons.emoji_events_rounded), label: 'Leaderboard'),
              BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}

// ── LOGIN SCREEN ─────────────────────
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  Future<void> _googleSignIn(WidgetRef ref) async {
    try {
      final googleUser = await ref.read(googleSignInProvider).signIn();
      if (googleUser == null) return;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await ref.read(authProvider).signInWithCredential(credential);
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
    }
  }

  // ✅ GUEST LOGIN FUNCTION
  Future<void> _guestLogin(BuildContext context, WidgetRef ref) async {
    try {
      await FirebaseAuth.instance.signInAnonymously();

      // Mark onboarding as seen for guest users
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('seenOnboarding', true);

      // Navigate to home screen
      if (context.mounted) {
        context.go('/home');
      }

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Guest login failed: $e")),
        );
      }
    }
  }

  @override Widget build(BuildContext context, WidgetRef ref) {
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
                    color: Colors.white
                ),
              ),
            ),
            const SizedBox(height: 80),

            // Google Sign In Button
            ElevatedButton.icon(
              onPressed: () => _googleSignIn(ref),
              icon: const Icon(Icons.g_mobiledata, size: 34, color: Colors.red),
              label: Text(
                'Continue with Google',
                style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.black87
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 4,
              ),
            ),

            const SizedBox(height: 20),

            // OR Divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
              child: Row(
                children: [
                  Expanded(child: Divider(color: Colors.white.withOpacity(0.5), thickness: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'or',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.white.withOpacity(0.5), thickness: 1)),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ✅ Guest Login Button
            ElevatedButton(
              onPressed: () => _guestLogin(context, ref),
              child: Text(
                'Continue as Guest',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8E44AD), // Purple color for guest button
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                  side: const BorderSide(color: Colors.white, width: 1.5),
                ),
                elevation: 4,
              ),
            ),

            const SizedBox(height: 30),

            // Guest Login Info Text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Continue as guest to explore features. Your progress will be saved locally.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}