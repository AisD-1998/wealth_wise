import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:wealth_wise/constants/subscription_constants.dart';
import 'package:wealth_wise/providers/subscription_provider.dart';
import 'package:wealth_wise/theme/app_theme.dart';

// Animation widget for delayed entrance animation
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
      begin: widget.beginOffset ?? const Offset(0, 0.2),
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

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _initializing = true;
  static const Duration _loadingTimeout = Duration(seconds: 8);
  int _selectedPlanIndex = 1; // Default to monthly (index 1)

  @override
  void initState() {
    super.initState();
    _initializeSubscription();

    // Setup timeout to exit loading state if it takes too long
    Future.delayed(_loadingTimeout, () {
      if (mounted && _initializing) {
        setState(() {
          _initializing = false;
        });

        final provider =
            Provider.of<SubscriptionProvider>(context, listen: false);
        provider.forceExitLoadingState();
      }
    });
  }

  // Initialize subscription provider
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

  // Haptic feedback for better user experience
  void _playHapticFeedback() {
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtextColor =
        isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;
    final backgroundColor = isDarkMode ? Colors.black : Colors.white;

    // Check if the screen width allows side-by-side cards
    final screenWidth = MediaQuery.of(context).size.width;
    final canShowSideBySide = screenWidth > 600;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: textColor,
          ),
          onPressed: () {
            if (widget.onSkip != null) {
              widget.onSkip!();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
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

            // Show subscription plans
            return _buildSubscriptionContent(
                context, provider, isDarkMode, canShowSideBySide);
          },
        ),
      ),
    );
  }

  // Loading state widget
  Widget _buildLoadingState(BuildContext context, bool isDarkMode) {
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
          ),
          const SizedBox(height: 20),
          Text(
            'Loading subscription options...',
            style: TextStyle(
              color: textColor,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // Error state widget
  Widget _buildErrorState(
      BuildContext context, SubscriptionProvider provider, bool isDarkMode) {
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 20),
            Text(
              'Subscription Service Unavailable',
              style: TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              provider.errorMessage ??
                  'Unable to load subscription options. Please try again later.',
              style: TextStyle(
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _initializeSubscription(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Main subscription content
  Widget _buildSubscriptionContent(BuildContext context,
      SubscriptionProvider provider, bool isDarkMode, bool canShowSideBySide) {
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtextColor =
        isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;
    final cardColor = isDarkMode ? Colors.grey.shade900 : Colors.white;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 24),

        // Header Section
        Text(
          'Premium Subscription',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'finances',
          style: TextStyle(
            fontSize: 18,
            color: subtextColor,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Subscription Plans
        canShowSideBySide
            ? _buildSideBySidePlans(
                provider, isDarkMode, textColor, subtextColor, cardColor)
            : _buildStackedPlans(
                provider, isDarkMode, textColor, subtextColor, cardColor),

        const SizedBox(height: 30),

        // Features List
        Text(
          'Premium Features',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 16),

        // Feature list items
        ..._buildFeaturesList(isDarkMode, textColor, subtextColor),

        const SizedBox(height: 40),

        // Subscribe Button
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          child: ElevatedButton(
            onPressed: () => _handleSubscriptionPurchase(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Subscribe',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // Maybe Later Button
        TextButton(
          onPressed: () {
            if (widget.onSkip != null) {
              widget.onSkip!();
            } else {
              Navigator.of(context).pop();
            }
          },
          style: TextButton.styleFrom(
            foregroundColor: subtextColor,
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
          child: const Text(
            'Maybe Later',
            style: TextStyle(
              fontSize: 16,
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Restore Purchases Button
        TextButton(
          onPressed: () => _handleRestorePurchases(context),
          style: TextButton.styleFrom(
            foregroundColor: subtextColor,
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
          child: const Text(
            'Restore Purchases',
            style: TextStyle(
              fontSize: 14,
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Legal text at the bottom
        Text(
          'Payment will be charged to your account at confirmation of purchase. '
          'Subscription automatically renews unless auto-renew is turned off at least 24 hours before the end of the current period.',
          style: TextStyle(
            fontSize: 12,
            color: subtextColor,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  String _getProductPrice(SubscriptionProvider provider, String productId) {
    try {
      return provider.products.firstWhere((p) => p.id == productId).price;
    } catch (_) {
      return productId.contains('annual')
          ? SubscriptionConstants.annualFallbackPriceDisplay
          : SubscriptionConstants.monthlyFallbackPriceDisplay;
    }
  }

  // Side by side subscription plans (for larger screens)
  Widget _buildSideBySidePlans(SubscriptionProvider provider, bool isDarkMode,
      Color textColor, Color subtextColor, Color cardColor) {
    final monthlyPrice = _getProductPrice(provider, SubscriptionConstants.monthlyProductId);
    final annualPrice = _getProductPrice(provider, SubscriptionConstants.annualProductId);

    return Row(
      children: [
        Expanded(
          child: _buildPlanCard(
            title: 'Monthly',
            price: monthlyPrice,
            subtitle: 'per month',
            isSelected: _selectedPlanIndex == 1,
            features: ['Basic features', 'No ads'],
            isDarkMode: isDarkMode,
            textColor: textColor,
            subtextColor: subtextColor,
            cardColor: cardColor,
            onTap: () {
              setState(() {
                _selectedPlanIndex = 1;
              });
              _playHapticFeedback();
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildPlanCard(
            title: 'Annual',
            price: annualPrice,
            subtitle: 'per year',
            isSelected: _selectedPlanIndex == 2,
            features: ['All features', 'Priority support'],
            isDarkMode: isDarkMode,
            textColor: textColor,
            subtextColor: subtextColor,
            cardColor: cardColor,
            onTap: () {
              setState(() {
                _selectedPlanIndex = 2;
              });
              _playHapticFeedback();
            },
            discount: SubscriptionConstants.annualDiscountLabel,
          ),
        ),
      ],
    );
  }

  // Stacked subscription plans (for smaller screens)
  Widget _buildStackedPlans(SubscriptionProvider provider, bool isDarkMode,
      Color textColor, Color subtextColor, Color cardColor) {
    final monthlyPrice = _getProductPrice(provider, SubscriptionConstants.monthlyProductId);
    final annualPrice = _getProductPrice(provider, SubscriptionConstants.annualProductId);

    return Column(
      children: [
        _buildPlanCard(
          title: 'Monthly',
          price: monthlyPrice,
          subtitle: 'per month',
          isSelected: _selectedPlanIndex == 1,
          features: [],
          isDarkMode: isDarkMode,
          textColor: textColor,
          subtextColor: subtextColor,
          cardColor: cardColor,
          onTap: () {
            setState(() {
              _selectedPlanIndex = 1;
            });
            _playHapticFeedback();
          },
        ),
        const SizedBox(height: 16),
        _buildPlanCard(
          title: 'Annual',
          price: annualPrice,
          subtitle: 'per year',
          isSelected: _selectedPlanIndex == 2,
          features: [],
          isDarkMode: isDarkMode,
          textColor: textColor,
          subtextColor: subtextColor,
          cardColor: cardColor,
          onTap: () {
            setState(() {
              _selectedPlanIndex = 2;
            });
            _playHapticFeedback();
          },
          discount: SubscriptionConstants.annualDiscountLabel,
        ),
      ],
    );
  }

  // Individual subscription plan card
  Widget _buildPlanCard({
    required String title,
    required String price,
    required String subtitle,
    required bool isSelected,
    required List<String> features,
    required bool isDarkMode,
    required Color textColor,
    required Color subtextColor,
    required Color cardColor,
    required VoidCallback onTap,
    String? discount,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryGreen
                : isDarkMode
                    ? Colors.grey.shade800
                    : Colors.grey.shade300,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                if (isSelected)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 51),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 14,
                          color: AppTheme.primaryGreen,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Selected',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              price,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppTheme.primaryGreen : textColor,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: subtextColor,
              ),
            ),
            if (discount != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  discount,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // Build the features list
  List<Widget> _buildFeaturesList(
      bool isDarkMode, Color textColor, Color subtextColor) {
    final features = [
      'Unlimited transaction history',
      'Advanced analytics',
      'Unlimited savings goals',
      'Custom categories',
      'Ad-free experience',
    ];

    return features.map((feature) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryGreen.withValues(alpha: 26),
              ),
              child: Icon(
                Icons.check_circle,
                color: AppTheme.primaryGreen,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              feature,
              style: TextStyle(
                fontSize: 16,
                color: textColor,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  // Handle subscription purchase via real IAP
  void _handleSubscriptionPurchase(BuildContext context) async {
    final provider = Provider.of<SubscriptionProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    HapticFeedback.mediumImpact();

    // Determine which product ID to purchase
    final productId = _selectedPlanIndex == 2
        ? SubscriptionConstants.annualProductId
        : SubscriptionConstants.monthlyProductId;

    // Find the matching ProductDetails from the store
    final product = provider.products.cast<ProductDetails?>().firstWhere(
          (p) => p!.id == productId,
          orElse: () => null,
        );

    if (product == null) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Product not available. Please try again later.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Opening store...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      // Initiate real IAP purchase — result delivered via purchase stream
      await provider.buySubscription(product);
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Purchase failed: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Restore previous purchases
  void _handleRestorePurchases(BuildContext context) async {
    final provider = Provider.of<SubscriptionProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    HapticFeedback.mediumImpact();

    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Restoring purchases...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      await provider.restorePurchases();
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              provider.isSubscribed
                  ? 'Subscription restored successfully!'
                  : 'No previous subscription found.',
            ),
            backgroundColor:
                provider.isSubscribed ? AppTheme.primaryGreen : null,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Restore failed: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

// Add this new class for the gradient border effect
class GradientBorderPainter extends CustomPainter {
  final Gradient gradient;
  final double borderRadius;
  final double strokeWidth;

  GradientBorderPainter({
    required this.gradient,
    required this.borderRadius,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rRect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = gradient.createShader(rect);

    canvas.drawRRect(rRect, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
