// lib/screens/course/contents/content_player_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'text_content_screen.dart';
import 'video_content_screen.dart';
import 'quiz_content_screen.dart';
import 'pdf_content_screen.dart';

class ContentPlayerScreen extends StatelessWidget {
  final Map<String, dynamic> content;

  const ContentPlayerScreen({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final String type = (content['type'] as String?)?.toLowerCase().trim() ?? 'text';

    Widget screen;

    switch (type) {
      case 'video':
      case 'youtube':
      case 'vimeo':
        screen = VideoContentScreen(content: content);
        break;

      case 'quiz':
      case 'mcq':
      case 'assessment':
        screen = QuizContentScreen(content: content);
        break;

      case 'pdf':
      case 'document':
      case 'file':
        screen = PdfContentScreen(content: content);
        break;

      case 'text':
      case 'article':
      case 'lesson':
      case 'html':
      case 'markdown':
      default:
        screen = TextContentScreen(content: content);
        break;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF6C5CE7),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          content['title']?.toString() ?? 'Lesson',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Share coming soon!")),
            ),
          ),
        ],
      ),
      body: SafeArea(child: screen),
    );
  }
}