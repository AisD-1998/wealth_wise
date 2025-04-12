import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wealth_wise/providers/subscription_provider.dart';
import 'package:wealth_wise/theme/app_theme.dart';
import 'package:wealth_wise/widgets/loading_indicator.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:wealth_wise/services/billing_service.dart';

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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Consumer<SubscriptionProvider>(
          builder: (context, provider, _) {
            // Show loading only during first initialization
            if (_initializing || provider.isLoading) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const LoadingIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Loading subscription options...',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Handle errors or no products available
            if (provider.errorMessage != null || provider.products.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        provider.errorMessage ??
                            'Failed to load subscription options',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _initializeSubscription,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text('Retry'),
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
                        child: const Text('Skip for now'),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (provider.isSubscribed) {
              return _buildActiveSubscription(context, provider);
            }

            return _buildSubscriptionOffers(context, provider);
          },
        ),
      ),
      bottomNavigationBar: Consumer<SubscriptionProvider>(
        builder: (context, provider, _) {
          if (!_initializing &&
              !provider.isLoading &&
              !provider.isSubscribed &&
              provider.errorMessage == null) {
            return Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 13),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Skip button
                  TextButton(
                    onPressed: () {
                      if (widget.onSkip != null) {
                        widget.onSkip!();
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                    child: const Text(
                      'Skip for now',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildActiveSubscription(
      BuildContext context, SubscriptionProvider provider) {
    final endDate = provider.subscriptionEndDate;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 26),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.verified,
                size: 80,
                color: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'You\'re a Premium Member!',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGreen,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Your subscription is active until:',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              endDate != null
                  ? '${endDate.day}/${endDate.month}/${endDate.year}'
                  : 'Lifetime',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.check_circle),
              label: const Text('Continue Enjoying Premium'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              icon: const Icon(Icons.cancel_outlined, color: Colors.red),
              label: const Text(
                'Cancel Subscription',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () => _showCancelDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionOffers(
      BuildContext context, SubscriptionProvider provider) {
    // Use the products from subscription provider
    final products = provider.products;

    // Ensure we have at least 2 products
    if (products.length < 2) {
      return Center(
        child: Text(
          'Subscription products not available',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }

    // Find the monthly and annual products
    final monthlyProduct = products.firstWhere(
      (p) => p.id.contains('monthly'),
      orElse: () => products[0],
    );

    final annualProduct = products.firstWhere(
      (p) => p.id.contains('annual'),
      orElse: () => products.length > 1 ? products[1] : products[0],
    );

    return Stack(
      children: [
        // Close button positioned at top right
        Positioned(
          top: 16,
          right: 16,
          child: InkWell(
            onTap: () {
              if (widget.onSkip != null) {
                widget.onSkip!();
              } else {
                Navigator.of(context).pop();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 40),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.black54, size: 24),
            ),
          ),
        ),

        // Main content
        SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 50),

              // Premium logo and branding
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryGreen,
                        AppTheme.accentMint,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: AppTheme.primaryGreen.withValues(alpha: 50),
                          blurRadius: 20,
                          spreadRadius: 1,
                          offset: const Offset(0, 10))
                    ]),
                child: const Icon(
                  Icons.workspace_premium,
                  size: 70,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 30),

              // Premium heading
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  'Unlock WealthWise Premium',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 12),

              // Premium description
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  'Take control of your finances with unlimited features and no ads',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.black54,
                        height: 1.4,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 40),

              // Compare plans section
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Compare Plans',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                    ),
                    const SizedBox(height: 20),

                    // Subscription plan selector
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                        color: Colors.white,
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            // Monthly option
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedPlanIndex = 1;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: _selectedPlanIndex == 1
                                        ? AppTheme.primaryGreen
                                            .withValues(alpha: 26)
                                        : Colors.transparent,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(15),
                                      bottomLeft: Radius.circular(15),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        'Monthly',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: _selectedPlanIndex == 1
                                              ? AppTheme.primaryGreen
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        monthlyProduct.price,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 18,
                                          color: _selectedPlanIndex == 1
                                              ? AppTheme.primaryGreen
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'per month',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Divider
                            Container(
                              width: 1,
                              color: Colors.grey.shade300,
                            ),
                            // Annual option
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedPlanIndex = 2;
                                  });
                                },
                                child: Stack(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: _selectedPlanIndex == 2
                                            ? AppTheme.primaryGreen
                                                .withValues(alpha: 26)
                                            : Colors.transparent,
                                        borderRadius: const BorderRadius.only(
                                          topRight: Radius.circular(15),
                                          bottomRight: Radius.circular(15),
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            'Annual',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: _selectedPlanIndex == 2
                                                  ? AppTheme.primaryGreen
                                                  : Colors.grey.shade700,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            annualProduct.price,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 18,
                                              color: _selectedPlanIndex == 2
                                                  ? AppTheme.primaryGreen
                                                  : Colors.grey.shade700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'per year',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade600,
                                          borderRadius: const BorderRadius.only(
                                            bottomLeft: Radius.circular(8),
                                            topRight: Radius.circular(15),
                                          ),
                                        ),
                                        child: const Text(
                                          'SAVE 58%',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Subscribe button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ElevatedButton(
                  onPressed: () => _handleSubscriptionPurchase(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 54),
                    elevation: 3,
                    shadowColor: AppTheme.primaryGreen.withValues(alpha: 100),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Subscribe ${_selectedPlanIndex == 1 ? "Monthly" : "Annually"}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Features section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Premium Features',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                      ),
                      const SizedBox(height: 16),
                      _buildFeatureItem(
                          'Unlimited Transactions', Icons.receipt_long),
                      _buildFeatureItem('Ad-Free Experience', Icons.block),
                      _buildFeatureItem('Advanced Analytics', Icons.analytics),
                      _buildFeatureItem('Multiple Savings Goals', Icons.flag),
                      _buildFeatureItem('Cloud Backup', Icons.cloud_upload),
                      _buildFeatureItem(
                          'Priority Support', Icons.support_agent),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Legal information
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 8.0,
                ),
                child: Text(
                  'Payment will be charged to your account at confirmation of purchase. '
                  'Subscription automatically renews unless auto-renew is turned off at least 24 hours before the end of the current period. '
                  'Manage your subscriptions in App Store settings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    height: 1.5,
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  void _handleSubscriptionPurchase(BuildContext context) async {
    // Capture all context-dependent values before async operations
    final billingService = Provider.of<BillingService>(context, listen: false);
    final provider = Provider.of<SubscriptionProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // Show loading indicator
    scaffoldMessenger.showSnackBar(
      const SnackBar(content: Text('Processing your subscription...')),
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

    // Initiate purchase
    final success = await billingService.purchaseSubscription(selectedProduct);

    if (success) {
      // Subscription was successful (using our mock implementation in dev mode)
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Subscription activated successfully!')),
        );

        // Close this screen after a short delay
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            navigator.pop();
          }
        });
      }
    } else {
      // Show error message
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
              content: Text(
                  'Failed to process your subscription. Please try again later.')),
        );
      }
    }
  }

  void _showCancelDialog(BuildContext context) {
    final billingService = Provider.of<BillingService>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel Subscription'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to cancel your subscription?'),
            SizedBox(height: 16),
            Text(
              'You\'ll continue to have access until the end of your current billing period.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Keep Subscription'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);

              // Cancel the subscription
              final success = await billingService.cancelSubscription();

              // Show result message
              if (mounted) {
                if (success) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Your subscription has been cancelled'),
                    ),
                  );
                } else {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Failed to cancel subscription. Please try again later.'),
                    ),
                  );
                }
              }
            },
            child: const Text('Cancel Subscription'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 26),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: AppTheme.primaryGreen,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
