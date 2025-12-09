// lib/screens/course_detail_screen.dart
import 'dart:convert';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dio/dio.dart';
import '../../providers/course_providers.dart';
import '../../providers/course_progress_provider.dart';
import '../../providers/user_progress_merged_provider.dart';
import '../../core/services/api_service.dart';

class CourseDetailScreen extends ConsumerStatefulWidget {
  final int courseId;
  const CourseDetailScreen({super.key, required this.courseId});

  @override
  ConsumerState<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen> {
  bool _isEnrolling = false;

  Future<void> _enrollInCourse() async {
    final userAsync = ref.read(userWithProgressProvider);
    final user = userAsync.asData?.value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to enroll")),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Enroll in Course", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: const Text("Are you sure you want to enroll in this course?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7)),
            child: const Text("Enroll Now"),
          ),
        ],
      ),
    );

    if (!(confirmed ?? false)) return;

    setState(() => _isEnrolling = true);

    try {
      final api = ref.read(apiServiceProvider);
      await api.post(
        '/course/${widget.courseId}/enroll',
        {
          'courseid': widget.courseId.toString(),
          'userid': user.id.toString(),
        },
      );

      ref.invalidate(preciseCourseProgressProvider((widget.courseId, user.id)));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Successfully enrolled!")),
      );
    } catch (e) {
      String msg = "Enrollment failed!";
      if (e is DioException) {
        final data = e.response?.data;
        msg = data is Map ? jsonEncode(data) : data.toString();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text(msg)),
      );
      debugPrint('Enrollment Error: $e');
    } finally {
      setState(() => _isEnrolling = false);
    }
  }

  void _shareCourse(String title, dynamic slug) {
    final url = "https://prepking.online/c/${slug ?? widget.courseId}";
    Share.share("$title\n\nJoin now: $url", subject: "Check out this course!");
  }

  // FIXED: Extract real lesson count from PHP serialized content_ids
  int _getLessonCount(Map<String, dynamic> course) {
    final String? serialized = course['content_ids'] as String?;
    if (serialized == null || serialized.isEmpty) return 0;

    // PHP serialized array starts with a:{count}:{
    final regExp = RegExp(r'a:(\d+):');
    final match = regExp.firstMatch(serialized);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final courseAsync = ref.watch(courseDetailProvider(widget.courseId));
    final contentsAsync = ref.watch(courseContentsProvider(widget.courseId));
    final userAsync = ref.watch(userWithProgressProvider);
    final userId = userAsync.asData?.value?.id ?? 0;

    if (userId == 0) {
      return _buildUI(courseAsync, contentsAsync, progress: 0.0, isEnrolled: false, isCompleted: false);
    }

    final progressAsync = ref.watch(preciseCourseProgressProvider((widget.courseId, userId)));
    final double progress = progressAsync.when(
      data: (data) => data == null
          ? 0.0
          : (double.tryParse(data['progress_percentage'].toString()) ?? 0.0) / 100.0,
      loading: () => userAsync.value?.courseProgress[widget.courseId.toString()] ?? 0.0,
      error: (_, __) => userAsync.value?.courseProgress[widget.courseId.toString()] ?? 0.0,
    );

    final bool isEnrolled = progressAsync.hasValue && progressAsync.value != null;
    final bool isCompleted = progress >= 0.99;

    return _buildUI(
      courseAsync,
      contentsAsync,
      progress: progress.clamp(0.0, 1.0),
      isEnrolled: isEnrolled,
      isCompleted: isCompleted,
    );
  }

  Widget _buildUI(
      AsyncValue<Map<String, dynamic>> courseAsync,
      AsyncValue<List<Map<String, dynamic>>> contentsAsync, {
        required double progress,
        required bool isEnrolled,
        required bool isCompleted,
      }) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      body: courseAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF6C5CE7))),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 80, color: Colors.red),
              const SizedBox(height: 16),
              Text("Failed to load course", style: GoogleFonts.poppins(fontSize: 18)),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(courseDetailProvider(widget.courseId)),
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
              ),
            ],
          ),
        ),
        data: (course) {
          final title = course['title'] ?? 'Course';
          final thumbnail = course['thumbnail'];
          final slug = course['slug'] ?? course['id'].toString();

          // FIX APPLIED HERE
          final int lessonCount = _getLessonCount(course);

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 340,
                    pinned: true,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          thumbnail != null
                              ? Image.network(thumbnail, fit: BoxFit.cover)
                              : Lottie.asset('assets/lottie/learning.json', fit: BoxFit.cover),
                          Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.black45, Colors.black87],
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 24,
                            left: 20,
                            right: 60,
                            child: FadeInUp(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title, style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      Chip(
                                        backgroundColor: Colors.purple.shade100.withOpacity(0.9),
                                        label: Text(course['topic'] ?? 'General', style: GoogleFonts.poppins(fontSize: 12)),
                                      ),
                                      Chip(
                                        backgroundColor: Colors.orange.shade100.withOpacity(0.9),
                                        label: Text(course['difficulty'] ?? 'Medium', style: GoogleFonts.poppins(fontSize: 12)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 50,
                            right: 16,
                            child: IconButton(
                              icon: const Icon(Icons.share_rounded, color: Colors.white, size: 28),
                              onPressed: () => _shareCourse(title, slug),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          if (isEnrolled && progress > 0.0)
                            FadeInUp(
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                margin: const EdgeInsets.only(bottom: 24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15, offset: const Offset(0, 8))],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Your Progress", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: LinearProgressIndicator(
                                            value: progress,
                                            backgroundColor: Colors.grey[200],
                                            valueColor: const AlwaysStoppedAnimation(Color(0xFF6C5CE7)),
                                            minHeight: 10,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text("${(progress * 100).toInt()}%", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF6C5CE7))),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          Text("COURSE DETAILS", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),

                          // FIXED LINE: Now shows correct number of lessons
                          _buildInfoCard(Icons.play_circle_outline, lessonCount > 0 ? "$lessonCount Lessons" : "N/A Lessons", "Total lessons"),
                          const SizedBox(height: 12),
                          _buildInfoCard(Icons.access_time, "${course['duration_minutes'] ?? '60'} mins", "Duration"),
                          const SizedBox(height: 12),
                          _buildInfoCard(Icons.card_giftcard, course['certificate_enabled'] == 1 ? "Certificate Included" : "No Certificate", ""),

                          const SizedBox(height: 32),
                          Text("LESSONS", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),

                          contentsAsync.when(
                            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF6C5CE7))),
                            error: (_, __) => const Text("Failed to load lessons", style: TextStyle(color: Colors.red)),
                            data: (contents) => contents.isEmpty
                                ? const Text("No lessons available yet")
                                : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: contents.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final c = contents[i];
                                final isCompleted = ref.read(userWithProgressProvider).asData?.value?.completedContentIds.contains(c['id'].toString()) ?? false;
                                return ListTile(
                                  enabled: isEnrolled,
                                  leading: CircleAvatar(
                                    backgroundColor: isCompleted ? Colors.green : Colors.grey[300],
                                    child: isCompleted
                                        ? const Icon(Icons.check, color: Colors.white)
                                        : Text("${i + 1}", style: const TextStyle(color: Colors.white)),
                                  ),
                                  title: Text(c['title'] ?? "Lesson ${i + 1}", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                                  subtitle: c['duration_minutes'] != null ? Text("${c['duration_minutes']} mins") : null,
                                  trailing: isEnrolled ? const Icon(Icons.chevron_right) : const Icon(Icons.lock_outline),
                                  onTap: isEnrolled ? () => context.push('/courses/content/${widget.courseId}/${c['id']}') : null,
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Bottom Button
              Positioned(
                bottom: 30,
                left: 24,
                right: 24,
                child: FadeInUp(
                  child: ElevatedButton.icon(
                    onPressed: _isEnrolling
                        ? null
                        : () {
                      if (isCompleted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Certificate coming soon!")));
                      } else if (isEnrolled) {
                        context.push('/courses/content/${widget.courseId}');
                      } else {
                        _enrollInCourse();
                      }
                    },
                    icon: _isEnrolling
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                        : Icon(
                      isCompleted
                          ? Icons.card_giftcard_rounded
                          : isEnrolled
                          ? (progress > 0 ? Icons.play_arrow_rounded : Icons.play_circle_fill)
                          : Icons.rocket_launch_rounded,
                      size: 28,
                    ),
                    label: Text(
                      _isEnrolling
                          ? "Enrolling..."
                          : isCompleted
                          ? "View Certificate"
                          : isEnrolled
                          ? (progress > 0 ? "Continue Learning" : "Start Learning")
                          : "Enroll Now",
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      elevation: 12,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String title, String subtitle) {
    return FadeInUp(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF6C5CE7).withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: const Color(0xFF6C5CE7), size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                if (subtitle.isNotEmpty) Text(subtitle, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600])),
              ],
            ),
          ],
        ),
      ),
    );
  }
}