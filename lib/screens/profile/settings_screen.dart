// lib/screens/profile/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/api_constants.dart';
import '../../core/services/api_service.dart';
import '../../providers/user_provider.dart';
import '../../providers/course_providers.dart'; // Assumes quizzesProvider is defined here
import '../../widgets/language_select_dialog.dart';
import '../../widgets/exam_select_dialog.dart';
import '../quizzes/quizzes_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isLoading = false;
  bool? _localNotificationValue;

  Future<void> _updateUserSettings(Map<String, dynamic> updates) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final userAsync = ref.watch(currentUserProvider);
      final user = userAsync.value;
      if (user == null) throw Exception('User not logged in');

      final api = ref.read(apiServiceProvider);

      final Map<String, dynamic> payload = {};
      if (updates.containsKey('notifications_enabled')) {
        payload['isNotificationEnabled'] = updates['notifications_enabled'] ? 1 : 0;
      }
      if (updates.containsKey('theme')) {
        payload['theme'] = updates['theme'] == 'dark' ? 'Dark' : 'Light';
      }

      final response = await api.put('/user/${user.id}', payload);

      if (response['success'] == true) {
        ref.invalidate(currentUserProvider); // Refresh user data
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception(response['message'] ?? 'Update failed');
      }
    } catch (e) {
      debugPrint('Settings update error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update settings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _launchPrivacyPolicy() async {
    final url = Uri.parse(ApiConstants.privacyUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open privacy policy')),
      );
    }
  }

  // Launch Delete Account Request Form
  Future<void> _launchDeleteAccountForm() async {
    const String deleteFormUrl =
        'https://docs.google.com/forms/d/e/1FAIpQLSfSqN3qrvPYhXWYR09bY-rOlxk9AOWVCTcnynX-kpKpTWJFsA/viewform?usp=header';
    final url = Uri.parse(deleteFormUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open delete account form')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading settings: $err'),
            ],
          ),
        ),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User not logged in'));
          }

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ─── Notifications ───
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: SwitchListTile(
                      title: Text(
                        'Enable Notifications',
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        'Receive quiz reminders and updates',
                        style: GoogleFonts.poppins(color: Colors.grey[600]),
                      ),
                      value: _localNotificationValue ?? user.notificationsEnabled,
                      onChanged: _isLoading
                          ? null
                          : (bool value) async {
                        setState(() => _localNotificationValue = value);
                        await _updateUserSettings({'notifications_enabled': value});
                        _localNotificationValue = null;
                      },
                      activeColor: const Color(0xFF6C5CE7),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ─── Theme ───
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      title: Text(
                        'Theme',
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        'Choose your preferred appearance',
                        style: GoogleFonts.poppins(color: Colors.grey[600]),
                      ),
                      trailing: DropdownButton<String>(
                        value: user.theme.toLowerCase(),
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'light', child: Text('Light')),
                          DropdownMenuItem(value: 'dark', child: Text('Dark')),
                        ],
                        onChanged: _isLoading
                            ? null
                            : (String? value) {
                          if (value != null) {
                            _updateUserSettings({'theme': value});
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ─── Privacy Policy ───
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: const Icon(Icons.policy, color: Color(0xFF6C5CE7)),
                      title: Text(
                        'Privacy Policy',
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: _launchPrivacyPolicy,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ─── Select Language ───
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: const Icon(Icons.language, color: Color(0xFF6C5CE7)),
                      title: Text(
                        'Select Language',
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final result = await showLanguageSelectDialog(context);
                        if (result == true) {
                          ref.invalidate(currentUserProvider);
                          ref.invalidate(courseListProvider);
                          ref.invalidate(quizzesProvider);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ─── Select Exams ───
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: const Icon(Icons.school, color: Color(0xFF6C5CE7)),
                      title: Text(
                        'Select Exams',
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        'Choose up to 4 exams you are preparing for',
                        style: GoogleFonts.poppins(color: Colors.grey[600]),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final result = await showExamSelectDialog(context);
                        if (result == true) {
                          ref.invalidate(currentUserProvider);
                          ref.invalidate(courseListProvider);
                          ref.invalidate(quizzesProvider);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 30),

                  // ─── Delete Account ───
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: const Icon(Icons.delete_forever, color: Colors.red),
                      title: Text(
                        'Delete Account',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.red,
                        ),
                      ),
                      subtitle: Text(
                        'Permanently delete your account and all data',
                        style: GoogleFonts.poppins(color: Colors.grey[600]),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: Colors.red),
                      onTap: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Account?'),
                            content: const Text(
                              'This action is permanent and cannot be undone.\n'
                                  'All your progress, quizzes, and personal data will be deleted.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true) {
                          await _launchDeleteAccountForm();
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),

              // Loading Overlay
              if (_isLoading)
                Container(
                  color: Colors.black26,
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C5CE7)),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}