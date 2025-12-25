// lib/screens/courses/content_list_screen.dart
import 'package:animate_do/animate_do.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import '../../providers/course_providers.dart'; // Contains courseContentsProvider
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
      if (mounted) {
        context.push('/certificate', extra: {'courseId': widget.courseId});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final contentsAsync = ref.watch(courseContentsProvider(widget.courseId));
    final userProgressAsync = ref.watch(userWithProgressProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Course Content",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color(0xFF6C5CE7),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          userProgressAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF6C5CE7))),
            error: (_, __) => const Center(child: Text("Error loading progress")),
            data: (user) {
              final Set<String> completedIds = user?.completedContentIds ?? {};

              return contentsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(child: Text("Error loading content")),
                data: (contents) {
                  // Auto-celebrate when course is fully completed
                  final allCompleted = contents.isNotEmpty &&
                      contents.every(
                              (c) => completedIds.contains(c['id'].toString()));

                  if (allCompleted) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _showCompletionCelebration();
                    });
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: contents.length,
                    itemBuilder: (ctx, i) {
                      final content = contents[i];
                      final contentId = content['id'].toString();
                      final isCompleted = completedIds.contains(contentId);

                      // Lock next lesson until previous is completed
                      final prevContentId =
                      i > 0 ? contents[i - 1]['id'].toString() : null;
                      final isLocked = i > 0 &&
                          prevContentId != null &&
                          !completedIds.contains(prevContentId);

                      // Determine content type
                      final String rawType = (content['type'] as String?)
                          ?.toLowerCase()
                          .trim() ??
                          'text';

                      String route;
                      switch (rawType) {
                        case 'video':
                        case 'youtube':
                        case 'vimeo':
                          route = '/courses/content/video';
                          break;
                        case 'audio':
                          route = '/courses/content/audio';
                          break;
                        case 'quiz':
                        case 'mcq':
                        case 'assessment':
                          route = '/courses/content/quiz';
                          break;
                        case 'pdf':
                        case 'document':
                        case 'file':
                          route = '/courses/content/pdf';
                          break;
                        case 'text':
                        case 'article':
                        case 'lesson':
                        case 'html':
                        case 'markdown':
                        default:
                          route = '/courses/content/text';
                          break;
                      }

                      // Choose appropriate icon based on type
                      IconData typeIcon;
                      switch (rawType) {
                        case 'video':
                        case 'youtube':
                        case 'vimeo':
                          typeIcon = Icons.play_circle_filled;
                          break;
                        case 'audio':
                          typeIcon = Icons.headset;
                          break;
                        case 'quiz':
                        case 'mcq':
                        case 'assessment':
                          typeIcon = Icons.quiz;
                          break;
                        case 'pdf':
                        case 'document':
                        case 'file':
                          typeIcon = Icons.picture_as_pdf;
                          break;
                        default:
                          typeIcon = Icons.description;
                          break;
                      }

                      return FadeInUp(
                        delay: Duration(milliseconds: i * 100),
                        duration: const Duration(milliseconds: 600),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              colors: isLocked
                                  ? [Colors.grey.shade300, Colors.grey.shade400]
                                  : isCompleted
                                  ? [
                                Colors.green.shade400,
                                Colors.green.shade600
                              ]
                                  : [
                                const Color(0xFF6C5CE7),
                                const Color(0xFF4A43B0)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            leading: CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.white.withOpacity(0.3),
                              child: Icon(
                                isCompleted
                                    ? Icons.check_rounded
                                    : (isLocked ? Icons.lock_rounded : typeIcon),
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            title: Text(
                              content['title'] ?? "Lesson ${i + 1}",
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 17,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Row(
                                children: [
                                  Icon(
                                    typeIcon,
                                    color: Colors.white70,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    (content['type'] as String?)
                                        ?.toUpperCase() ??
                                        "TEXT",
                                    style: GoogleFonts.poppins(
                                      color: Colors.white70,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: isCompleted
                                ? const Icon(Icons.check_circle_rounded,
                                color: Colors.white, size: 32)
                                : (isLocked
                                ? const Icon(Icons.lock_outline,
                                color: Colors.white70, size: 28)
                                : const Icon(Icons.arrow_forward_ios_rounded,
                                color: Colors.white, size: 24)),
                            enabled: !isLocked,
                            onTap: !isLocked
                                ? () {
                              context.push(route, extra: content);
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

          // Confetti Celebration (full screen)
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              colors: const [
                Colors.purple,
                Colors.pink,
                Colors.blue,
                Colors.orange,
                Colors.green,
                Colors.yellow
              ],
              emissionFrequency: 0.05,
              numberOfParticles: 80,
              gravity: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}