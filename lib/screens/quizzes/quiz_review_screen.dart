// lib/screens/quizzes/quiz_review_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class QuizReviewScreen extends StatelessWidget {
  /// Accepts either:
  /// - List<Map<String, dynamic>> from QuizResultScreen
  /// - Full API response map (from attempt_review or result)
  final dynamic reviewData;

  const QuizReviewScreen({super.key, required this.reviewData});

  List<Map<String, dynamic>> _extractQuestions() {
    try {
      // Case 1: Already a clean list (from QuizResultScreen)
      if (reviewData is List) {
        return List<Map<String, dynamic>>.from(reviewData);
      }

      // Case 2: Full API response with 'data' → 'questions_data'
      if (reviewData is Map<String, dynamic>) {
        final data = reviewData['data'] ?? reviewData;

        // If questions_data is already a List
        if (data['questions_data'] is List) {
          return List<Map<String, dynamic>>.from(data['questions_data']);
        }

        // If questions_data is a JSON string (common in attempt_review)
        if (data['questions_data'] is String) {
          final decoded = jsonDecode(data['questions_data']) as List;
          return decoded.cast<Map<String, dynamic>>();
        }
        if (data['questions_data'] is String) {
          final decoded = jsonDecode(data['questions_data']) as List;
          return decoded.cast<Map<String, dynamic>>();
        }
      }

      return [];
    } catch (e) {
      print('Error parsing review data: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final questions = _extractQuestions();

    if (questions.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text("Quiz Review"),
          backgroundColor: const Color(0xFF6C5CE7),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(
          child: Text(
            "No review data available",
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ),
      );
    }

    final correctCount = questions.where((q) => q['is_correct'] == true).length;
    final wrongCount = questions.where((q) => q['is_correct'] == false && q['answered'] == true).length;
    final skippedCount = questions.where((q) => q['answered'] != true).length;
    final percentage = questions.isNotEmpty
        ? (correctCount / questions.length * 100).toStringAsFixed(1)
        : "0.0";

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6C5CE7),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Quiz Review",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Top Summary
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 30, 20, 25),
            decoration: const BoxDecoration(
              color: Color(0xFF6C5CE7),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                Text(
                  "$correctCount / ${questions.length}",
                  style: GoogleFonts.poppins(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  "$percentage%",
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _summaryChip("$correctCount", "Correct", Icons.check_circle, Colors.green),
                    _summaryChip("$wrongCount", "Wrong", Icons.close, Colors.red),
                    _summaryChip("$skippedCount", "Skipped", Icons.remove_circle_outline, Colors.grey),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Questions List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: questions.length,
              itemBuilder: (context, index) {
                final q = questions[index];
                final bool isCorrect = q['is_correct'] == true;
                final bool answered = q['answered'] == true;
                final String? selected = q['selected_option']?.toString();

                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  elevation: 6,
                  shadowColor: const Color(0xFF6C5CE7).withOpacity(0.25),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    leading: CircleAvatar(
                      radius: 32,
                      backgroundColor: answered
                          ? (isCorrect ? Colors.green.shade600 : Colors.red.shade600)
                          : Colors.grey.shade400,
                      child: Icon(
                        answered
                            ? (isCorrect ? Icons.check : Icons.close)
                            : Icons.remove,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    title: Text(
                      "Question ${index + 1}",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2D3436),
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            answered
                                ? (isCorrect
                                ? "Correct Answer"
                                : "Wrong • You chose Option $selected")
                                : "Not Answered",
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: answered
                                  ? (isCorrect ? Colors.green.shade700 : Colors.red.shade700)
                                  : Colors.grey.shade600,
                            ),
                          ),
                          if (answered && !isCorrect) ...[
                            const SizedBox(height: 6),
                            Text(
                              "Correct answer was not available",
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.orange.shade700,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    trailing: answered
                        ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isCorrect ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "Option $selected",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: isCorrect ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                      ),
                    )
                        : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String count, String label, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 36),
        const SizedBox(height: 8),
        Text(
          count,
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
        ),
      ],
    );
  }
}