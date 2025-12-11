// lib/main.dart — FINAL VERSION (google_sign_in v7.2.0 COMPATIBLE)
import 'dart:async';
import 'package:animate_do/animate_do.dart';
import 'package:confetti/confetti.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart'; // v7.2.0
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';

// ── SCREENS ─────────────────────
import 'screens/home/home_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/quizzes/quizzes_screen.dart';
import 'screens/quizzes/quiz_detail_screen.dart';
import 'screens/quizzes/standard_quiz_player_screen.dart';
import 'screens/quizzes/instant_quiz_player_screen.dart';
import 'screens/quizzes/quiz_result_screen.dart';
import 'screens/quizzes/quiz_review_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart'; // ← We moved LoginScreen to its own file (recommended)

// ── COURSES SCREENS (REAL ONES) ─────────────────────
import 'screens/courses/course_list_screen.dart';
import 'screens/courses/course_detail_screen.dart';
import 'screens/courses/content_list_screen.dart';

// ── PLACEHOLDER SCREENS ─────────────────────
class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('LEADERBOARD')),
    body: const Center(
        child: Text('LEADERBOARD COMING SOON',
            style: TextStyle(
                fontSize: 28,
                color: Color(0xFF6C5CE7),
                fontWeight: FontWeight.bold))),
  );
}

// ── PROFILE SUB-SCREENS ─────────────────────
class CertificatesScreen extends StatelessWidget {
  const CertificatesScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
        title: const Text("My Certificates"),
        leading: BackButton(onPressed: () => context.pop())),
    body: const Center(child: Text("Certificates Loading Soon...", style: TextStyle(fontSize: 20))),
  );
}

class QuizHistoryScreen extends StatelessWidget {
  const QuizHistoryScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
        title: const Text("Quiz History"),
        leading: BackButton(onPressed: () => context.pop())),
    body: const Center(child: Text("Your Past Attempts", style: TextStyle(fontSize: 20))),
  );
}

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
        title: const Text("Edit Profile"),
        leading: BackButton(onPressed: () => context.pop())),
    body: const Center(child: Text("Update Name & Mobile", style: TextStyle(fontSize: 20))),
  );
}

class ProfileSettingsScreen extends StatelessWidget {
  const ProfileSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
        title: const Text("Settings"),
        leading: BackButton(onPressed: () => context.pop())),
    body: const Center(child: Text("Notifications • Theme • Privacy", style: TextStyle(fontSize: 20))),
  );
}

// ── MAIN ─────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.delayed(const Duration(milliseconds: 100));
  await Firebase.initializeApp();

  // FIXED v7.2.0: Initialize the singleton instance (call once)
  await GoogleSignIn.instance.initialize(
    // Optional: Add these for web/iOS (from Google Cloud Console)
    // clientId: 'your-web-client-id.googleusercontent.com',
    // serverClientId: 'your-server-client-id.googleusercontent.com',
  );

  runApp(const ProviderScope(child: PrepKingApp()));
}

// ── PROVIDERS ────────────────────────
final authProvider = Provider((ref) => FirebaseAuth.instance);
final authStateProvider = StreamProvider<User?>((ref) => ref.watch(authProvider).authStateChanges());
final sharedPrefsProvider = FutureProvider<SharedPreferences>((ref) => SharedPreferences.getInstance());

// ── ROUTER (UNCHANGED – STILL PERFECT) ─────────────────────
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
          GoRoute(
            path: '/courses',
            pageBuilder: (_, __) => const NoTransitionPage(child: CourseListScreen()),
            routes: [
              GoRoute(
                path: 'detail/:id',
                builder: (context, state) => CourseDetailScreen(courseId: int.parse(state.pathParameters['id']!)),
              ),
              GoRoute(
                path: 'content/:courseId',
                builder: (context, state) => ContentListScreen(courseId: int.parse(state.pathParameters['courseId']!)),
              ),
            ],
          ),
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

      // Quiz & Certificate routes (unchanged — perfect)
      GoRoute(path: '/quizzes/detail', builder: (context, state) => QuizDetailScreen(quiz: state.extra as Map<String, dynamic>)),
      GoRoute(path: '/q/:slug', builder: (context, state) => Scaffold(body: Center(child: Text('Loading quiz: ${state.pathParameters['slug']}')))),
      GoRoute(path: '/quizzes/instant-player', builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return InstantQuizPlayerScreen(quiz: extra['quiz'], attemptId: extra['attempt_id']);
      }),
      GoRoute(path: '/quizzes/standard-player', builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return StandardQuizPlayerScreen(quiz: extra['quiz'], attemptId: extra['attempt_id']);
      }),
      GoRoute(path: '/quizzes/result', builder: (context, state) => QuizResultScreen(result: state.extra as Map<String, dynamic>)),
      GoRoute(path: '/quiz-review', builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final attemptId = extra?['attemptId'] ?? extra?['attempt_id'] ?? 0;
        final testName = extra?['testName'] ?? extra?['quiz_title'];
        if (attemptId <= 0) {
          return const Scaffold(body: Center(child: Text('Invalid Attempt ID', style: TextStyle(color: Colors.red))));
        }
        return QuizReviewScreen(attemptId: attemptId, testName: testName);
      }),
      GoRoute(path: '/certificate', builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final courseId = extra?['courseId'];
        return Scaffold(
          appBar: AppBar(title: const Text("Certificate"), backgroundColor: const Color(0xFF6C5CE7)),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Lottie.asset('assets/lottie/certificate.json', width: 200),
                const SizedBox(height: 20),
                Text("Congratulations!", style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold)),
                Text("Course ID: $courseId Completed!", style: GoogleFonts.poppins(fontSize: 18)),
              ],
            ),
          ),
        );
      }),
    ],
  );
});

// ── APP & SCAFFOLD (UNCHANGED) ─────────────────────
class PrepKingApp extends ConsumerWidget {
  const PrepKingApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

class MainScaffold extends ConsumerStatefulWidget {
  final Widget child;
  const MainScaffold({super.key, required this.child});
  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
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
        const SnackBar(content: Text('Press back again to exit'), backgroundColor: Color(0xFF6C5CE7)),
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: widget.child,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) {
            setState(() => _currentIndex = i);
            context.go(_locations[i]);
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF6C5CE7),
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.menu_book_rounded), label: 'Courses'),
            BottomNavigationBarItem(icon: Icon(Icons.quiz_rounded), label: 'Quizzes'),
            BottomNavigationBarItem(icon: Icon(Icons.emoji_events_rounded), label: 'Leaderboard'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}