// lib/screens/quizzes/quizzes_screen.dart — UPDATED & CRASH-PROOF
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../../core/services/api_service.dart';

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
  @override
  Widget build(BuildContext context) {
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
                        // If null, return default value
                        if (raw == null) return "Easy";
                        final diff = raw.toString().trim();
                        // If empty or "null", return default
                        if (diff.isEmpty || diff.toLowerCase() == "null") return "Easy";
                        // If only one letter
                        if (diff.length == 1) return diff.toUpperCase();
                        // Normal case
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
                                      // ✅ FIX 3 — Prevent crash if Lottie asset missing
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
                                        // ✅ FIX 4 — Null-safe date formatting (if you have date display)
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
    );
  }
}