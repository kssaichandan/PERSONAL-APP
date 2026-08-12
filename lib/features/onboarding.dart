import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      secondaryIcon: Icons.auto_awesome_rounded,
      title: 'Welcome to Your Hub',
      description: 'One place to organize your thoughts, build better habits, and stay on top of your life. Let us show you how it works.',
    ),
    OnboardingPage(
      icon: Icons.note_alt_rounded,
      secondaryIcon: Icons.push_pin_rounded,
      title: 'Never Lose a Great Idea',
      description: 'Capture thoughts instantly with rich text notes. Organize with colors and tags, and keep your favorites pinned at the top.',
    ),
    OnboardingPage(
      icon: Icons.checklist_rtl_rounded,
      secondaryIcon: Icons.local_fire_department_rounded,
      title: 'Build Habits That Stick',
      description: 'Track daily habits with streaks and reminders. Watch your progress grow with visual weekly and monthly insights.',
    ),
    OnboardingPage(
      icon: Icons.calendar_month_rounded,
      secondaryIcon: Icons.notifications_active_rounded,
      title: 'Stay On Top of Your Schedule',
      description: 'See events, habits, and notes in one unified calendar. Set reminders so nothing slips through the cracks.',
    ),
    OnboardingPage(
      icon: Icons.calculate_rounded,
      secondaryIcon: Icons.functions_rounded,
      title: 'Calculate On the Go',
      description: 'Quick calculations with history and memory functions. Switch to scientific mode when you need more power.',
    ),
    OnboardingPage(
      icon: Icons.hourglass_empty_rounded,
      secondaryIcon: Icons.flag_rounded,
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
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete_v1', true);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    }
  }

  void _goToPage(int page) {
    if (page >= 0 && page < _pages.length) {
      HapticFeedback.selectionClick();
      _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _goToPreviousPage() {
    _goToPage(_currentPage - 1);
  }

  void _goToNextPage() {
    _goToPage(_currentPage + 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLastPage = _currentPage == _pages.length - 1;
    final isLandscape = MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;
    final activeDotColor = theme.colorScheme.primary;
    final inactiveDotColor = theme.colorScheme.outlineVariant;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header Bar with Step Counter & Skip
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentPage + 1} of ${_pages.length}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: isLastPage ? 0.0 : 1.0,
                    child: IgnorePointer(
                      ignoring: isLastPage,
                      child: TextButton(
                        onPressed: _completeOnboarding,
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.onSurfaceVariant,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
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
            // Bottom Controls Area
            Padding(
              padding: const EdgeInsets.only(left: 24, right: 24, top: 12, bottom: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    children: [
                      // Interactive Indicator Dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _pages.length,
                          (index) => GestureDetector(
                            onTap: () => _goToPage(index),
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                width: _currentPage == index ? 32 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _currentPage == index
                                      ? activeDotColor
                                      : inactiveDotColor,
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: _currentPage == index
                                      ? [
                                          BoxShadow(
                                            color: activeDotColor.withValues(alpha: 0.3),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Bottom Navigation Action Row
                      Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOutCubic,
                            width: _currentPage > 0 ? 56 : 0,
                            margin: EdgeInsets.only(right: _currentPage > 0 ? 12 : 0),
                            child: _currentPage > 0
                                ? IconButton.filledTonal(
                                    onPressed: _goToPreviousPage,
                                    icon: const Icon(Icons.arrow_back_rounded),
                                    iconSize: 22,
                                    style: IconButton.styleFrom(
                                      minimumSize: const Size(56, 56),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          Expanded(
                            child: FilledButton(
                              onPressed: isLastPage
                                  ? _completeOnboarding
                                  : _goToNextPage,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                minimumSize: const Size(double.infinity, 56),
                                backgroundColor: isLastPage
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.primary,
                                elevation: isLastPage ? 2 : 0,
                              ),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (child, animation) =>
                                    ScaleTransition(scale: animation, child: child),
                                child: Row(
                                  key: ValueKey(isLastPage),
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      isLastPage ? 'Get Started' : 'Next',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    if (isLastPage) ...[
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward_rounded, size: 20),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
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
  final IconData secondaryIcon;
  final String title;
  final String description;

  const OnboardingPage({
    super.key,
    required this.icon,
    required this.secondaryIcon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLandscape = MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;

    Widget buildIllustration(double size, double iconSize, double badgeSize, double badgeIconSize) {
      return Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Outer Glow Container
          Container(
            width: size + 28,
            height: size + 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
          ),
          // Main Icon Circle Container
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primaryContainer,
                  theme.colorScheme.primary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.35),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(icon, size: iconSize, color: theme.colorScheme.onPrimary),
          ),
          // Floating Secondary Badge Accent
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer,
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.surface,
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                secondaryIcon,
                size: badgeIconSize,
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      );
    }

    if (isLandscape) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                buildIllustration(84, 40, 32, 18),
                const SizedBox(width: 36),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              buildIllustration(132, 64, 44, 24),
              const SizedBox(height: 44),
              Text(
                title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.6,
                  height: 1.25,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                description,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.55,
                  letterSpacing: -0.1,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

