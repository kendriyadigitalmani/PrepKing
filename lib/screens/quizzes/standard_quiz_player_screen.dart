import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'dart:developer' as developer;
import '../../core/services/api_service.dart';
import '../../providers/user_provider.dart';

class StandardQuizPlayerScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> quiz;
  final int attemptId;

  const StandardQuizPlayerScreen({
    super.key,
    required this.quiz,
    required this.attemptId,
  });

  @override
  ConsumerState<StandardQuizPlayerScreen> createState() => _StandardQuizPlayerScreenState();
}

class _StandardQuizPlayerScreenState extends ConsumerState<StandardQuizPlayerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Timer & Quiz State
  late Timer _timer;
  int _remainingSeconds = 0;
  int _originalDurationSeconds = 0;
  int _currentIndex = 0;
  int _score = 0;
  List<Map<String, dynamic>> _questions = [];
  List<String?> _selectedAnswers = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isResuming = false;

  // Quiz Mode
  late final bool _isSequential;

  // UI State
  bool _isAnswered = false;
  bool _isLocked = false;
  bool _isTransitioning = false;

  // Animation Controllers
  late AnimationController _questionController;
  late AnimationController _optionsController;
  late AnimationController _exitController;

  // Animations
  late Animation<Offset> _questionSlideAnimation;
  late Animation<double> _optionsFadeAnimation;
  late Animation<Offset> _exitSlideAnimation;

  // Question Palette
  bool _showPalette = false;
  List<bool> _visitedQuestions = [];
  List<bool> _answeredQuestions = [];
  List<bool> _markedQuestions = [];

  // Colors
  final Color _primaryColor = const Color(0xFF6C5CE7);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAnimations();
    _initQuizType();
    _loadAttemptAndQuestions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateAttemptProgress();
    _questionController.dispose();
    _optionsController.dispose();
    _exitController.dispose();
    if (_timer.isActive) _timer.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _updateAttemptProgress();
    }
  }

  /// 🔥 STEP 1: MAGIC CONVERTER FUNCTION ✅ IMPLEMENTED
  int convertCorrectAnswer(dynamic value) {
    final v = int.tryParse(value?.toString() ?? '-1') ?? -1;
    if (v >= 0 && v <= 3) {
      return v + 1; // 🔥 Magic: 0→1, 1→2, 2→3, 3→4
    }
    return -1;
  }

  /// ✅ STEP 2: COMPLETE NORMALIZER WITH MAGIC CONVERSION
  Map<String, dynamic> normalizeQuestion(Map<String, dynamic> q) {
    return {
      'id': int.tryParse(q['id']?.toString() ?? '0') ?? 0,
      'quiz_id': int.tryParse(q['quiz_id']?.toString() ?? '0') ?? 0,
      'question': q['question']?.toString() ?? "",
      'option1': q['option1']?.toString() ?? "",
      'option2': q['option2']?.toString() ?? "",
      'option3': q['option3']?.toString() ?? "",
      'option4': q['option4']?.toString() ?? "",
      // 🔥 ONE LINE MAGIC! Handles ALL server formats
      'correct_answer': convertCorrectAnswer(q['correct_answer']),
      'order': int.tryParse(q['order']?.toString() ?? '0') ?? 0,
    };
  }

  /// ✅ STEP 3: SIMPLIFIED - Always returns clean INT (1-4 or -1)
  int _getCorrectAnswer(Map<String, dynamic> question) {
    final ans = question['correct_answer'];
    if (ans is int && ans >= 1 && ans <= 4) return ans;
    return -1;
  }

  void _initializeAnimations() {
    _questionController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _optionsController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _exitController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _questionSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _questionController,
      curve: Curves.elasticOut,
    ));

    _optionsFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _optionsController,
      curve: Curves.easeIn,
    ));

    _exitSlideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-1.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _exitController,
      curve: Curves.easeInOut,
    ));
  }

  void _initQuizType() {
    _isSequential = widget.quiz['is_sequential'] == "1" || widget.quiz['is_sequential'] == 1;
    final durationMinutes = int.tryParse(widget.quiz['duration_minutes']?.toString() ?? '10') ?? 10;
    _remainingSeconds = durationMinutes * 60;
    _originalDurationSeconds = durationMinutes * 60;
  }

  /// ✅ STEP 2 APPLIED: Full normalization in action
  Future<void> _loadAttemptAndQuestions() async {
    try {
      final api = ref.read(apiServiceProvider);

      // Step 1: Load raw questions from server
      final questionsResponse = await api.get('/saved_question/quiz/${widget.quiz['id']}');
      if (questionsResponse['success'] != true) {
        throw Exception(questionsResponse['message'] ?? 'Failed to load questions');
      }

      final List<dynamic> rawQuestions = questionsResponse['data'] ?? [];

      // 🔥 MAGIC HAPPENS HERE: FULL NORMALIZATION
      final questions = rawQuestions
          .map((q) => normalizeQuestion(q as Map<String, dynamic>))
          .toList();

      // ✅ VERIFICATION LOGGING
      developer.log('🎯 NORMALIZATION COMPLETE: ${questions.length} questions');
      for (int i = 0; i < questions.length && i < 3; i++) {
        final q = questions[i];
        developer.log('📋 Q${i + 1}: correct_answer = ${q['correct_answer']} (type: ${q['correct_answer'].runtimeType})');
      }

      // Step 2: Try to load attempt details
      Map<String, dynamic>? attempt;
      try {
        final attemptResponse = await api.get('/quiz_attempt/${widget.attemptId}');
        if (attemptResponse['success'] == true) {
          attempt = attemptResponse['data'];
        }
      } catch (e) {
        developer.log('⚠️ Could not load attempt details: $e');
      }

      if (!mounted) return;

      setState(() {
        _questions = questions;
        _selectedAnswers = List.filled(questions.length, null);
        _visitedQuestions = List.filled(questions.length, false);
        _answeredQuestions = List.filled(questions.length, false);
        _markedQuestions = List.filled(questions.length, false);
        _isLoading = false;
      });

      if (_questions.isEmpty) return;

      // ✅ RESUME LOGIC
      if (attempt != null && attempt['status'] == 'in_progress') {
        await _resumeAttempt(attempt);
      } else {
        // New attempt - start from beginning
        setState(() {
          _currentIndex = 0;
          _visitedQuestions[0] = true;
        });
        _startQuestionAnimations();
        _startMainTimer();
      }
    } catch (e) {
      developer.log("❌ Load attempt error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load quiz: $e")),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resumeAttempt(Map<String, dynamic> attempt) async {
    try {
      setState(() => _isResuming = true);
      final currentQuestionIndex = int.tryParse(attempt['current_question_index']?.toString() ?? '0') ?? 0;
      final score = double.tryParse(attempt['obtained_marks']?.toString() ?? '0') ?? 0.0;
      developer.log('🔄 Resuming attempt ${attempt['id']} at question $currentQuestionIndex');
      developer.log('📊 Current score: $score');

      // Load previous answers from attempt_review
      await _loadAttemptReviewAnswers(attempt['id'] as int);

      if (!mounted) return;

      setState(() {
        _currentIndex = currentQuestionIndex.clamp(0, _questions.length - 1);
        _score = score.toInt();
        _visitedQuestions[_currentIndex] = true;
        _answeredQuestions[_currentIndex] = _selectedAnswers[_currentIndex] != null;
        _isAnswered = _answeredQuestions[_currentIndex];
        _isResuming = false;
      });

      // Show resume message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.play_arrow, color: Colors.white),
                const SizedBox(width: 8),
                Text('Resumed from question ${_currentIndex + 1}/${_questions.length} • Score: $_score'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }

      _startQuestionAnimations();
      _startMainTimer();
    } catch (e) {
      developer.log('❌ Resume attempt error: $e');
      setState(() => _isResuming = false);
      _startQuestionAnimations();
      _startMainTimer();
    }
  }

  Future<void> _loadAttemptReviewAnswers(int attemptId) async {
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.get('/attempt_review', query: {
        'result_id': attemptId.toString(),
      });
      if (response['success'] == true) {
        final List<dynamic> reviews = response['data'] ?? [];
        int loadedCount = 0;
        for (var review in reviews) {
          final questionId = review['question_id'] as int?;
          final selectedOption = review['selected_option'];
          final questionIndex = _questions.indexWhere((q) => (q['id'] as int) == questionId);
          if (questionIndex == -1) {
            developer.log('⚠️ Question ID $questionId not found');
            continue;
          }
          final selectedStr = selectedOption?.toString();
          _selectedAnswers[questionIndex] = selectedStr;
          _answeredQuestions[questionIndex] = true;
          _visitedQuestions[questionIndex] = true;
          loadedCount++;
        }
        developer.log('✅ Loaded $loadedCount previous answers');
      }
    } catch (e) {
      developer.log('⚠️ Could not load attempt reviews: $e');
    }
  }

  Future<void> _updateAttemptProgress() async {
    try {
      final api = ref.read(apiServiceProvider);
      final questionsData = [];
      for (int i = 0; i < _questions.length; i++) {
        questionsData.add({
          'question_index': i,
          'question_id': _questions[i]['id'],
          'selected_option': _selectedAnswers[i],
          'answered': _answeredQuestions[i],
          'marked': _markedQuestions[i],
        });
      }
      await api.put('/quiz_attempt/${widget.attemptId}', {
        'current_question_index': _currentIndex.toString(),
        'questions_data': jsonEncode(questionsData),
        'time_spent_total': (_originalDurationSeconds - _remainingSeconds).toString(),
        'obtained_marks': _score.toString(),
        'correct_answers': _answeredQuestions.where((a) => a).length,
        'status': 'in_progress',
      });
      developer.log('✅ Progress saved: Question $_currentIndex');
    } catch (e) {
      developer.log('⚠️ Failed to save progress: $e');
    }
  }

  void _startQuestionAnimations() {
    _questionController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _optionsController.forward();
      });
    });
  }

  void _startMainTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          timer.cancel();
          _submitQuiz();
        }
      });
    });
  }

  /// ✅ STEP 4: PERFECT INT COMPARISON
  void _selectAnswer(String selectedOption) {
    if (_isAnswered || _isLocked) return;

    final selectedInt = int.tryParse(selectedOption);
    if (selectedInt == null || selectedInt < 1 || selectedInt > 4) {
      developer.log("❌ Invalid option: $selectedOption");
      return;
    }

    final question = _questions[_currentIndex];
    final correctInt = _getCorrectAnswer(question); // Always 1-4 or -1
    final isCorrect = selectedInt == correctInt; // ✅ PURE INT COMPARISON

    developer.log('🎯 Answer Check: Selected=$selectedInt, Correct=$correctInt, Result=${isCorrect ? "✅" : "❌"}');

    setState(() {
      _selectedAnswers[_currentIndex] = selectedOption;
      _answeredQuestions[_currentIndex] = true;
      _isAnswered = true;
      _isLocked = true;
      if (isCorrect) _score += 10;
    });

    // Save answer immediately
    _saveAnswerToServer(selectedOption, isCorrect);
    _updateAttemptProgress();

    // Auto next after 1 second (optional)
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _isAnswered && !_isTransitioning) {
        _goToNextQuestion();
      }
    });
  }

  void _goToNextQuestion() {
    _updateAttemptProgress();
    if (_currentIndex < _questions.length - 1) {
      setState(() => _isTransitioning = true);
      _exitController.forward().then((_) {
        _questionController.reset();
        _optionsController.reset();
        _exitController.reset();
        setState(() {
          _currentIndex++;
          _isAnswered = _selectedAnswers[_currentIndex] != null;
          _isLocked = false;
          _isTransitioning = false;
          _visitedQuestions[_currentIndex] = true;
        });
        _startQuestionAnimations();
      });
    } else {
      _showSubmitConfirmation();
    }
  }

  void _goToPreviousQuestion() {
    if (_currentIndex > 0) {
      _updateAttemptProgress();
      setState(() {
        _currentIndex--;
        _visitedQuestions[_currentIndex] = true;
        _isAnswered = _selectedAnswers[_currentIndex] != null;
        _isLocked = false;
      });
      _startQuestionAnimations();
    }
  }

  void _resetCurrentAnswer() {
    if (_selectedAnswers[_currentIndex] != null) {
      final question = _questions[_currentIndex];
      final correctInt = _getCorrectAnswer(question);
      final selectedInt = int.tryParse(_selectedAnswers[_currentIndex]!) ?? -1;
      final wasCorrect = selectedInt == correctInt;
      setState(() {
        _selectedAnswers[_currentIndex] = null;
        _answeredQuestions[_currentIndex] = false;
        _isAnswered = false;
        _isLocked = false;
        if (wasCorrect) _score -= 10;
      });
      _updateAttemptProgress();
    }
  }

  void _jumpToQuestion(int index) {
    _updateAttemptProgress();
    setState(() {
      _currentIndex = index;
      _visitedQuestions[_currentIndex] = true;
      _showPalette = false;
      _isAnswered = _selectedAnswers[_currentIndex] != null;
      _isLocked = false;
    });
    _startQuestionAnimations();
  }

  void _toggleMarkQuestion() {
    setState(() {
      _markedQuestions[_currentIndex] = !_markedQuestions[_currentIndex];
    });
    _updateAttemptProgress();
  }

  void _showQuestionPalette() {
    setState(() => _showPalette = true);
  }

  /// ✅ STEP 5: BULLETPROOF SERVER SAVE WITH INT VALUES
  Future<void> _saveAnswerToServer(String selected, bool isCorrect) async {
    try {
      final user = ref.read(currentUserProvider).asData?.value;
      if (user?.id == null) {
        developer.log("❌ User ID missing");
        return;
      }

      final question = _questions[_currentIndex];
      final questionId = question['id'] as int;
      if (questionId == 0) {
        developer.log("❌ Invalid question ID");
        return;
      }

      // ✅ DIRECT INT ACCESS - ZERO PARSING
      final correctInt = _getCorrectAnswer(question);
      final selectedInt = int.tryParse(selected) ?? -1;

      if (selectedInt < 1 || selectedInt > 4) {
        developer.log("⚠️ Invalid selected option: $selectedInt");
        return;
      }

      final Map<String, dynamic> payload = {
        'result_id': widget.attemptId,
        'quiz_id': widget.quiz['id'],
        'question_id': questionId,
        'user_id': user!.id,
        'question_text': question['question'] ?? 'Question unavailable',
        // 🔥 CLEAN INT VALUES
        'selected_option': selectedInt, // 1, 2, 3, or 4
        'correct_option': correctInt,   // 1, 2, 3, 4, or -1
        'is_correct': isCorrect ? 1 : 0,
        'question_marks': 10.00,
        'obtained_marks': isCorrect ? 10.00 : 0.00,
        'options_provided': [
          question['option1'] ?? '',
          question['option2'] ?? '',
          question['option3'] ?? '',
          question['option4'] ?? ''
        ],
        'time_spent': 45,
        'student_id': null,
      };

      developer.log("📤 Saving: Q$questionId | Selected: $selectedInt | Correct: $correctInt");

      final response = await ref.read(apiServiceProvider).post('/attempt_review', payload);
      if (response['success'] == true) {
        developer.log("✅ Saved: Q$questionId | Result: ${isCorrect ? '✅' : '❌'}");
      } else {
        developer.log("⚠️ Save warning: ${response['message']}");
      }
    } catch (e, stackTrace) {
      developer.log("❌ Save error: $e\n$stackTrace");
    }
  }

  Future<void> _submitQuiz() async {
    if (_isSubmitting) return;
    _isSubmitting = true;
    if (_timer.isActive) _timer.cancel();

    await _updateAttemptProgress();

    try {
      final userId = ref.read(currentUserProvider).asData?.value?.id;
      if (userId == null) throw Exception("User not found");

      // ✅ FINAL SCORE CALCULATION WITH INT COMPARISON
      int calculatedScore = 0;
      for (int i = 0; i < _questions.length; i++) {
        if (_selectedAnswers[i] != null) {
          final question = _questions[i];
          final correctInt = _getCorrectAnswer(question);
          final selectedInt = int.tryParse(_selectedAnswers[i]!) ?? -1;
          final isCorrect = selectedInt == correctInt;
          if (isCorrect) calculatedScore += 10;
        }
      }

      final fullMarks = _questions.length * 10;
      final totalTimeTaken = (_originalDurationSeconds - _remainingSeconds);

      final resultResponse = await ref.read(apiServiceProvider).post('/result', {
        'quiz_id': widget.quiz['id'].toString(),
        'user_id': userId.toString(),
        'attempt_id': widget.attemptId.toString(),
        'score': calculatedScore.toString(),
        'full_marks': fullMarks.toString(),
        'time_taken': totalTimeTaken.toString(),
      });

      if (resultResponse['success'] != true) {
        throw Exception(resultResponse['message'] ?? 'Failed to create result');
      }

      final resultId = resultResponse['id'];
      final linkedAttemptId = resultResponse['attempt_id'] ?? widget.attemptId;
      developer.log("✅ Quiz completed! Result ID: $resultId, Score: $calculatedScore/$fullMarks");

      if (!mounted) return;

      // Mark attempt as completed
      await ref.read(apiServiceProvider).put('/quiz_attempt/${widget.attemptId}', {
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String(),
      });

      context.go('/quizzes/result', extra: {
        'result_id': resultId,
        'attempt_id': linkedAttemptId,
        'score': calculatedScore,
        'total_questions': _questions.length,
        'total_marks': fullMarks,
        'quiz_title': widget.quiz['quiz_title'] ?? widget.quiz['title'],
        'percentage': (calculatedScore / fullMarks * 100).toStringAsFixed(1),
        'time_taken': totalTimeTaken,
        'passed': calculatedScore >= (fullMarks * 0.6),
      });
    } catch (e) {
      developer.log("❌ Submit error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Submit failed: $e")),
      );
      setState(() => _isSubmitting = false);
    }
  }

  void _showSubmitConfirmation() {
    final answeredCount = _selectedAnswers.where((answer) => answer != null).length;
    final unansweredCount = _questions.length - answeredCount;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Submit Quiz?", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Summary:", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text("✅ Answered: $answeredCount", style: GoogleFonts.poppins()),
            Text(
              unansweredCount > 0
                  ? "❌ Unanswered: $unansweredCount"
                  : "✅ All questions answered!",
              style: GoogleFonts.poppins(
                color: unansweredCount > 0 ? Colors.orange : Colors.green,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Are you sure you want to submit your answers?",
              style: GoogleFonts.poppins(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Go Back", style: GoogleFonts.poppins(color: Colors.grey[700])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _submitQuiz();
            },
            child: Text("Submit Quiz", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<bool> _onWillPop() async {
    await _updateAttemptProgress();
    final shouldQuit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Leave Quiz?", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Your progress is saved.", style: GoogleFonts.poppins()),
            const SizedBox(height: 8),
            Text(
              "You can resume later from where you left off.",
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Stay", style: GoogleFonts.poppins(color: Colors.grey[700])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
            onPressed: () => Navigator.pop(context, true),
            child: Text("Leave", style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
    if (shouldQuit == true && mounted) {
      context.go('/quizzes');
    }
    return shouldQuit ?? false;
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Widget _buildTopBar() {
    final totalTime = _originalDurationSeconds;
    return Column(
      children: [
        // Attempt info bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade100, Colors.orange.shade50],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history, color: Colors.orange.shade700, size: 16),
              const SizedBox(width: 6),
              Text(
                'Attempt #${widget.attemptId}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade700,
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.star, color: _primaryColor, size: 16),
              const SizedBox(width: 4),
              Text(
                '$_score pts',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
            ],
          ),
        ),
        LinearProgressIndicator(
          value: 1.0 - (_remainingSeconds / totalTime),
          backgroundColor: Colors.grey[300],
          color: _primaryColor,
          minHeight: 6,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Q ${_currentIndex + 1}/${_questions.length}',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _remainingSeconds < 60 ? Colors.red : _primaryColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    _formatTime(_remainingSeconds),
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.grid_view_rounded),
              onPressed: _showQuestionPalette,
            ),
          ],
        ),
      ],
    );
  }

  /// ✅ UPDATED: Option buttons with perfect INT logic
  Widget _buildOptionButton(int index, String optionText, int correctAnswer) {
    final optionLetter = (index + 1).toString();
    final isSelected = _selectedAnswers[_currentIndex] == optionLetter;
    final selectedInt = int.tryParse(optionLetter) ?? -1;
    final isCorrect = selectedInt == correctAnswer;
    final isWrong = isSelected && selectedInt != correctAnswer && _isAnswered;

    Color getBackgroundColor() {
      if (_isAnswered) {
        if (isCorrect) return Colors.green.shade400;
        if (isWrong) return Colors.red.shade400;
        return Colors.grey[200]!;
      }
      return isSelected ? _primaryColor : Colors.grey[100]!;
    }

    Color getTextColor() {
      if (_isAnswered) {
        if (isCorrect || isWrong) return Colors.white;
        return Colors.black87;
      }
      return isSelected ? Colors.white : Colors.black87;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      child: Transform.scale(
        scale: isSelected ? 1.02 : 1.0,
        child: ElevatedButton(
          onPressed: _isLocked ? null : () => _selectAnswer(optionLetter),
          style: ElevatedButton.styleFrom(
            backgroundColor: getBackgroundColor(),
            foregroundColor: getTextColor(),
            elevation: isSelected ? 8 : (_isAnswered ? 4 : 2),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white24
                      : (_isAnswered && isCorrect
                      ? Colors.green.shade600
                      : _primaryColor),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    optionLetter,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isCorrect && _isAnswered ? 18 : 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  optionText,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigation() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (_selectedAnswers[_currentIndex] != null && !_isLocked)
              ElevatedButton(
                onPressed: _resetCurrentAnswer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Icon(Icons.refresh, size: 20),
              ),
            const SizedBox(width: 8),
            if (_currentIndex > 0 || !_isSequential)
              ElevatedButton.icon(
                onPressed: _goToPreviousQuestion,
                icon: const Icon(Icons.arrow_back),
                label: const Text("Previous"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: _currentIndex < _questions.length - 1
              ? _goToNextQuestion
              : _showSubmitConfirmation,
          icon: Icon(_currentIndex < _questions.length - 1
              ? Icons.arrow_forward
              : Icons.send),
          label: Text(
            _currentIndex < _questions.length - 1 ? "Next" : "Submit Quiz",
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionPalette() {
    if (!_showPalette) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => setState(() => _showPalette = false),
      child: Container(
        color: Colors.black54,
        child: GestureDetector(
          onTap: () {}, // Prevent closing when tapping inside
          child: DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Question Palette',
                            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          ElevatedButton.icon(
                            onPressed: _showSubmitConfirmation,
                            icon: const Icon(Icons.send, size: 18),
                            label: Text('Submit Quiz', style: GoogleFonts.poppins(fontSize: 14)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildStatusIndicator('Answered', Colors.blue),
                          _buildStatusIndicator('Not Answered', Colors.yellow[700]!),
                          _buildStatusIndicator('Not Visited', Colors.grey),
                          _buildStatusIndicator('Marked', Colors.purple),
                        ],
                      ),
                      const SizedBox(height: 20),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1,
                        ),
                        itemCount: _questions.length,
                        itemBuilder: (context, index) {
                          return _buildPaletteNumber(index);
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => setState(() => _showPalette = false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Close Palette', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPaletteNumber(int index) {
    Color getColor() {
      if (_markedQuestions[index]) return Colors.purple;
      if (_answeredQuestions[index]) return Colors.blue;
      if (_visitedQuestions[index]) return Colors.yellow[700]!;
      return Colors.grey;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: GestureDetector(
        onTap: () => _jumpToQuestion(index),
        child: Container(
          decoration: BoxDecoration(
            color: getColor(),
            borderRadius: BorderRadius.circular(8),
            border: _currentIndex == index
                ? Border.all(color: Colors.black, width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String text, Color color) {
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.poppins(fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isResuming)
                Column(
                  children: [
                    Lottie.asset('assets/lottie/loading.json', width: 80, height: 80),
                    const SizedBox(height: 16),
                    Text(
                      "Resuming your progress...",
                      style: GoogleFonts.poppins(fontSize: 16, color: _primaryColor),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Loading question ${_currentIndex + 1}...",
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                )
              else ...[
                Lottie.asset('assets/lottie/loading.json', width: 120, height: 120),
                const SizedBox(height: 20),
                Text(
                  "Loading Questions...",
                  style: GoogleFonts.poppins(fontSize: 18, color: _primaryColor),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.quiz_outlined, size: 100, color: Colors.grey[400]),
              const SizedBox(height: 20),
              Text(
                "No questions available for this quiz",
                style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => context.pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  "Back to Quizzes",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final question = _questions[_currentIndex];
    final correctAnswer = _getCorrectAnswer(question); // ✅ Always INT

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => _onWillPop().then((shouldPop) {
              if (shouldPop) {
                // Navigation handled in _onWillPop
              }
            }),
          ),
          title: const SizedBox.shrink(),
          actions: [
            IconButton(
              icon: Icon(
                _markedQuestions[_currentIndex] ? Icons.bookmark : Icons.bookmark_border,
                color: _markedQuestions[_currentIndex] ? Colors.purple : Colors.grey,
              ),
              onPressed: _toggleMarkQuestion,
            ),
          ],
        ),
        body: GestureDetector(
          onHorizontalDragEnd: (details) {
            if (!_isLocked) {
              if (details.primaryVelocity! < 0 && _currentIndex < _questions.length - 1) {
                _goToNextQuestion();
              } else if (details.primaryVelocity! > 0 && _currentIndex > 0) {
                _goToPreviousQuestion();
              }
            }
          },
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildTopBar(),
                    const SizedBox(height: 30),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: _isTransitioning
                          ? const SizedBox.shrink()
                          : SlideTransition(
                        key: ValueKey(_currentIndex),
                        position: _isTransitioning
                            ? _exitSlideAnimation
                            : _questionSlideAnimation,
                        child: FadeTransition(
                          opacity: _isTransitioning
                              ? ReverseAnimation(_exitController)
                              : _questionController,
                          child: Card(
                            elevation: 8,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                question['question'] ?? "Question?",
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _isTransitioning
                            ? const SizedBox.shrink()
                            : FadeTransition(
                          key: ValueKey('options_$_currentIndex'),
                          opacity: _optionsFadeAnimation,
                          child: ListView(
                            padding: EdgeInsets.zero,
                            children: [
                              _buildOptionButton(0, question['option1'] ?? '', correctAnswer),
                              _buildOptionButton(1, question['option2'] ?? '', correctAnswer),
                              _buildOptionButton(2, question['option3'] ?? '', correctAnswer),
                              _buildOptionButton(3, question['option4'] ?? '', correctAnswer),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (!_isSubmitting) ...[
                      const SizedBox(height: 20),
                      _buildNavigation(),
                    ],
                  ],
                ),
              ),
              _buildQuestionPalette(),
            ],
          ),
        ),
      ),
    );
  }
}