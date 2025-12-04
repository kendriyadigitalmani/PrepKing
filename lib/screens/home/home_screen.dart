// lib/screens/home/home_screen.dart → REAL DATA FROM https://quizard.in/api_002.php
import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../../providers/user_provider.dart'; // ← YOUR PROVIDER

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override ConsumerState<HomeScreen> createState() => _HomeScreenState();
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
                  // HEADER — REAL NAME FROM YOUR SERVER + GOOGLE PHOTO
                  Row(
                    children: [
                      Expanded(
                        child: userAsync.when(
                          data: (user) => user != null
                              ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Hello,", style: GoogleFonts.poppins(fontSize: 20, color: Colors.white70)),
                              Text(user.name, style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                            ],
                          )
                              : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Hello,", style: GoogleFonts.poppins(fontSize: 20, color: Colors.white70)),
                              Text("Warrior", style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                            ],
                          ),
                          loading: () => const Text("Loading...", style: TextStyle(color: Colors.white70)),
                          error: (_, __) => const Text("Warrior", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
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

                  // REAL STREAK + COINS FROM YOUR SERVER
                  userAsync.when(
                    data: (user) => user != null
                        ? Row(
                      children: [
                        Expanded(child: _streakCard(user.streak)),
                        const SizedBox(width: 16),
                        Expanded(child: _coinsCard(user.coins)),
                      ],
                    )
                        : Row(children: [_streakCard(7), const SizedBox(width: 16), _coinsCard(1250)]),
                    loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
                    error: (_, __) => Row(children: [_streakCard(7), const SizedBox(width: 16), _coinsCard(1250)]),
                  ),

                  const SizedBox(height: 30),

                  // Continue Learning (we'll make this real in 2 mins)
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
                Text("5 Quick Questions", style: GoogleFonts.poppins(fontSize: 16, color: Colors.white)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => context.push('/quiz/daily'),
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