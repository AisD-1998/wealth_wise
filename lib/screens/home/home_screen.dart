import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:wealth_wise/models/saving_goal.dart';
import 'package:wealth_wise/models/transaction.dart';
import 'package:wealth_wise/providers/auth_provider.dart';
import 'package:wealth_wise/providers/finance_provider.dart';
import 'package:wealth_wise/screens/settings/categories_screen.dart';
import 'package:wealth_wise/screens/savings/savings_screen.dart';
import 'package:wealth_wise/screens/reports/reports_screen.dart';
import 'package:wealth_wise/screens/transactions/transactions_screen.dart';
import 'package:wealth_wise/screens/profile/profile_screen.dart';
import 'package:wealth_wise/screens/settings/settings_screen.dart';
import 'package:wealth_wise/services/auth_service.dart';
import 'package:wealth_wise/utils/ui_helpers.dart';
import 'package:wealth_wise/widgets/balance_card.dart';
import 'package:wealth_wise/widgets/loading_animation_utils.dart';
import 'package:wealth_wise/utils/currency_formatter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  final List<Widget> _screens = [
    const HomeScreenDashboard(),
    const CategoriesScreen(),
    const SavingsScreen(),
    const TransactionsScreen(),
    const ReportsScreen(),
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          children: _screens,
        ),
      ),
      appBar: AppBar(
        title: RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.titleLarge,
            children: [
              const TextSpan(text: 'Wealth'),
              TextSpan(
                text: 'Wise',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (Provider.of<AuthProvider>(context).user != null)
            IconButton(
              icon: const Icon(Icons.person_outline),
              tooltip: 'Profile',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ProfileScreen()),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category),
            label: 'Categories',
          ),
          NavigationDestination(
            icon: Icon(Icons.savings_outlined),
            selectedIcon: Icon(Icons.savings),
            label: 'Savings',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Transactions',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
        ],
      ),
    );
  }
}

class HomeScreenDashboard extends StatefulWidget {
  const HomeScreenDashboard({super.key});

  @override
  State<HomeScreenDashboard> createState() => _HomeScreenDashboardState();
}

class _HomeScreenDashboardState extends State<HomeScreenDashboard> {
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
            BalanceCard(
              balance: financeProvider.totalBalance,
              income: financeProvider.totalIncome,
              expenses: financeProvider.totalExpenses,
            ),
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
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const TransactionsScreen()),
                  ),
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
                        CurrencyFormatter.formatWithContext(
                            context, transaction.amount),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: transaction.type == TransactionType.expense
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () {
                        _showTransactionOptions(context, transaction);
                      },
                      onLongPress: () async {
                        final confirm = await UIHelpers.showConfirmationDialog(
                          context: context,
                          title: 'Delete Transaction',
                          message:
                              'Are you sure you want to delete this transaction?',
                          confirmText: 'Delete',
                          cancelText: 'Cancel',
                        );

                        if (confirm && context.mounted) {
                          _deleteTransaction(transaction, context);
                        }
                      },
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
                      value:
                          '${((financeProvider.totalIncome - financeProvider.totalExpenses) / financeProvider.totalIncome * 100).toStringAsFixed(1)}%',
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

  void _showTransactionOptions(BuildContext context, Transaction transaction) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('View Details'),
                onTap: () {
                  Navigator.pop(context);
                  _showTransactionDetails(context, transaction);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Transaction'),
                onTap: () {
                  Navigator.pop(context);
                  UIHelpers.showTransactionForm(
                    context,
                    transaction.type,
                    existingTransaction: transaction,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Transaction',
                    style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await UIHelpers.showConfirmationDialog(
                    context: context,
                    title: 'Delete Transaction',
                    message:
                        'Are you sure you want to delete this transaction?',
                    confirmText: 'Delete',
                    cancelText: 'Cancel',
                  );

                  if (confirm && context.mounted) {
                    _deleteTransaction(transaction, context);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTransactionDetails(BuildContext context, Transaction transaction) {
    final theme = Theme.of(context);
    final isIncome = transaction.type == TransactionType.income;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title and amount row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      transaction.title,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    isIncome
                        ? '+${CurrencyFormatter.formatWithContext(context, transaction.amount)}'
                        : '-${CurrencyFormatter.formatWithContext(context, transaction.amount)}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: isIncome ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Details list
              DetailItem(
                icon: Icons.calendar_today,
                title: 'Date',
                value: DateFormat('MMMM d, yyyy').format(transaction.date),
              ),
              DetailItem(
                icon: Icons.access_time,
                title: 'Time',
                value: DateFormat('h:mm a').format(transaction.date),
              ),
              DetailItem(
                icon: Icons.category,
                title: 'Category',
                value: transaction.category ?? 'Uncategorized',
              ),
              if (transaction.note != null && transaction.note!.isNotEmpty)
                DetailItem(
                  icon: Icons.notes,
                  title: 'Notes',
                  value: transaction.note!,
                ),

              // Show saving goal info for income transactions with goals
              if (transaction.contributesToGoal && transaction.goalId != null)
                FutureBuilder<SavingGoal?>(
                  future: Provider.of<FinanceProvider>(context, listen: false)
                      .getSavingGoalById(transaction.goalId!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: LoadingAnimationUtils.smallDollarSpinner(
                                size: 20),
                          ),
                        ),
                      );
                    }

                    final goal = snapshot.data;
                    if (goal == null) {
                      return DetailItem(
                        icon: Icons.savings,
                        title: 'Saving Goal',
                        value: 'Unknown or deleted goal',
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DetailItem(
                          icon: Icons.savings,
                          title: 'Saving Goal',
                          value: goal.title,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 42.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Progress: ${CurrencyFormatter.formatWithContext(context, goal.currentAmount)} / ${CurrencyFormatter.formatWithContext(context, goal.targetAmount)}',
                                style: TextStyle(
                                  color: goal.isCompleted
                                      ? Colors.green
                                      : Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: (goal.currentAmount / goal.targetAmount)
                                    .clamp(0.0, 1.0),
                                backgroundColor: Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  goal.isCompleted
                                      ? Colors.green
                                      : theme.colorScheme.primary,
                                ),
                                minHeight: 6,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                goal.isCompleted
                                    ? 'Goal completed!'
                                    : '${((goal.currentAmount / goal.targetAmount) * 100).toStringAsFixed(1)}% complete',
                                style: TextStyle(
                                  color: goal.isCompleted
                                      ? Colors.green
                                      : Colors.grey[600],
                                  fontSize: 12,
                                  fontWeight: goal.isCompleted
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),

              const SizedBox(height: 24),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                    onPressed: () {
                      Navigator.pop(context);
                      UIHelpers.showTransactionForm(
                        context,
                        transaction.type,
                        existingTransaction: transaction,
                      );
                    },
                  ),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                    onPressed: () async {
                      Navigator.pop(context);
                      _deleteTransaction(transaction, context);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
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

  void _deleteTransaction(Transaction transaction, BuildContext context) async {
    // Check if this state is still mounted before proceeding
    if (!mounted) return;

    // Store a reference to scaffoldMessenger before async operations
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Make sure we have the transaction provider
    final financeProvider =
        Provider.of<FinanceProvider>(context, listen: false);

    // Show a loading indicator
    scaffoldMessenger.showSnackBar(
      const SnackBar(content: Text('Deleting transaction...')),
    );

    try {
      // Ensure the transaction has a valid ID
      if (transaction.id == null || transaction.id!.isEmpty) {
        scaffoldMessenger.clearSnackBars();
        scaffoldMessenger.showSnackBar(
          const SnackBar(
              content: Text('Cannot delete: Invalid transaction ID')),
        );
        return;
      }

      // Log transaction details for debugging
      debugPrint(
          'Deleting transaction: ${transaction.id} - ${transaction.title}');

      // Use the finance provider to properly handle goal updates when deleting
      final success = await financeProvider.deleteTransaction(transaction);

      // Check if state is still mounted before continuing
      if (!mounted) return;

      scaffoldMessenger.clearSnackBars();
      if (success) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('${transaction.title} deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Failed to delete ${transaction.title}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.clearSnackBars();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// DetailItem widget for showing transaction details
class DetailItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const DetailItem({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
