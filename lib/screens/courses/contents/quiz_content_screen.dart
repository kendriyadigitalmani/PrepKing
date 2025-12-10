// lib/screens/course/contents/quiz_content_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class QuizContentScreen extends StatelessWidget {
  final Map<String, dynamic> content;

  const QuizContentScreen({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final quizId = int.tryParse(content['quiz_id']?.toString() ?? '0') ?? 0;
    final total = content['total_questions'] ?? 10;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: const Color(0xFF6C5CE7).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.quiz, size: 90, color: Color(0xFF6C5CE7)),
            ),
            const SizedBox(height: 40),
            Text(
              content['title']?.toString() ?? 'Quiz',
              style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              "$total Questions • Earn points on completion",
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 50),
            ElevatedButton.icon(
              onPressed: quizId > 0
                  ? () => context.push('/quiz/$quizId', extra: content)
                  : null,
              icon: const Icon(Icons.play_arrow, size: 28),
              label: const Text("Start Quiz", style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}