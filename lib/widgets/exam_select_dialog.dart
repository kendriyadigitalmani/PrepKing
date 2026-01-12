// lib/widgets/exam_select_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../core/services/api_service.dart';
import '../core/utils/user_preferences.dart';
import '../providers/exam_provider.dart';
import '../providers/user_provider.dart';
import '../models/user_model.dart'; // ← NEW: Needed for UserModel type

Future<bool?> showExamSelectDialog(BuildContext context) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.6),
    transitionDuration: const Duration(milliseconds: 300),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: animation, child: child),
      );
    },
    pageBuilder: (context, _, __) {
      return const _ExamSelectDialogContent();
    },
  );
}

class _ExamSelectDialogContent extends ConsumerStatefulWidget {
  const _ExamSelectDialogContent();

  @override
  ConsumerState<_ExamSelectDialogContent> createState() => _ExamSelectDialogContentState();
}

class _ExamSelectDialogContentState extends ConsumerState<_ExamSelectDialogContent> {
  late Set<int> _selectedExamIds; // ← Will be initialized in initState

  @override
  void initState() {
    super.initState();
    _selectedExamIds = {}; // Initial empty set

    // 🔥 STEP 3: Pre-populate selected exams from UserModel + SharedPreferences fallback
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final userAsync = ref.read(currentUserProvider);
      if (userAsync.asData == null) return;

      final UserModel? user = userAsync.value;
      if (user == null) return;

      // Primary source: UserModel.examIds
      Set<int> initialIds = Set.from(user.examIds);

      // Fallback: If UserModel is missing exams, load from SharedPreferences
      if (initialIds.isEmpty) {
        final prefs = UserPreferences();
        final storedExams = await prefs.getExams();
        initialIds = Set.from(storedExams);
      }

      // Apply to UI if still mounted
      if (mounted) {
        setState(() {
          _selectedExamIds = initialIds;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final examsAsync = ref.watch(examsProvider);
    final userAsync = ref.watch(currentUserProvider);

    return Center(
      child: Material(
        borderRadius: BorderRadius.circular(24),
        elevation: 20,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          constraints: const BoxConstraints(maxHeight: 600),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Exams (Max 4)',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF6C5CE7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Choose up to 4 exams you are preparing for',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Flexible(
                child: examsAsync.when(
                  loading: () => _buildShimmerGrid(),
                  error: (err, stack) => Center(
                    child: Text(
                      'Failed to load exams',
                      style: GoogleFonts.poppins(color: Colors.red),
                    ),
                  ),
                  data: (exams) {
                    if (exams.isEmpty) {
                      return Center(
                        child: Text(
                          'No exams available',
                          style: GoogleFonts.poppins(),
                        ),
                      );
                    }
                    return SingleChildScrollView(
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: exams.map((exam) {
                          final id = exam['id'] as int;
                          final name = exam['name'] as String;
                          final isSelected = _selectedExamIds.contains(id);

                          return FilterChip(
                            label: Text(
                              name,
                              style: GoogleFonts.poppins(fontSize: 14),
                            ),
                            selected: isSelected,
                            onSelected: _selectedExamIds.length >= 4 && !isSelected
                                ? null
                                : (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedExamIds.add(id);
                                } else {
                                  _selectedExamIds.remove(id);
                                }
                              });
                            },
                            selectedColor: const Color(0xFF6C5CE7).withOpacity(0.2),
                            checkmarkColor: const Color(0xFF6C5CE7),
                            backgroundColor: Colors.grey[200],
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                              side: BorderSide(
                                color: isSelected ? const Color(0xFF6C5CE7) : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${_selectedExamIds.length}/4 selected',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: _selectedExamIds.length >= 4 ? Colors.orange : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedExamIds.isEmpty
                      ? null
                      : () async {
                    final user = userAsync.value;
                    if (user == null) {
                      Navigator.pop(context, false);
                      return;
                    }

                    try {
                      final api = ref.read(apiServiceProvider);
                      await api.updateUserExams(user.id, _selectedExamIds.toList());

                      final prefs = UserPreferences();
                      await prefs.saveExams(_selectedExamIds.toList());

                      // 🔥 Force refresh currentUserProvider so UI updates instantly everywhere
                      ref.invalidate(currentUserProvider);

                      if (mounted) Navigator.pop(context, true);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to save exams: $e')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C5CE7),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Confirm Exams',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: List.generate(8, (_) => Container(
          width: 140,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
          ),
        )),
      ),
    );
  }
}