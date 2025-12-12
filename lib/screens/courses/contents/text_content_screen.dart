// lib/screens/course/contents/text_content_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class TextContentScreen extends StatelessWidget {
  final Map<String, dynamic> content;

  const TextContentScreen({super.key, required this.content});

  // Helper to safely get and format reading time
  String _getReadingTimeDisplay() {
    final dynamic readingTimeRaw = content['reading_time'];
    if (readingTimeRaw == null) return '';

    final String value = readingTimeRaw.toString().trim();

    // Check if it's a valid integer
    final int? minutes = int.tryParse(value);
    if (minutes != null) {
      return "Reading time: $minutes min";
    } else {
      // If it's not a number (e.g., "text", "variable"), show as-is without "min"
      return "Reading time: $value";
    }
  }

  @override
  Widget build(BuildContext context) {
    // Try multiple possible keys for body content
    final String? body = content['body'] ??
        content['content'] ??
        content['description'] ??
        content['ctext'];

    // Improved HTML detection: check for common HTML tags
    final bool isHtml = body != null &&
        (body.contains(RegExp(r'<[a-zA-Z][^>]*>')) || // Any HTML tag
            body.contains('&') || // HTML entities
            body.contains('<p') ||
            body.contains('<div') ||
            body.contains('<h') ||
            body.contains('<img') ||
            body.contains('<br'));

    final String readingTimeText = _getReadingTimeDisplay();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
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
                  child: const Icon(
                    Icons.image_not_supported,
                    size: 60,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 24),

          // Title
          Text(
            content['title']?.toString().trim() ?? 'Untitled Lesson',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 12),

          // Reading time (only show if we have something to display)
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

          const Divider(height: 40, thickness: 1),

          // Body Content
          if (body != null && body.trim().isNotEmpty)
            if (isHtml)
              Html(
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
                  "img": Style(
                    width: Width(100, Unit.percent),
                    height: Height.auto(),
                    margin: Margins.symmetric(vertical: 20),
                    display: Display.block,
                    alignment: Alignment.center,
                  ),
                  "p": Style(
                    margin: Margins.symmetric(vertical: 12),
                  ),
                  "ul,ol": Style(
                    margin: Margins.symmetric(vertical: 12),
                  ),
                  "li": Style(
                    margin: Margins.only(left: 20),
                  ),
                  "blockquote": Style(
                    backgroundColor: Colors.grey[100],
                    padding: HtmlPaddings.all(16), // Corrected to HtmlPaddings
                    margin: Margins.symmetric(vertical: 16),
                    border: Border(
                      left: BorderSide(color: Colors.grey, width: 4),
                    ),
                  ),
                },
              )
            else
              MarkdownBody(
                data: body,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(fontSize: 17, height: 1.7),
                  h1: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                  h2: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  h3: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  blockquote: const TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                    backgroundColor: Color(0xFFF9F9F9),
                  ),
                  code: const TextStyle(
                    backgroundColor: Color(0xFFF1F1F1),
                    fontFamily: 'monospace',
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: const Color(0xFFF1F1F1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              )
          else
            const Center(
              child: Text(
                "No content available.",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),

          // Extra bottom padding for scrolling
          const SizedBox(height: 120),
        ],
      ),
    );
  }
}