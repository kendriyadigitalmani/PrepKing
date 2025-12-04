// lib/screens/quizzes/quiz_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:developer' as developer;
import '../../core/services/api_service.dart';
import '../../providers/user_provider.dart';
import '../../providers/quiz_attempts_provider.dart';

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

class QuizDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> quiz;
  const QuizDetailScreen({super.key, required this.quiz});

  @override
  ConsumerState<QuizDetailScreen> createState() => _QuizDetailScreenState();
}

class _QuizDetailScreenState extends ConsumerState<QuizDetailScreen> {
  bool isStarting = false;

  /// ✅ SAFE QUIZ ID EXTRACTION
  int get _quizId {
    return safeIntParse(
        widget.quiz['id'],
        context: 'QuizDetailScreen._quizId',
        defaultValue: 0
    );
  }

  bool _isInstantQuiz(Map<String, dynamic> quiz) {
    final instantValue = quiz['isInstantQuiz'] ?? quiz['instantquiz'];
    if (instantValue == null) return false;
    if (instantValue is bool) return instantValue;
    if (instantValue is int) return instantValue == 1;
    if (instantValue is String) {
      return instantValue == "1" || instantValue.toLowerCase() == "true";
    }
    return false;
  }

  /// ✅ SAFE ATTEMPT NUMBER EXTRACTION
  int _safeGetAttemptNumber(Map<String, dynamic> attempt) {
    return safeIntParse(
        attempt['attempt_number'],
        context: 'Attempt #${attempt['id'] ?? 'unknown'} - attempt_number',
        defaultValue: 1
    );
  }

  /// ✅ SAFE ATTEMPT ID EXTRACTION
  int _safeGetAttemptId(Map<String, dynamic> attempt) {
    return safeIntParse(
        attempt['id'],
        context: 'Attempt ID extraction',
        defaultValue: 0
    );
  }

  Future<void> _startQuiz() async {
    if (isStarting) return;
    setState(() => isStarting = true);

    try {
      developer.log('🚀 Starting quiz ID: $_quizId');

      // ✅ VALIDATE QUIZ ID
      if (_quizId == 0) {
        throw Exception("❌ INVALID QUIZ ID: ${widget.quiz['id']} (Type: ${widget.quiz['id'].runtimeType})");
      }

      final userAsync = ref.read(currentUserProvider);
      final user = userAsync.asData?.value;

      if (user == null || user.id == 0) {
        throw Exception("Profile loading... Try again.");
      }

      final api = ref.read(apiServiceProvider);

      // ✅ STEP 1: Check for existing in-progress attempt
      Map<String, dynamic>? latestAttempt;

      // Try provider first
      try {
        final latestAttemptAsync = ref.read(latestQuizAttemptProvider(_quizId));
        if (latestAttemptAsync.hasValue && latestAttemptAsync.value != null) {
          latestAttempt = latestAttemptAsync.value;
          developer.log('✅ Provider found latest attempt: ${latestAttempt?['id']}');
        }
      } catch (e) {
        developer.log('⚠️ Provider error, trying manual fetch: $e');
      }

      // Fallback: Manual API call
      if (latestAttempt == null) {
        try {
          developer.log('🔍 Manual attempt fetch for quiz $_quizId');
          final attemptsResponse = await api.get('/quiz_attempt', query: {
            'course_quiz_id': _quizId.toString(),
            'user_id': user.id.toString(),
          });

          if (attemptsResponse['success'] == true) {
            final attemptsData = attemptsResponse['data'] ?? [];
            final attempts = List<Map<String, dynamic>>.from(attemptsData);

            if (attempts.isNotEmpty) {
              // ✅ SAFE MAX ID CALCULATION
              latestAttempt = attempts.reduce((a, b) {
                final idA = _safeGetAttemptId(a);
                final idB = _safeGetAttemptId(b);
                developer.log('Comparing attempts: ${a['id']} vs ${b['id']}');
                return idA > idB ? a : b;
              });
              developer.log('✅ Manual latest attempt found: ${_safeGetAttemptId(latestAttempt!)}');
            }
          }
        } catch (e) {
          developer.log('⚠️ Manual attempt fetch failed: $e');
        }
      }

      int attemptId;
      int nextAttemptNumber;

      // ✅ STEP 2: DECIDE RESUME OR NEW ATTEMPT
      if (latestAttempt != null) {
        final latestStatus = latestAttempt['status']?.toString() ?? '';
        if (latestStatus == 'in_progress') {
          // RESUME EXISTING ATTEMPT
          attemptId = _safeGetAttemptId(latestAttempt);
          nextAttemptNumber = _safeGetAttemptNumber(latestAttempt);

          developer.log('🔄 RESUMING existing attempt: ID $attemptId (Attempt #$nextAttemptNumber)');

          if (mounted) {
            _showResumeSnackBar(nextAttemptNumber);
          }
        } else {
          developer.log('ℹ️ Latest attempt completed (${latestStatus}), creating new one');
          latestAttempt = null; // Continue to create new
        }
      }

      // ✅ STEP 3: CREATE NEW ATTEMPT
      if (latestAttempt == null) {
        final List<Map<String, dynamic>> existingAttempts = [];

        try {
          final attemptsResponse = await api.get('/quiz_attempt', query: {
            'course_quiz_id': _quizId.toString(),
            'user_id': user.id.toString(),
          });

          if (attemptsResponse['success'] == true) {
            final attemptsData = attemptsResponse['data'] ?? [];
            existingAttempts.addAll(List<Map<String, dynamic>>.from(attemptsData));
            developer.log('📊 Found ${existingAttempts.length} existing attempts');
          }
        } catch (e) {
          developer.log("⚠️ Could not fetch existing attempts: $e");
        }

        // ✅ SAFE NEXT ATTEMPT NUMBER CALCULATION
        nextAttemptNumber = 1;
        if (existingAttempts.isNotEmpty) {
          try {
            final validAttemptNumbers = <int>[];
            for (var attempt in existingAttempts) {
              final attemptNum = _safeGetAttemptNumber(attempt);
              if (attemptNum > 0) {
                validAttemptNumbers.add(attemptNum);
              }
            }

            if (validAttemptNumbers.isNotEmpty) {
              nextAttemptNumber = validAttemptNumbers.reduce((a, b) => a > b ? a : b) + 1;
              developer.log('📈 Next attempt calculated: $nextAttemptNumber (Max was: ${validAttemptNumbers.reduce((a, b) => a > b ? a : b)})');
            }
          } catch (e) {
            developer.log('❌ Error calculating next attempt number: $e');
            nextAttemptNumber = 1;
          }
        }

        developer.log("📊 Creating NEW attempt #$nextAttemptNumber for quiz $_quizId");

        final response = await api.post('/quiz_attempt', {
          'course_quiz_id': _quizId.toString(),
          'user_id': user.id.toString(),
          'attempt_number': nextAttemptNumber.toString(),
          'status': 'in_progress',
          'current_question_index': '0',
          'time_spent_total': '0',
          'score': '0.00',
          'total_marks': '0.00',
          'obtained_marks': '0.00',
          'correct_answers': '0',
          'incorrect_answers': '0',
          'unanswered_questions': '0',
          'questions_data': '[]',
        });

        if (response['success'] != true) {
          throw Exception('Failed to start quiz: ${response['message'] ?? 'Unknown error'}');
        }

        // ✅ SAFE ATTEMPT ID EXTRACTION FROM RESPONSE
        attemptId = safeIntParse(
            response['data']?['id'] ?? response['id'],
            context: 'New attempt ID from API response',
            defaultValue: 0
        );

        if (attemptId == 0) {
          throw Exception(
              "❌ NO VALID ATTEMPT ID RETURNED!\n"
                  "Response data: ${response['data']}\n"
                  "Response id: ${response['id']}\n"
                  "Full response: $response"
          );
        }

        developer.log("✅ NEW ATTEMPT CREATED: ID $attemptId (Attempt #$nextAttemptNumber)");
      } else {
        attemptId = _safeGetAttemptId(latestAttempt!);
      }

      // ✅ STEP 4: NAVIGATE TO QUIZ PLAYER
      final isInstantQuiz = _isInstantQuiz(widget.quiz);
      if (!mounted) return;

      final routeData = {
        'quiz': widget.quiz,
        'attempt_id': attemptId, // ✅ GUARANTEED TO BE INT
      };

      developer.log('🎯 Navigating to ${isInstantQuiz ? "Instant" : "Standard"} Quiz Player with attempt ID: $attemptId');

      if (isInstantQuiz) {
        context.go('/quizzes/instant-player', extra: routeData);
      } else {
        context.go('/quizzes/standard-player', extra: routeData);
      }

    } catch (e, stackTrace) {
      developer.log("❌ START QUIZ ERROR: $e\nSTACK TRACE:\n$stackTrace");

      if (!mounted) return;

      _showErrorSnackBar("Failed to start quiz: ${e.toString().split('\n').first}");
    } finally {
      if (mounted) {
        setState(() => isStarting = false);
      }
    }
  }

  /// ✅ RESUME SNACKBAR
  void _showResumeSnackBar(int attemptNumber) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.play_arrow, color: Colors.white),
            const SizedBox(width: 8),
            Text('Resuming your previous attempt #$attemptNumber'),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// ✅ ERROR SNACKBAR
  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _shareQuiz() {
    try {
      final slug = widget.quiz['slug'] ?? widget.quiz['id'].toString();
      final shareUrl = "https://prepking.online/q/$slug";
      final title = widget.quiz['quiz_title'] ?? "Check out this quiz!";

      Share.share(
        "Hey! Try this amazing quiz on PrepKing:\n\n$title\n\n$shareUrl",
        subject: title,
      );
    } catch (e) {
      developer.log('❌ Share error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to share quiz'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// ✅ FIXED: SAFE ATTEMPT HISTORY WITH MAXIMUM ERROR PROTECTION
  Widget _buildAttemptHistory() {
    return Consumer(
      builder: (context, ref, child) {
        final attemptsAsync = ref.watch(quizAttemptsProvider(_quizId));

        return attemptsAsync.when(
          data: (attempts) {
            if (attempts.isEmpty) return const SizedBox.shrink();

            // ✅ SAFE SORTING WITH ERROR HANDLING
            List<Map<String, dynamic>> sortedAttempts;
            try {
              sortedAttempts = List.from(attempts);
              sortedAttempts.sort((a, b) {
                try {
                  final idA = safeIntParse(a['id'], context: 'History sort A', defaultValue: 0);
                  final idB = safeIntParse(b['id'], context: 'History sort B', defaultValue: 0);
                  return idB.compareTo(idA); // Newest first
                } catch (e) {
                  developer.log('❌ Sort error: $e');
                  return 0;
                }
              });
            } catch (e) {
              developer.log('❌ Attempt history sorting error: $e');
              sortedAttempts = List.from(attempts);
            }

            return Card(
              margin: const EdgeInsets.only(top: 16, bottom: 8),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.history, color: Color(0xFF6C5CE7)),
                        const SizedBox(width: 8),
                        Text(
                          '📋 Attempt History',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...sortedAttempts.take(5).map((attempt) {
                      try {
                        final status = attempt['status']?.toString() ?? 'unknown';
                        final attemptNum = _safeGetAttemptNumber(attempt);
                        final score = attempt['score']?.toString() ?? '0.00';
                        final startedAt = attempt['started_at']?.toString();

                        Color getStatusColor() {
                          if (status == 'in_progress') return Colors.orange;
                          if (score != '0.00') {
                            final scoreNum = double.tryParse(score);
                            if (scoreNum != null && scoreNum > 0) return Colors.green;
                          }
                          return Colors.grey;
                        }

                        String getStatusText() {
                          switch (status) {
                            case 'in_progress':
                              return 'In Progress';
                            case 'completed':
                              return 'Completed';
                            default:
                              return status;
                          }
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: getStatusColor(),
                              child: Text(
                                '$attemptNum',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            title: Text(
                              'Attempt #$attemptNum',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  getStatusText(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: getStatusColor(),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (startedAt != null && startedAt.isNotEmpty)
                                  Text(
                                    _formatDateTime(startedAt),
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                            trailing: status == 'in_progress'
                                ? const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.orange,
                              size: 20,
                            )
                                : Text(
                              score,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: getStatusColor(),
                              ),
                            ),
                          ),
                        );
                      } catch (e) {
                        developer.log('❌ Error building attempt item: $e');
                        return const SizedBox.shrink();
                      }
                    }),
                    if (sortedAttempts.length > 5)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: TextButton.icon(
                          onPressed: () {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Full history feature coming soon!'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.arrow_forward_ios, size: 14),
                          label: Text(
                            'View all ${sortedAttempts.length} attempts',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (error, stack) {
            developer.log('❌ Attempt history error: $error\n$stack');
            return const SizedBox.shrink();
          },
        );
      },
    );
  }

  String _formatDateTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return '${_getRelativeTime(dateTime)} • ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      developer.log('❌ DateTime parse error: $e');
      return dateTimeString;
    }
  }

  String _getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final quiz = widget.quiz;
    final isInstant = _isInstantQuiz(quiz);

    // ✅ VALIDATE QUIZ DATA
    if (_quizId == 0) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Invalid Quiz'),
          backgroundColor: Colors.red,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 80, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'Invalid quiz data',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Please try again or contact support',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          quiz['quiz_title'] ?? "Quiz",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF6C5CE7), const Color(0xFF8B78FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white),
            onPressed: _shareQuiz,
            tooltip: "Share Quiz",
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 📱 Quiz Info Card
            Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // 🎯 Quiz Title
                    Text(
                      quiz['quiz_title'] ?? "Quiz",
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    // 📊 Info Chips
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _infoChip(
                          Icons.timer,
                          isInstant
                              ? "30 sec per Q"
                              : "${safeIntParse(quiz['duration_minutes'], context: 'duration_minutes', defaultValue: 10)} mins",
                        ),
                        _infoChip(
                          Icons.quiz,
                          "${safeIntParse(quiz['total_questions'], context: 'total_questions', defaultValue: 10)} Qs",
                        ),
                        _infoChip(
                          Icons.star,
                          "${safeIntParse(quiz['passing_criteria'], context: 'passing_criteria', defaultValue: 60)}% Pass",
                        ),
                      ],
                    ),
                    // ⚡ Instant Quiz Badge
                    if (isInstant) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.orange.shade400, Colors.orange.shade600],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.3),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.flash_on, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              "Instant Quiz Mode",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // 📝 Quiz Description
                    if (quiz['description'] != null && quiz['description'].toString().isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Text(
                          quiz['description']!,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[600],
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ✅ ATTEMPT HISTORY
            _buildAttemptHistory(),
            const SizedBox(height: 24),

            // 📋 Instructions Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFF6C5CE7)),
                        const SizedBox(width: 8),
                        Text(
                          "Instructions",
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...[
                      _buildInstructionItem(
                        isInstant
                            ? "⚡ 30 seconds per question with instant feedback"
                            : "⏱️ ${safeIntParse(quiz['duration_minutes'], context: 'instruction_duration', defaultValue: 10)} minutes total time",
                      ),
                      _buildInstructionItem(
                        isInstant
                            ? "🎯 Auto-advance to next question"
                            : "📝 Review and change answers before submitting",
                      ),
                      _buildInstructionItem("✅ No negative marking"),
                      _buildInstructionItem("🎮 Complete in one session"),
                      _buildInstructionItem("💾 Progress automatically saved"),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // ✅ SMART START QUIZ BUTTON
            Consumer(
              builder: (context, ref, child) {
                final latestAttemptAsync = ref.watch(latestQuizAttemptProvider(_quizId));
                String buttonText = isInstant ? "🚀 Start Instant Quiz" : "🚀 Start Quiz Now";
                Color buttonColor = const Color(0xFF6C5CE7);
                IconData buttonIcon = isInstant ? Icons.flash_on : Icons.play_arrow_rounded;

                // Check for in-progress attempt
                if (latestAttemptAsync.asData?.value != null) {
                  final latestAttempt = latestAttemptAsync.asData!.value!;
                  final status = latestAttempt['status']?.toString() ?? '';
                  if (status == 'in_progress') {
                    buttonText = "📱 Resume Previous Attempt";
                    buttonColor = Colors.orange;
                    buttonIcon = Icons.play_arrow_rounded;
                  }
                }

                return Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 65,
                      child: ElevatedButton.icon(
                        onPressed: isStarting ? null : _startQuiz,
                        icon: isStarting
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                            : Icon(buttonIcon),
                        label: Text(
                          isStarting ? "Starting Quiz..." : buttonText,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isStarting ? Colors.grey : buttonColor,
                          foregroundColor: Colors.white,
                          elevation: isStarting ? 0 : 10,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    // ✅ RESUME INFO BANNER
                    Consumer(
                      builder: (context, ref, child) {
                        final latestAttemptAsync = ref.watch(latestQuizAttemptProvider(_quizId));
                        if (latestAttemptAsync.asData?.value != null) {
                          final latestAttempt = latestAttemptAsync.asData!.value!;
                          final status = latestAttempt['status']?.toString() ?? '';
                          if (status == 'in_progress' && !isStarting) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.info_outline, size: 16, color: Colors.orange),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Your previous attempt is still in progress. Tap to resume!",
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.orange[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // 🛠️ HELPER METHODS
  Widget _infoChip(IconData icon, String text) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF6C5CE7).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF6C5CE7), size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildInstructionItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Color(0xFF6C5CE7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              color: Colors.white,
              size: 12,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 14,
                height: 1.4,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}