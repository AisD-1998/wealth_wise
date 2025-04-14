import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wealth_wise/services/billing_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:wealth_wise/providers/subscription_provider.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  int _selectedPlanIndex = 0;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _initializeSubscription();
  }

  Future<void> _initializeSubscription() async {
    if (!mounted) return;

    setState(() {
      _initializing = true;
    });

    final billingService = Provider.of<BillingService>(context, listen: false);
    await billingService.initialize();

    if (mounted) {
      setState(() {
        _initializing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Management'),
        backgroundColor: theme.colorScheme.surface,
      ),
      body: Consumer<BillingService>(
        builder: (context, billingService, _) {
          if (_initializing || billingService.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Subscription status card
              Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            billingService.isSubscribed
                                ? Icons.verified
                                : Icons.info_outline,
                            color: billingService.isSubscribed
                                ? Colors.green
                                : Colors.orange,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Current Plan',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        billingService.isSubscribed ? 'Premium' : 'Free',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: billingService.isSubscribed
                              ? Colors.green
                              : Colors.grey[700],
                        ),
                      ),
                      if (billingService.isSubscribed &&
                          billingService.subscriptionEndDate != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Valid until: ${_formatDate(billingService.subscriptionEndDate!)}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      if (billingService.isSubscribed)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.cancel_outlined,
                              color: Colors.red),
                          label: const Text('Cancel Subscription'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                          ),
                          onPressed: () => _showCancelDialog(context),
                        )
                      else
                        Text(
                          'Upgrade to Premium for unlimited access and enhanced features.',
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Subscription options section (only shown if not subscribed)
              if (!billingService.isSubscribed) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    'Choose a Plan',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Plan selection cards
                _buildPlanSelectionCard(
                  context,
                  0,
                  'Free',
                  '0.00',
                  'Limited features',
                  [
                    'Up to 50 transactions per month',
                    'Basic expense categories',
                    'Simple reports and charts',
                    'Single savings goal',
                    'Ad-supported',
                  ],
                  Colors.grey,
                  billingService.isSubscribed,
                ),

                const SizedBox(height: 16),

                _buildPlanSelectionCard(
                  context,
                  1,
                  'Monthly Premium',
                  _getProductPrice(billingService.products, 'monthly'),
                  'Full access billed monthly',
                  [
                    'Unlimited transactions',
                    'Custom categories',
                    'Advanced financial reports',
                    'Multiple savings goals',
                    'Ad-free experience',
                    'Cloud backup',
                    'Priority support',
                  ],
                  Colors.blue,
                  billingService.isSubscribed,
                ),

                const SizedBox(height: 16),

                _buildPlanSelectionCard(
                  context,
                  2,
                  'Annual Premium',
                  _getProductPrice(billingService.products, 'annual'),
                  'Save 58% compared to monthly',
                  [
                    'All Monthly Premium features',
                    'Best value option',
                    'Financial planning tools',
                    'Export data in multiple formats',
                    'Premium budgeting tools',
                  ],
                  Colors.indigo,
                  billingService.isSubscribed,
                ),

                const SizedBox(height: 24),

                // Subscribe button
                ElevatedButton(
                  onPressed: _selectedPlanIndex == 0
                      ? null
                      : () =>
                          _handleSubscriptionPurchase(context, billingService),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _selectedPlanIndex == 0
                        ? 'Current Plan'
                        : 'Subscribe to ${_selectedPlanIndex == 1 ? "Monthly" : "Annual"} Premium',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlanSelectionCard(
    BuildContext context,
    int planIndex,
    String planName,
    String price,
    String description,
    List<String> features,
    Color accentColor,
    bool isCurrentlySubscribed,
  ) {
    final theme = Theme.of(context);
    final isCurrentPlan = isCurrentlySubscribed && planIndex > 0 ||
        planIndex == 0 && !isCurrentlySubscribed;

    return GestureDetector(
      onTap: isCurrentlySubscribed
          ? null
          : () {
              setState(() {
                _selectedPlanIndex = planIndex;
              });
            },
      child: Card(
        elevation: _selectedPlanIndex == planIndex ? 4 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: _selectedPlanIndex == planIndex
                ? accentColor
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    planName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                  if (isCurrentPlan)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(
                          alpha: (accentColor.a * 0.2).toDouble(),
                          red: accentColor.r.toDouble(),
                          green: accentColor.g.toDouble(),
                          blue: accentColor.b.toDouble(),
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: accentColor),
                      ),
                      child: Text(
                        'Current Plan',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    price,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (planIndex > 0)
                    Text(
                      planIndex == 1 ? '/ month' : '/ year',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              ...features.map((feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: accentColor,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            feature,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  String _getProductPrice(List<ProductDetails> products, String type) {
    if (products.isEmpty) {
      return type == 'monthly' ? '3.99' : '19.99';
    }

    final product = products.firstWhere(
      (p) => p.id.contains(type),
      orElse: () => type == 'monthly'
          ? ProductDetails(
              id: 'wealthwise_monthly',
              title: 'Monthly Premium',
              description: 'Unlimited access for one month',
              price: '3.99',
              rawPrice: 3.99,
              currencyCode: 'USD',
            )
          : ProductDetails(
              id: 'wealthwise_annual',
              title: 'Annual Premium',
              description: 'Unlimited access for one year (58% discount)',
              price: '19.99',
              rawPrice: 19.99,
              currencyCode: 'USD',
            ),
    );

    return product.price;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
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

  void _handleSubscriptionPurchase(
      BuildContext context, BillingService billingService) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final provider = Provider.of<SubscriptionProvider>(context, listen: false);

    // Show loading indicator
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Processing your subscription...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      // Get the appropriate mock plan ID based on selection
      String planId =
          _selectedPlanIndex == 2 ? 'wealthwise_annual' : 'wealthwise_monthly';

      // Call the mock purchase process
      final success = await billingService.processPurchase(planId);

      if (success) {
        // Also update the provider's subscription status for UI updates
        await provider.setSubscriptionStatus(
            true,
            _selectedPlanIndex == 2
                ? DateTime.now().add(const Duration(days: 365))
                : DateTime.now().add(const Duration(days: 30)));

        // Reload provider and billing service state to update UI globally
        await provider.initialize();
        await billingService.initialize();

        // Force UI refresh
        setState(() {});

        // Subscription was successful - show success
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Subscription successful!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
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
}
