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
  late Animation<double> _touchScaleAnimation;

  // Question Progress
  List<bool> _visitedQuestions = [];
  List<bool> _answeredQuestions = [];

  // ⭐ PERFECTED COLORS FOR INSTANT QUIZ
  final Color _primaryColor = const Color(0xFF6C5CE7);
  final Color _touchColor = const Color(0xFF8B78FF);
  final Color _correctColor = Colors.green;
  final Color _wrongColor = Colors.red;
  final Color _dullColor = Color(0xFFA7A7A7);
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

  /// ✅ VALIDATE ATTEMPT ID IN INITSTATE
  @override
  void initState() {
    super.initState();
    // 🔥 CRITICAL: VALIDATE ATTEMPT ID IMMEDIATELY
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
      final converted = v + 1; // 🔥 0→1, 1→2, 2→3, 3→4
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

  /// ✅ FIXED: COMPLETE LOAD WITH MAXIMUM ERROR PROTECTION
  Future<void> _loadAttemptAndQuestions() async {
    try {
      developer.log('🚀 Loading quiz ${_quizId} with attempt ${widget.attemptId}');
      final api = ref.read(apiServiceProvider);

      // Step 1: Load questions
      final questionsResponse = await api.get('/saved_question/quiz/$_quizId');
      if (questionsResponse['success'] != true) {
        throw Exception('Failed to load questions: ${questionsResponse['message'] ?? 'Unknown error'}');
      }

      final List<dynamic> questionsData = questionsResponse['data'] ?? [];
      developer.log('📚 Raw questions loaded: ${questionsData.length}');

      // ✅ SAFE NORMALIZATION WITH VALIDATION
      final questions = <Map<String, dynamic>>[];
      for (int i = 0; i < questionsData.length; i++) {
        try {
          final rawQuestion = questionsData[i] as Map<String, dynamic>;
          final normalized = normalizeQuestion(rawQuestion);

          // Validate normalized question
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

      // Log first question verification
      if (questions.isNotEmpty) {
        final firstQuestion = questions[0];
        developer.log('🔍 FIRST QUESTION VERIFICATION:');
        developer.log(' ID: ${firstQuestion['id']}');
        developer.log(' Correct Answer: ${firstQuestion['correct_answer']}');
        developer.log(' Question: ${firstQuestion['question'].substring(0, 50)}...');
      }

      // Step 2: Try to load attempt details
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

      // Step 3: Initialize state
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

      // Step 4: RESUME LOGIC
      if (attempt != null && attempt['status']?.toString() == 'in_progress') {
        await _resumeAttempt(attempt);
      } else {
        // New attempt - start from beginning
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

  /// ✅ FIXED: RESUME ATTEMPT WITH SAFE INDEXING
  Future<void> _resumeAttempt(Map<String, dynamic> attempt) async {
    try {
      setState(() => _isResuming = true);

      // Safe index parsing
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

      // Load previous answers
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

      // Show resume message
      if (mounted) {
        _showResumeSnackBar(clampedIndex + 1, _questions.length, _score);
      }

      // Start animations and timer
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

  /// ✅ FIXED: LOAD PREVIOUS ANSWERS WITH SAFE INT COMPARISONS
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
            // ✅ SAFE INT EXTRACTION
            final questionId = safeIntParse(
                review['question_id'],
                context: 'Review question_id',
                defaultValue: 0
            );
            if (questionId == 0) continue;

            final selectedOption = review['selected_option']?.toString();

            // ✅ SAFE INDEX LOOKUP WITH INT COMPARISON
            final questionIndex = _questions.indexWhere((q) {
              final qId = safeIntParse(q['id'], context: 'Question ID lookup', defaultValue: 0);
              return qId == questionId;
            });

            if (questionIndex == -1) {
              developer.log('⚠️ Question ID $questionId not found');
              continue;
            }

            // Update state
            _selectedAnswers[questionIndex] = selectedOption;
            _answeredQuestions[questionIndex] = true;
            _visitedQuestions[questionIndex] = true;

            // ✅ PERFECT INT COMPARISON (UI: 1-4)
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

  /// ✅ FIXED: UPDATE ATTEMPT PROGRESS
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
    _questionController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _optionsController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _feedbackController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _timerController = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    );
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _exitController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _touchController = AnimationController(
      duration: const Duration(milliseconds: 150),
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

    _feedbackScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _feedbackController,
      curve: Curves.elasticOut,
    ));

    _timerAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(_timerController);

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: -10.0, end: 10.0), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: 10.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: -10.0, end: 10.0), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: 10.0, end: 0.0), weight: 1),
    ]).animate(_shakeController);

    _exitSlideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-1.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _exitController,
      curve: Curves.easeInOut,
    ));

    _touchScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.03), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.03, end: 1.0), weight: 50),
    ]).animate(_touchController);
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

  /// ✅ FIXED: TIMEOUT WITH SAFE INT COMPARISON
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

  /// ✅ FIXED: ANSWER SELECTION WITH PERFECT INT COMPARISON
  void _selectAnswer(String selectedOption) {
    if (_isAnswered || _isLocked) return;

    final selectedInt = int.tryParse(selectedOption);
    if (selectedInt == null || selectedInt < 1 || selectedInt > 4) {
      developer.log("❌ Invalid option selected: $selectedOption");
      return;
    }

    final question = _questions[_currentIndex];
    final correctInt = _getCorrectAnswer(question);
    final isCorrect = selectedInt == correctInt; // ✅ PERFECT: 1-4 vs 1-4

    developer.log('🔍 Answer Check: Q${question['id']} | Selected=$selectedInt | Correct=$correctInt | ${isCorrect ? "✅" : "❌"}');

    // Immediate touch feedback
    setState(() {
      _touchedOption = selectedOption;
      _isTouchState = true;
      _selectedAnswers[_currentIndex] = selectedOption;
      _userAnswer = selectedOption;
      _correctAnswer = correctInt.toString();
    });

    _touchController.forward();

    // Stop timer
    _timer.cancel();
    _timerController.stop();

    // Check answer after 300ms delay
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

      // Auto-next after 2 seconds
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

  /// ✅ FIXED: BULLETPROOF SAVE ANSWER - USES PUT INSTEAD OF POST FOR EXISTING ATTEMPTS
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

      // Get existing attempt data
      final api = ref.read(apiServiceProvider);

      // ✅ FIRST: Try to load existing attempt
      Map<String, dynamic>? existingAttempt;
      try {
        final attemptResponse = await api.get('/quiz_attempt/${widget.attemptId}');
        if (attemptResponse['success'] == true) {
          existingAttempt = attemptResponse['data'];
        }
      } catch (e) {
        developer.log("⚠️ Could not load existing attempt: $e");
      }

      // ✅ Prepare question data for update
      List<Map<String, dynamic>> questionsData = [];

      if (existingAttempt != null && existingAttempt['questions_data'] != null) {
        try {
          // Parse existing questions_data
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

      // ✅ Update or add question data for current question
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
        // Update existing question
        questionsData[questionIndex] = questionPayload;
      } else {
        // Add new question
        questionsData.add(questionPayload);
      }

      // ✅ Prepare attempt update payload
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

      // ✅ Use PUT to update existing attempt instead of POST
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

  /// ✅ FIXED: COMPLETE QUIZ SUBMISSION WITH CORRECT DATA TYPES
  Future<void> _submitQuiz() async {
    if (_isSubmitting) return;
    _isSubmitting = true;

    try {
      if (_timer.isActive) _timer.cancel();
      _timerController.stop();

      // Final attempt update to mark as completed
      await _updateAttemptProgress();

      final user = ref.read(currentUserProvider).asData?.value;
      if (user?.id == null) throw Exception("User not found");

      // Safe calculations
      final totalQuestions = _questions.length;
      final fullMarks = totalQuestions * 10;
      final totalTime = (_perQuestionTime * totalQuestions);

      // ✅ FIXED: Ensure numeric types
      final resultPayload = {
        'quiz_id': _quizId,  // Use int, not string
        'user_id': user!.id, // Use int, not string
        'attempt_id': widget.attemptId, // Use int, not string
        'score': _score,     // Use int, not string
        'full_marks': fullMarks, // Use int, not string
        'time_taken': totalTime, // Use int, not string
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

      // Mark attempt as completed (optional - result creation might already do this)
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

      // Fallback: Try alternative submission
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

      // Alternative payload format
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

  Widget _buildTopBar() {
    return Column(
      children: [
        // ✅ Attempt info bar
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
        // Progress bar
        LinearProgressIndicator(
          value: (_currentIndex + 1) / _questions.length,
          backgroundColor: Colors.grey[300],
          color: _primaryColor,
          minHeight: 6,
        ),
        const SizedBox(height: 16),
        // Timer and question counter
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    value: _timerAnimation.value,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _isLocked
                          ? _timerPausedColor
                          : (_remainingSeconds < 10 ? Colors.red : _primaryColor),
                    ),
                    strokeWidth: 6,
                  ),
                ),
                Text(
                  '$_remainingSeconds',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _isLocked
                        ? _timerPausedColor
                        : (_remainingSeconds < 10 ? Colors.red : _primaryColor),
                  ),
                ),
              ],
            ),
            Text(
              'Q ${_currentIndex + 1}/${_questions.length}',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 60),
          ],
        ),
      ],
    );
  }

  /// ✅ FIXED: OPTION BUTTON WITH PERFECT INT COMPARISON
  Widget _buildOptionButton(int index, List<dynamic> options, int correctAnswer) {
    final List<String> stringOptions = options.map((option) => option?.toString() ?? '').toList();
    final optionLetter = (index + 1).toString();
    final optionText = stringOptions[index];
    final isSelected = _selectedAnswers[_currentIndex] == optionLetter;
    final isCorrectOption = (index + 1) == correctAnswer; // ✅ PERFECT: 1-4 comparison
    final isTouched = _touchedOption == optionLetter && _isTouchState;

    Color getBackgroundColor() {
      if (_showFeedback) {
        if (isCorrectOption) return _correctColor;
        if (isSelected && !isCorrectOption) return _wrongColor;
        return _dullColor;
      } else if (isTouched) {
        return _touchColor;
      }
      return Colors.grey[100]!;
    }

    Color getTextColor() {
      if (_showFeedback || isTouched) return Colors.white;
      return Colors.black87;
    }

    double getOpacity() {
      if (_isTouchState && !isTouched) return 0.65;
      return 1.0;
    }

    Widget? getTrailingIcon() {
      if (_showFeedback) {
        if (isCorrectOption) {
          return ScaleTransition(
            scale: _feedbackScaleAnimation,
            child: const Icon(Icons.check_circle, color: Colors.white, size: 24),
          );
        }
        if (isSelected && !isCorrectOption) {
          return ScaleTransition(
            scale: _feedbackScaleAnimation,
            child: const Icon(Icons.cancel, color: Colors.white, size: 24),
          );
        }
      }
      return null;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(bottom: 12),
      child: AnimatedBuilder(
        animation: _touchController,
        builder: (context, child) {
          return Transform.scale(
            scale: isTouched ? _touchScaleAnimation.value : 1.0,
            child: Opacity(
              opacity: getOpacity(),
              child: ElevatedButton(
                onPressed: _isLocked ? null : () => _selectAnswer(optionLetter),
                style: ElevatedButton.styleFrom(
                  backgroundColor: getBackgroundColor(),
                  foregroundColor: getTextColor(),
                  elevation: (isTouched || isSelected) ? 8 : 2,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: getTextColor() == Colors.white ? Colors.white24 : _primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          optionLetter,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        optionText,
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                    if (getTrailingIcon() != null) ...[
                      const SizedBox(width: 8),
                      getTrailingIcon()!,
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeedbackMessage() {
    final isCorrect = _answerResults[_currentIndex] == true;
    return ScaleTransition(
      scale: _feedbackScaleAnimation,
      child: AnimatedBuilder(
        animation: _shakeController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(_shakeAnimation.value, 0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isCorrect ? Colors.green[50] : Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCorrect ? Colors.green : Colors.red,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isCorrect ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isCorrect ? Icons.check_circle : Icons.cancel,
                    color: isCorrect ? Colors.green : Colors.red,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isCorrect ? "Correct! 🎉" : "Incorrect!",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isCorrect ? Colors.green : Colors.red,
                    ),
                  ),
                  if (!isCorrect && _correctAnswer != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      "Correct: $_correctAnswer",
                      style: GoogleFonts.poppins(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Loading state
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
                  "Loading Instant Quiz...",
                  style: GoogleFonts.poppins(fontSize: 18, color: _primaryColor),
                ),
                const SizedBox(height: 8),
                Text(
                  "Quiz ID: $_quizId | Attempt: ${widget.attemptId}",
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // No questions state
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
                "No questions available",
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
    final List<dynamic> options = ['1', '2', '3', '4']
        .map((i) => question['option$i'])
        .where((o) => o != null && o.toString().isNotEmpty)
        .toList();
    final correctAnswer = _getCorrectAnswer(question); // ✅ Returns PERFECT 1-4 INT

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
              if (shouldPop) context.pop();
            }),
          ),
          title: const SizedBox.shrink(),
        ),
        body: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildTopBar(),
                  const SizedBox(height: 30),
                  // Question
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: _isTransitioning
                        ? const SizedBox.shrink()
                        : SlideTransition(
                      key: ValueKey(_currentIndex),
                      position: _isTransitioning ? _exitSlideAnimation : _questionSlideAnimation,
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
                              question['question'] ?? "Question unavailable",
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
                  // Options
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _isTransitioning
                          ? const SizedBox.shrink()
                          : FadeTransition(
                        key: ValueKey('options_$_currentIndex'),
                        opacity: _optionsFadeAnimation,
                        child: ListView.builder(
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            return _buildOptionButton(index, options, correctAnswer);
                          },
                        ),
                      ),
                    ),
                  ),
                  // Feedback
                  if (_showFeedback) ...[
                    const SizedBox(height: 16),
                    _buildFeedbackMessage(),
                    if (_isLocked) ...[
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _answerResults[_currentIndex] == true ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}