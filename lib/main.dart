// lib/main.dart ← FINAL PRODUCTION VERSION – PREPKING 2025
import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ProviderScope(child: PrepKingApp()));
}

// ── Providers ─────────────────────
final googleSignInProvider = Provider((ref) => GoogleSignIn());
final authProvider = Provider((ref) => FirebaseAuth.instance);
final authStateProvider = StreamProvider<User?>((ref) =>
    ref.watch(authProvider).authStateChanges());

// For checking first-time user
final sharedPrefsProvider = FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

// ── Router with Onboarding Logic ─────────────────────
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStateProvider);
  final prefsAsync = ref.watch(sharedPrefsProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final loggedIn = auth.value != null;
      final atSplash = state.matchedLocation == '/splash';
      final seenOnboarding = prefsAsync.value?.getBool('seenOnboarding') ?? false;

      if (atSplash) {
        if (loggedIn) {
          return seenOnboarding ? '/home' : '/onboarding';
        }
        return '/login';
      }

      if (!loggedIn && !state.matchedLocation.startsWith('/login')) return '/login';
      if (loggedIn && state.matchedLocation == '/login') return '/home';

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
    ],
  );
});

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

// ── Splash Screen ─────────────────────
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  @override
  void dispose() {
    _controller.dispose();
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
            Lottie.asset(
              'assets/lottie/splash.json',
              controller: _controller,
              onLoaded: (c) {
                _controller
                  ..duration = c.duration
                  ..forward().whenComplete(() => Future.delayed(
                      const Duration(milliseconds: 800), () => context.go('/home')));
              },
              width: 260,
            ),
            const SizedBox(height: 40),
            FadeInDown(
                child: Text('PrepKing',
                    style: GoogleFonts.poppins(
                        fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white))),
            const SizedBox(height: 12),
            FadeInUp(
                child: Text('Master Any Exam. Anytime. Anywhere.',
                    style: GoogleFonts.poppins(fontSize: 17, color: Colors.white70))),
            const SizedBox(height: 100),
            const DotsLoader(),
          ],
        ),
      ),
    );
  }
}

// ── Onboarding Screen (3 Gorgeous Pages) ─────────────────────
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> onboardingData = [
    {
      "title": "Practice Smart",
      "text": "Thousands of questions with detailed solutions",
      "lottie": "practice.json"
    },
    {
      "title": "Track Progress",
      "text": "See your improvement with beautiful analytics",
      "lottie": "progress.json"
    },
    {
      "title": "Compete & Win",
      "text": "Join live contests and climb the leaderboard",
      "lottie": "trophy.json"
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF6C5CE7),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: onboardingData.length,
                itemBuilder: (context, index) => OnboardingPage(data: onboardingData[index]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(3, (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(right: 8),
                      height: 10,
                      width: _currentPage == i ? 30 : 10,
                      decoration: BoxDecoration(
                        color: _currentPage == i ? Colors.white : Colors.white38,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    )),
                  ),
                  FloatingActionButton(
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.arrow_forward, color: Color(0xFF6C5CE7)),
                    onPressed: () async {
                      if (_currentPage == 2) {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('seenOnboarding', true);
                        if (mounted) context.go('/home');
                      } else {
                        _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.ease);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingPage extends StatelessWidget {
  final Map<String, String> data;
  const OnboardingPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset('assets/lottie/${data["lottie"]}', width: 300),
          const SizedBox(height: 60),
          Text(data["title"]!, style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 20),
          Text(data["text"]!, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 18, color: Colors.white70)),
        ],
      ),
    );
  }
}

// ── Login Screen (unchanged – perfect) ─────────────────────
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
    } catch (e) { debugPrint(e.toString()); }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF6C5CE7),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElasticIn(child: Text('Welcome to PrepKing', style: GoogleFonts.poppins(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white))),
            const SizedBox(height: 80),
            ElevatedButton.icon(
              onPressed: () => _googleSignIn(ref),
              icon: const Icon(Icons.g_mobiledata, size: 34, color: Colors.red),
              label: Text('Continue with Google', style: GoogleFonts.poppins(fontSize: 18, color: Colors.black87)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black87, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Home Screen with Modern Dashboard ─────────────────────
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF6C5CE7), Color(0xFF4A3CB7)])),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Hello,', style: GoogleFonts.poppins(fontSize: 20, color: Colors.white70)),
                      Text('PrepKing Warrior!', style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                    ]),
                    CircleAvatar(radius: 28, backgroundColor: Colors.white24, child: Icon(Icons.person, size: 36, color: Colors.white)),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(40))),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const SizedBox(height: 30),
                        Text('What do you want to master today?', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 40),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          mainAxisSpacing: 20,
                          crossAxisSpacing: 20,
                          children: [
                            _featureCard(Icons.menu_book, 'Practice', Colors.purple),
                            _featureCard(Icons.bar_chart, 'Leaderboard', Colors.orange),
                            _featureCard(Icons.timer, 'Mock Tests', Colors.green),
                            _featureCard(Icons.emoji_events, 'Live Contests', Colors.red),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureCard(IconData icon, String title, Color color) {
    return Container(
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: color),
          const SizedBox(height: 16),
          Text(title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

// DotsLoader (unchanged)
class DotsLoader extends StatefulWidget {
  const DotsLoader({super.key});
  @override State<DotsLoader> createState() => _DotsLoaderState();
}

class _DotsLoaderState extends State<DotsLoader> with TickerProviderStateMixin {
  late final List<AnimationController> _controllers = List.generate(3, (_) => AnimationController(vsync: this, duration: const Duration(milliseconds: 600)))..forEach((c) => c.repeat(reverse: true));
  @override void dispose() { for (var c in _controllers) {
    c.dispose();
  }  super.dispose(); }
  @override Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) => ScaleTransition(
      scale: Tween<double>(begin: 0.4, end: 1).animate(CurvedAnimation(parent: _controllers[i], curve: Curves.easeInOut)),
      child: Container(margin: const EdgeInsets.symmetric(horizontal: 4), width: 10, height: 10, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
    )));
  }
}