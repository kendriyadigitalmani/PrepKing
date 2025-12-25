// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

// ───────── SCREENS ──────────────────────────────────────────────────
import 'screens/home/home_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/quizzes/quizzes_screen.dart';
import 'screens/quizzes/daily_quizzes_screen.dart';
import 'screens/quizzes/quiz_detail_screen.dart';
import 'screens/quizzes/standard_quiz_player_screen.dart';
import 'screens/quizzes/instant_quiz_player_screen.dart';
import 'screens/quizzes/quiz_result_screen.dart';
import 'screens/quizzes/quiz_review_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/leaderboard/leaderboard_screen.dart';

// ───────── COURSES SCREENS ──────────────────────────────────────────
import 'screens/courses/course_list_screen.dart';
import 'screens/courses/course_detail_screen.dart';
import 'screens/courses/content_list_screen.dart';
import 'screens/courses/contents/pdf_content_screen.dart';
import 'screens/courses/contents/quiz_content_screen.dart';
import 'screens/courses/contents/text_content_screen.dart';
import 'screens/courses/contents/video_content_screen.dart';
import 'screens/courses/contents/audio_player_screen.dart';
import 'screens/courses/contents/text_audio_player_screen.dart'; // ← NEW IMPORT

// ───────── PROFILE SUB-SCREENS (REAL IMPLEMENTATIONS) ───────────────
import 'screens/profile/edit_profile_screen.dart';
import 'screens/profile/certificates_screen.dart';
import 'screens/profile/quiz_history_screen.dart';
import 'screens/profile/coin_store_screen.dart';
import 'screens/profile/help_support_screen.dart';
import 'screens/profile/about_prepking_screen.dart';

// ───────── SETTINGS SCREEN ──────────────────────────────────────────
import 'screens/profile/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 🔥 Firebase initialization has been completely removed from here.
  // It is now handled asynchronously inside appInitProvider (triggered from SplashScreen)
  // This ensures the splash animation starts instantly with zero blocking.
  runApp(const ProviderScope(child: PrepKingApp()));
}

// ───────── ROUTER ───────────────────────────────────────────────────
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (_, __) => null,
    debugLogDiagnostics: false,
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/login/email', builder: (_, __) => const EmailLoginScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
              path: '/home',
              pageBuilder: (_, __) => const NoTransitionPage(child: HomeScreen())),
          GoRoute(
            path: '/courses',
            pageBuilder: (_, __) =>
            const NoTransitionPage(child: CourseListScreen()),
            routes: [
              GoRoute(
                path: 'detail/:id',
                builder: (context, state) {
                  final idStr = state.pathParameters['id']!;
                  final id = int.tryParse(idStr);
                  if (id == null) {
                    return Scaffold(
                        body: Center(child: Text('Invalid course ID: $idStr')));
                  }
                  return CourseDetailScreen(courseId: id);
                },
              ),
              GoRoute(
                path: 'content/text',
                builder: (context, state) =>
                    TextContentScreen(content: state.extra as Map<String, dynamic>),
              ),
              GoRoute(
                path: 'content/video',
                builder: (context, state) =>
                    VideoContentScreen(content: state.extra as Map<String, dynamic>),
              ),
              GoRoute(
                path: 'content/pdf',
                builder: (context, state) =>
                    PdfContentScreen(content: state.extra as Map<String, dynamic>),
              ),
              GoRoute(
                path: 'content/quiz',
                builder: (context, state) =>
                    QuizContentScreen(content: state.extra as Map<String, dynamic>),
              ),
              GoRoute(
                path: 'content/audio',
                builder: (context, state) =>
                    AudioPlayerScreen(content: state.extra as Map<String, dynamic>),
              ),
              // ← NEW ROUTE FOR TEXT-TO-SPEECH PLAYER
              GoRoute(
                path: 'content/text-audio',
                builder: (context, state) {
                  final data = state.extra as Map<String, dynamic>;
                  return TextAudioPlayerScreen(
                    title: data['title'] as String,
                    text: data['text'] as String,
                  );
                },
              ),
              GoRoute(
                path: 'content/:courseId',
                builder: (context, state) {
                  final idStr = state.pathParameters['courseId']!;
                  final courseId = int.tryParse(idStr);
                  if (courseId == null) {
                    return Scaffold(
                      body: Center(child: Text('Invalid course ID: "$idStr"')),
                    );
                  }
                  return ContentListScreen(courseId: courseId);
                },
              ),
            ],
          ),
          GoRoute(
              path: '/quizzes',
              pageBuilder: (_, __) =>
              const NoTransitionPage(child: QuizzesScreen())),
          GoRoute(
            path: '/quizzes/daily',
            pageBuilder: (_, __) =>
            const NoTransitionPage(child: DailyQuizzesScreen()),
          ),
          GoRoute(
              path: '/leaderboard',
              pageBuilder: (_, __) =>
              const NoTransitionPage(child: LeaderboardScreen())),
          GoRoute(
            path: '/profile',
            pageBuilder: (_, __) =>
            const NoTransitionPage(child: ProfileScreen()),
            routes: [
              GoRoute(
                  path: 'certificates',
                  builder: (_, __) => const CertificatesScreen()),
              GoRoute(
                  path: 'history', builder: (_, __) => const QuizHistoryScreen()),
              GoRoute(
                  path: 'edit', builder: (_, __) => const EditProfileScreen()),
              GoRoute(
                  path: 'settings',
                  builder: (_, __) => const SettingsScreen()),
              GoRoute(path: 'coins', builder: (_, __) => const CoinStoreScreen()),
              GoRoute(path: 'help', builder: (_, __) => const HelpSupportScreen()),
              GoRoute(path: 'about', builder: (_, __) => const AboutPrepKingScreen()),
            ],
          ),
        ],
      ),
      // ───────── Standalone routes ────────────────────────────────────────
      GoRoute(
          path: '/quizzes/detail',
          builder: (context, state) =>
              QuizDetailScreen(quiz: state.extra as Map<String, dynamic>)),
      GoRoute(
          path: '/q/:slug',
          builder: (context, state) => Scaffold(
              body: Center(
                  child: Text('Loading quiz: ${state.pathParameters['slug']}')))),
      GoRoute(path: '/quizzes/instant-player', builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return InstantQuizPlayerScreen(
            quiz: extra['quiz'], attemptId: extra['attempt_id']);
      }),
      GoRoute(path: '/quizzes/standard-player', builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return StandardQuizPlayerScreen(
            quiz: extra['quiz'], attemptId: extra['attempt_id']);
      }),
      GoRoute(
          path: '/quizzes/result',
          builder: (context, state) =>
              QuizResultScreen(result: state.extra as Map<String, dynamic>)),
      GoRoute(path: '/quiz-review', builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final attemptId = extra?['attemptId'] ?? extra?['attempt_id'] ?? 0;
        final testName = extra?['testName'] ?? extra?['quiz_title'];
        if (attemptId <= 0) {
          return const Scaffold(
              body: Center(
                  child: Text('Invalid Attempt ID',
                      style: TextStyle(color: Colors.red))));
        }
        return QuizReviewScreen(attemptId: attemptId, testName: testName);
      }),
      GoRoute(path: '/certificate', builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final courseId = extra?['courseId'];
        return Scaffold(
          appBar: AppBar(
              title: const Text("Certificate"),
              backgroundColor: const Color(0xFF6C5CE7)),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Lottie.asset('assets/lottie/certificate.json', width: 200),
                const SizedBox(height: 20),
                Text("Congratulations!",
                    style: GoogleFonts.poppins(
                        fontSize: 28, fontWeight: FontWeight.bold)),
                Text("Course ID: $courseId Completed!",
                    style: GoogleFonts.poppins(fontSize: 18)),
              ],
            ),
          ),
        );
      }),
    ],
  );
});

// ───────── APP & SCAFFOLD ───────────────────────────────────────────
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
  final List<String> _locations = [
    '/home',
    '/courses',
    '/quizzes',
    '/leaderboard',
    '/profile'
  ];
  DateTime? _lastBackPressTime;

  Future<bool> _onWillPop() async {
    final now = DateTime.now();
    if (_currentIndex != 0) return true;
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Press back again to exit'),
            backgroundColor: Color(0xFF6C5CE7)),
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    // Sync bottom navigation index with current route
    final index = _locations.indexWhere((path) => location.startsWith(path));
    if (index != -1 && index != _currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _currentIndex = index);
        }
      });
    }
    // Hide bottom bar when viewing the audio player screen
    final hideBottomBar = location.contains('/content/audio');

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: widget.child,
        bottomNavigationBar: hideBottomBar
            ? null
            : BottomNavigationBar(
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
            BottomNavigationBarItem(
                icon: Icon(Icons.menu_book_rounded), label: 'Courses'),
            BottomNavigationBarItem(icon: Icon(Icons.quiz_rounded), label: 'Quizzes'),
            BottomNavigationBarItem(
                icon: Icon(Icons.emoji_events_rounded), label: 'Leaderboard'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}