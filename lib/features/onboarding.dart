import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = const [
    OnboardingPage(
      icon: Icons.rocket_launch_rounded,
      title: 'Welcome to Your Personal Hub',
      description: 'One place to organize your thoughts, build better habits, and stay on top of your life. Let us show you how it works.',
    ),
    OnboardingPage(
      icon: Icons.note_alt_rounded,
      title: 'Never Lose a Great Idea',
      description: 'Capture thoughts instantly with rich text notes. Organize with colors and tags, and keep your favorites pinned at the top.',
    ),
    OnboardingPage(
      icon: Icons.checklist_rtl_rounded,
      title: 'Build Habits That Stick',
      description: 'Track daily habits with streaks and reminders. Watch your progress grow with visual weekly and monthly insights.',
    ),
    OnboardingPage(
      icon: Icons.calendar_month_rounded,
      title: 'Stay On Top of Your Schedule',
      description: 'See events, habits, and notes in one unified calendar. Set reminders so nothing slips through the cracks.',
    ),
    OnboardingPage(
      icon: Icons.calculate_rounded,
      title: 'Calculate On the Go',
      description: 'Quick calculations with history and memory functions. Switch to scientific mode when you need more power.',
    ),
    OnboardingPage(
      icon: Icons.hourglass_empty_rounded,
      title: 'See Your Life in Perspective',
      description: 'Track days lived and set life milestones. A gentle reminder to make each day count.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete_v1', true);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    }
  }

  void _goToPreviousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _goToNextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLastPage = _currentPage == _pages.length - 1;
    final isLandscape = MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;
    const Color activeDotColor = Color(0xFF7CD9C8);
    const Color inactiveDotColor = Color(0xFFB0D8D0);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: Semantics(
                  button: true,
                  label: 'Skip onboarding',
                  child: TextButton(
                    onPressed: _completeOnboarding,
                    child: Text(
                      'Skip',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) => _pages[index],
              ),
            ),
            if (isLandscape) const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => Semantics(
                        label: 'Page ${index + 1} of ${_pages.length}',
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? activeDotColor
                                : inactiveDotColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (_currentPage > 0)
                        Semantics(
                          button: true,
                          label: 'Go to previous page',
                          child: IconButton(
                            onPressed: _goToPreviousPage,
                            icon: const Icon(Icons.arrow_back_rounded),
                            iconSize: 28,
                            style: IconButton.styleFrom(
                              minimumSize: const Size(48, 48),
                            ),
                          ),
                        ),
                      Expanded(
                        child: Semantics(
                          button: true,
                          label: isLastPage
                              ? 'Get started with the app'
                              : 'Go to next page',
                          child: FilledButton(
                            onPressed: isLastPage
                                ? _completeOnboarding
                                : _goToNextPage,
                            style: FilledButton.styleFrom(
                              backgroundColor: activeDotColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              minimumSize: const Size(double.infinity, 52),
                            ),
                            child: Text(
                              isLastPage ? 'Get Started' : 'Next',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_currentPage > 0) const SizedBox(width: 48),
                    ],
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
  final IconData icon;
  final String title;
  final String description;

  const OnboardingPage({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLandscape = MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;
    if (isLandscape) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFF7CD9C8),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: Colors.white),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    semanticsLabel: title,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
              color: Color(0xFF7CD9C8),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 60, color: Colors.white),
          ),
          const SizedBox(height: 32),
          Text(
            title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            semanticsLabel: title,
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
