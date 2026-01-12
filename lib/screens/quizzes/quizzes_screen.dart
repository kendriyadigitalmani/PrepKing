// lib/screens/quizzes/quizzes_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import '../../core/services/api_service.dart';
import '../../core/utils/user_preferences.dart'; // ← NEW IMPORT

// ✅ UPDATED quizzesProvider - CRASH PROOF
final quizzesProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final response = await api.get('/saved_quiz');
  if (response is Map && response['data'] is List) {
    return response['data'];
  }
  return [];
});

class QuizzesScreen extends ConsumerStatefulWidget {
  const QuizzesScreen({super.key});

  @override
  ConsumerState<QuizzesScreen> createState() => _QuizzesScreenState();
}

class _QuizzesScreenState extends ConsumerState<QuizzesScreen> {
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
          title: Text('Quizzes', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
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

    // Preferences ready → normal quizzes list
    final quizzesAsync = ref.watch(quizzesProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 150,
            flexibleSpace: FlexibleSpaceBar(
              title: Text("Quizzes", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
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
              loading: () => SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator(color: Color(0xFF6C5CE7))),
              ),
              error: (error, stack) => SliverToBoxAdapter(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text("No internet connection", style: GoogleFonts.poppins(fontSize: 18)),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => ref.refresh(quizzesProvider),
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
                              return const Icon(Icons.folder_open, size: 80, color: Colors.grey);
                            },
                          ),
                          const SizedBox(height: 20),
                          Text("No quizzes available", style: GoogleFonts.poppins(fontSize: 18)),
                        ],
                      ),
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final quiz = quizzes[index];
                      // ✅ FIX 2 — Safe isInstantQuiz parsing
                      final isInstant = quiz['isInstantQuiz']?.toString() == "1";
                      // ✅ FIX 1 — Crash-proof difficulty handling
                      final String difficultyText = () {
                        final raw = quiz['difficulty'];
                        if (raw == null) return "Easy";
                        final diff = raw.toString().trim();
                        if (diff.isEmpty || diff.toLowerCase() == "null") return "Easy";
                        if (diff.length == 1) return diff.toUpperCase();
                        return diff[0].toUpperCase() + diff.substring(1).toLowerCase();
                      }();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Card(
                          elevation: 6,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              debugPrint("Opening Quiz ID: ${quiz['id']} - ${quiz['quiz_title']}");
                              context.push('/quizzes/detail', extra: quiz);
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
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Lottie.asset(
                                      isInstant ? 'assets/lottie/lightning.json' : 'assets/lottie/quiz.json',
                                      width: 60,
                                      errorBuilder: (context, error, stack) {
                                        return Icon(
                                            isInstant ? Icons.flash_on : Icons.quiz_rounded,
                                            size: 40,
                                            color: Colors.white
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
                                          quiz['quiz_title'] ?? "Untitled Quiz",
                                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.timer, size: 16, color: Colors.grey[600]),
                                            const SizedBox(width: 4),
                                            Text("${quiz['duration_minutes'] ?? 10} mins", style: GoogleFonts.poppins(fontSize: 14)),
                                            const SizedBox(width: 16),
                                            Icon(Icons.bar_chart, size: 16, color: Colors.grey[600]),
                                            const SizedBox(width: 4),
                                            Text(
                                              difficultyText,
                                              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                        if (quiz['notifyDate'] != null)
                                          Text(
                                            "Date: ${quiz['notifyDate']?.toString().trim().isEmpty ?? true ? "N/A" : quiz['notifyDate']}",
                                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                                          ),
                                        if (isInstant)
                                          Container(
                                            margin: const EdgeInsets.only(top: 8),
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.pink.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              "Instant Quiz",
                                              style: GoogleFonts.poppins(
                                                  color: Colors.pink,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios, color: Colors.grey),
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
          ref.invalidate(quizzesProvider);
        },
        child: const Icon(Icons.refresh_rounded, color: Colors.white),
      ),
    );
  }
}