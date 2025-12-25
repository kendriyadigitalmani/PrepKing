// lib/screens/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import '../core/utils/user_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> onboardingData = [
    {
      "title": "Practice Smart",
      "text": "Thousands of questions with detailed solutions",
      "lottie": "practice.json",
    },
    {
      "title": "Track Progress",
      "text": "See your improvement with beautiful analytics",
      "lottie": "progress.json",
    },
    {
      "title": "Compete & Win",
      "text": "Join live contests and climb the leaderboard",
      "lottie": "trophy.json",
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Called when user completes onboarding
  Future<void> _completeOnboarding() async {
    // Mark onboarding as seen using the safe, updated UserPreferences
    await UserPreferences().saveOnboardingSeen();

    if (!mounted) return;

    // Always go to login after onboarding (user must sign in to save progress)
    // This is best practice: onboarding → login → home
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF6C5CE7),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: onboardingData.length,
                itemBuilder: (context, index) {
                  final data = onboardingData[index];
                  return OnboardingPage(data: data);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(30.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page indicators
                  Row(
                    children: List.generate(
                      onboardingData.length,
                          (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 8),
                        height: 10,
                        width: _currentPage == i ? 30 : 10,
                        decoration: BoxDecoration(
                          color: _currentPage == i ? Colors.white : Colors.white38,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),
                  // Next / Done button
                  FloatingActionButton(
                    backgroundColor: Colors.white,
                    elevation: 6,
                    onPressed: () async {
                      if (_currentPage == onboardingData.length - 1) {
                        await _completeOnboarding();
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    child: Icon(
                      _currentPage == onboardingData.length - 1
                          ? Icons.check
                          : Icons.arrow_forward,
                      color: const Color(0xFF6C5CE7),
                      size: 28,
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
}

class OnboardingPage extends StatelessWidget {
  final Map<String, String> data;

  const OnboardingPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/lottie/${data["lottie"]}',
            width: 320,
            fit: BoxFit.contain,
            repeat: true,
            errorBuilder: (context, error, stackTrace) {
              // Fallback if Lottie fails to load
              return const Icon(
                Icons.quiz,
                size: 200,
                color: Colors.white70,
              );
            },
          ),
          const SizedBox(height: 60),
          Text(
            data["title"]!,
            style: GoogleFonts.poppins(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            data["text"]!,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}