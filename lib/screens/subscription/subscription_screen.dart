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
  final bool showCloseButton = true;
  bool _initializing = true;
  static const Duration _loadingTimeout = Duration(seconds: 8);

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
      appBar: AppBar(
        title: const Text('WealthWise Premium'),
        centerTitle: true,
        backgroundColor: AppTheme.primaryGreen,
        elevation: 0,
        actions: showCloseButton
            ? [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ]
            : null,
      ),
      body: Consumer<SubscriptionProvider>(
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
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Debug info
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade50,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Debug Info:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text('isSubscribed: ${provider.isSubscribed}',
                            style: const TextStyle(fontSize: 12)),
                        Text(
                            'End date: ${provider.subscriptionEndDate?.toString() ?? 'N/A'}',
                            style: const TextStyle(fontSize: 12)),
                        Text(
                            'Products: ${Provider.of<BillingService>(context, listen: false).products.length}',
                            style: const TextStyle(fontSize: 12)),
                        const Text(
                            'Test mode enabled - purchases are simulated',
                            style: TextStyle(
                                fontSize: 11, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
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
                color: AppTheme.primaryGreen.withValues(alpha: 0.1),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionOffers(
      BuildContext context, SubscriptionProvider provider) {
    // Get the billing service from provider tree
    final billingService = Provider.of<BillingService>(context, listen: false);

    // Get the actual product details from the billing service
    final products = billingService.products;
    final hasRealProducts = products.isNotEmpty;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Icon(
                  Icons.workspace_premium,
                  size: 80,
                  color: AppTheme.primaryGreen,
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    'Upgrade to Premium',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryGreen,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    'Get unlimited access to all premium features',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 40),

                // Monthly subscription
                _buildSubscriptionCard(
                  context,
                  hasRealProducts
                      ? products.firstWhere(
                          (p) => p.id.contains('monthly'),
                          orElse: () => ProductDetails(
                            id: 'wealthwise_monthly_premium',
                            title: 'Monthly Premium',
                            description: 'Unlimited access for one month',
                            price: '\$4.99',
                            rawPrice: 4.99,
                            currencyCode: 'USD',
                          ),
                        )
                      : ProductDetails(
                          id: 'wealthwise_monthly_premium',
                          title: 'Monthly Premium',
                          description: 'Unlimited access for one month',
                          price: '\$4.99',
                          rawPrice: 4.99,
                          currencyCode: 'USD',
                        ),
                  [
                    'Unlimited transactions',
                    'Custom categories',
                    'Advanced reports',
                    'Multiple savings goals',
                    'Ad-free experience',
                    'Cloud backup',
                    'Priority support',
                  ],
                  'Most Popular',
                  Colors.blue,
                ),

                const SizedBox(height: 20),

                // Annual subscription
                _buildSubscriptionCard(
                  context,
                  hasRealProducts
                      ? products.firstWhere(
                          (p) => p.id.contains('annual'),
                          orElse: () => ProductDetails(
                            id: 'wealthwise_annual_premium',
                            title: 'Annual Premium',
                            description:
                                'Unlimited access for one year (58% discount)',
                            price: '\$29.99',
                            rawPrice: 29.99,
                            currencyCode: 'USD',
                          ),
                        )
                      : ProductDetails(
                          id: 'wealthwise_annual_premium',
                          title: 'Annual Premium',
                          description:
                              'Unlimited access for one year (58% discount)',
                          price: '\$29.99',
                          rawPrice: 29.99,
                          currencyCode: 'USD',
                        ),
                  [
                    'All Monthly Premium features',
                    'Save over 50% vs monthly plan',
                    'Financial planning tools',
                    'Premium budgeting tools',
                    'Export data in multiple formats',
                  ],
                  'Best Value',
                  Colors.indigo,
                ),

                const SizedBox(height: 40),

                // Features section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Premium Features',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
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

                const SizedBox(height: 40),

                // Legal information
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 8.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Legal Information',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Payment will be charged to your Google Play account at confirmation of purchase. '
                        'Subscription automatically renews unless auto-renew is turned off at least 24 hours before the end of the current period. '
                        'Manage your subscriptions in Google Play Store settings.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionCard(BuildContext context, ProductDetails product,
      List<String> features, String highlight, Color color) {
    final billingService = Provider.of<BillingService>(context, listen: false);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 24.0),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with price
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      product.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        highlight,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  product.price,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  product.description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Features list
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...features.map((feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: color,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(feature),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),

          // Subscribe button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () {
                // Show loading indicator
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Initiating purchase...')),
                );

                // Capture ScaffoldMessenger before async operation
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                // Use the real Google Play Billing to purchase with test mode enabled
                billingService
                    .buySubscription(product, testMode: true)
                    .then((_) {
                  // Show success message after purchase completes
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                          content:
                              Text('Subscription activated successfully!')),
                    );
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'Subscribe',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
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
          Icon(
            icon,
            color: AppTheme.primaryGreen,
            size: 24,
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
