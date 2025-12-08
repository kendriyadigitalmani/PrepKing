import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../providers/course_providers.dart';
import '../../providers/user_progress_merged_provider.dart';
import '../../core/services/api_service.dart';

// New provider to fetch course contents
final courseContentsProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, courseId) async {
  final api = ref.read(apiServiceProvider);
  final response = await api.get('/course/$courseId/contents');
  if (response['success'] == true) {
    return List<Map<String, dynamic>>.from(response['data'] ?? []);
  }
  return [];
});

class CourseDetailScreen extends ConsumerStatefulWidget {
  final int courseId;
  const CourseDetailScreen({super.key, required this.courseId});

  @override
  ConsumerState<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen> {
  bool _isEnrolling = false;
  bool _isEnrolled = false;

  @override
  void initState() {
    super.initState();
    _checkEnrollmentStatus();
  }

  Future<void> _checkEnrollmentStatus() async {
    final user = ref.read(userWithProgressProvider).value;
    if (user == null) return;
    final progress = user.courseProgress[widget.courseId.toString()];
    setState(() {
      _isEnrolled = progress != null && progress > 0;
    });
  }

  Future<void> _enrollInCourse() async {
    final user = ref.read(userWithProgressProvider).value;
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
      await api.post('/course/enroll', {
        'userid': user.id,
        'courseid': widget.courseId,
      });
      ref.invalidate(userWithProgressProvider);
      setState(() {
        _isEnrolled = true;
        _isEnrolling = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Successfully enrolled!")),
      );
    } catch (e) {
      setState(() => _isEnrolling = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Enrollment failed: $e")),
      );
    }
  }

  // Proper slug sharing (same as QuizDetailScreen)
  void _shareCourse(String title, dynamic slugOrId) {
    final slug = slugOrId?.toString() ?? widget.courseId.toString();
    final url = "https://prepking.online/c/$slug";
    Share.share("$title\n\nJoin now: $url", subject: "Check out this course on PrepKing!");
  }

  String _getButtonText(double progress) {
    if (progress >= 1.0) return "View Certificate";
    if (_isEnrolled && progress > 0) return "Continue Learning";
    if (_isEnrolled) return "Start Learning";
    return "Enroll Now";
  }

  IconData _getButtonIcon(double progress) {
    if (progress >= 1.0) return Icons.card_giftcard_rounded;
    if (_isEnrolled && progress > 0) return Icons.play_arrow_rounded;
    if (_isEnrolled) return Icons.play_circle_fill;
    return Icons.rocket_launch_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final courseAsync = ref.watch(courseDetailProvider(widget.courseId));
    final userAsync = ref.watch(userWithProgressProvider);
    final contentsAsync = ref.watch(courseContentsProvider(widget.courseId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      body: courseAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF6C5CE7))),
        error: (_, __) => Center(child: Text("Failed to load course", style: GoogleFonts.poppins())),
        data: (course) {
          final progress = userAsync.value?.courseProgress[widget.courseId.toString()] ?? 0.0;
          final slug = course['slug'] ?? course['id'].toString();
          final title = course['title'] ?? 'Course';
          final thumbnail = course['thumbnail'];

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // Collapsible Header (Kept Intact)
                  SliverAppBar(
                    expandedHeight: 340,
                    pinned: true,
                    backgroundColor: Colors.transparent,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          thumbnail != null
                              ? Image.network(thumbnail, fit: BoxFit.cover)
                              : Lottie.asset('assets/lottie/learning.json', fit: BoxFit.cover),
                          Container(
                            decoration: BoxDecoration(
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
                                  Text(
                                    title,
                                    style: GoogleFonts.poppins(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Chip(
                                        backgroundColor: Colors.purple.shade100.withOpacity(0.9),
                                        label: Text(course['topic'] ?? 'General',
                                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.purple.shade900)),
                                      ),
                                      const SizedBox(width: 8),
                                      Chip(
                                        backgroundColor: Colors.orange.shade100.withOpacity(0.9),
                                        label: Text(course['difficulty'] ?? 'Medium',
                                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.orange.shade900)),
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

                          // Progress Card
                          if (_isEnrolled && progress > 0)
                            FadeInUp(
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                margin: const EdgeInsets.only(bottom: 24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 8))],
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
                                        Text("${(progress * 100).toInt()}%", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6C5CE7))),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // COURSE DETAILS Section
                          Text("COURSE DETAILS", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                          const SizedBox(height: 16),
                          _buildInfoCard(Icons.play_circle_outline, "${course['lessons_count'] ?? contentsAsync.asData?.value.length ?? 'N/A'} Lessons", "Total lessons"),
                          const SizedBox(height: 12),
                          _buildInfoCard(Icons.access_time, "${course['duration_minutes'] ?? '480'} mins", "Estimated duration"),
                          const SizedBox(height: 12),
                          _buildInfoCard(Icons.card_giftcard, course['certificate_enabled'] == 1 ? "Certificate Included" : "No Certificate", ""),

                          const SizedBox(height: 32),

                          // LESSONS Section (Non-clickable preview)
                          Text("LESSONS", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                          const SizedBox(height: 16),

                          contentsAsync.when(
                            loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF6C5CE7))),
                            error: (_, __) => Text("Failed to load lessons", style: GoogleFonts.poppins(color: Colors.red)),
                            data: (contents) {
                              if (contents.isEmpty) {
                                return Container(
                                  padding: const EdgeInsets.all(32),
                                  decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16)),
                                  child: Center(
                                    child: Text("No lessons available yet", style: GoogleFonts.poppins(color: Colors.grey[600])),
                                  ),
                                );
                              }
                              return ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: contents.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final content = contents[index];
                                  final isCompleted = userAsync.value?.completedContentIds.contains(content['id'].toString()) ?? false;
                                  return ListTile(
                                    enabled: false,
                                    leading: CircleAvatar(
                                      backgroundColor: isCompleted ? Colors.green : Colors.grey[300],
                                      child: isCompleted
                                          ? const Icon(Icons.check, color: Colors.white)
                                          : Text("${index + 1}", style: const TextStyle(color: Colors.white)),
                                    ),
                                    title: Text(
                                      content['title'] ?? "Lesson ${index + 1}",
                                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: content['duration_minutes'] != null
                                        ? Text("${content['duration_minutes']} mins")
                                        : null,
                                    trailing: Icon(Icons.lock_outline, color: Colors.grey[400]),
                                  );
                                },
                              );
                            },
                          ),

                          const SizedBox(height: 120), // Space for FAB
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Smart Floating Action Button
              Positioned(
                bottom: 30,
                left: 24,
                right: 24,
                child: FadeInUp(
                  delay: const Duration(milliseconds: 600),
                  child: ElevatedButton.icon(
                    onPressed: _isEnrolling
                        ? null
                        : () async {
                      if (progress >= 1.0) {
                        // Handle certificate view later
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Certificate feature coming soon!")));
                      } else if (_isEnrolled) {
                        context.push('/courses/content/${widget.courseId}');
                      } else {
                        await _enrollInCourse();
                      }
                    },
                    icon: _isEnrolling
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                        : Icon(_getButtonIcon(progress), size: 28),
                    label: Text(
                      _isEnrolling ? "Enrolling..." : _getButtonText(progress),
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C5CE7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      elevation: 12,
                      shadowColor: const Color(0xFF6C5CE7).withOpacity(0.5),
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
              decoration: BoxDecoration(
                color: const Color(0xFF6C5CE7).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
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