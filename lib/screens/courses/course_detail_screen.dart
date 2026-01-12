// lib/screens/courses/course_detail_screen.dart
import 'dart:convert';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dio/dio.dart';
import '../../providers/course_providers.dart'; // courseDetailProvider, courseContentsProvider
import '../../providers/course_progress_provider.dart'; // preciseCourseProgressProvider
import '../../providers/user_provider.dart'; // currentUserProvider for user ID
import '../../core/services/api_service.dart';

class CourseDetailScreen extends ConsumerStatefulWidget {
  final int courseId;
  const CourseDetailScreen({super.key, required this.courseId});

  @override
  ConsumerState<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen> {
  bool _isEnrolling = false;

  // Safe parsing helper for double values from API (handles String, int, double, null)
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Future<void> _enrollInCourse() async {
    final api = ref.read(apiServiceProvider);
    final userId = ref.read(currentUserProvider).value?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not logged in")),
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
      await api.post(
        '/course/${widget.courseId}/enroll',
        {}, // empty body
        query: {
          "courseid": widget.courseId,
        },
      );

      // Invalidate related providers
      ref.invalidate(courseDetailProvider(widget.courseId));
      ref.invalidate(courseContentsProvider(widget.courseId));
      ref.invalidate(preciseCourseProgressProvider((widget.courseId, userId)));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Successfully enrolled!")),
      );
    } catch (e) {
      String msg = "Enrollment failed!";
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map<String, dynamic> && data.containsKey('message')) {
          msg = data['message'];
        } else {
          msg = data is Map ? jsonEncode(data) : data.toString();
        }
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

  String _getContentRoute(Map<String, dynamic> content) {
    final String rawType = (content['type'] as String?)?.toLowerCase().trim() ?? 'text';
    switch (rawType) {
      case 'video':
      case 'youtube':
      case 'vimeo':
        return '/courses/content/video';
      case 'audio':
      case 'audiobook':
      case 'mp3':
        return '/courses/content/audio';
      case 'quiz':
      case 'mcq':
      case 'assessment':
        return '/courses/content/quiz';
      case 'pdf':
      case 'document':
      case 'file':
        return '/courses/content/pdf';
      case 'text':
      case 'article':
      case 'lesson':
      case 'html':
      case 'markdown':
      default:
        return '/courses/content/text';
    }
  }

  @override
  Widget build(BuildContext context) {
    final courseAsync = ref.watch(courseDetailProvider(widget.courseId));
    final contentsAsync = ref.watch(courseContentsProvider(widget.courseId));
    final userAsync = ref.watch(currentUserProvider);
    final userId = userAsync.value?.id ?? 0;
    final progressAsync = ref.watch(preciseCourseProgressProvider((widget.courseId, userId)));

    return courseAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF6C5CE7))),
      ),
      error: (err, _) => Scaffold(
        body: Center(
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
      ),
      data: (course) {
        // Extract progress data safely from precise provider
        final progressData = progressAsync.when(
          data: (data) => data ?? {},
          loading: () => {'isEnrolled': false, 'progress_percentage': 0.0, 'completed': <int>[]},
          error: (_, __) => {'isEnrolled': false, 'progress_percentage': 0.0, 'completed': <int>[]},
        );

        final bool isEnrolled = progressData['isEnrolled'] == true;
        final double progressPercentage = _parseDouble(progressData['progress_percentage']);
        final List<int> completedContentIds = progressData['completed'] as List<int>? ?? [];

        // Clamp for UI
        final double clampedProgress = progressPercentage.clamp(0.0, 100.0);
        final double progress = clampedProgress / 100.0;
        final bool isCompleted = progressPercentage >= 100.0;

        final title = course['title'] ?? 'Course';
        final thumbnail = course['thumbnail'];
        final slug = course['slug'] ?? course['id'].toString();

        final int lessonCount = contentsAsync.when(
          data: (contents) => contents.length,
          loading: () => 0,
          error: (_, __) => 0,
        );

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FF),
          body: Stack(
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
                                  Text(title,
                                      style: GoogleFonts.poppins(
                                          fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      Chip(
                                        backgroundColor: Colors.purple.shade100.withOpacity(0.9),
                                        label: Text(course['topic'] ?? 'General',
                                            style: GoogleFonts.poppins(fontSize: 12)),
                                      ),
                                      Chip(
                                        backgroundColor: Colors.orange.shade100.withOpacity(0.9),
                                        label: Text(course['difficulty'] ?? 'Medium',
                                            style: GoogleFonts.poppins(fontSize: 12)),
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
                          if (isEnrolled && clampedProgress > 0.0)
                            FadeInUp(
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                margin: const EdgeInsets.only(bottom: 24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black12, blurRadius: 15, offset: const Offset(0, 8))
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Your Progress",
                                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
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
                                        Text("${clampedProgress.toStringAsFixed(0)}%",
                                            style: GoogleFonts.poppins(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF6C5CE7))),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          Text("COURSE DETAILS",
                              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          _buildInfoCard(
                            Icons.play_circle_outline,
                            "$lessonCount Lessons",
                            "Total lessons",
                          ),
                          const SizedBox(height: 12),
                          _buildInfoCard(Icons.access_time, "${course['duration_minutes'] ?? '60'} mins", "Duration"),
                          const SizedBox(height: 12),
                          _buildInfoCard(Icons.card_giftcard,
                              course['certificate_enabled'] == 1 ? "Certificate Included" : "No Certificate", ""),
                          const SizedBox(height: 32),
                          Text("LESSONS", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          contentsAsync.when(
                            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF6C5CE7))),
                            error: (_, __) => const Text("Failed to load lessons",
                                style: TextStyle(color: Colors.red)),
                            data: (contents) => contents.isEmpty
                                ? const Text("No lessons available yet")
                                : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: contents.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final c = contents[i];
                                final int contentId = c['id'] as int;
                                final bool isCompleted = completedContentIds.contains(contentId) ||
                                    (c['is_completed'] as bool? ?? false);
                                final bool isLocked = course['is_sequential'] == 1 &&
                                    i > 0 &&
                                    !completedContentIds.contains(contents[i - 1]['id'] as int);

                                return ListTile(
                                  enabled: isEnrolled && !isLocked,
                                  leading: CircleAvatar(
                                    backgroundColor: isCompleted ? Colors.green : Colors.grey[300],
                                    child: isCompleted
                                        ? const Icon(Icons.check, color: Colors.white)
                                        : Text("${i + 1}", style: const TextStyle(color: Colors.white)),
                                  ),
                                  title: Text(c['title'] ?? "Lesson ${i + 1}",
                                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                                  subtitle: c['duration_minutes'] != null
                                      ? Text("${c['duration_minutes']} mins")
                                      : null,
                                  trailing: isLocked
                                      ? const Icon(Icons.lock_outline, color: Colors.grey)
                                      : isCompleted
                                      ? const Icon(Icons.check_circle, color: Colors.green)
                                      : const Icon(Icons.chevron_right),
                                  onTap: (isEnrolled && !isLocked)
                                      ? () {
                                    final route = _getContentRoute(c);
                                    context.push(route, extra: {
                                      ...c,
                                      'course_id': widget.courseId,
                                    });
                                  }
                                      : null,
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
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Certificate coming soon!")));
                      } else if (isEnrolled) {
                        context.push('/courses/content/${widget.courseId}');
                      } else {
                        _enrollInCourse();
                      }
                    },
                    icon: _isEnrolling
                        ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                        : Icon(
                      isCompleted
                          ? Icons.card_giftcard_rounded
                          : isEnrolled
                          ? (progressPercentage > 0 ? Icons.play_arrow_rounded : Icons.play_circle_fill)
                          : Icons.rocket_launch_rounded,
                      size: 28,
                    ),
                    label: Text(
                      _isEnrolling
                          ? "Enrolling..."
                          : isCompleted
                          ? "View Certificate"
                          : isEnrolled
                          ? (progressPercentage > 0 ? "Continue Learning" : "Start Learning")
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
          ),
        );
      },
    );
  }

  Widget _buildInfoCard(IconData icon, String title, String subtitle) {
    return FadeInUp(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8))
          ],
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
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600])),
              ],
            ),
          ],
        ),
      ),
    );
  }
}