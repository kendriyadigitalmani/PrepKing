// lib/screens/quizzes/quiz_result_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:developer' as developer;

class QuizResultScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> result;
  const QuizResultScreen({super.key, required this.result});

  @override
  ConsumerState<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends ConsumerState<QuizResultScreen> {
  late final ConfettiController _confettiController;
  final ScreenshotController _screenshotController = ScreenshotController();

  double _score = 0.0;
  double _fullMarks = 50.0;
  double _percentage = 0.0;
  String _quizTitle = "Quiz";
  int _attemptId = 0;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 5));
    _extractResultData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted && _percentage >= 60) {
          _confettiController.play();
        }
      });
    });
  }

  void _extractResultData() {
    try {
      final data = widget.result['data'] ?? widget.result;

      final String? idStr = data['id']?.toString() ??
          data['attempt_id']?.toString() ??
          data['attemptId']?.toString();
      _attemptId = int.tryParse(idStr ?? '') ?? 0;

      _quizTitle = data['quiz_title']?.toString() ??
          data['title']?.toString() ??
          "Quiz Result";

      final String? scoreStr = data['obtained_marks']?.toString() ??
          data['score']?.toString() ??
          data['result_score']?.toString();
      final String? totalStr = data['total_marks']?.toString() ??
          data['full_marks']?.toString() ??
          '50';

      _score = double.tryParse(scoreStr ?? '0') ?? 0.0;
      _fullMarks = double.tryParse(totalStr ?? '50') ?? 50.0;
      _percentage = _fullMarks > 0 ? (_score / _fullMarks) * 100 : 0.0;

      developer.log(
          'QuizResult → attemptId: $_attemptId | Score: $_score/$_fullMarks (${_percentage.toStringAsFixed(1)}%)');
      setState(() {});
    } catch (e, s) {
      developer.log('Error extracting result data', error: e, stackTrace: s);
      setState(() {});
    }
  }

  Future<void> _shareScreenshot() async {
    // Critical: Delay to ensure full layout + confetti render
    await Future.delayed(const Duration(milliseconds: 800));

    try {
      final imageBytes = await _screenshotController.capture(
        delay: const Duration(milliseconds: 400),
        pixelRatio: MediaQuery.of(context).devicePixelRatio * 1.5, // High quality
      );

      if (imageBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to capture screenshot")),
        );
        return;
      }

      final quizData = widget.result['data'] ?? widget.result;
      final String slugOrId = () {
        final slug = quizData['slug']?.toString().trim();
        if (slug != null && slug.isNotEmpty) return slug;
        final quizId = quizData['quiz_id'] ?? quizData['id'];
        return quizId?.toString() ?? 'unknown';
      }();

      final String shareUrl = "https://prepking.online/q/$slugOrId";
      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/quiz_result_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(path)..writeAsBytesSync(imageBytes);

      await Share.shareXFiles(
        [XFile(path)],
        text:
        "I scored ${_score.toInt()}/${_fullMarks.toInt()} (${_percentageString}%) in \"$_quizTitle\" on PrepKing!\n\nCan you beat my score?\n\n$shareUrl",
        subject: "My Quiz Result - PrepKing",
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Share failed: $e")),
        );
      }
    }
  }

  String get _percentageString => _percentage.toStringAsFixed(1);

  void _navigateToReview() {
    if (_attemptId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Review not available for this attempt")),
      );
      return;
    }
    context.push(
      '/quiz-review',
      extra: {
        'attemptId': _attemptId,
        'testName': _quizTitle,
      },
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final passed = _percentage >= 60;
    final totalQuestions =
    (widget.result['data']?['total_questions'] ?? 5).toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ==================== FULL SCORECARD (CAPTURED AREA) ====================
              Screenshot(
                controller: _screenshotController,
                child: Container(
                  color: const Color(0xFFF8FAFC),
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header: Lottie + Message
                          Container(
                            padding: const EdgeInsets.fromLTRB(20, 40, 20, 30),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  const Color(0xFF6C5CE7).withOpacity(0.15),
                                  Colors.white.withOpacity(0.9),
                                  Colors.white,
                                ],
                              ),
                            ),
                            child: Column(
                              children: [
                                Lottie.asset(
                                  passed
                                      ? 'assets/lottie/trophy.json'
                                      : 'assets/lottie/sad.json',
                                  width: 260,
                                  height: 260,
                                  fit: BoxFit.contain,
                                  repeat: true,
                                  errorBuilder: (_, __, ___) => Icon(
                                    passed ? Icons.celebration : Icons.sentiment_dissatisfied,
                                    size: 160,
                                    color: passed ? Colors.amber.shade700 : Colors.orange.shade700,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 36, vertical: 18),
                                  decoration: BoxDecoration(
                                    color:
                                    passed ? Colors.green.shade600 : Colors.orange.shade600,
                                    borderRadius: BorderRadius.circular(32),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (passed ? Colors.green : Colors.orange)
                                            .withOpacity(0.5),
                                        blurRadius: 16,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    passed
                                        ? "Congratulations! You Passed!"
                                        : "Better Luck Next Time!",
                                    style: GoogleFonts.poppins(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Score & Stats
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              children: [
                                // Final Score Card
                                Card(
                                  elevation: 14,
                                  shadowColor: const Color(0xFF6C5CE7).withOpacity(0.35),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(32.0),
                                    child: Column(
                                      children: [
                                        Text(
                                          "Your Final Score",
                                          style: GoogleFonts.poppins(
                                            fontSize: 22,
                                            color: Colors.grey[700],
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 28),
                                        FittedBox(
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                _score.toStringAsFixed(0),
                                                style: GoogleFonts.poppins(
                                                  fontSize: 84,
                                                  fontWeight: FontWeight.bold,
                                                  color: const Color(0xFF6C5CE7),
                                                ),
                                              ),
                                              Text(
                                                " / ${_fullMarks.toStringAsFixed(0)}",
                                                style: GoogleFonts.poppins(
                                                  fontSize: 38,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 44, vertical: 16),
                                          decoration: BoxDecoration(
                                            color: passed
                                                ? Colors.green.shade600
                                                : Colors.orange.shade600,
                                            borderRadius: BorderRadius.circular(32),
                                          ),
                                          child: Text(
                                            "${_percentageString}%",
                                            style: GoogleFonts.poppins(
                                              fontSize: 38,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 28),

                                // Quiz Info + Stats Card
                                Card(
                                  elevation: 10,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(14),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF6C5CE7)
                                                    .withOpacity(0.12),
                                                borderRadius:
                                                BorderRadius.circular(16),
                                              ),
                                              child: const Icon(Icons.quiz_outlined,
                                                  color: Color(0xFF6C5CE7), size: 32),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _quizTitle,
                                                    style: GoogleFonts.poppins(
                                                        fontSize: 20,
                                                        fontWeight:
                                                        FontWeight.w600),
                                                  ),
                                                  Text(
                                                    "$totalQuestions Questions • Instant Quiz",
                                                    style: GoogleFonts.poppins(
                                                        fontSize: 15,
                                                        color: Colors.grey[600]),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 28),
                                        Row(
                                          mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                          children: [
                                            _buildStatCard(Icons.timer_outlined,
                                                "Time Taken", "2m 30s"),
                                            _buildStatCard(Icons.trending_up,
                                                "Accuracy", "${_percentageString}%"),
                                            _buildStatCard(Icons.star,
                                                "Points", _score.toStringAsFixed(0)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 80), // Clean bottom padding for share
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Confetti (inside screenshot)
                      if (passed)
                        ConfettiWidget(
                          confettiController: _confettiController,
                          blastDirectionality: BlastDirectionality.explosive,
                          emissionFrequency: 0.04,
                          numberOfParticles: 80,
                          gravity: 0.18,
                          shouldLoop: false,
                          colors: const [
                            Colors.red,
                            Colors.blue,
                            Colors.green,
                            Colors.yellow,
                            Colors.purple,
                            Colors.orange,
                            Colors.pink
                          ],
                        ),
                    ],
                  ),
                ),
              ),

              // ==================== ACTION BUTTONS (OUTSIDE SCREENSHOT) ====================
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 40, 20, 50),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: _shareScreenshot,
                        icon: const Icon(Icons.share, size: 28),
                        label: Text(
                          "Share My Result",
                          style: GoogleFonts.poppins(
                              fontSize: 19, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          elevation: 8,
                          shadowColor: Colors.green.withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: _attemptId > 0 ? _navigateToReview : null,
                        icon: const Icon(Icons.remove_red_eye_outlined, size: 28),
                        label: Text(
                          _attemptId > 0 ? "Review Answers" : "Review Not Available",
                          style: GoogleFonts.poppins(
                              fontSize: 19, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _attemptId > 0
                              ? const Color(0xFF6C5CE7)
                              : Colors.grey.shade400,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: OutlinedButton.icon(
                        onPressed: () => context.go('/quizzes'),
                        icon: const Icon(Icons.arrow_back_ios_new, size: 22),
                        label: Text(
                          "Back to Quizzes",
                          style: GoogleFonts.poppins(
                              fontSize: 19, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6C5CE7),
                          side: const BorderSide(
                              color: Color(0xFF6C5CE7), width: 2.8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String label, String value) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF6C5CE7).withOpacity(0.2),
                const Color(0xFF5A4FCF).withOpacity(0.1)
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF6C5CE7).withOpacity(0.4)),
          ),
          child: Icon(icon, color: const Color(0xFF6C5CE7), size: 34),
        ),
        const SizedBox(height: 14),
        Text(
          value,
          style: GoogleFonts.poppins(
              fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF6C5CE7)),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}