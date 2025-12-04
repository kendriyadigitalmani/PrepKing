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
import '../../core/services/api_service.dart';

class QuizResultScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> result;
  const QuizResultScreen({super.key, required this.result});

  @override
  ConsumerState<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends ConsumerState<QuizResultScreen> {
  late final ConfettiController _confettiController;
  final ScreenshotController _screenshotController = ScreenshotController();

  bool _isLoading = false;
  List<Map<String, dynamic>> _reviewData = [];
  Map<String, dynamic>? _resultData;

  double _score = 0.0;
  double _fullMarks = 50.0;
  double _percentage = 0.0;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 5));
    developer.log('QuizResultScreen → Raw result: ${jsonEncode(widget.result)}');
    _processResultData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        if (_percentage >= 60) {
          _confettiController.play();
        }
      });
    });
  }

  double _getScore() {
    return double.tryParse(
      widget.result['score']?.toString() ??
          widget.result['data']?['score']?.toString() ??
          _resultData?['score']?.toString() ??
          '0',
    ) ??
        0.0;
  }

  double _getFullMarks() {
    return double.tryParse(
      widget.result['full_marks']?.toString() ??
          widget.result['data']?['full_marks']?.toString() ??
          _resultData?['full_marks']?.toString() ??
          '50',
    ) ??
        50.0;
  }

  double _calculatePercentage() {
    final score = _getScore();
    final full = _getFullMarks();
    return full > 0 ? (score / full) * 100 : 0.0;
  }

  void _processResultData() {
    try {
      if (widget.result['success'] == true && widget.result['id'] != null) {
        final resultId = widget.result['id'].toString();
        developer.log('Fresh result → loading detailed data for ID: $resultId');
        _loadDetailedResult(resultId);
        return;
      }

      final data = widget.result['data'] ?? widget.result;
      _resultData = Map<String, dynamic>.from(data);
      _updateFromResultData();
    } catch (e, s) {
      developer.log('Error processing result data', error: e, stackTrace: s);
    }
  }

  void _updateFromResultData() {
    if (_resultData == null) return;

    setState(() {
      _score = double.tryParse(_resultData!['score'].toString()) ?? 0.0;
      _fullMarks = double.tryParse(_resultData!['full_marks'].toString()) ?? 50.0;
      _percentage = _calculatePercentage();

      final questionsData = _resultData!['questions_data'];
      if (questionsData is List && questionsData.isNotEmpty) {
        _reviewData = questionsData.cast<Map<String, dynamic>>().toList();
      } else if (questionsData is String) {
        try {
          final decoded = jsonDecode(questionsData) as List;
          _reviewData = decoded.cast<Map<String, dynamic>>();
        } catch (_) {
          _reviewData = [];
        }
      } else {
        _reviewData = [];
      }
    });
  }

  Future<void> _loadDetailedResult(String resultId) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.get('/result/$resultId');
      if (response['success'] == true && response['data'] != null) {
        _resultData = Map<String, dynamic>.from(response['data']);
        _updateFromResultData();
      }
    } catch (e, s) {
      developer.log('Failed to load detailed result', error: e, stackTrace: s);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load detailed results')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _shareScreenshot() async {
    try {
      final imageBytes = await _screenshotController.capture();
      if (imageBytes == null) return;

      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/quiz_result_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(path)..writeAsBytesSync(imageBytes);

      await Share.shareXFiles(
        [XFile(path)],
        text: "I scored ${_score.toInt()}/${_fullMarks.toInt()} (${_percentage.toStringAsFixed(1)}%) in PrepKing Quiz! Can you beat me?",
        subject: "My Quiz Result - PrepKing",
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Share failed: $e")),
      );
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final passed = _percentage >= 60;
    final totalQuestions = _reviewData.isNotEmpty ? _reviewData.length : 5;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // ONLY THIS PART IS CAPTURED IN SHARE
            Expanded(
              child: Screenshot(
                controller: _screenshotController,
                child: Container(
                  color: const Color(0xFFF8FAFC),
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Container(
                          height: MediaQuery.of(context).size.height * 0.4,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                const Color(0xFF6C5CE7).withOpacity(0.1),
                                Colors.white,
                              ],
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              ConfettiWidget(
                                confettiController: _confettiController,
                                blastDirectionality: BlastDirectionality.explosive,
                                emissionFrequency: 0.05,
                                numberOfParticles: 100,
                                gravity: 0.25,
                                shouldLoop: false,
                                colors: const [
                                  Colors.red, Colors.blue, Colors.green,
                                  Colors.yellow, Colors.purple, Colors.orange,
                                  Colors.pink, Colors.cyan, Colors.amber,
                                ],
                              ),
                              Lottie.asset(
                                passed ? 'assets/lottie/trophy.json' : 'assets/lottie/sad.json',
                                width: 220,
                                height: 220,
                                fit: BoxFit.contain,
                                repeat: true,
                                errorBuilder: (_, __, ___) => Icon(
                                  passed ? Icons.celebration : Icons.sentiment_dissatisfied,
                                  size: 140,
                                  color: passed ? Colors.amber.shade700 : Colors.orange.shade700,
                                ),
                              ),
                              Positioned(
                                bottom: 30,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: passed ? Colors.green.shade600 : Colors.orange.shade600,
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Text(
                                    passed ? "Congratulations!" : "Better Luck Next Time!",
                                    style: GoogleFonts.poppins(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            children: [
                              Card(
                                elevation: 12,
                                shadowColor: const Color(0xFF6C5CE7).withOpacity(0.3),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                child: Padding(
                                  padding: const EdgeInsets.all(28.0),
                                  child: Column(
                                    children: [
                                      Text("Your Final Score",
                                          style: GoogleFonts.poppins(fontSize: 20, color: Colors.grey[700], fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 20),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(_score.toStringAsFixed(0),
                                              style: GoogleFonts.poppins(fontSize: 64, fontWeight: FontWeight.bold, color: const Color(0xFF6C5CE7))),
                                          Text(" / ${_fullMarks.toStringAsFixed(0)}",
                                              style: GoogleFonts.poppins(fontSize: 28, color: Colors.grey[600])),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: passed ? Colors.green.shade600 : Colors.orange.shade600,
                                          borderRadius: BorderRadius.circular(30),
                                        ),
                                        child: Text("${_percentage.toStringAsFixed(1)}%",
                                            style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Card(
                                elevation: 6,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(color: const Color(0xFF6C5CE7).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                            child: const Icon(Icons.quiz_outlined, color: Color(0xFF6C5CE7), size: 28),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text("Instant Quiz Challenge", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                                                Text("$totalQuestions Questions • 2.5 minutes", style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600])),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          _buildStatCard(Icons.timer_outlined, "Time", "2m 30s"),
                                          _buildStatCard(Icons.trending_up, "Accuracy", "${_percentage.toStringAsFixed(0)}%"),
                                          _buildStatCard(Icons.star_border, "Points", _score.toStringAsFixed(0)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // BUTTONS BELOW — NOT INCLUDED IN SHARE
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                children: [
                  // Share Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _shareScreenshot,
                      icon: const Icon(Icons.share, color: Colors.white),
                      label: Text("Share My Result",
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // REVIEW BUTTON — ALWAYS VISIBLE IF DATA EXISTS
                  if (_isLoading)
                    _buildLoadingCard()
                  else if (_reviewData.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          context.push('/quiz-review', extra: {
                            'reviewData': _reviewData,
                            'score': _score,
                            'fullMarks': _fullMarks,
                            'percentage': _percentage,
                          });
                        },
                        icon: const Icon(Icons.remove_red_eye_outlined, color: Colors.white),
                        label: Text("Review Answers (${_reviewData.length})",
                            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C5CE7),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    )
                  else
                    _buildReviewComingSoonCard(),

                  const SizedBox(height: 20),

                  // Back to Quizzes
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: () => context.go('/quizzes'),
                      icon: const Icon(Icons.arrow_back_ios_new),
                      label: Text("Back to Quizzes", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6C5CE7),
                        side: const BorderSide(color: Color(0xFF6C5CE7), width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.blue.shade200)),
      child: const Row(
        children: [
          SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)),
          SizedBox(width: 16),
          Expanded(child: Text("Loading your detailed results...", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildReviewComingSoonCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.amber.shade300)),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, color: Colors.amber.shade700),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Review Coming Soon", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.amber.shade800)),
                Text("Detailed analysis will appear here", style: GoogleFonts.poppins(fontSize: 14, color: Colors.amber.shade700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String label, String value) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [const Color(0xFF6C5CE7).withOpacity(0.15), const Color(0xFF5A4FCF).withOpacity(0.1)]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF6C5CE7).withOpacity(0.3)),
          ),
          child: Icon(icon, color: const Color(0xFF6C5CE7), size: 30),
        ),
        const SizedBox(height: 12),
        Text(value, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF6C5CE7))),
        Text(label, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600)),
      ],
    );
  }
}