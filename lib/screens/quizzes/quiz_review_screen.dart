import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class QuizReviewScreen extends StatefulWidget {
  final int attemptId; // Only this is required now
  final String? testName;

  const QuizReviewScreen({
    Key? key,
    required this.attemptId,
    this.testName,
  }) : super(key: key);

  @override
  _QuizReviewScreenState createState() => _QuizReviewScreenState();
}

class _QuizReviewScreenState extends State<QuizReviewScreen> {
  List<Map<String, dynamic>> _questions = [];
  Map<String, dynamic> _testStats = {};
  Map<String, dynamic> _metaData = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchReviewData();
  }

  Future<void> _fetchReviewData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final url =
          'https://quizard.in/api_002.php/attempt_review/fulldata/${widget.attemptId}';
      final response = await http.get(Uri.parse(url)).timeout(
        Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse['success'] == true) {
          final data = jsonResponse['data'];

          // Extract metadata
          _metaData = {
            'quiz_title': data['quiz_title'] ?? 'Quiz Review',
            'score': data['obtained_marks'] ?? '0',
            'total_marks': data['total_marks'] ?? '0',
            'percentage': data['result_percentage'] ?? '0',
            'time_taken': data['time_spent_total'] ?? 0,
            'completed_at': data['completed_at'] ?? '',
            'user_name': data['user_name'] ?? '',
          };

          final List<dynamic> rawQuestions = data['questions_data'] ?? [];

          final List<Map<String, dynamic>> parsedQuestions = rawQuestions.map((item) {
            final fullQ = item['full_question'] as Map<String, dynamic>;

            // Convert option1, option2, option3, option4 → List<String>
            List<String> options = [];
            for (int i = 1; i <= 4; i++) {
              String? opt = fullQ['option$i'];
              if (opt != null && opt.toString().trim().isNotEmpty) {
                options.add(opt.toString().trim());
              }
            }

            // Correct answer is 1-based in API, but we convert to 0-based letter (A, B, C, D)
            int correctIdx = (fullQ['correct_answer'] is num)
                ? (fullQ['correct_answer'] as num).toInt()
                : 0;
            String correctOptionLetter = correctIdx >= 0 && correctIdx < 4
                ? String.fromCharCode(65 + correctIdx)
                : '?';

            // Selected option is string like "1", "2", etc. → convert to "A", "B"
            String? selectedLetter;
            if (item['selected_option'] != null) {
              int sel = int.tryParse(item['selected_option'].toString()) ?? -1;
              if (sel >= 1 && sel <= 4) {
                selectedLetter = String.fromCharCode(64 + sel);
              }
            }

            return {
              'question_index': item['question_index'] ?? 0,
              'question_text': fullQ['question']?.toString() ?? 'Question not available',
              'options': options,
              'correct_answer': correctOptionLetter,
              'selected_option': selectedLetter,
              'is_correct': item['is_correct'] == true,
              'answered': item['answered'] == true,
              'marked': false, // not supported in new API, kept for compatibility
              'explanation': fullQ['explanation']?.toString(),
              'difficulty': fullQ['difficulty']?.toString() ?? 'Medium',
            };
          }).toList();

          final stats = _calculateTestStats(parsedQuestions);

          setState(() {
            _questions = parsedQuestions;
            _testStats = stats;
            _isLoading = false;
          });
        } else {
          throw Exception(jsonResponse['message'] ?? 'Failed to load review');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _calculateTestStats(List<Map<String, dynamic>> questions) {
    int total = questions.length;
    int correct = questions.where((q) => q['is_correct'] == true).length;
    int answered = questions.where((q) => q['answered'] == true).length;
    int incorrect = answered - correct;
    int unanswered = total - answered;

    double accuracy = total > 0 ? (correct / total) * 100 : 0.0;

    return {
      'total': total,
      'correct': correct,
      'incorrect': incorrect,
      'unanswered': unanswered,
      'accuracy': accuracy,
      'score': _metaData['score'] ?? '$correct/ $total',
    };
  }

  Future<void> _saveReview() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reviews = prefs.getStringList('saved_reviews') ?? [];

      final reviewToSave = {
        'timestamp': DateTime.now().toIso8601String(),
        'attempt_id': widget.attemptId,
        'test_name': widget.testName ?? _metaData['quiz_title'],
        'stats': _testStats,
        'meta': _metaData,
        'questions': _questions,
      };

      reviews.add(jsonEncode(reviewToSave));
      await prefs.setStringList('saved_reviews', reviews);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Review saved offline!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed'), backgroundColor: Colors.red),
      );
    }
  }

  // === UI Widgets (same beautiful design as before) ===

  Widget _buildStatsCard() {
    return Card(
      elevation: 6,
      margin: EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              _metaData['quiz_title'] ?? 'Quiz Review',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo),
            ),
            SizedBox(height: 12),
            Text(
              'Score: ${_metaData['score']} / ${_metaData['total_marks']}  •  ${_metaData['percentage']}%',
              style: TextStyle(fontSize: 18, color: Colors.blueGrey),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem('Correct', '${_testStats['correct']}', Colors.green),
                _buildStatItem('Wrong', '${_testStats['incorrect']}', Colors.red),
                _buildStatItem('Skipped', '${_testStats['unanswered']}', Colors.orange),
                _buildStatItem('Accuracy', '${_testStats['accuracy'].toStringAsFixed(1)}%', Colors.blue),
              ],
            ),
            SizedBox(height: 16),
            LinearProgressIndicator(
              value: _testStats['correct'] / _testStats['total'],
              backgroundColor: Colors.red.shade100,
              valueColor: AlwaysStoppedAnimation(Colors.green),
              minHeight: 10,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> q, int index) {
    final selected = q['selected_option'] as String?;
    final correct = q['correct_answer'] as String;
    final options = q['options'] as List<String>;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: q['is_correct']
                      ? Colors.green
                      : q['answered']
                      ? Colors.red
                      : Colors.grey,
                  child: Text('${q['question_index'] + 1}', style: TextStyle(color: Colors.white)),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Question ${q['question_index'] + 1}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(q['question_text'], style: TextStyle(fontSize: 15, height: 1.5)),
            SizedBox(height: 20),

            // Options
            ...options.asMap().entries.map((e) {
              int idx = e.key;
              String text = e.value;
              String letter = String.fromCharCode(65 + idx);

              bool isCorrect = letter == correct;
              bool isSelected = letter == selected;

              return Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isCorrect
                      ? Colors.green.withOpacity(0.1)
                      : isSelected
                      ? Colors.red.withOpacity(0.1)
                      : null,
                  border: Border.all(
                    color: isCorrect
                        ? Colors.green
                        : isSelected
                        ? Colors.red
                        : Colors.grey.shade300,
                    width: isCorrect || isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: isCorrect
                          ? Colors.green
                          : isSelected
                          ? Colors.red
                          : Colors.grey.shade300,
                      child: Text(letter, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    SizedBox(width: 12),
                    Expanded(child: Text(text)),
                    if (isCorrect) Icon(Icons.check_circle, color: Colors.green),
                    if (isSelected && !isCorrect) Icon(Icons.cancel, color: Colors.red),
                  ],
                ),
              );
            }).toList(),

            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: q['is_correct']
                    ? Colors.green.withOpacity(0.1)
                    : q['answered']
                    ? Colors.red.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    q['is_correct']
                        ? Icons.check_circle
                        : q['answered']
                        ? Icons.cancel
                        : Icons.help_outline,
                    color: q['is_correct']
                        ? Colors.green
                        : q['answered']
                        ? Colors.red
                        : Colors.grey,
                  ),
                  SizedBox(width: 12),
                  Text(
                    q['is_correct']
                        ? 'Correct Answer'
                        : q['answered']
                        ? 'Wrong Answer'
                        : 'Not Attempted',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Spacer(),
                  Text('Correct: $correct', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            if (q['explanation'] != null && q['explanation'].toString().trim().isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [Icon(Icons.lightbulb, color: Colors.amber), SizedBox(width: 8), Text('Explanation', style: TextStyle(fontWeight: FontWeight.bold))]),
                    SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Text(q['explanation'], style: TextStyle(height: 1.5)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.testName ?? 'Review'),
        actions: [
          IconButton(icon: Icon(Icons.save), onPressed: _saveReview),
          IconButton(icon: Icon(Icons.refresh), onPressed: _fetchReviewData),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text('Failed to load review', style: TextStyle(fontSize: 18)),
            Text(_error!, style: TextStyle(color: Colors.red)),
            ElevatedButton(onPressed: _fetchReviewData, child: Text('Retry')),
          ],
        ),
      )
          : Column(
        children: [
          _buildStatsCard(),
          Expanded(
            child: ListView.builder(
              itemCount: _questions.length,
              itemBuilder: (ctx, i) => _buildQuestionCard(_questions[i], i),
            ),
          ),
        ],
      ),
      floatingActionButton: _questions.isNotEmpty
          ? FloatingActionButton(
        child: Icon(Icons.arrow_upward),
        onPressed: () => PrimaryScrollController.of(context).animateTo(0, duration: Duration(milliseconds: 400), curve: Curves.ease),
      )
          : null,
    );
  }
}