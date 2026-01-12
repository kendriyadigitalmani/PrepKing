// lib/screens/quizzes/daily_quizzes_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import '../../core/services/api_service.dart';
import '../../core/utils/user_preferences.dart'; // ← NEW IMPORT

/// Provider for fetching Daily Quizzes
/// Endpoint: https://quizard.in/api_002.php/saved_quiz?type=quiz_daily
final dailyQuizzesProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final response = await api.get('/saved_quiz', query: {'type': 'quiz_daily'});
  if (response is Map<String, dynamic> &&
      response['success'] == true &&
      response['data'] is List) {
    return List<dynamic>.from(response['data']);
  }
  return [];
});

class DailyQuizzesScreen extends ConsumerStatefulWidget {
  const DailyQuizzesScreen({super.key});

  @override
  ConsumerState<DailyQuizzesScreen> createState() => _DailyQuizzesScreenState();
}

class _DailyQuizzesScreenState extends ConsumerState<DailyQuizzesScreen> {
  bool _isPrefsReady = false;
  bool _isLoadingPrefs = true;

  @override
  void initState() {
    super.initState();
    _checkPreferences();
  }

  Future<void> _checkPreferences() async {
    final prefs = UserPreferences();
    final ready = await prefs.isPreferencesReady();

    if (mounted) {
      setState(() {
        _isPrefsReady = ready;
        _isLoadingPrefs = false;
      });
    }
  }

  // UI when Language & Exams are not selected
  Widget _buildMissingPrefsView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.settings, size: 80, color: const Color(0xFF6C5CE7)),
            const SizedBox(height: 24),
            Text(
              'Please Select Language and Exams',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Go to Settings under Profile to set your Language and Exams.',
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.settings, color: Colors.white),
              label: Text(
                'Go to Settings',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: () {
                context.push('/profile/settings').then((_) {
                  // Re-check preferences when returning from settings
                  _checkPreferences();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking preferences
    if (_isLoadingPrefs) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
        ),
      );
    }

    // If preferences not ready → show message
    if (!_isPrefsReady) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF6C5CE7),
          title: Text('Daily Quizzes', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          elevation: 0,
        ),
        body: _buildMissingPrefsView(),
        floatingActionButton: FloatingActionButton(
          backgroundColor: const Color(0xFF6C5CE7),
          onPressed: _checkPreferences,
          child: const Icon(Icons.refresh, color: Colors.white),
        ),
      );
    }

    // Preferences ready → normal daily quizzes list
    final quizzesAsync = ref.watch(dailyQuizzesProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 150,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                "Daily Quizzes",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF6C5CE7), Color(0xFF4A3CB7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            pinned: true,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: quizzesAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
                ),
              ),
              error: (error, stack) => SliverToBoxAdapter(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        "No internet connection",
                        style: GoogleFonts.poppins(fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => ref.refresh(dailyQuizzesProvider),
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                ),
              ),
              data: (quizzes) {
                if (quizzes.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Lottie.asset(
                            'assets/lottie/empty.json',
                            width: 200,
                            errorBuilder: (context, error, stack) {
                              return const Icon(Icons.folder_open,
                                  size: 80, color: Colors.grey);
                            },
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "No daily quiz available today",
                            style: GoogleFonts.poppins(fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Check back tomorrow!",
                            style: GoogleFonts.poppins(
                                fontSize: 14, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final quiz = quizzes[index];
                      // ✅ Robust Instant Quiz Detection (for list UI only)
                      final bool isInstant = () {
                        final value = quiz['isInstantQuiz'] ?? quiz['instantquiz'];
                        if (value is bool) return value;
                        if (value is int && value == 1) return true;
                        if (value is String &&
                            (value == "1" || value.toLowerCase() == "true")) {
                          return true;
                        }
                        final type = quiz['type']?.toString().trim();
                        return type == 'quiz_daily';
                      }();
                      // Safe difficulty handling
                      final String difficultyText = () {
                        final raw = quiz['difficulty'];
                        if (raw == null) return "Medium";
                        final diff = raw.toString().trim();
                        if (diff.isEmpty || diff.toLowerCase() == "null") {
                          return "Medium";
                        }
                        if (diff.length == 1) return diff.toUpperCase();
                        return diff[0].toUpperCase() +
                            diff.substring(1).toLowerCase();
                      }();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Card(
                          elevation: 6,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                          ),
                          child: InkWell(
                            borderRadius: const BorderRadius.all(Radius.circular(20)),
                            // 🔥 KEY FIX: Normalize quiz object BEFORE navigation
                            onTap: () {
                              final Map<String, dynamic> normalizedQuiz = {
                                ...quiz,
                                'isInstantQuiz': 1, // Force instant behavior
                                'instantquiz': 1, // Backward compatibility
                                // 'type' remains 'quiz_daily' if needed elsewhere
                              };
                              context.push('/quizzes/detail', extra: normalizedQuiz);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: isInstant
                                            ? [Colors.pinkAccent, Colors.purple]
                                            : [const Color(0xFF6C5CE7), const Color(0xFF4A3CB7)],
                                      ),
                                      borderRadius: const BorderRadius.all(Radius.circular(16)),
                                    ),
                                    child: Lottie.asset(
                                      isInstant ? 'assets/lottie/lightning.json' : 'assets/lottie/quiz.json',
                                      width: 60,
                                      errorBuilder: (context, error, stack) {
                                        return Icon(
                                          isInstant ? Icons.flash_on : Icons.quiz_rounded,
                                          size: 40,
                                          color: Colors.white,
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
                                          quiz['quiz_title'] ?? "Daily Quiz",
                                          style: GoogleFonts.poppins(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(Icons.timer,
                                                size: 16,
                                                color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(
                                              "${quiz['duration_minutes'] ?? 30} mins",
                                              style: GoogleFonts.poppins(fontSize: 14),
                                            ),
                                            const SizedBox(width: 16),
                                            const Icon(Icons.bar_chart,
                                                size: 16,
                                                color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(
                                              difficultyText,
                                              style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                        if (isInstant) ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.pink.withOpacity(0.2),
                                              borderRadius: const BorderRadius.all(Radius.circular(20)),
                                            ),
                                            child: Text(
                                              "Instant Quiz",
                                              style: GoogleFonts.poppins(
                                                color: Colors.pink,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios,
                                      color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: quizzes.length,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF6C5CE7),
        onPressed: () {
          _checkPreferences(); // Re-check prefs on refresh
          ref.invalidate(dailyQuizzesProvider);
        },
        child: const Icon(Icons.refresh_rounded, color: Colors.white),
      ),
    );
  }
}