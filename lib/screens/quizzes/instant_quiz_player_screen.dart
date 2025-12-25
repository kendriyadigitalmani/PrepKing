// lib/screens/quizzes/instant_quiz_player_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:vibration/vibration.dart';
import 'dart:developer' as developer;
import '../../core/services/api_service.dart';
import '../../providers/user_provider.dart';

/// ✅ UNIVERSAL SAFE INT PARSER - PREVENTS ALL TYPE ERRORS
int safeIntParse(dynamic value, {String? context, required int defaultValue}) {
  if (value == null) {
    developer.log('❌ NULL VALUE ERROR | Context: $context | Using default: $defaultValue');
    return defaultValue;
  }
  if (value is int) {
    developer.log('✅ INT VALUE OK | Context: $context | Value: $value');
    return value;
  }
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) {
      developer.log('✅ STRING→INT SUCCESS | Context: $context | "$value" → $parsed');
      return parsed;
    } else {
      developer.log('❌ INVALID STRING ERROR | Context: $context | "$value" → Using default: $defaultValue');
      return defaultValue;
    }
  }
  developer.log('❌ TYPE MISMATCH ERROR | Context: $context | Type: ${value.runtimeType} | Value: $value → Using default: $defaultValue');
  return defaultValue;
}

class InstantQuizPlayerScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> quiz;
  final int attemptId;
  const InstantQuizPlayerScreen({
    super.key,
    required this.quiz,
    required this.attemptId,
  });

  @override
  ConsumerState<InstantQuizPlayerScreen> createState() => _InstantQuizPlayerScreenState();
}

class _InstantQuizPlayerScreenState extends ConsumerState<InstantQuizPlayerScreen>
    with TickerProviderStateMixin {
  // Timer & Quiz State
  late Timer _timer;
  int _remainingSeconds = 0;
  int _currentIndex = 0;
  int _score = 0;
  List<Map<String, dynamic>> _questions = [];
  List<String?> _selectedAnswers = [];
  List<bool?> _answerResults = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isResuming = false;

  // UI State - INSTANT QUIZ SPECIFIC
  bool _isAnswered = false;
  bool _isLocked = false;
  bool _showFeedback = false;
  String? _correctAnswer;
  String? _userAnswer;
  bool _isTransitioning = false;

  // Instant Quiz Touch State
  bool _isTouchState = false;
  String? _touchedOption;

  // Animation Controllers
  late AnimationController _questionController;
  late AnimationController _optionsController;
  late AnimationController _feedbackController;
  late AnimationController _timerController;
  late AnimationController _shakeController;
  late AnimationController _exitController;
  late AnimationController _touchController;

  // Animations
  late Animation<Offset> _questionSlideAnimation;
  late Animation<double> _optionsFadeAnimation;
  late Animation<double> _feedbackScaleAnimation;
  late Animation<double> _timerAnimation;
  late Animation<double> _shakeAnimation;
  late Animation<Offset> _exitSlideAnimation;

  // Question Progress
  List<bool> _visitedQuestions = [];
  List<bool> _answeredQuestions = [];

  // ⭐ COLORS FROM CODE 2 (DARK THEME)
  final Color _primaryColor = const Color(0xFF6C5CE7);
  final Color _touchColor = const Color(0xFF8B78FF);
  final Color _correctColor = const Color(0xFF4CAF50);
  final Color _wrongColor = const Color(0xFFF44336);
  final Color _dullColor = Colors.grey.withOpacity(0.7);
  final Color _timerPausedColor = Colors.grey;

  final int _perQuestionTime = 30;

  /// ✅ SAFE QUIZ ID EXTRACTION
  int get _quizId {
    return safeIntParse(
        widget.quiz['id'],
        context: 'InstantQuizPlayerScreen._quizId',
        defaultValue: 0
    );
  }

  @override
  void initState() {
    super.initState();
    developer.log('🔍 Validating attemptId: ${widget.attemptId} (Type: ${widget.attemptId.runtimeType})');
    if (widget.attemptId <= 0) {
      developer.log('❌ CRITICAL ERROR: Invalid attemptId: ${widget.attemptId}');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Invalid quiz attempt. Please start a new quiz.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
          context.pop();
        }
      });
      return;
    }
    developer.log('✅ Valid attemptId confirmed: ${widget.attemptId}');
    _initializeAnimations();
    _loadAttemptAndQuestions();
  }

  /// ✅ PERFECT API 0-3 → UI 1-4 CONVERSION
  int convertCorrectAnswer(dynamic value) {
    final v = safeIntParse(value, context: 'convertCorrectAnswer', defaultValue: -1);
    if (v >= 0 && v <= 3) {
      final converted = v + 1;
      developer.log('🔥 CONVERSION: API $v → UI $converted');
      return converted;
    }
    developer.log('⚠️ Invalid correct_answer: $value → Using -1');
    return -1;
  }

  /// ✅ COMPLETE QUESTION NORMALIZATION WITH ERROR HANDLING
  Map<String, dynamic> normalizeQuestion(Map<String, dynamic> q) {
    try {
      return {
        'id': safeIntParse(q['id'], context: 'Question ID', defaultValue: 0),
        'quiz_id': safeIntParse(q['quiz_id'], context: 'Question Quiz ID', defaultValue: 0),
        'question': q['question']?.toString() ?? "Question unavailable",
        'option1': q['option1']?.toString() ?? "",
        'option2': q['option2']?.toString() ?? "",
        'option3': q['option3']?.toString() ?? "",
        'option4': q['option4']?.toString() ?? "",
        'correct_answer': convertCorrectAnswer(q['correct_answer']),
        'order': safeIntParse(q['order'], context: 'Question Order', defaultValue: 0),
      };
    } catch (e, stackTrace) {
      developer.log('❌ Question normalization error: $e\nStack: $stackTrace');
      return {
        'id': 0,
        'quiz_id': 0,
        'question': 'Question unavailable due to data error',
        'option1': '',
        'option2': '',
        'option3': '',
        'option4': '',
        'correct_answer': -1,
        'order': 0,
      };
    }
  }

  /// ✅ SAFE CORRECT ANSWER GETTER
  int _getCorrectAnswer(Map<String, dynamic> question) {
    final ans = question['correct_answer'];
    final correctInt = safeIntParse(ans, context: 'getCorrectAnswer', defaultValue: -1);
    if (correctInt >= 1 && correctInt <= 4) {
      return correctInt;
    }
    developer.log('⚠️ Invalid correct_answer in question ${question['id']}: $ans');
    return -1;
  }

  /// ✅ COMPLETE LOAD WITH MAXIMUM ERROR PROTECTION
  Future<void> _loadAttemptAndQuestions() async {
    try {
      developer.log('🚀 Loading quiz ${_quizId} with attempt ${widget.attemptId}');
      final api = ref.read(apiServiceProvider);
      final questionsResponse = await api.get('/saved_question/quiz/$_quizId');
      if (questionsResponse['success'] != true) {
        throw Exception('Failed to load questions: ${questionsResponse['message'] ?? 'Unknown error'}');
      }
      final List<dynamic> questionsData = questionsResponse['data'] ?? [];
      developer.log('📚 Raw questions loaded: ${questionsData.length}');

      final questions = <Map<String, dynamic>>[];
      for (int i = 0; i < questionsData.length; i++) {
        try {
          final rawQuestion = questionsData[i] as Map<String, dynamic>;
          final normalized = normalizeQuestion(rawQuestion);
          if (normalized['id'] > 0 &&
              normalized['correct_answer'] >= 1 &&
              normalized['correct_answer'] <= 4 &&
              [normalized['option1'], normalized['option2'], normalized['option3'], normalized['option4']]
                  .where((o) => o.isNotEmpty).length >= 2) {
            questions.add(normalized);
          } else {
            developer.log('⚠️ Skipping invalid question ${normalized['id']}');
          }
        } catch (e) {
          developer.log('❌ Failed to normalize question $i: $e');
        }
      }
      if (questions.isEmpty) {
        throw Exception('No valid questions found after processing');
      }
      developer.log('✅ Loaded ${questions.length} VALID normalized questions');

      Map<String, dynamic>? attempt;
      try {
        final attemptResponse = await api.get('/quiz_attempt/${widget.attemptId}');
        if (attemptResponse['success'] == true) {
          attempt = attemptResponse['data'];
          developer.log('✅ Attempt details loaded: ${attempt?['id']}');
        }
      } catch (e) {
        developer.log('⚠️ Could not load attempt details: $e');
      }

      if (!mounted) return;

      setState(() {
        _questions = questions;
        _selectedAnswers = List.filled(questions.length, null);
        _answerResults = List.filled(questions.length, null);
        _visitedQuestions = List.filled(questions.length, false);
        _answeredQuestions = List.filled(questions.length, false);
        _isLoading = false;
      });

      if (_questions.isEmpty) {
        throw Exception('No questions available after processing');
      }

      if (attempt != null && attempt['status']?.toString() == 'in_progress') {
        await _resumeAttempt(attempt);
      } else {
        setState(() {
          _currentIndex = 0;
          _visitedQuestions[0] = true;
        });
        _startQuestionAnimations();
        _startPerQuestionTimer();
        developer.log('🎯 New attempt started at question 1');
      }
    } catch (e, stackTrace) {
      developer.log("❌ LOAD ATTEMPT ERROR: $e\nSTACK: $stackTrace");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Failed to load quiz: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  /// ✅ RESUME ATTEMPT WITH SAFE INDEXING
  Future<void> _resumeAttempt(Map<String, dynamic> attempt) async {
    try {
      setState(() => _isResuming = true);
      final currentQuestionIndex = safeIntParse(
          attempt['current_question_index'],
          context: 'Resume current_question_index',
          defaultValue: 0
      );
      final score = safeIntParse(
          attempt['obtained_marks'],
          context: 'Resume obtained_marks',
          defaultValue: 0
      );
      developer.log('🔄 Resuming attempt ${widget.attemptId} at question $currentQuestionIndex');
      developer.log('📊 Current score: $score');

      await _loadAttemptReviewAnswers(widget.attemptId);

      if (!mounted) return;
      final clampedIndex = currentQuestionIndex.clamp(0, _questions.length - 1);
      setState(() {
        _currentIndex = clampedIndex;
        _score = score;
        _visitedQuestions[_currentIndex] = true;
        _answeredQuestions[_currentIndex] = _selectedAnswers[_currentIndex] != null;
        _isAnswered = _answeredQuestions[_currentIndex];
        _isLocked = _isAnswered;
        _isResuming = false;
      });

      if (mounted) {
        _showResumeSnackBar(clampedIndex + 1, _questions.length, _score);
      }

      _startQuestionAnimations();
      if (!_isAnswered) {
        _startPerQuestionTimer();
      }
    } catch (e, stackTrace) {
      developer.log('❌ Resume attempt error: $e\nStack: $stackTrace');
      setState(() => _isResuming = false);
      _startQuestionAnimations();
      _startPerQuestionTimer();
    }
  }

  /// ✅ LOAD PREVIOUS ANSWERS WITH SAFE INT COMPARISONS
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
          try {
            final questionId = safeIntParse(
                review['question_id'],
                context: 'Review question_id',
                defaultValue: 0
            );
            if (questionId == 0) continue;
            final selectedOption = review['selected_option']?.toString();

            final questionIndex = _questions.indexWhere((q) {
              final qId = safeIntParse(q['id'], context: 'Question ID lookup', defaultValue: 0);
              return qId == questionId;
            });
            if (questionIndex == -1) {
              developer.log('⚠️ Question ID $questionId not found');
              continue;
            }

            _selectedAnswers[questionIndex] = selectedOption;
            _answeredQuestions[questionIndex] = true;
            _visitedQuestions[questionIndex] = true;

            final question = _questions[questionIndex];
            final correctInt = _getCorrectAnswer(question);
            final selectedInt = int.tryParse(selectedOption ?? '') ?? -1;
            final isCorrect = selectedInt == correctInt;
            _answerResults[questionIndex] = isCorrect;
            if (isCorrect) _score += 10;
            loadedCount++;
          } catch (e) {
            developer.log('❌ Error processing review: $e');
          }
        }
        developer.log('✅ Loaded $loadedCount previous answers with PERFECT INT matching');
      }
    } catch (e) {
      developer.log('⚠️ Could not load attempt reviews: $e');
    }
  }

  /// ✅ UPDATE ATTEMPT PROGRESS
  Future<void> _updateAttemptProgress() async {
    try {
      final api = ref.read(apiServiceProvider);
      final questionsData = <Map<String, dynamic>>[];
      for (int i = 0; i < _questions.length; i++) {
        questionsData.add({
          'question_index': i,
          'question_id': _questions[i]['id'],
          'selected_option': _selectedAnswers[i],
          'is_correct': _answerResults[i],
          'answered': _answeredQuestions[i],
        });
      }
      final timeSpent = (_perQuestionTime * _currentIndex + (_perQuestionTime - _remainingSeconds));
      await api.put('/quiz_attempt/${widget.attemptId}', {
        'current_question_index': _currentIndex.toString(),
        'questions_data': jsonEncode(questionsData),
        'time_spent_total': timeSpent.toString(),
        'obtained_marks': _score.toString(),
        'correct_answers': _answerResults.where((r) => r == true).length.toString(),
        'incorrect_answers': _answerResults.where((r) => r == false).length.toString(),
        'unanswered_questions': _questions.length - _answeredQuestions.where((a) => a).length,
        'status': _currentIndex < _questions.length - 1 ? 'in_progress' : 'completed',
      });
      developer.log('✅ Progress saved: Q$_currentIndex | Score: $_score | Time: $timeSpent');
    } catch (e) {
      developer.log('⚠️ Failed to save progress: $e');
    }
  }

  void _initializeAnimations() {
    _questionController = AnimationController(duration: const Duration(milliseconds: 700), vsync: this);
    _optionsController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _feedbackController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _timerController = AnimationController(duration: Duration(seconds: _perQuestionTime), vsync: this);
    _shakeController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _exitController = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    _touchController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);

    _questionSlideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _questionController, curve: Curves.easeOut));

    _optionsFadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _optionsController, curve: Curves.easeIn));

    _feedbackScaleAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _feedbackController, curve: Curves.elasticOut));

    _timerAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(_timerController);

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: -10, end: 10), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: 10, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: -10, end: 10), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: 10, end: 0), weight: 1),
    ]).animate(_shakeController);

    _exitSlideAnimation = Tween<Offset>(begin: Offset.zero, end: const Offset(-1, 0))
        .animate(CurvedAnimation(parent: _exitController, curve: Curves.easeInOut));
  }

  void _startQuestionAnimations() {
    _questionController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _optionsController.forward();
      });
    });
    _timerController.duration = Duration(seconds: _perQuestionTime);
    _timerController.forward(from: 0.0);
  }

  void _startPerQuestionTimer() {
    _remainingSeconds = _perQuestionTime;
    _timerController.reset();
    _timerController.duration = Duration(seconds: _perQuestionTime);
    _timerController.forward();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
          _timerController.value = _remainingSeconds / _perQuestionTime;
        } else {
          timer.cancel();
          _handleTimeOut();
        }
      });
    });
  }

  void _handleTimeOut() {
    if (!_isAnswered) {
      final question = _questions[_currentIndex];
      final correctInt = _getCorrectAnswer(question);
      setState(() {
        _isAnswered = true;
        _isLocked = true;
        _correctAnswer = correctInt.toString();
        _answerResults[_currentIndex] = false;
        _timerController.stop();
      });
      _saveAnswerToServer("", false);
      _showTimeOutFeedback();
      _updateAttemptProgress();
    }
  }

  void _selectAnswer(String selectedOption) {
    if (_isAnswered || _isLocked) return;
    final selectedInt = int.tryParse(selectedOption);
    if (selectedInt == null || selectedInt < 1 || selectedInt > 4) {
      developer.log("❌ Invalid option selected: $selectedOption");
      return;
    }
    final question = _questions[_currentIndex];
    final correctInt = _getCorrectAnswer(question);
    final isCorrect = selectedInt == correctInt;

    setState(() {
      _touchedOption = selectedOption;
      _isTouchState = true;
      _selectedAnswers[_currentIndex] = selectedOption;
      _userAnswer = selectedOption;
      _correctAnswer = correctInt.toString();
    });
    _touchController.forward();

    _timer.cancel();
    _timerController.stop();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _isTouchState = false;
        _isAnswered = true;
        _isLocked = true;
        _answeredQuestions[_currentIndex] = true;
        _answerResults[_currentIndex] = isCorrect;
        if (isCorrect) _score += 10;
        _showFeedback = true;
      });
      _feedbackController.forward();
      _provideHapticFeedback(isCorrect);
      if (!isCorrect) {
        _shakeController.forward();
      }
      _saveAnswerToServer(selectedOption, isCorrect);
      _updateAttemptProgress();

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _goToNextQuestion();
      });
    });
  }

  void _provideHapticFeedback(bool isCorrect) async {
    if (await Vibration.hasVibrator() ?? false) {
      if (!isCorrect) {
        Vibration.vibrate(duration: 200, amplitude: 100);
      } else {
        Vibration.vibrate(pattern: [0, 50, 50, 50]);
      }
    }
  }

  void _showTimeOutFeedback() {
    setState(() => _showFeedback = true);
    _feedbackController.forward();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _goToNextQuestion();
    });
  }

  void _goToNextQuestion() {
    _updateAttemptProgress();
    if (_currentIndex < _questions.length - 1) {
      setState(() => _isTransitioning = true);
      _exitController.forward().then((_) {
        _questionController.reset();
        _optionsController.reset();
        _feedbackController.reset();
        _exitController.reset();
        _shakeController.reset();
        _touchController.reset();
        if (!mounted) return;
        setState(() {
          _currentIndex++;
          _isAnswered = _selectedAnswers[_currentIndex] != null;
          _isLocked = _isAnswered;
          _showFeedback = false;
          _isTransitioning = false;
          _isTouchState = false;
          _touchedOption = null;
          _userAnswer = null;
          _correctAnswer = null;
          _visitedQuestions[_currentIndex] = true;
        });
        _startQuestionAnimations();
        if (!_isAnswered) {
          _startPerQuestionTimer();
        }
        developer.log('➡️ Moved to question ${_currentIndex + 1}/${_questions.length}');
      });
    } else {
      developer.log('🏁 All questions completed! Submitting...');
      _submitQuiz();
    }
  }

  /// ✅ BULLETPROOF SAVE ANSWER - USES PUT INSTEAD OF POST FOR EXISTING ATTEMPTS
  Future<void> _saveAnswerToServer(String selected, bool isCorrect) async {
    try {
      final user = ref.read(currentUserProvider).asData?.value;
      if (user?.id == null) {
        developer.log("❌ User ID missing");
        return;
      }
      final question = _questions[_currentIndex];
      final questionId = safeIntParse(question['id'],
          context: 'Save question_id',
          defaultValue: 0
      );
      if (questionId == 0) {
        developer.log("❌ Invalid question ID for saving");
        return;
      }
      final correctInt = _getCorrectAnswer(question);
      final selectedInt = int.tryParse(selected) ?? -1;

      final api = ref.read(apiServiceProvider);
      Map<String, dynamic>? existingAttempt;
      try {
        final attemptResponse = await api.get('/quiz_attempt/${widget.attemptId}');
        if (attemptResponse['success'] == true) {
          existingAttempt = attemptResponse['data'];
        }
      } catch (e) {
        developer.log("⚠️ Could not load existing attempt: $e");
      }

      List<Map<String, dynamic>> questionsData = [];
      if (existingAttempt != null && existingAttempt['questions_data'] != null) {
        try {
          if (existingAttempt['questions_data'] is String) {
            questionsData = List<Map<String, dynamic>>.from(
                jsonDecode(existingAttempt['questions_data'])
            );
          } else if (existingAttempt['questions_data'] is List) {
            questionsData = List<Map<String, dynamic>>.from(
                existingAttempt['questions_data']
            );
          }
        } catch (e) {
          developer.log("⚠️ Error parsing existing questions_data: $e");
        }
      }

      final questionIndex = questionsData.indexWhere(
              (q) => safeIntParse(q['question_id'],
              context: 'Find question_id',
              defaultValue: 0
          ) == questionId
      );

      final questionPayload = {
        'question_index': _currentIndex,
        'question_id': questionId,
        'selected_option': selectedInt >= 1 ? selectedInt.toString() : null,
        'is_correct': isCorrect,
        'answered': selectedInt >= 1,
        'correct_option': correctInt,
        'question_text': question['question'] ?? 'Question unavailable',
        'options_provided': [
          question['option1'] ?? '',
          question['option2'] ?? '',
          question['option3'] ?? '',
          question['option4'] ?? ''
        ],
        'time_spent': _perQuestionTime - _remainingSeconds,
      };

      if (questionIndex >= 0) {
        questionsData[questionIndex] = questionPayload;
      } else {
        questionsData.add(questionPayload);
      }

      final timeSpent = (_perQuestionTime * _currentIndex +
          (_perQuestionTime - _remainingSeconds));
      final updatePayload = {
        'current_question_index': _currentIndex,
        'questions_data': jsonEncode(questionsData),
        'time_spent_total': timeSpent,
        'obtained_marks': _score,
        'correct_answers': _answerResults.where((r) => r == true).length,
        'incorrect_answers': _answerResults.where((r) => r == false).length,
        'unanswered_questions': _questions.length -
            _answeredQuestions.where((a) => a).length,
        'status': _currentIndex < _questions.length - 1 ?
        'in_progress' : 'completed',
      };

      developer.log("💾 Updating attempt ${widget.attemptId} with: ${jsonEncode(updatePayload)}");

      final response = await api.put('/quiz_attempt/${widget.attemptId}', updatePayload);
      if (response['success'] == true) {
        developer.log("✅ Answer saved successfully in attempt ${widget.attemptId}");
      } else {
        developer.log("⚠️ Update warning: ${response['message']}");
      }
    } catch (e, stackTrace) {
      developer.log("❌ Save error: $e\nStack: $stackTrace");
    }
  }

  /// ✅ COMPLETE QUIZ SUBMISSION WITH CORRECT DATA TYPES
  Future<void> _submitQuiz() async {
    if (_isSubmitting) return;
    _isSubmitting = true;
    try {
      if (_timer.isActive) _timer.cancel();
      _timerController.stop();

      await _updateAttemptProgress();

      final user = ref.read(currentUserProvider).asData?.value;
      if (user?.id == null) throw Exception("User not found");

      final totalQuestions = _questions.length;
      final fullMarks = totalQuestions * 10;
      final totalTime = (_perQuestionTime * totalQuestions);

      final resultPayload = {
        'quiz_id': _quizId,
        'user_id': user!.id,
        'attempt_id': widget.attemptId,
        'score': _score,
        'full_marks': fullMarks,
        'time_taken': totalTime,
      };

      developer.log("📤 Submitting result: ${jsonEncode(resultPayload)}");
      final resultResponse = await ref.read(apiServiceProvider).post('/result', resultPayload);
      if (resultResponse['success'] != true) {
        throw Exception(resultResponse['message'] ?? 'Failed to create result');
      }

      final resultId = safeIntParse(
          resultResponse['id'] ?? resultResponse['data']?['id'],
          context: 'Submit result_id',
          defaultValue: 0
      );
      if (resultId == 0) {
        throw Exception('Invalid result ID returned from server');
      }

      await ref.read(apiServiceProvider).put('/quiz_attempt/${widget.attemptId}', {
        'status': 'completed',
        'completed_at': DateTime.now().toIso8601String(),
      });

      developer.log("🎉 QUIZ COMPLETED! Result ID: $resultId | Score: $_score/$fullMarks (${(_score / fullMarks * 100).toStringAsFixed(1)}%)");

      if (!mounted) return;
      context.go('/quizzes/result', extra: {
        'result_id': resultId,
        'attempt_id': widget.attemptId,
        'score': _score,
        'total_questions': totalQuestions,
        'total_marks': fullMarks,
        'quiz_title': widget.quiz['quiz_title'] ?? widget.quiz['title'],
        'percentage': (_score / fullMarks * 100).toStringAsFixed(1),
        'time_taken': totalTime,
        'passed': _score >= (fullMarks * 0.6),
        'slug': widget.quiz['slug']?.toString().trim().isNotEmpty == true
            ? widget.quiz['slug']
            : widget.quiz['id'].toString(),
      });
    } catch (e, stackTrace) {
      developer.log("❌ Submit error: $e\nStack: $stackTrace");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Submit failed: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _fallbackSubmit();
    } finally {
      _isSubmitting = false;
    }
  }

  /// ✅ FALLBACK: Alternative submission method
  Future<void> _fallbackSubmit() async {
    try {
      final user = ref.read(currentUserProvider).asData?.value;
      if (user?.id == null) return;
      final totalQuestions = _questions.length;
      final fullMarks = totalQuestions * 10;

      final altPayload = {
        'quiz_id': _quizId.toString(),
        'user_id': user!.id.toString(),
        'score': _score.toString(),
        'full_marks': fullMarks.toString(),
        'time_taken': (_perQuestionTime * totalQuestions).toString(),
        'completed_at': DateTime.now().toIso8601String(),
      };

      developer.log("🔄 Trying fallback submission: ${jsonEncode(altPayload)}");
      final response = await ref.read(apiServiceProvider).post('/result', altPayload);
      if (response['success'] == true) {
        final resultId = safeIntParse(
            response['id'],
            context: 'Fallback result_id',
            defaultValue: 0
        );
        if (resultId > 0 && mounted) {
          context.go('/quizzes/result', extra: {
            'result_id': resultId,
            'attempt_id': widget.attemptId,
            'score': _score,
            'total_questions': totalQuestions,
            'total_marks': fullMarks,
            'quiz_title': widget.quiz['quiz_title'] ?? widget.quiz['title'],
            'percentage': (_score / fullMarks * 100).toStringAsFixed(1),
            'time_taken': _perQuestionTime * totalQuestions,
            'passed': _score >= (fullMarks * 0.6),
            'slug': widget.quiz['slug']?.toString().trim().isNotEmpty == true
                ? widget.quiz['slug']
                : widget.quiz['id'].toString(),
          });
        }
      }
    } catch (e) {
      developer.log("❌ Fallback submit also failed: $e");
    }
  }

  /// ✅ RESUME SNACKBAR
  void _showResumeSnackBar(int current, int total, int score) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.play_arrow, color: Colors.white),
            const SizedBox(width: 8),
            Text('Resumed from question $current/$total • Score: $score'),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    await _updateAttemptProgress();
    final shouldQuit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Quit Quiz?", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          "Your progress is saved. You can resume later from question ${_currentIndex + 1}!",
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Continue", style: GoogleFonts.poppins(color: Colors.grey[700])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: Text("Quit", style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
    return shouldQuit ?? false;
  }

  // ==================== UI FROM CODE 2 ====================

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('COINS\n0',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70)),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      value: _timerAnimation.value.clamp(0.0, 1.0),
                      strokeWidth: 6,
                      backgroundColor: Colors.grey[800],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _isLocked
                            ? _timerPausedColor
                            : (_remainingSeconds < 10 ? Colors.red : _primaryColor),
                      ),
                    ),
                  ),
                  Text('$_remainingSeconds',
                      style: GoogleFonts.poppins(
                          fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
              Text('SCORE\n$_score',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 8),
          Text('${_currentIndex + 1}/${_questions.length}',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.white60)),
        ],
      ),
    );
  }

  Widget _buildOptionButton(int index, List<dynamic> options, int correctAnswer) {
    final optionLetter = (index + 1).toString();
    final optionText = options[index]?.toString() ?? '';
    final isTouched = _touchedOption == optionLetter && _isTouchState;
    final isSelected = _selectedAnswers[_currentIndex] == optionLetter;
    final isCorrectOption = (index + 1) == correctAnswer;

    Color backgroundColor() {
      if (_showFeedback) {
        if (isCorrectOption) return _correctColor;
        if (isSelected && !isCorrectOption) return _wrongColor;
        return Colors.grey[800]!.withOpacity(0.6);
      }
      if (isTouched) return _touchColor;
      return Colors.grey[800]!;
    }

    Color textColor() => (_showFeedback || isTouched) ? Colors.white : Colors.white;

    double opacity() => (_isTouchState && !isTouched) ? 0.7 : 1.0;

    Widget? trailingIcon() {
      if (!_showFeedback) return null;
      if (isCorrectOption) {
        return ScaleTransition(
            scale: _feedbackScaleAnimation,
            child: const Icon(Icons.check, color: Colors.white, size: 28));
      }
      if (isSelected && !isCorrectOption) {
        return ScaleTransition(
            scale: _feedbackScaleAnimation,
            child: const Icon(Icons.close, color: Colors.white, size: 28));
      }
      return null;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      child: AnimatedBuilder(
        animation: Listenable.merge([_touchController, _feedbackController]),
        builder: (context, child) {
          final double touchScale = isTouched
              ? (1.0 + 0.03 * Curves.easeOut.transform(_touchController.value))
              : 1.0;
          return Transform.scale(
            scale: touchScale,
            child: Opacity(
              opacity: opacity(),
              child: Material(
                color: backgroundColor(),
                borderRadius: BorderRadius.circular(30),
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: _isLocked ? null : () => _selectAnswer(optionLetter),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: textColor().withOpacity(0.3),
                          child: Text(optionLetter,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                            child: Text(optionText,
                                style: GoogleFonts.poppins(fontSize: 16, color: textColor()))),
                        if (trailingIcon() != null) ...[
                          const SizedBox(width: 8),
                          trailingIcon()!,
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _questions.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: Center(child: Lottie.asset('assets/lottie/loading.json')),
      );
    }

    final question = _questions[_currentIndex];
    final List<dynamic> options = ['1', '2', '3', '4']
        .map((i) => question['option$i'])
        .where((o) => o != null && o.toString().isNotEmpty)
        .toList();
    final correctAnswer = _getCorrectAnswer(question);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              const SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SlideTransition(
                  position: _questionSlideAnimation,
                  child: Card(
                    color: const Color(0xFF1E1E1E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        question['question'] ?? "Question unavailable",
                        style: GoogleFonts.poppins(
                            fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: FadeTransition(
                  opacity: _optionsFadeAnimation,
                  child: ListView.builder(
                    itemCount: options.length,
                    itemBuilder: (context, index) => _buildOptionButton(index, options, correctAnswer),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _updateAttemptProgress();
    _questionController.dispose();
    _optionsController.dispose();
    _feedbackController.dispose();
    _timerController.dispose();
    _shakeController.dispose();
    _exitController.dispose();
    _touchController.dispose();
    if (_timer.isActive) _timer.cancel();
    super.dispose();
  }
}