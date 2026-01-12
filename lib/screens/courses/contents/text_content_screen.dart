// lib/screens/course/contents/text_content_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_html/flutter_html.dart';
import 'dart:convert';
import '../../../core/services/api_service.dart';
import '../../../providers/user_progress_merged_provider.dart';

class TextContentScreen extends ConsumerWidget {
  final Map<String, dynamic> content;
  const TextContentScreen({super.key, required this.content});

  String? _getTextContent() {
    final dynamic ctextRaw = content['ctext'];
    if (ctextRaw == null) return null;
    final String ctext = ctextRaw.toString().trim();
    return ctext.isEmpty ? null : ctext;
  }

  bool _isHtmlContent(String text) {
    return text.contains(RegExp(
      r'<(p|div|h[1-6]|ul|ol|li|blockquote|img|br|table|thead|tbody|tr|td|th|section|article|span)\b',
      caseSensitive: false,
    ));
  }

  String _getReadingTimeDisplay() {
    final dynamic readingTimeRaw = content['reading_time'];
    if (readingTimeRaw == null) return '';
    final String value = readingTimeRaw.toString().trim();
    final int? minutes = int.tryParse(value);
    if (minutes != null && minutes > 0) {
      return "Reading time: $minutes min";
    } else if (value.isNotEmpty) {
      return "Reading time: $value";
    }
    return '';
  }

  Future<void> _markAsCompleted(WidgetRef ref, BuildContext context) async {
    final userAsync = ref.read(userWithProgressProvider);
    final user = userAsync.value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to mark as completed")),
      );
      return;
    }

    // ← FIXED: Use 'course_id' (passed from ContentListScreen) instead of 'course_quiz_id'
    final int? contentId = content['id'] as int?;
    final int? courseId = content['course_id'] as int?;

    if (contentId == null || courseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid lesson data")),
      );
      return;
    }

    try {
      final api = ref.read(apiServiceProvider);
      // Exact same format as your working quiz attempt example
      await api.put(
        '/content/$contentId/progress',
        {
          'completed': true,
          'time_spent': 30, // seconds spent on this lesson
        },
        query: {
          'userid': user.id.toString(),
          'courseid': courseId.toString(),
          'contentid': contentId.toString(),
        },
      );
      // Refresh progress so ContentListScreen, CourseDetail, etc. update instantly
      ref.invalidate(userWithProgressProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Lesson marked as completed! 🎉"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error marking lesson as completed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to save progress: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? body = _getTextContent();
    final bool isHtml = body != null && _isHtmlContent(body ?? '');
    final String readingTimeText = _getReadingTimeDisplay();
    final String title = content['title']?.toString().trim() ?? 'Untitled Lesson';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF6C5CE7),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Optional Thumbnail
                if (content['thumbnail'] != null &&
                    content['thumbnail'].toString().trim().isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      content['thumbnail'].toString().trim(),
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 220,
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported,
                            size: 60, color: Colors.grey),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                // Title
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                // Reading Time
                if (readingTimeText.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 18, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        readingTimeText,
                        style: const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                if (readingTimeText.isNotEmpty) const SizedBox(height: 16),
                // Listen Button
                if (body != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          context.push(
                            '/courses/content/text-audio',
                            extra: {
                              'title': title,
                              'text': body,
                            },
                          );
                        },
                        icon: const Icon(Icons.headphones, size: 20),
                        label: const Text("Listen to this lesson"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C5CE7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ),
                  ),
                const Divider(height: 40, thickness: 1),
                // Main Text Content
                if (body != null)
                  isHtml
                      ? Html(
                    data: body,
                    style: {
                      "body": Style(
                        fontSize: FontSize(17),
                        lineHeight: LineHeight(1.7),
                        margin: Margins.zero,
                      ),
                      "h1,h2,h3,h4,h5,h6": Style(
                        fontWeight: FontWeight.bold,
                        fontSize: FontSize(22),
                      ),
                      "p": Style(margin: Margins.symmetric(vertical: 12)),
                      "ul,ol": Style(margin: Margins.symmetric(vertical: 12)),
                      "li": Style(margin: Margins.only(left: 20)),
                      "img": Style(
                        width: Width(100, Unit.percent),
                        height: Height.auto(),
                        margin: Margins.symmetric(vertical: 20),
                        display: Display.block,
                      ),
                      "blockquote": Style(
                        backgroundColor: Colors.grey[100],
                        padding: HtmlPaddings.all(16),
                        margin: Margins.symmetric(vertical: 16),
                        border: Border(
                            left: BorderSide(color: Colors.grey, width: 4)),
                      ),
                    },
                  )
                      : Text(
                    body,
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1.7,
                      color: Colors.black87,
                    ),
                  )
                else
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Text(
                        "No text content available.",
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  ),
                const SizedBox(height: 100), // Space for floating button
              ],
            ),
          ),
          // Floating "Mark as Completed" Button
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _markAsCompleted(ref, context),
                  icon: const Icon(Icons.check_circle_outline, size: 28),
                  label: Text(
                    "Mark as Completed",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 8,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}