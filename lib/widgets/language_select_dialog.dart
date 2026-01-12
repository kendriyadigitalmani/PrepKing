// lib/widgets/language_select_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../core/services/api_service.dart';
import '../core/utils/user_preferences.dart';
import '../providers/language_provider.dart';
import '../providers/user_provider.dart';
import '../models/user_model.dart'; // ← NEW: Needed for UserModel type

Future<bool?> showLanguageSelectDialog(BuildContext context) {
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
      return const _LanguageSelectDialogContent();
    },
  );
}

class _LanguageSelectDialogContent extends ConsumerStatefulWidget {
  const _LanguageSelectDialogContent();

  @override
  ConsumerState<_LanguageSelectDialogContent> createState() => _LanguageSelectDialogContentState();
}

class _LanguageSelectDialogContentState extends ConsumerState<_LanguageSelectDialogContent> {
  int? _selectedLanguageId;

  @override
  void initState() {
    super.initState();

    // 🔥 STEP 3: Pre-populate selected language from UserModel + SharedPreferences fallback
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final userAsync = ref.read(currentUserProvider);
      if (userAsync.asData == null) return;

      final UserModel? user = userAsync.value;
      if (user == null) return;

      // Primary source: UserModel.languageId
      int? initialId = user.languageId;

      // Fallback: If UserModel is missing language, load from SharedPreferences
      if (initialId == null) {
        final prefs = UserPreferences();
        final storedLanguage = await prefs.getLanguage();
        initialId = storedLanguage;
      }

      // Apply to UI if still mounted
      if (mounted) {
        setState(() {
          _selectedLanguageId = initialId;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final languagesAsync = ref.watch(languagesProvider);
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
                'Select Your Language',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF6C5CE7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Flexible(
                child: languagesAsync.when(
                  loading: () => _buildShimmerList(),
                  error: (err, stack) => Center(
                    child: Text(
                      'Failed to load languages',
                      style: GoogleFonts.poppins(color: Colors.red),
                    ),
                  ),
                  data: (languages) {
                    if (languages.isEmpty) {
                      return Center(
                        child: Text(
                          'No languages available',
                          style: GoogleFonts.poppins(),
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: languages.length,
                      itemBuilder: (context, index) {
                        final lang = languages[index];
                        final id = lang['id'] as int;
                        final name = lang['language_name'] as String;

                        return RadioListTile<int>(
                          value: id,
                          groupValue: _selectedLanguageId,
                          onChanged: (value) {
                            setState(() {
                              _selectedLanguageId = value;
                            });
                          },
                          title: Text(
                            name,
                            style: GoogleFonts.poppins(fontSize: 16),
                          ),
                          activeColor: const Color(0xFF6C5CE7),
                          dense: true,
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedLanguageId == null
                      ? null
                      : () async {
                    final user = userAsync.value;
                    if (user == null) {
                      Navigator.pop(context, false);
                      return;
                    }

                    try {
                      final api = ref.read(apiServiceProvider);
                      await api.updateUserLanguage(user.id, _selectedLanguageId!);

                      final prefs = UserPreferences();
                      await prefs.saveLanguage(_selectedLanguageId!);

                      // 🔥 Force refresh currentUserProvider so UI updates instantly everywhere
                      ref.invalidate(currentUserProvider);

                      if (mounted) Navigator.pop(context, true);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to save language: $e')),
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
                    'Confirm Language',
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

  Widget _buildShimmerList() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: 8,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(width: 24, height: 24, color: Colors.white),
              const SizedBox(width: 16),
              Expanded(child: Container(height: 16, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}