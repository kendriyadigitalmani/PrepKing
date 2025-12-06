import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../../providers/course_providers.dart';
import '../../providers/user_progress_merged_provider.dart'; // ← NEW

class CourseDetailScreen extends ConsumerWidget {
  final int courseId;
  const CourseDetailScreen({super.key, required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseAsync = ref.watch(courseDetailProvider(courseId));
    final userProgressAsync = ref.watch(userWithProgressProvider); // ← FIXED

    return Scaffold(
      body: courseAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF6C5CE7))),
        error: (_, __) => const Center(child: Text("Failed to load course")),
        data: (course) {
          final progress = userProgressAsync.value?.courseProgress[courseId.toString()] ?? 0.0;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    course['course_title'] ?? "Course",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        course['thumbnail'] ?? "https://via.placeholder.com/600x400/6C5CE7/FFFFFF?text=${course['course_title']?.substring(0,2)}",
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: const Color(0xFF6C5CE7)),
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                backgroundColor: const Color(0xFF6C5CE7),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FadeInUp(
                        child: Text(
                          "Course Progress",
                          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.grey[300],
                              valueColor: const AlwaysStoppedAnimation(Color(0xFF6C5CE7)),
                              minHeight: 12,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            "${(progress * 100).toInt()}%",
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      FadeInUp(
                        delay: const Duration(milliseconds: 200),
                        child: ElevatedButton.icon(
                          onPressed: () => context.push('/courses/content/$courseId'),
                          icon: const Icon(Icons.play_arrow_rounded, size: 28),
                          label: Text(
                            "Start / Continue Learning",
                            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6C5CE7),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 8,
                            minimumSize: const Size(double.infinity, 60),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(child: Lottie.asset('assets/lottie/learning.json', height: 150)),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}