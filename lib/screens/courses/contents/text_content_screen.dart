// lib/screens/course/contents/text_content_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_html/flutter_html.dart';

class TextContentScreen extends StatelessWidget {
  final Map<String, dynamic> content;

  const TextContentScreen({super.key, required this.content});

  /// Safely extract and trim ctext – this is the only field we use for text content
  String? _getTextContent() {
    final dynamic ctextRaw = content['ctext'];
    if (ctextRaw == null) return null;
    final String ctext = ctextRaw.toString().trim();
    return ctext.isEmpty ? null : ctext;
  }

  /// Detect if the content contains actual HTML tags
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

  @override
  Widget build(BuildContext context) {
    final String? body = _getTextContent();
    final bool isHtml = body != null && _isHtmlContent(body);
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
      body: SingleChildScrollView(
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
                    child: const Icon(Icons.image_not_supported, size: 60, color: Colors.grey),
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

            const Divider(height: 40, thickness: 1),

            // Main Text Content from ctext
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
                    border: Border(left: BorderSide(color: Colors.grey, width: 4)),
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

            const SizedBox(height: 120), // Bottom padding for navigation
          ],
        ),
      ),
    );
  }
}