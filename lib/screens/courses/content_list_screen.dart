// lib/screens/content_list_screen.dart

import 'package:animate_do/animate_do.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import '../../providers/course_providers.dart';           // Contains courseContentsProvider
import '../../providers/user_progress_merged_provider.dart'; // Contains userWithProgressProvider

class ContentListScreen extends ConsumerStatefulWidget {
  final int courseId;
  const ContentListScreen({super.key, required this.courseId});

  @override
  ConsumerState<ContentListScreen> createState() => _ContentListScreenState();
}

class _ContentListScreenState extends ConsumerState<ContentListScreen> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _showCompletionCelebration() {
    _confettiController.play();
    Future.delayed(const Duration(seconds: 1), () {
      context.push('/certificate', extra: {'courseId': widget.courseId});
    });
  }

  @override
  Widget build(BuildContext context) {
    // FIXED: Use the correct provider
    final contentsAsync = ref.watch(courseContentsProvider(widget.courseId));
    final userProgressAsync = ref.watch(userWithProgressProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text("Course Content", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF6C5CE7),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          userProgressAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF6C5CE7))),
            error: (_, __) => const Center(child: Text("Error loading progress")),
            data: (user) {
              final completedIds = user.completedContentIds;

              return contentsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(child: Text("Error loading content")),
                data: (contents) {
                  // Auto-celebrate when course is fully completed
                  final allCompleted = contents.isNotEmpty &&
                      contents.every((c) => completedIds.contains(c['id'].toString()));

                  if (allCompleted) {
                    WidgetsBinding.instance.addPostFrameCallback((_) => _showCompletionCelebration());
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: contents.length,
                    itemBuilder: (ctx, i) {
                      final content = contents[i];
                      final contentId = content['id'].toString();
                      final isCompleted = completedIds.contains(contentId);

                      // Lock next lesson until previous is completed
                      final prevContentId = i > 0 ? contents[i - 1]['id'].toString() : null;
                      final isLocked = i > 0 && prevContentId != null && !completedIds.contains(prevContentId);

                      return FadeInLeft(
                        delay: Duration(milliseconds: i * 100),
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 6,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isCompleted ? Colors.green : const Color(0xFF6C5CE7),
                              child: Icon(
                                isCompleted
                                    ? Icons.check
                                    : (isLocked ? Icons.lock : Icons.play_arrow),
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              content['title'] ?? "Lesson ${i + 1}",
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              (content['type'] as String?)?.toUpperCase() ?? "TEXT",
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                            trailing: isCompleted
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : (isLocked
                                ? const Icon(Icons.lock, color: Colors.grey)
                                : const Icon(Icons.arrow_forward_ios, color: Color(0xFF6C5CE7))),
                            enabled: !isLocked,
                            onTap: !isLocked
                                ? () {
                              context.push('/content/player/${content['id']}', extra: content);
                            }
                                : null,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),

          // Confetti Celebration
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              colors: const [Colors.purple, Colors.pink, Colors.blue, Colors.orange, Colors.green],
              emissionFrequency: 0.05,
              numberOfParticles: 50,
            ),
          ),
        ],
      ),
    );
  }
}