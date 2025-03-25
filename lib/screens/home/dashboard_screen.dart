import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:wealth_wise/models/transaction.dart';
import 'package:wealth_wise/providers/auth_provider.dart';
import 'package:wealth_wise/providers/finance_provider.dart';
import 'package:wealth_wise/utils/ui_helpers.dart';
import 'package:wealth_wise/services/auth_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Load user and finance data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final financeProvider =
          Provider.of<FinanceProvider>(context, listen: false);

      if (authProvider.user != null) {
        financeProvider.initializeFinanceData(authProvider.user!.uid);
      } else {
        // Try to get current user if not available
        AuthService().getCurrentUser().then((user) {
          if (user != null) {
            authProvider.setUser(user);
            financeProvider.initializeFinanceData(user.uid);
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final financeProvider = Provider.of<FinanceProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: RichText(
          text: TextSpan(
            style: theme.textTheme.titleLarge,
            children: [
              const TextSpan(text: 'Wealth'),
              TextSpan(
                text: 'Wise',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (authProvider.user != null)
            IconButton(
              icon: const Icon(Icons.person_outline),
              tooltip: 'Profile',
              onPressed: () => Navigator.pushNamed(context, '/profile'),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: theme.colorScheme.primary,
        onRefresh: () async {
          if (authProvider.user != null) {
            await financeProvider.initializeFinanceData(authProvider.user!.uid);
          }
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          children: [
            if (authProvider.user != null)
              Text(
                'Hello, ${authProvider.user!.displayName ?? 'User'}!',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            const SizedBox(height: 16.0),
            _buildBalanceCard(context, financeProvider),
            const SizedBox(height: 24.0),

            // Quick Actions Section
            Text(
              'Quick Actions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16.0),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    context,
                    icon: Icons.add_circle_outline,
                    title: 'Add Expense',
                    onTap: () =>
                        _showTransactionForm(context, TransactionType.expense),
                    color: theme.colorScheme.errorContainer,
                    iconColor: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: _buildActionCard(
                    context,
                    icon: Icons.add_circle_outline,
                    title: 'Add Income',
                    onTap: () =>
                        _showTransactionForm(context, TransactionType.income),
                    color: theme.colorScheme.primaryContainer,
                    iconColor: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24.0),

            // Recent Transactions & Insights
            Row(
              children: [
                Text(
                  'Recent Transactions',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/transactions'),
                  child: const Text('See All'),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            if (financeProvider.transactions.isEmpty)
              _buildEmptyState(
                context,
                'No recent transactions',
                'Your recent transactions will appear here',
                Icons.receipt_long_outlined,
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: financeProvider.transactions.length > 3
                      ? 3
                      : financeProvider.transactions.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    indent: 16.0,
                    endIndent: 16.0,
                  ),
                  itemBuilder: (context, index) {
                    final transaction = financeProvider.transactions[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            transaction.type == TransactionType.expense
                                ? theme.colorScheme.errorContainer
                                : theme.colorScheme.primaryContainer,
                        child: Icon(
                          transaction.type == TransactionType.expense
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          color: transaction.type == TransactionType.expense
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                        ),
                      ),
                      title: Text(
                        transaction.title,
                        style: theme.textTheme.bodyLarge,
                      ),
                      subtitle: Text(
                        DateFormat('MMM dd, yyyy').format(transaction.date),
                        style: theme.textTheme.bodySmall,
                      ),
                      trailing: Text(
                        '\$${transaction.amount.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: transaction.type == TransactionType.expense
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 24.0),

            // Insights Section
            Text(
              'Financial Insights',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16.0),
            if (authProvider.user == null)
              _buildEmptyState(
                context,
                'Sign in to view insights',
                'Create an account to track your finances',
                Icons.insights_outlined,
              )
            else if (financeProvider.transactions.isEmpty)
              _buildEmptyState(
                context,
                'No data available',
                'Add transactions to see your financial insights',
                Icons.insights_outlined,
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _buildInsightCard(
                      context,
                      icon: Icons.savings_outlined,
                      title: 'Savings Rate',
                      value: financeProvider.totalIncome > 0
                          ? '${((financeProvider.totalIncome - financeProvider.totalExpenses) / financeProvider.totalIncome * 100).toStringAsFixed(1)}%'
                          : '0%',
                      color: theme.colorScheme.tertiaryContainer,
                      iconColor: theme.colorScheme.tertiary,
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: _buildInsightCard(
                      context,
                      icon: Icons.trending_up,
                      title: 'Top Category',
                      value: financeProvider.topExpenseCategory ?? 'N/A',
                      color: theme.colorScheme.secondaryContainer,
                      iconColor: theme.colorScheme.secondary,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(
      BuildContext context, FinanceProvider financeProvider) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Total Balance',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              '\$${financeProvider.totalBalance.toStringAsFixed(2)}',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24.0),
            Row(
              children: [
                Expanded(
                  child: _buildFinanceSummaryItem(
                    context,
                    label: 'Income',
                    amount: financeProvider.totalIncome,
                    isPositive: true,
                  ),
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: theme.colorScheme.outlineVariant,
                ),
                Expanded(
                  child: _buildFinanceSummaryItem(
                    context,
                    label: 'Expenses',
                    amount: financeProvider.totalExpenses,
                    isPositive: false,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinanceSummaryItem(
    BuildContext context, {
    required String label,
    required double amount,
    required bool isPositive,
  }) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4.0),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPositive ? Icons.arrow_upward : Icons.arrow_downward,
              color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
              size: 16,
            ),
            const SizedBox(width: 4.0),
            Text(
              '\$${amount.toStringAsFixed(2)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required Color color,
    required Color iconColor,
  }) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 32.0,
                color: iconColor,
              ),
              const SizedBox(height: 8.0),
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 48.0,
            color: theme.colorScheme.primary.withValues(alpha: 128),
          ),
          const SizedBox(height: 16.0),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4.0),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 153),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showTransactionForm(BuildContext context, TransactionType type) {
    UIHelpers.showTransactionForm(context, type);
  }

  Widget _buildInsightCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required Color iconColor,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(
                    alpha: 51), // 0.2 opacity → alpha 51 (20% of 255)
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
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
}
