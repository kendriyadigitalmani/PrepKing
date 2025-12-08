// lib/screens/course_list_screen.dart  (or wherever you keep it)

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/api_service.dart'; // ← ADD THIS
import '../../providers/user_progress_merged_provider.dart';
import '../../providers/user_progress_merged_provider.dart';

/// Provider that returns list of all courses
final allCoursesProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final response = await api.get('/course');
  if (response is Map<String, dynamic> && response['success'] == true) {
    return (response['data'] as List?) ?? [];
  }
  return [];
});

class CourseListScreen extends ConsumerWidget {
  const CourseListScreen({super.key});

  // Count total lessons from PHP-serialized content_ids string
  int _getTotalContents(Map<String, dynamic> course) {
    final contentIds = course['content_ids'];
    if (contentIds == null || contentIds is! String) return 0;
    try {
      final match = RegExp(r'a:(\d+)').firstMatch(contentIds);
      return match != null ? int.parse(match.group(1)!) : 0;
    } catch (e) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(allCoursesProvider);
    final userProgressAsync = ref.watch(userWithProgressProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
              const EdgeInsetsDirectional.only(start: 20, bottom: 16),
              title: Text(
                "Courses",
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF6C5CE7), Color(0xFF4A3CB7)],
                  ),
                ),
              ),
            ),
            backgroundColor: const Color(0xFF6C5CE7),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: coursesAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF6C5CE7),
                  ),
                ),
              ),
              error: (_, __) => SliverToBoxAdapter(
                child: Center(
                  child: Column(
                    children: [
                      Lottie.asset('assets/lottie/no_connection.json',
                          width: 200),
                      const SizedBox(height: 20),
                      Text("No internet connection",
                          style: GoogleFonts.poppins(fontSize: 18)),
                      TextButton(
                        onPressed: () => ref.refresh(allCoursesProvider),
                        child: const Text("Retry",
                            style: TextStyle(color: Color(0xFF6C5CE7))),
                      ),
                    ],
                  ),
                ),
              ),
              data: (courses) {
                if (courses.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Lottie.asset('assets/lottie/empty.json', width: 250),
                          const SizedBox(height: 20),
                          Text(
                            "No courses available yet",
                            style: GoogleFonts.poppins(
                                fontSize: 20, color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final course = courses[index];
                      final courseId = course['id'].toString();

                      // This now works perfectly thanks to the updated UserModel.fromJson()
                      final progress = userProgressAsync.value
                          ?.courseProgress[courseId] ??
                          0.0;

                      final totalLessons = _getTotalContents(course);

                      return FadeInUp(
                        delay: Duration(milliseconds: index * 100),
                        child: Hero(
                          tag: 'course-hero-$courseId',
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Card(
                              elevation: 8,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24)),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: () =>
                                    context.push('/courses/detail/$courseId'),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    children: [
                                      // Default = learning.json Lottie for every course
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: Container(
                                          width: 80,
                                          height: 80,
                                          color: Colors.grey[200],
                                          child: course['thumbnail'] != null &&
                                              course['thumbnail']
                                                  .toString()
                                                  .isNotEmpty
                                              ? Image.network(
                                            course['thumbnail'],
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (_, __, ___) =>
                                                Lottie.asset(
                                                  'assets/lottie/learning.json',
                                                  fit: BoxFit.cover,
                                                  repeat: true,
                                                ),
                                          )
                                              : Lottie.asset(
                                            'assets/lottie/learning.json',
                                            fit: BoxFit.cover,
                                            repeat: true,
                                          ),
                                        ),
                                      ),

                                      const SizedBox(width: 16),

                                      // Course Info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              course['title'] ??
                                                  "Untitled Course",
                                              style: GoogleFonts.poppins(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                const Icon(Icons.play_circle_outline,
                                                    size: 18, color: Colors.grey),
                                                const SizedBox(width: 6),
                                                Text(
                                                  "$totalLessons Lessons",
                                                  style: GoogleFonts.poppins(
                                                      fontSize: 14,
                                                      color: Colors.grey[700]),
                                                ),
                                                const Spacer(),
                                                if (progress > 0)
                                                  Text(
                                                    "${(progress * 100).toInt()}% Done",
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                      color: const Color(0xFF6C5CE7),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            LinearProgressIndicator(
                                              value: progress,
                                              backgroundColor: Colors.grey[300],
                                              valueColor:
                                              const AlwaysStoppedAnimation(
                                                  Color(0xFF6C5CE7)),
                                              minHeight: 7,
                                              borderRadius:
                                              BorderRadius.circular(10),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Arrow
                                      Padding(
                                        padding:
                                        const EdgeInsets.only(left: 12),
                                        child: Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          color: Colors.grey[600],
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: courses.length,
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
          ref.invalidate(allCoursesProvider);
          ref.invalidate(userWithProgressProvider);
        },
        child: const Icon(Icons.refresh_rounded, color: Colors.white),
      ),
    );
  }
}