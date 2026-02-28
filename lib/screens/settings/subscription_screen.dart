import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'package:wealth_wise/constants/subscription_constants.dart';
import 'package:wealth_wise/providers/subscription_provider.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  static const _kCurrentPlan = 'Current Plan';

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

    final provider = Provider.of<SubscriptionProvider>(context, listen: false);
    await provider.initialize();

    if (mounted) {
      setState(() {
        _initializing = false;
      });
    }
  }

  Widget _buildCurrentPlanCard(
    ThemeData theme, SubscriptionProvider provider) {
    return Card(
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
                  provider.isSubscribed ? Icons.verified : Icons.info_outline,
                  color: provider.isSubscribed ? Colors.green : Colors.orange,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  _kCurrentPlan,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              provider.isSubscribed ? 'Premium' : 'Free',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: provider.isSubscribed ? Colors.green : Colors.grey[700],
              ),
            ),
            if (provider.isSubscribed &&
                provider.subscriptionEndDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Valid until: ${_formatDate(provider.subscriptionEndDate!)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            if (provider.isSubscribed)
              OutlinedButton.icon(
                icon: const Icon(Icons.cancel_outlined, color: Colors.red),
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
                style: TextStyle(color: Colors.grey[600]),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPlanOptions(
      ThemeData theme, SubscriptionProvider provider) {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Text(
          'Choose a Plan',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      _buildPlanSelectionCard(
        0, 'Free', '0.00', 'Limited features',
        [
          'Up to 50 transactions per month',
          'Basic expense categories',
          'Simple reports and charts',
          'Single savings goal',
          'Ad-supported',
        ],
        Colors.grey,
      ),
      const SizedBox(height: 16),
      _buildPlanSelectionCard(
        1, 'Monthly Premium',
        _getProductPrice(provider, SubscriptionConstants.monthlyProductId),
        'Full access billed monthly',
        [
          'Unlimited transactions',
          'Custom categories',
          'Advanced financial reports',
          'Multiple savings goals',
          'Ad-free experience',
          'Sync across devices',
          'Priority support',
        ],
        Colors.blue,
      ),
      const SizedBox(height: 16),
      _buildPlanSelectionCard(
        2, 'Annual Premium',
        _getProductPrice(provider, SubscriptionConstants.annualProductId),
        'Save ${SubscriptionConstants.annualDiscountLabel} compared to monthly',
        [
          'All Monthly Premium features',
          'Best value option',
          'Financial planning tools',
          'Export data in multiple formats',
          'Premium budgeting tools',
        ],
        Colors.indigo,
      ),
      const SizedBox(height: 24),
      _buildSubscribeButton(theme, provider),
      const SizedBox(height: 12),
      _buildRestorePurchasesButton(provider),
    ];
  }

  Widget _buildSubscribeButton(
      ThemeData theme, SubscriptionProvider provider) {
    return ElevatedButton(
      onPressed: _selectedPlanIndex == 0
          ? null
          : () => _handleSubscriptionPurchase(context, provider),
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
        _subscribeButtonLabel(),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildRestorePurchasesButton(SubscriptionProvider provider) {
    return Center(
      child: TextButton(
        onPressed: () => _handleRestorePurchases(context, provider),
        child: Text(
          'Restore Purchases',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Management'),
        backgroundColor: theme.colorScheme.surface,
      ),
      body: Consumer<SubscriptionProvider>(
        builder: (context, provider, _) {
          if (_initializing || provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildCurrentPlanCard(theme, provider),
              if (!provider.isSubscribed) ..._buildPlanOptions(theme, provider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlanSelectionCard(
    int planIndex,
    String planName,
    String price,
    String description,
    List<String> features,
    Color accentColor,
  ) {
    final theme = Theme.of(context);
    final isCurrentlySubscribed =
        Provider.of<SubscriptionProvider>(context, listen: false).isSubscribed;
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
                        _kCurrentPlan,
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

  String _subscribeButtonLabel() {
    if (_selectedPlanIndex == 0) {
      return _kCurrentPlan;
    }
    final planName = _selectedPlanIndex == 1 ? 'Monthly' : 'Annual';
    return 'Subscribe to $planName Premium';
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showCancelDialog(BuildContext context) {
    final provider = Provider.of<SubscriptionProvider>(context, listen: false);
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
              'You will be redirected to your device\'s subscription management page to cancel.',
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

              // Open platform subscription management (Play Store / App Store)
              try {
                await provider.openSubscriptionManagement();
              } catch (e) {
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(
                          'Could not open subscription management: $e'),
                    ),
                  );
                }
              }
            },
            child: const Text('Manage Subscription'),
          ),
        ],
      ),
    );
  }

  void _handleSubscriptionPurchase(
      BuildContext context, SubscriptionProvider provider) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

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

  void _handleRestorePurchases(
      BuildContext context, SubscriptionProvider provider) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

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
            backgroundColor: provider.isSubscribed ? Colors.green : null,
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
