// lib/screens/course/contents/text_content_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class TextContentScreen extends StatelessWidget {
  final Map<String, dynamic> content;

  const TextContentScreen({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final String? body = content['body'] ?? content['content'] ?? content['description'];
    final bool isHtml = body != null && (body.contains('<p') || body.contains('<div') || body.contains('<h'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          if (content['thumbnail'] != null && content['thumbnail'].toString().isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                content['thumbnail'].toString(),
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
            content['title']?.toString() ?? 'Untitled Lesson',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),

          // Reading time
          if (content['reading_time'] != null)
            Row(
              children: [
                const Icon(Icons.access_time, size: 18, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  "Reading time: ${content['reading_time']} min",
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),

          const Divider(height: 40),

          // Body Content
          if (isHtml && body != null)
            Html(
              data: body,
              style: {
                "body": Style(fontSize: FontSize(17), lineHeight: LineHeight(1.7)),
                "h1,h2,h3": Style(fontWeight: FontWeight.bold, fontSize: FontSize(22)),
                "img": Style(width: Width(100, Unit.percent), margin: Margin.all(10)),
              },
            )
          else if (body != null && body.trim().isNotEmpty)
            MarkdownBody(
              data: body,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(fontSize: 17, height: 1.7),
                h1: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold),
                h2: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold),
                blockquote: const TextStyle(color: Colors.grey),
                code: const TextStyle(backgroundColor: Color(0xFFF1F1F1), fontFamily: 'monospace'),
              ),
            )
          else
            const Center(
              child: Text("No content available.", style: TextStyle(fontSize: 16, color: Colors.grey)),
            ),

          const SizedBox(height: 120),
        ],
      ),
    );
  }
}