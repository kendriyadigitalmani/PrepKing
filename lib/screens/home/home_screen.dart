// lib/screens/home/home_screen.dart
import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../../providers/user_provider.dart';
import '../../core/utils/user_preferences.dart';
import '../../providers/continue_learning_provider.dart'; // ← Uses /user_progress/{userId}
import '../../widgets/language_select_dialog.dart';
import '../../widgets/exam_select_dialog.dart';
import '../../models/user_model.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _fireController;
  bool _hasCheckedDialogs = false;

  @override
  void initState() {
    super.initState();
    _fireController = AnimationController(vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final userAsync = ref.read(currentUserProvider);
      if (userAsync.asData == null || userAsync.asData?.value == null) return;
      UserModel user = userAsync.asData!.value!;
      user = await _loadPrefsIfMissing(user);
      if (!_hasCheckedDialogs) {
        _hasCheckedDialogs = true;
        if (user.languageId == null) {
          final languageSelected = await showLanguageSelectDialog(context);
          if (languageSelected == true && user.examIds.isEmpty) {
            await showExamSelectDialog(context);
          }
        } else if (user.examIds.isEmpty) {
          await showExamSelectDialog(context);
        }
      }
    });
  }

  Future<UserModel> _loadPrefsIfMissing(UserModel user) async {
    final prefs = UserPreferences();
    final storedLanguage = await prefs.getLanguage();
    final storedExams = await prefs.getExams();
    bool needsUpdate = false;
    UserModel updatedUser = user;
    if (user.languageId == null && storedLanguage != null) {
      updatedUser = user.copyWith(languageId: storedLanguage);
      needsUpdate = true;
    }
    if (user.examIds.isEmpty && storedExams.isNotEmpty) {
      updatedUser = updatedUser.copyWith(examIds: storedExams);
      needsUpdate = true;
    }
    if (needsUpdate) {
      ref.invalidate(currentUserProvider);
    }
    return updatedUser;
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
                  // HEADER
                  Row(
                    children: [
                      Expanded(
                        child: userAsync.when(
                          data: (user) {
                            if (user != null) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Hello,",
                                      style: GoogleFonts.poppins(
                                          fontSize: 20, color: Colors.white70)),
                                  Text(user.name,
                                      style: GoogleFonts.poppins(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white)),
                                ],
                              );
                            } else {
                              return _buildFallbackHeader();
                            }
                          },
                          loading: () => _buildFallbackHeader(),
                          error: (_, __) => _buildFallbackHeader(),
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
                  // Streak & Coins
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
                  // Continue Learning Section – NOW LOCKED TO BACKEND PROGRESS
                  _buildContinueLearningSection(),
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

  Widget _buildFallbackHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Hello,",
            style: GoogleFonts.poppins(fontSize: 20, color: Colors.white70)),
        Text("PrepKing Warrior",
            style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
      ],
    );
  }

  Widget _buildFallbackStats() {
    return Row(
      children: [
        Expanded(child: _streakCard(7)),
        const SizedBox(width: 16),
        Expanded(child: _coinsCard(1250)),
      ],
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
          Lottie.asset('assets/lottie/fire.json',
              controller: _fireController,
              onLoaded: (c) {
                _fireController
                  ..duration = c.duration
                  ..repeat();
              },
              height: 60),
          Text("$streak Day Streak",
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
          Text("Keep burning!",
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70)),
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
          Text(coins.toString(),
              style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          Text("Coins",
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.white)),
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
                Text("Daily Challenge",
                    style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                Text("Current Affairs Quiz",
                    style: GoogleFonts.poppins(fontSize: 16, color: Colors.white)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => context.push('/quizzes/daily'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.purple),
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
        Text(title,
            style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w600, color: color)),
      ],
    ),
  );

  // ==================== CONTINUE LEARNING SECTION (NOW ACCURATE) ====================
  Widget _buildContinueLearningSection() {
    final userAsync = ref.watch(currentUserProvider);
    return userAsync.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();
        final progressAsync = ref.watch(continueLearningProvider(user.id));
        return progressAsync.when(
          loading: () => _continueSkeleton(),
          error: (_, __) => const SizedBox.shrink(),
          data: (courses) {
            if (courses.isEmpty) return const SizedBox.shrink();
            return Column(
              children: courses.map((item) => _continueCourseCard(item)).toList(),
            );
          },
        );
      },
      loading: () => _continueSkeleton(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _continueCourseCard(Map<String, dynamic> item) => FadeInUp(
    child: GestureDetector(
        onTap: () {
          final courseId = item['course_id'] as int?;
          if (courseId != null && courseId > 0) {
            context.push('/courses/detail/$courseId');
          }
        },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 20),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Continue Learning",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    item['course_image'] ?? '',
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[300],
                      child: const Icon(Icons.menu_book, color: Colors.grey),
                    ),
                    loadingBuilder: (_, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[300],
                        child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['title'] ?? 'Untitled Course',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // FIXED: Use backend progress_percentage directly
                      LinearProgressIndicator(
                        value: (double.tryParse(
                            item['progress_percentage']?.toString() ?? '0') ??
                            0.0) /
                            100.0,
                        backgroundColor: Colors.grey[300],
                        valueColor:
                        const AlwaysStoppedAnimation(Color(0xFF6C5CE7)),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${(double.tryParse(item['progress_percentage']?.toString() ?? '0') ?? 0.0).toStringAsFixed(0)}% Complete",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF6C5CE7),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Color(0xFF6C5CE7),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _continueSkeleton() => FadeInUp(
    child: Container(
      height: 160,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
      ),
    ),
  );
}