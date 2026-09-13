import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';

/// A modal bottom-sheet user guide shown once on first login.
///
/// Contains the same six feature pages as the onboarding carousel but
/// presented as a popup over the home screen instead of a separate route.
Future<void> showUserGuideBottomSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => const _UserGuideSheet(),
  );
}

class _UserGuideSheet extends StatefulWidget {
  const _UserGuideSheet();

  @override
  State<_UserGuideSheet> createState() => _UserGuideSheetState();
}

class _UserGuideSheetState extends State<_UserGuideSheet> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<_GuidePage> _pages = [
    _GuidePage(
      icon: Icons.person_outline_rounded,
      title: 'Your Profile',
      description:
          'You can access your profile from the top-right corner of the Home screen.',
    ),
    _GuidePage(
      icon: Icons.dashboard_outlined,
      title: 'Dashboard',
      description: 'Swipe left to go to the Dashboard.',
    ),
    _GuidePage(
      icon: Icons.receipt_long_outlined,
      title: 'Log Expenses',
      description: 'Tap on an activity to log an expense.',
    ),
    _GuidePage(
      icon: Icons.assignment_outlined,
      title: 'Start a Plan',
      description: 'You must have an available plan to start one.',
    ),
    _GuidePage(
      icon: Icons.add_location_alt_outlined,
      title: 'Plan New Trip',
      description: 'Tap "Plan New" to generate a plan.',
    ),
    _GuidePage(
      icon: Icons.play_circle_outline_rounded,
      title: 'Continue Your Trip',
      description: 'Continue from where you left off.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _dismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _pages.length - 1;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.65,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // ── Drag handle ──
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.gray200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Skip button ──
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 4, right: 16),
              child: TextButton(
                onPressed: _dismiss,
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.blueGray300,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),

          // ── Page content ──
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _pages.length,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemBuilder: (context, index) {
                final page = _pages[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon circle
                      Container(
                        width: 110,
                        height: 110,
                        decoration: const BoxDecoration(
                          color: AppColors.teal50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          page.icon,
                          size: 52,
                          color: AppColors.tealA700,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Title
                      Text(
                        page.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.gray900,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Description
                      Text(
                        page.description,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.blueGray700,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // ── Dot indicators ──
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (index) {
                final isActive = index == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isActive ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.tealA700 : AppColors.gray200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),

          // ── Next / Get Started button ──
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _nextPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.tealA700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  isLastPage ? 'Get Started' : 'Next',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuidePage {
  final IconData icon;
  final String title;
  final String description;

  const _GuidePage({
    required this.icon,
    required this.title,
    required this.description,
  });
}
