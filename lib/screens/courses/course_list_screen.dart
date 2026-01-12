// lib/screens/courses/course_list_screen.dart

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../../core/utils/user_preferences.dart';
import '../../providers/course_providers.dart'; // ← CHANGED: Now uses updated course_providers.dart

class CourseListScreen extends ConsumerStatefulWidget {
  const CourseListScreen({super.key});

  @override
  ConsumerState<CourseListScreen> createState() => _CourseListScreenState();
}

class _CourseListScreenState extends ConsumerState<CourseListScreen> {
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

  // Count total lessons from PHP-serialized content_ids string (kept for display only)
  int _getTotalContents(Map<String, dynamic> course) {
    final contentIds = course['content_ids'];
    if (contentIds == null || contentIds is! String || contentIds.trim().isEmpty) {
      return 0;
    }
    try {
      // Split by comma, trim whitespace, and filter out empty strings
      final ids = contentIds.split(',').map((id) => id.trim()).where((id) => id.isNotEmpty).toList();
      return ids.length;
    } catch (e) {
      return 0;
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
    // Show loading only while checking preferences
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
          title: Text('Courses', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
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

    // Preferences ready → normal course list
    // CHANGED: Now uses the enhanced courseListProvider from course_providers.dart
    final coursesAsync = ref.watch(courseListProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(start: 20, bottom: 16),
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
                  child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
                ),
              ),
              error: (_, __) => SliverToBoxAdapter(
                child: Center(
                  child: Column(
                    children: [
                      Lottie.asset('assets/lottie/no_connection.json', width: 200),
                      const SizedBox(height: 20),
                      Text("No internet connection", style: GoogleFonts.poppins(fontSize: 18)),
                      TextButton(
                        onPressed: () => ref.refresh(courseListProvider),
                        child: const Text("Retry", style: TextStyle(color: Color(0xFF6C5CE7))),
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
                            style: GoogleFonts.poppins(fontSize: 20, color: Colors.grey[600]),
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

                      // FIXED: Use backend-provided normalized progress
                      final double progressPercentage = course['progress_percentage'] as double? ?? 0.0;
                      final int totalLessons = _getTotalContents(course);
                      final String displayId = course['id'].toString();

                      return FadeInUp(
                        delay: Duration(milliseconds: index * 100),
                        child: Hero(
                          tag: 'course-hero-$displayId',
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Card(
                              elevation: 8,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: () => context.push('/courses/detail/$displayId'),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: Container(
                                          width: 80,
                                          height: 80,
                                          color: Colors.grey[200],
                                          child: (course['thumbnail'] != null &&
                                              course['thumbnail'].toString().isNotEmpty)
                                              ? Image.network(
                                            course['thumbnail'],
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Lottie.asset(
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
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              course['title'] ?? "Untitled Course",
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
                                                const Icon(Icons.play_circle_outline, size: 18, color: Colors.grey),
                                                const SizedBox(width: 6),
                                                Text(
                                                  "$totalLessons Lessons",
                                                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]),
                                                ),
                                                const Spacer(),
                                                // Show accurate backend percentage
                                                Text(
                                                  "${progressPercentage.toStringAsFixed(0)}% Done",
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
                                              value: progressPercentage / 100.0, // 0.0 to 1.0
                                              backgroundColor: Colors.grey[300],
                                              valueColor: const AlwaysStoppedAnimation(Color(0xFF6C5CE7)),
                                              minHeight: 7,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(left: 12),
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
          _checkPreferences();
          ref.invalidate(courseListProvider); // ← Now refreshes correct provider
        },
        child: const Icon(Icons.refresh_rounded, color: Colors.white),
      ),
    );
  }
}