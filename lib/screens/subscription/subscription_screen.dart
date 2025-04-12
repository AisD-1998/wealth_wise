import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wealth_wise/providers/subscription_provider.dart';
import 'package:wealth_wise/theme/app_theme.dart';
import 'package:wealth_wise/widgets/loading_indicator.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:wealth_wise/services/billing_service.dart';
// New imports for animations and responsive design
import 'dart:ui'; // Import for ImageFilter
import 'package:flutter/services.dart';

// Add custom DelayedAnimation widget to replace TweenAnimationBuilder with delay
class DelayedAnimation extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Curve curve;
  final Offset? beginOffset;

  const DelayedAnimation({
    super.key,
    required this.child,
    required this.delay,
    this.duration = const Duration(milliseconds: 800),
    this.curve = Curves.easeOutCubic,
    this.beginOffset,
  });

  @override
  State<DelayedAnimation> createState() => _DelayedAnimationState();
}

class _DelayedAnimationState extends State<DelayedAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: widget.curve,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: widget.beginOffset ?? Offset.zero,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: widget.curve,
      ),
    );

    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

class SubscriptionScreen extends StatefulWidget {
  final VoidCallback? onSkip;

  const SubscriptionScreen({super.key, this.onSkip});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with SingleTickerProviderStateMixin {
  bool _initializing = true;
  static const Duration _loadingTimeout = Duration(seconds: 8);
  int _selectedPlanIndex = 1; // Default to monthly (index 1)

  // Animation controllers for micro-interactions
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  // Track payment flow steps
  int _currentStep = 0; // 0: plan selection, 1: review, 2: success

  // Track if the page has been scrolled
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolled = false;

  @override
  void initState() {
    super.initState();
    // Initialize the subscription provider when the screen loads
    _initializeSubscription();

    // Setup a timeout to force exit loading state if it takes too long
    Future.delayed(_loadingTimeout, () {
      if (mounted && _initializing) {
        setState(() {
          _initializing = false;
        });

        // Force the provider to exit loading state
        final provider =
            Provider.of<SubscriptionProvider>(context, listen: false);
        provider.forceExitLoadingState();
      }
    });

    // Setup animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Start the entrance animation
    _animationController.forward();

    // Listen to scroll changes
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.offset > 20 && !_hasScrolled) {
      setState(() => _hasScrolled = true);
    } else if (_scrollController.offset <= 20 && _hasScrolled) {
      setState(() => _hasScrolled = false);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Play haptic feedback for better tactile response
  void _playHapticFeedback() {
    HapticFeedback.mediumImpact();
  }

  // Go to next step in the payment flow
  void _nextStep() {
    _playHapticFeedback();
    setState(() {
      _currentStep++;
    });
    // Restart animations for the new step
    _animationController.reset();
    _animationController.forward();
  }

  // Go to previous step in the payment flow
  void _previousStep() {
    _playHapticFeedback();
    setState(() {
      _currentStep--;
    });
    // Restart animations for the new step
    _animationController.reset();
    _animationController.forward();
  }

  Future<void> _initializeSubscription() async {
    if (!mounted) return;

    setState(() {
      _initializing = true;
    });

    final provider = Provider.of<SubscriptionProvider>(context, listen: false);
    await provider.initialize();

    if (mounted) {
      setState(() {
        _initializing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the current theme to support both light and dark modes
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtextColor = isDarkMode ? Colors.grey.shade300 : Colors.black54;
    final dividerColor =
        isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200;

    // Use MediaQuery for responsive design
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 350;

    return Scaffold(
      backgroundColor: backgroundColor,
      // Apply a frosted glass effect to app bar when scrolled
      appBar: _hasScrolled
          ? AppBar(
              backgroundColor: backgroundColor.withValues(alpha: 204),
              elevation: 0,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios,
                  color: textColor,
                  size: 22,
                ),
                onPressed: () {
                  if (_currentStep > 0) {
                    _previousStep();
                  } else {
                    if (widget.onSkip != null) {
                      widget.onSkip!();
                    } else {
                      Navigator.of(context).pop();
                    }
                  }
                },
              ),
              title: AnimatedOpacity(
                opacity: _hasScrolled ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Text(
                  'Premium Subscription',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              actions: [
                if (_currentStep == 0)
                  TextButton(
                    onPressed: () {
                      if (widget.onSkip != null) {
                        widget.onSkip!();
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        color: subtextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
              // Apply frosted glass effect
              flexibleSpace: ClipRect(
                child: BackdropFilter(
                  filter: isDarkMode
                      ? ImageFilter.blur(sigmaX: 10, sigmaY: 10)
                      : ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(color: Colors.transparent),
                ),
              ),
            )
          : PreferredSize(
              preferredSize: const Size.fromHeight(0),
              child: Container(
                color: backgroundColor,
              ),
            ),
      body: SafeArea(
        child: Consumer<SubscriptionProvider>(
          builder: (context, provider, _) {
            // Show loading only during first initialization
            if (_initializing || provider.isLoading) {
              return _buildLoadingState(context, isDarkMode);
            }

            // Handle errors or no products available
            if (provider.errorMessage != null || provider.products.isEmpty) {
              return _buildErrorState(context, provider, isDarkMode);
            }

            if (provider.isSubscribed) {
              return _buildActiveSubscription(context, provider, isDarkMode);
            }

            // Show current step in the payment flow
            switch (_currentStep) {
              case 0:
                return _buildSubscriptionOffers(
                    context, provider, isDarkMode, isSmallScreen);
              case 1:
                return _buildReviewPurchase(context, provider, isDarkMode);
              case 2:
                return _buildSuccessState(context, isDarkMode);
              default:
                return _buildSubscriptionOffers(
                    context, provider, isDarkMode, isSmallScreen);
            }
          },
        ),
      ),
      // Bottom navigation - show different buttons based on current step
      bottomNavigationBar: Consumer<SubscriptionProvider>(
        builder: (context, provider, _) {
          if (_initializing || provider.isLoading || provider.isSubscribed) {
            return const SizedBox.shrink();
          }

          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _currentStep == 0 ? 80 : 90,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: backgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 13),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
              border: Border(
                top: BorderSide(color: dividerColor, width: 0.5),
              ),
            ),
            child: SafeArea(
              child: _currentStep == 0
                  ? TextButton(
                      onPressed: () {
                        if (widget.onSkip != null) {
                          widget.onSkip!();
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                      child: Text(
                        'Maybe later',
                        style: TextStyle(
                          color: subtextColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: _previousStep,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: dividerColor,
                                ),
                              ),
                            ),
                            child: Text(
                              'Back',
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _currentStep == 1
                                ? () => _handleSubscriptionPurchase(context)
                                : _nextStep,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              _currentStep == 1
                                  ? 'Confirm Purchase'
                                  : 'Continue',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }

  // Loading state with better animation
  Widget _buildLoadingState(BuildContext context, bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Custom animated loading indicator
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: LoadingIndicator(),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Fetching subscription options...',
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Just a moment',
            style: TextStyle(
              color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // Error state with improved retry option
  Widget _buildErrorState(
      BuildContext context, SubscriptionProvider provider, bool isDarkMode) {
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Error icon with animation
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.red.shade900.withValues(alpha: 51)
                          : Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.error_outline,
                      size: 60,
                      color: isDarkMode ? Colors.red.shade300 : Colors.red,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Unable to load subscription options',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              provider.errorMessage ??
                  'We couldn\'t retrieve the subscription details. Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _initializeSubscription,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                if (widget.onSkip != null) {
                  widget.onSkip!();
                } else {
                  Navigator.of(context).pop();
                }
              },
              child: Text(
                'Continue without premium',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Active subscription state
  Widget _buildActiveSubscription(
      BuildContext context, SubscriptionProvider provider, bool isDarkMode) {
    final endDate = provider.subscriptionEndDate;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final accentColor =
        isDarkMode ? AppTheme.accentMint : AppTheme.primaryGreen;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated checkmark icon
            DelayedAnimation(
              delay: const Duration(milliseconds: 200),
              beginOffset: const Offset(0, 20),
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withValues(alpha: 179),
                      accentColor,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 77),
                      blurRadius: 20,
                      spreadRadius: 5,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.verified,
                  size: 64,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Animated text reveal
            DelayedAnimation(
              delay: const Duration(milliseconds: 200),
              beginOffset: const Offset(0, 20),
              child: Text(
                'You\'re a Premium Member!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            // Animated text reveal with delay
            DelayedAnimation(
              delay: const Duration(milliseconds: 400),
              beginOffset: const Offset(0, 20),
              child: Column(
                children: [
                  Text(
                    'Your subscription is active until:',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: textColor,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.grey.shade800.withValues(alpha: 204)
                          : Colors.grey.shade200.withValues(alpha: 204),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      endDate != null
                          ? '${endDate.day}/${endDate.month}/${endDate.year}'
                          : 'Lifetime',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Animated button reveal
            DelayedAnimation(
              delay: const Duration(milliseconds: 600),
              beginOffset: const Offset(0, 20),
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Continue Enjoying Premium'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      minimumSize: const Size(double.infinity, 54),
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    icon: Icon(
                      Icons.manage_accounts_outlined,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                      size: 20,
                    ),
                    label: Text(
                      'Manage Subscription',
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                      ),
                    ),
                    onPressed: () => _showCancelDialog(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Purchase review screen
  Widget _buildReviewPurchase(
      BuildContext context, SubscriptionProvider provider, bool isDarkMode) {
    final products = provider.products;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtextColor = isDarkMode ? Colors.grey[300] : Colors.grey[700];
    final cardColor =
        isDarkMode ? Color.fromARGB(255, 35, 35, 40) : Colors.white;
    final borderColor =
        isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200;

    final selectedProduct = _selectedPlanIndex == 2
        ? products.firstWhere(
            (p) => p.id.contains('annual'),
            orElse: () => products[0],
          )
        : products.firstWhere(
            (p) => p.id.contains('monthly'),
            orElse: () => products[0],
          );

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Review header
              Center(
                child: Text(
                  'Review Your Purchase',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              Center(
                child: Text(
                  'Confirm the details below before proceeding',
                  style: TextStyle(
                    fontSize: 16,
                    color: subtextColor,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Order summary section
              Text(
                'Order Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),

              // Subscription details card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                  boxShadow: isDarkMode
                      ? []
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 13),
                            blurRadius: 10,
                            spreadRadius: 0,
                          ),
                        ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withValues(alpha: 26),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.diamond_outlined,
                            color: AppTheme.primaryGreen,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'WealthWise Premium',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                _selectedPlanIndex == 2
                                    ? 'Annual subscription'
                                    : 'Monthly subscription',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: subtextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          selectedProduct.price,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    Divider(color: borderColor),
                    const SizedBox(height: 20),

                    // Order total
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        Text(
                          selectedProduct.price,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ],
                    ),

                    if (_selectedPlanIndex == 2)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    AppTheme.primaryGreen.withValues(alpha: 26),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'SAVE 35%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Billing information
              Text(
                'Payment Method',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),

              // Payment method card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                  boxShadow: isDarkMode
                      ? []
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 13),
                            blurRadius: 10,
                            spreadRadius: 0,
                          ),
                        ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.grey.shade800.withValues(alpha: 204)
                                : Colors.grey.shade200.withValues(alpha: 204),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.account_balance_wallet_outlined,
                            color: isDarkMode
                                ? Colors.grey.shade300
                                : Colors.grey.shade700,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'App Store / Play Store',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.check_circle,
                          color: AppTheme.primaryGreen,
                          size: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Terms and conditions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.grey.shade900.withValues(alpha: 204)
                      : Colors.grey.shade50.withValues(alpha: 204),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: subtextColor,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'By confirming, you agree to our Terms of Service and Privacy Policy. Your subscription will automatically renew at the end of the billing period.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: subtextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.autorenew,
                          size: 18,
                          color: subtextColor,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'You can cancel anytime through your account settings. Subscription will remain active until the end of your billing period.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: subtextColor,
                            ),
                          ),
                        ),
                      ],
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

  // Success state after purchase
  Widget _buildSuccessState(BuildContext context, bool isDarkMode) {
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtextColor = isDarkMode ? Colors.grey[300] : Colors.grey[700];
    final accentColor =
        isDarkMode ? AppTheme.accentMint : AppTheme.primaryGreen;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Checkmark animation
                DelayedAnimation(
                  delay: const Duration(milliseconds: 200),
                  beginOffset: const Offset(0, 20),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accentColor.withValues(alpha: 179),
                          accentColor,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 77),
                          blurRadius: 20,
                          spreadRadius: 5,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.check,
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Success text with animation
                DelayedAnimation(
                  delay: const Duration(milliseconds: 200),
                  beginOffset: const Offset(0, 20),
                  child: Text(
                    'Subscription Activated!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                // Subtext with animation
                DelayedAnimation(
                  delay: const Duration(milliseconds: 400),
                  beginOffset: const Offset(0, 20),
                  child: Text(
                    'Thank you for subscribing to WealthWise Premium. You now have access to all premium features.',
                    style: TextStyle(
                      fontSize: 16,
                      color: subtextColor,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 40),
                // Button with animation
                DelayedAnimation(
                  delay: const Duration(milliseconds: 600),
                  beginOffset: const Offset(0, 20),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.rocket_launch),
                    label: const Text('Explore Premium Features'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      minimumSize: const Size(double.infinity, 54),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Main subscription offers screen
  Widget _buildSubscriptionOffers(BuildContext context,
      SubscriptionProvider provider, bool isDarkMode, bool isSmallScreen) {
    // Use the products from subscription provider
    final products = provider.products;

    // Find the monthly and annual products
    final monthlyProduct = products.firstWhere(
      (p) => p.id.contains('monthly'),
      orElse: () => products[0],
    );

    final annualProduct = products.firstWhere(
      (p) => p.id.contains('annual'),
      orElse: () => products.length > 1 ? products[1] : products[0],
    );

    // Theme colors based on mode
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtextColor = isDarkMode ? Colors.grey[300] : Colors.grey[700];
    final borderColor =
        isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200;
    // Calculate monthly equivalent of annual plan for comparison
    final annualPriceNumeric = annualProduct.rawPrice;
    final monthlyPriceNumeric = monthlyProduct.rawPrice;
    final monthlyEquivalent = annualPriceNumeric / 12;
    final savingsPercentage =
        ((monthlyPriceNumeric - monthlyEquivalent) / monthlyPriceNumeric * 100)
            .round();

    return Stack(
      children: [
        // Close button positioned at top right for small screens only
        if (isSmallScreen)
          Positioned(
            top: 16,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (widget.onSkip != null) {
                    widget.onSkip!();
                  } else {
                    Navigator.of(context).pop();
                  }
                },
                borderRadius: BorderRadius.circular(50),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.grey.shade800.withValues(alpha: 204)
                        : Colors.grey.shade200.withValues(alpha: 204),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    color: isDarkMode ? Colors.white : Colors.black54,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),

        // Main content
        FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 24),

                  // Premium logo and branding
                  _buildAnimatedLogo(isDarkMode),

                  const SizedBox(height: 24),

                  // Premium heading
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Text(
                      'Unlock Your Financial Potential',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Premium description
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Text(
                      'Join thousands who have transformed their finances with WealthWise Premium',
                      style: TextStyle(
                        fontSize: 16,
                        color: subtextColor,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Subscription plan selector - redesigned
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding:
                              const EdgeInsets.only(left: 4.0, bottom: 12.0),
                          child: Text(
                            'Choose Your Plan',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),

                        // Plans cards
                        Row(
                          children: [
                            // Monthly plan
                            Expanded(
                              child: _buildPlanCard(
                                context,
                                index: 1,
                                title: 'Monthly',
                                price: monthlyProduct.price,
                                subtitle: 'Billed monthly',
                                isSelected: _selectedPlanIndex == 1,
                                isDarkMode: isDarkMode,
                                onTap: () {
                                  setState(() {
                                    _selectedPlanIndex = 1;
                                  });
                                  _playHapticFeedback();
                                },
                                features: const [
                                  'Premium features',
                                  'Cancel anytime',
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Annual plan
                            Expanded(
                              child: _buildPlanCard(
                                context,
                                index: 2,
                                title: 'Annual',
                                price: annualProduct.price,
                                subtitle: 'Billed annually',
                                isSelected: _selectedPlanIndex == 2,
                                isRecommended: true,
                                savingsPercentage: savingsPercentage,
                                isDarkMode: isDarkMode,
                                onTap: () {
                                  setState(() {
                                    _selectedPlanIndex = 2;
                                  });
                                  _playHapticFeedback();
                                },
                                features: [
                                  'Premium features',
                                  'Save $savingsPercentage% vs monthly',
                                  'Best value',
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Benefits section
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What\'s Included',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Benefits list
                        ..._buildBenefitItems(isDarkMode),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Full comparison table
                  _buildFeatureComparisonTable(context, isDarkMode),

                  const SizedBox(height: 40),

                  // Testimonial section
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.grey.shade900.withValues(alpha: 204)
                          : Colors.grey.shade50.withValues(alpha: 204),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: List.generate(
                            5,
                            (index) => Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '"WealthWise Premium helped me save \$5,200 in just 6 months. The advanced analytics and goal tracking made all the difference!"',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 16,
                            height: 1.5,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: isDarkMode
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade300,
                              child: Text(
                                'JS',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Jennifer S.',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: textColor,
                                  ),
                                ),
                                Text(
                                  'Premium member since 2022',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDarkMode
                                        ? Colors.grey[400]
                                        : Colors.grey[700],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Money-back guarantee
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 20,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 26),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.primaryGreen.withValues(alpha: 51),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withValues(alpha: 26),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.verified_user,
                            color: AppTheme.primaryGreen,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '30-Day Money-Back Guarantee',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Not satisfied? Get a full refund within 30 days',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode
                                      ? Colors.grey[400]
                                      : Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Continue button for large screens
                  if (!isSmallScreen)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ElevatedButton(
                        onPressed: _nextStep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          minimumSize: const Size(double.infinity, 54),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Legal information
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 8.0,
                    ),
                    child: Text(
                      'Payment will be charged to your account at confirmation of purchase. '
                      'Subscription automatically renews unless auto-renew is turned off at least 24 hours before the end of the current period. '
                      'Manage your subscriptions in your account settings.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                        height: 1.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Animated logo
  Widget _buildAnimatedLogo(bool isDarkMode) {
    final accentColor =
        isDarkMode ? AppTheme.accentMint : AppTheme.primaryGreen;

    return DelayedAnimation(
      delay: Duration.zero, // No delay for the initial logo
      duration: const Duration(milliseconds: 1200),
      curve: Curves.elasticOut,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              accentColor.withValues(alpha: 179),
              accentColor,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 77),
              blurRadius: 20,
              spreadRadius: 5,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Icon(
          Icons.diamond_outlined,
          size: 60,
          color: Colors.white,
        ),
      ),
    );
  }

  // Build plan card with better visual hierarchy
  Widget _buildPlanCard(
    BuildContext context, {
    required int index,
    required String title,
    required String price,
    required String subtitle,
    required bool isSelected,
    required bool isDarkMode,
    required VoidCallback onTap,
    required List<String> features,
    bool isRecommended = false,
    int? savingsPercentage,
  }) {
    final accentColor =
        isDarkMode ? AppTheme.accentMint : AppTheme.primaryGreen;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtextColor = isDarkMode ? Colors.grey[400] : Colors.grey[700];

    // Card styling based on selection and recommendation
    final cardColor = isSelected
        ? (isDarkMode
            ? accentColor.withValues(alpha: 38)
            : accentColor.withValues(alpha: 20))
        : (isDarkMode ? Colors.grey.shade900 : Colors.white);

    final borderColor = isSelected
        ? accentColor
        : (isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300);

    final borderWidth = isSelected ? 2.0 : 1.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: borderWidth,
          ),
          boxShadow: isSelected && !isDarkMode
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 51),
                    blurRadius: 8,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Stack(
          children: [
            // Recommended badge
            if (isRecommended)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'BEST VALUE',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // Card content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? accentColor : textColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        price.split(' ')[1], // Get the numerical part
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? accentColor : textColor,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        price.split(' ')[0], // Get the currency
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? accentColor : textColor,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: subtextColor,
                    ),
                  ),
                  if (savingsPercentage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'SAVE $savingsPercentage%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  ...features.map((feature) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: isSelected ? accentColor : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                feature,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: subtextColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 8),
                  if (isSelected)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 26),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          'Selected',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
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

  // Build benefit items
  List<Widget> _buildBenefitItems(bool isDarkMode) {
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtextColor = isDarkMode ? Colors.grey[300] : Colors.grey[700];
    final accentColor =
        isDarkMode ? AppTheme.accentMint : AppTheme.primaryGreen;

    final benefits = [
      {
        'icon': Icons.analytics_outlined,
        'title': 'Advanced Analytics',
        'description':
            'Deep insights into your spending patterns and financial health',
      },
      {
        'icon': Icons.savings_outlined,
        'title': 'Unlimited Savings Goals',
        'description':
            'Set as many savings targets as you need and track progress',
      },
      {
        'icon': Icons.category_outlined,
        'title': 'Custom Categories',
        'description': 'Create and customize your own spending categories',
      },
      {
        'icon': Icons.sync_outlined,
        'title': 'Auto-Sync Across Devices',
        'description': 'Your data seamlessly synced on all your devices',
      },
      {
        'icon': Icons.ad_units_outlined,
        'title': 'Ad-Free Experience',
        'description': 'Enjoy a clean, distraction-free interface',
      },
    ];

    return benefits.asMap().entries.map((entry) {
      final index = entry.key;
      final benefit = entry.value;

      // Use DelayedAnimation instead of Future.delayed
      return DelayedAnimation(
        delay: Duration(milliseconds: 100 * index),
        duration: const Duration(milliseconds: 500),
        beginOffset: const Offset(20, 0),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  benefit['icon'] as IconData,
                  color: accentColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      benefit['title'] as String,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      benefit['description'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        color: subtextColor,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  // Build feature comparison table
  Widget _buildFeatureComparisonTable(BuildContext context, bool isDarkMode) {
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final borderColor =
        isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200;
    final headerColor = isDarkMode ? Colors.grey.shade900 : Colors.grey.shade50;
    final accentColor =
        isDarkMode ? AppTheme.accentMint : AppTheme.primaryGreen;

    // Define features to compare
    final features = [
      {
        'name': 'Transaction History',
        'free': 'Last 30 days',
        'premium': 'Unlimited'
      },
      {
        'name': 'Budget Categories',
        'free': 'Basic (10)',
        'premium': 'Advanced (50+)'
      },
      {'name': 'Savings Goals', 'free': '1 Goal', 'premium': 'Unlimited'},
      {'name': 'Finance Reports', 'free': 'Basic', 'premium': 'Advanced'},
      {'name': 'Data Export', 'free': false, 'premium': true},
      {'name': 'Ad-Free Experience', 'free': false, 'premium': true},
      {'name': 'Custom Categories', 'free': false, 'premium': true},
      {'name': 'Cloud Backup', 'free': false, 'premium': true},
      {'name': 'Priority Support', 'free': false, 'premium': true},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(16),
        color: isDarkMode ? Colors.black : Colors.white,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              color: headerColor,
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Features',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'Free',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 26),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Premium',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Feature rows
          ...features.map((feature) => _buildFeatureRow(
                feature['name'] as String,
                feature['free'],
                feature['premium'],
                isDarkMode,
              )),
        ],
      ),
    );
  }

  // Build individual feature row
  Widget _buildFeatureRow(
    String feature,
    dynamic free,
    dynamic premium,
    bool isDarkMode,
  ) {
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final borderColor =
        isDarkMode ? Colors.grey.shade900 : Colors.grey.shade100;
    final accentColor =
        isDarkMode ? AppTheme.accentMint : AppTheme.primaryGreen;

    final isBooleanValue = free is bool;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              feature,
              style: TextStyle(
                fontSize: 14,
                color: textColor,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: isBooleanValue
                  ? Icon(
                      free ? Icons.check : Icons.close,
                      color: free ? Colors.green : Colors.red.shade300,
                      size: 20,
                    )
                  : Text(
                      free.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: textColor,
                      ),
                    ),
            ),
          ),
          Expanded(
            child: Center(
              child: isBooleanValue
                  ? Icon(
                      premium ? Icons.check : Icons.close,
                      color: premium ? accentColor : Colors.red.shade300,
                      size: 20,
                    )
                  : Text(
                      premium.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSubscriptionPurchase(BuildContext context) async {
    // Capture all context-dependent values before async operations
    final billingService = Provider.of<BillingService>(context, listen: false);
    final provider = Provider.of<SubscriptionProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Haptic feedback for better user experience
    HapticFeedback.mediumImpact();

    // Show loading indicator
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Processing your subscription...'),
        duration: Duration(seconds: 2),
      ),
    );

    // Get the appropriate product based on selection
    final products = provider.products;
    if (products.isEmpty) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Subscription products not available')),
        );
      }
      return;
    }

    ProductDetails selectedProduct;

    // Select the product based on index
    if (_selectedPlanIndex == 2) {
      // Annual
      selectedProduct = products.firstWhere(
        (p) => p.id.contains('annual'),
        orElse: () => products[0],
      );
    } else {
      // Monthly (default)
      selectedProduct = products.firstWhere(
        (p) => p.id.contains('monthly'),
        orElse: () => products[0],
      );
    }

    try {
      // Initiate purchase
      final success =
          await billingService.purchaseSubscription(selectedProduct);

      if (success) {
        // Subscription was successful (using our mock implementation in dev mode)
        if (mounted) {
          // Move to success screen
          setState(() {
            _currentStep = 2;
          });
          // Reset animation controller for success screen
          _animationController.reset();
          _animationController.forward();
        }
      } else {
        // Show error message
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text(
                  'Failed to process your subscription. Please try again.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      // Handle exceptions
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('An error occurred: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showCancelDialog(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final billingService = Provider.of<BillingService>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Dialog card styling
    final backgroundColor = isDarkMode ? Colors.grey.shade900 : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtextColor = isDarkMode ? Colors.grey[400] : Colors.grey[700];

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Cancel Subscription',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.red.shade900.withValues(alpha: 51)
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDarkMode ? Colors.red.shade800 : Colors.red.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: isDarkMode ? Colors.red.shade300 : Colors.red,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Are you sure you want to cancel your premium subscription?',
                      style: TextStyle(
                        color: isDarkMode
                            ? Colors.red.shade300
                            : Colors.red.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You\'ll continue to have access until the end of your current billing period.',
              style: TextStyle(
                color: subtextColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Premium benefits you\'ll lose:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            ...[
              'Unlimited transactions',
              'Advanced analytics',
              'Custom categories'
            ].map(
              (benefit) => Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.remove_circle_outline,
                      color: Colors.red.shade300,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      benefit,
                      style: TextStyle(
                        color: subtextColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(
              foregroundColor: subtextColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size(100, 44),
            ),
            child: const Text(
              'Keep Premium',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size(100, 44),
            ),
            onPressed: () async {
              // Haptic feedback
              HapticFeedback.mediumImpact();

              // Close dialog first
              Navigator.pop(dialogContext);

              // Show loading indicator
              scaffoldMessenger.showSnackBar(
                const SnackBar(
                  content: Text('Processing your request...'),
                  duration: Duration(seconds: 1),
                ),
              );

              // Cancel the subscription
              final success = await billingService.cancelSubscription();

              // Show result message
              if (!mounted) return; // Check if widget is still mounted

              if (success) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Your subscription has been cancelled'),
                    duration: Duration(seconds: 3),
                  ),
                );

                // Use a post-frame callback to safely navigate after async operation
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                });
              } else {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Failed to cancel subscription. Please try again later.'),
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
            child: const Text(
              'Cancel Premium',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
        actionsPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
