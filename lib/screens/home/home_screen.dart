// lib/screens/home/home_screen.dart

import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../../providers/user_provider.dart';
// ✅ Add UserPreferences import
import '../../core/utils/user_preferences.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _fireController;

  @override
  void initState() {
    super.initState();
    _fireController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _fireController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6C5CE7), Color(0xFF4A3CB7)],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(currentUserProvider.future),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HEADER — Use provider data first, fallback to UserPreferences if needed
                  Row(
                    children: [
                      Expanded(
                        child: userAsync.when(
                          data: (user) {
                            if (user != null) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Hello,", style: GoogleFonts.poppins(fontSize: 20, color: Colors.white70)),
                                  Text(user.name, style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                                ],
                              );
                            } else {
                              // Provider returned null → try local cache
                              return _buildFallbackHeader();
                            }
                          },
                          loading: () => _buildFallbackHeader(), // Show cached while loading
                          error: (_, __) => _buildFallbackHeader(), // Show cached on error
                        ),
                      ),
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white24,
                        backgroundImage: FirebaseAuth.instance.currentUser?.photoURL != null
                            ? NetworkImage(FirebaseAuth.instance.currentUser!.photoURL!)
                            : null,
                        child: FirebaseAuth.instance.currentUser?.photoURL == null
                            ? const Icon(Icons.person, size: 36, color: Colors.white)
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  // Streak & Coins — same logic: provider first, fallback to local
                  userAsync.when(
                    data: (user) {
                      if (user != null) {
                        return Row(
                          children: [
                            Expanded(child: _streakCard(user.streak)),
                            const SizedBox(width: 16),
                            Expanded(child: _coinsCard(user.coins)),
                          ],
                        );
                      } else {
                        return _buildFallbackStats();
                      }
                    },
                    loading: () => _buildFallbackStats(),
                    error: (_, __) => _buildFallbackStats(),
                  ),
                  const SizedBox(height: 30),
                  _continueCard("Algebra Mastery", 0.75),
                  const SizedBox(height: 20),
                  _dailyChallengeCard(),
                  const SizedBox(height: 20),
                  _quickActions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ Fallback using UserPreferences
  Widget _buildFallbackHeader() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: UserPreferences().getUserData(),
      builder: (context, snapshot) {
        final name = snapshot.data?['name'] ?? 'Warrior';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Hello,", style: GoogleFonts.poppins(fontSize: 20, color: Colors.white70)),
            Text(name, style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        );
      },
    );
  }

  Widget _buildFallbackStats() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: UserPreferences().getUserData(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final streak = data?['streak'] as int? ?? 7;
        final coins = data?['coins'] as int? ?? 1250;
        return Row(
          children: [
            Expanded(child: _streakCard(streak)),
            const SizedBox(width: 16),
            Expanded(child: _coinsCard(coins)),
          ],
        );
      },
    );
  }

  // ... rest of your widgets unchanged (_streakCard, _coinsCard, etc.)
  Widget _streakCard(int streak) => FadeInLeft(
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          Lottie.asset('assets/lottie/fire.json', controller: _fireController, onLoaded: (c) {
            _fireController
              ..duration = c.duration
              ..repeat();
          }, height: 60),
          Text("$streak Day Streak", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
          Text("Keep burning!", style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70)),
        ],
      ),
    ),
  );

  Widget _coinsCard(int coins) => FadeInRight(
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Colors.amber, Colors.orange]),
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: Column(
        children: [
          Lottie.asset('assets/lottie/coin.json', height: 60),
          Text(coins.toString(), style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          Text("Coins", style: GoogleFonts.poppins(fontSize: 14, color: Colors.white)),
        ],
      ),
    ),
  );

  // ... _continueCard, _dailyChallengeCard, _quickActions — unchanged
  Widget _continueCard(String title, double progress) => FadeInUp(
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Continue Learning", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset("assets/images/course_placeholder.jpg", width: 80, height: 80, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: Colors.grey[300], child: const Icon(Icons.menu_book)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: progress, backgroundColor: Colors.grey[300], valueColor: const AlwaysStoppedAnimation(Color(0xFF6C5CE7))),
                    const SizedBox(height: 8),
                    Text("${(progress * 100).toInt()}% Complete", style: GoogleFonts.poppins(fontSize: 14)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Color(0xFF6C5CE7)),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _dailyChallengeCard() => FadeInUp(
    delay: const Duration(milliseconds: 200),
    child: Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Colors.pinkAccent, Colors.purple]),
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      child: Row(
        children: [
          Lottie.asset('assets/lottie/daily.json', width: 100),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Daily Challenge", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                Text("Current Affairs Quiz", style: GoogleFonts.poppins(fontSize: 16, color: Colors.white)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => context.push('/quizzes/daily'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.purple),
                  child: const Text("Start Now"),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _quickActions() => FadeInUp(
    delay: const Duration(milliseconds: 400),
    child: GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.6,
      children: [
        _quickAction("Practice", Icons.menu_book, Colors.blue),
        _quickAction("Mock Test", Icons.timer, Colors.green),
        _quickAction("Leaderboard", Icons.emoji_events, Colors.orange),
        _quickAction("Certificates", Icons.card_membership, Colors.purple),
      ],
    ),
  );

  Widget _quickAction(String title, IconData icon, Color color) => Container(
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 48, color: color),
        const SizedBox(height: 12),
        Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: color)),
      ],
    ),
  );
}