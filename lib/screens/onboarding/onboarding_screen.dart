import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wealth_wise/screens/auth/login_screen.dart';
import 'package:wealth_wise/theme/app_theme.dart';
import 'package:wealth_wise/screens/subscription/subscription_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  static const routeName = '/onboarding';

  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _showSubscriptionOffer = false;

  final List<Map<String, dynamic>> _onboardingData = [
    {
      'title': 'Welcome to WealthWise',
      'description':
          'Your personal finance companion for smarter money management.',
      'icon': Icons.account_balance_wallet,
      'image': 'assets/images/onboarding_1.png',
      'color': AppTheme.primaryGreen,
    },
    {
      'title': 'Track Your Spending',
      'description':
          'Easily record and categorize your expenses to understand where your money goes.',
      'icon': Icons.sync_alt,
      'image': 'assets/images/onboarding_2.png',
      'color': AppTheme.secondaryBlue,
    },
    {
      'title': 'Set Savings Goals',
      'description':
          'Define targets for your financial future and track your progress.',
      'icon': Icons.flag,
      'image': 'assets/images/onboarding_3.png',
      'color': AppTheme.warningOrange,
    },
    {
      'title': 'Detailed Reports',
      'description':
          'Visualize your finances with beautiful charts and insightful analytics.',
      'icon': Icons.insights,
      'image': 'assets/images/onboarding_4.png',
      'color': AppTheme.primaryGreen,
    },
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showSubscriptionScreen() {
    setState(() {
      _showSubscriptionOffer = true;
    });
  }

  void _completeOnboarding() async {
    // Mark onboarding as complete
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasCompletedOnboarding', true);

    // Navigate to login screen
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showSubscriptionOffer) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, dynamic result) {
          if (!didPop) {
            // Complete onboarding if user tries to go back from subscription screen
            _completeOnboarding();
          }
          return;
        },
        child: Scaffold(
          body: SubscriptionScreen(
            onSkip: _completeOnboarding, // Pass the completion function
          ),
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _onboardingData.length,
              onPageChanged: (int page) {
                setState(() {
                  _currentPage = page;
                });
              },
              itemBuilder: (context, index) {
                return _buildOnboardingPage(
                  _onboardingData[index]['title'],
                  _onboardingData[index]['description'],
                  _onboardingData[index]['icon'],
                  _onboardingData[index]['image'],
                  _onboardingData[index]['color'],
                );
              },
            ),
          ),
          _buildPageIndicator(),
          _buildBottomButtons(),
        ],
      ),
    );
  }

  Widget _buildOnboardingPage(String title, String description, IconData icon,
      String imagePath, Color color) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 80,
              color: color,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            description,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[700],
                  height: 1.5,
                ),
            textAlign: TextAlign.center,
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    List<Widget> indicators = [];
    for (int i = 0; i < _onboardingData.length; i++) {
      indicators.add(
        Container(
          width: i == _currentPage ? 16.0 : 8.0,
          height: 8.0,
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          decoration: BoxDecoration(
            color: i == _currentPage ? AppTheme.primaryGreen : Colors.grey[300],
            borderRadius: BorderRadius.circular(4.0),
          ),
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: indicators,
    );
  }

  Widget _buildBottomButtons() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () {
                _showSubscriptionScreen();
              },
              child: Text(
                'Skip',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (_currentPage < _onboardingData.length - 1) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                } else {
                  _showSubscriptionScreen();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text(
                _currentPage < _onboardingData.length - 1
                    ? 'Next'
                    : 'Get Started',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
