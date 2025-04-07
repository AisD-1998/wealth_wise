import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wealth_wise/providers/subscription_provider.dart';
import 'package:wealth_wise/services/billing_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/intl.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  int _selectedPlanIndex = 0;

  final List<Map<String, dynamic>> _plans = [
    {
      'name': 'Free',
      'price': 0.0,
      'period': 'forever',
      'features': [
        'Up to 50 transactions per month',
        'Basic expense categories',
        'Simple reports and charts',
        'Single savings goal',
        'Ad-supported',
      ],
      'color': Colors.grey,
      'button': 'Current Plan',
    },
    {
      'name': 'Premium',
      'price': 4.99,
      'period': 'month',
      'features': [
        'Unlimited transactions',
        'Custom categories',
        'Advanced financial reports',
        'Multiple savings goals',
        'Ad-free experience',
        'Cloud backup',
        '24/7 Priority support',
      ],
      'color': Colors.blue,
      'button': 'Upgrade Now',
    },
    {
      'name': 'Premium Annual',
      'price': 39.99,
      'period': 'year',
      'features': [
        'All Premium features',
        'Save 33% vs monthly plan',
        'Financial planning tools',
        'Premium budgeting tools',
        'Export data in multiple formats',
      ],
      'color': Colors.indigo,
      'button': 'Best Value',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Management'),
        backgroundColor: theme.colorScheme.surface,
      ),
      body: Consumer<SubscriptionProvider>(
        builder: (context, subscriptionProvider, _) {
          if (subscriptionProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Debug info section
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade50,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Debug Info:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('isSubscribed: ${subscriptionProvider.isSubscribed}'),
                    Text(
                        'End date: ${subscriptionProvider.subscriptionEndDate?.toString() ?? 'N/A'}'),
                    Text(
                        'Products loaded: ${Provider.of<BillingService>(context, listen: false).products.length}'),
                    const SizedBox(height: 8),
                    const Text(
                        'Note: Currently in test mode, purchases are simulated',
                        style: TextStyle(
                            fontStyle: FontStyle.italic, fontSize: 12)),
                  ],
                ),
              ),

              // Current subscription status
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: subscriptionProvider.isSubscribed
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Plan',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: subscriptionProvider.isSubscribed
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subscriptionProvider.isSubscribed ? 'Premium' : 'Free',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: subscriptionProvider.isSubscribed
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (subscriptionProvider.isSubscribed &&
                        subscriptionProvider.subscriptionEndDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          'Valid until ${DateFormat.yMMMMd().format(subscriptionProvider.subscriptionEndDate!)}',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer
                                .withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Plans section
              Text(
                'Available Plans',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              // Plan cards
              ...List.generate(_plans.length, (index) {
                final plan = _plans[index];
                final bool isCurrentPlan =
                    (index == 0 && !subscriptionProvider.isSubscribed) ||
                        (index > 0 && subscriptionProvider.isSubscribed);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPlanIndex = index;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _selectedPlanIndex == index
                            ? plan['color']
                            : Colors.grey.shade300,
                        width: _selectedPlanIndex == index ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Plan header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: plan['color'].withValues(alpha: 0.1),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(11),
                              topRight: Radius.circular(11),
                            ),
                          ),
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    plan['name'],
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: plan['color'],
                                    ),
                                  ),
                                  if (plan['price'] > 0)
                                    Text(
                                      '\$${plan['price']}/${plan['period']}',
                                      style:
                                          theme.textTheme.titleSmall?.copyWith(
                                        color: plan['color'],
                                      ),
                                    ),
                                  if (plan['price'] == 0)
                                    Text(
                                      'Free ${plan['period']}',
                                      style:
                                          theme.textTheme.titleSmall?.copyWith(
                                        color: plan['color'],
                                      ),
                                    ),
                                ],
                              ),
                              const Spacer(),
                              Radio(
                                value: index,
                                groupValue: _selectedPlanIndex,
                                activeColor: plan['color'],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedPlanIndex = value!;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),

                        // Plan features
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Features:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              ...List.generate(
                                plan['features'].length,
                                (i) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline,
                                        color: plan['color'],
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(plan['features'][i]),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (index == _selectedPlanIndex)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: ElevatedButton(
                              onPressed: isCurrentPlan
                                  ? null
                                  : () => _processPurchase(context, index),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: plan['color'],
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    plan['color'].withValues(alpha: 0.3),
                              ),
                              child: Text(
                                isCurrentPlan ? 'Current Plan' : plan['button'],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 16),

              // Billing history
              if (subscriptionProvider.isSubscribed)
                Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Billing History',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      // In a real app, this would fetch real billing history
                      // For now, just showing a placeholder
                      ListTile(
                        title: const Text('Premium Subscription'),
                        subtitle: const Text('Payment successful'),
                        trailing: Text(
                          '\$4.99',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Invoice downloaded'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.download),
                          label: const Text('Download Invoices'),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Payment information
              if (subscriptionProvider.isSubscribed)
                Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Subscription Details',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      // Show Google Play subscription details instead of credit card
                      ListTile(
                        leading: const Icon(Icons.subscriptions),
                        title: const Text('Google Play Subscription'),
                        subtitle: const Text('Managed through Google Play'),
                        trailing: IconButton(
                          icon: const Icon(Icons.open_in_new),
                          onPressed: () {
                            // Direct users to manage subscriptions in Google Play
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Open Google Play Store to manage your subscription'),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 32),

              // Plan comparison
              Text(
                'Plan Comparison',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              // Plan comparison table
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 20,
                  columns: const [
                    DataColumn(label: Text('Feature')),
                    DataColumn(label: Text('Free')),
                    DataColumn(label: Text('Premium')),
                  ],
                  rows: [
                    const DataRow(cells: [
                      DataCell(Text('Transactions')),
                      DataCell(Text('50/month')),
                      DataCell(Text('Unlimited')),
                    ]),
                    const DataRow(cells: [
                      DataCell(Text('Categories')),
                      DataCell(Text('Basic')),
                      DataCell(Text('Custom')),
                    ]),
                    const DataRow(cells: [
                      DataCell(Text('Reports')),
                      DataCell(Text('Basic')),
                      DataCell(Text('Advanced')),
                    ]),
                    const DataRow(cells: [
                      DataCell(Text('Savings Goals')),
                      DataCell(Text('1')),
                      DataCell(Text('Unlimited')),
                    ]),
                    const DataRow(cells: [
                      DataCell(Text('Ads')),
                      DataCell(Text('Yes')),
                      DataCell(Text('No')),
                    ]),
                    const DataRow(cells: [
                      DataCell(Text('Support')),
                      DataCell(Text('Email')),
                      DataCell(Text('Priority')),
                    ]),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Legal information
              Text(
                'Legal Information',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Subscriptions will be charged to your Google Play account at confirmation of purchase. Subscriptions automatically renew unless auto-renew is turned off at least 24 hours before the end of the current period. You can manage your subscriptions in your Google Play account settings after purchase.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),

              if (subscriptionProvider.isSubscribed)
                Padding(
                  padding: const EdgeInsets.only(top: 24.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _showCancelDialog(context),
                      child: const Text('Cancel Subscription'),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _processPurchase(BuildContext context, int planIndex) {
    final billingService = Provider.of<BillingService>(context, listen: false);

    // Show dialog to confirm purchase
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Purchase ${_plans[planIndex]['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'You are about to subscribe to our ${_plans[planIndex]['name']} plan.'),
            const SizedBox(height: 8),
            Text(
              'Price: \$${_plans[planIndex]['price']}/${_plans[planIndex]['period']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'In production, this would initiate a real Google Play purchase.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);

              // Show loading indicator
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Initiating purchase...')),
              );

              // Capture scaffold messenger before async gap
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              // Use the appropriate product based on selected plan
              if (billingService.products.isNotEmpty) {
                late ProductDetails product;

                // Select the correct product based on plan index
                if (planIndex == 1) {
                  // Monthly
                  product = billingService.products.firstWhere(
                      (p) => p.id.contains('monthly'),
                      orElse: () => billingService.products.first);
                } else if (planIndex == 2) {
                  // Annual
                  product = billingService.products.firstWhere(
                      (p) => p.id.contains('annual'),
                      orElse: () => billingService.products.last);
                } else {
                  // Free plan - no purchase needed
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('You are now on the free plan')),
                  );
                  return;
                }

                // Start the purchase process with test mode enabled
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
              } else {
                // Fallback for when products aren't available
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Subscription products not available')),
                );
              }
            },
            child: const Text('Subscribe'),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    final billingService = Provider.of<BillingService>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Subscription'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () {
              Navigator.pop(context);

              // Capture scaffold messenger before async operation
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              billingService.cancelSubscription().then((_) {
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Your subscription has been cancelled'),
                    ),
                  );
                }
              });
            },
            child: const Text('Cancel Subscription'),
          ),
        ],
      ),
    );
  }
}
