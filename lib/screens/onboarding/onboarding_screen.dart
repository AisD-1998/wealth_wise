import 'package:flutter/material.dart';
import 'package:wealth_wise/screens/auth/login_screen.dart';
import 'package:wealth_wise/services/shared_prefs.dart';
import 'package:wealth_wise/widgets/custom_action_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingItem> _items = [
    OnboardingItem(
      title: 'Track Your Spending',
      description:
          'Monitor all your expenses and income in one place with easy-to-understand visualizations.',
      icon: Icons.bar_chart_rounded,
    ),
    OnboardingItem(
      title: 'Set Saving Goals',
      description:
          'Create and track saving goals to help you achieve your financial dreams.',
      icon: Icons.savings_rounded,
    ),
    OnboardingItem(
      title: 'Smart Budgeting',
      description:
          'Set budgets for different categories and get notified when you are near your limits.',
      icon: Icons.account_balance_wallet_rounded,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Complete onboarding and navigate to login screen
  void _completeOnboarding() async {
    // Set the flag to indicate onboarding is complete
    await SharedPrefs.setBool('hasCompletedOnboarding', true);

    if (!mounted) return;

    // Navigate to login screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _items.length,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                itemBuilder: (context, index) {
                  return _buildOnboardingPage(_items[index], theme);
                },
              ),
            ),

            // Page indicator
            Padding(
              padding: const EdgeInsets.only(bottom: 32.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _buildPageIndicator(),
              ),
            ),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Skip button
                  _currentPage < _items.length - 1
                      ? TextButton(
                          onPressed: _completeOnboarding,
                          child: const Text('Skip'),
                        )
                      : const SizedBox(width: 80),

                  // Next/Get Started button
                  CustomActionButton(
                    onPressed: () {
                      if (_currentPage < _items.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        _completeOnboarding();
                      }
                    },
                    label: _currentPage < _items.length - 1
                        ? 'Next'
                        : 'Get Started',
                    icon: _currentPage < _items.length - 1
                        ? Icons.arrow_forward
                        : Icons.check_circle_outline,
                    isSmall: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingPage(OnboardingItem item, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 26),
              shape: BoxShape.circle,
            ),
            child: Icon(
              item.icon,
              size: 80,
              color: theme.colorScheme.primary,
            ),
          ),

          const SizedBox(height: 48),

          // Title
          Text(
            item.title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // Description
          Text(
            item.description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 179),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageIndicator() {
    List<Widget> indicators = [];

    for (int i = 0; i < _items.length; i++) {
      indicators.add(
        Container(
          width: i == _currentPage ? 16.0 : 8.0,
          height: 8.0,
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: i == _currentPage
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.primary.withValues(alpha: 77),
          ),
        ),
      );
    }

    return indicators;
  }
}

class OnboardingItem {
  final String title;
  final String description;
  final IconData icon;

  OnboardingItem({
    required this.title,
    required this.description,
    required this.icon,
  });
}
