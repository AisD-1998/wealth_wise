import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:wealth_wise/models/saving_goal.dart';
import 'package:wealth_wise/models/transaction.dart';
import 'package:wealth_wise/providers/auth_provider.dart';
import 'package:wealth_wise/providers/finance_provider.dart';
import 'package:wealth_wise/providers/user_preferences_provider.dart';
import 'package:wealth_wise/models/user_preferences.dart';
import 'package:wealth_wise/screens/settings/categories_screen.dart';
import 'package:wealth_wise/screens/savings/savings_screen.dart';
import 'package:wealth_wise/screens/budgets/budgets_screen.dart';
import 'package:wealth_wise/screens/bills/bills_screen.dart';
import 'package:wealth_wise/screens/reports/reports_screen.dart';
import 'package:wealth_wise/screens/transactions/transactions_screen.dart';
import 'package:wealth_wise/screens/profile/profile_screen.dart';
import 'package:wealth_wise/screens/settings/settings_screen.dart';
import 'package:wealth_wise/services/auth_service.dart';
import 'package:wealth_wise/utils/ui_helpers.dart';
import 'package:wealth_wise/widgets/balance_card.dart';
import 'package:wealth_wise/widgets/loading_animation_utils.dart';
import 'package:wealth_wise/utils/currency_formatter.dart';
import 'package:wealth_wise/models/bill_reminder.dart';
import 'package:wealth_wise/models/budget_alert.dart';
import 'package:wealth_wise/controllers/feature_access_controller.dart';
import 'package:wealth_wise/services/database_service.dart';
import 'package:wealth_wise/services/insights_service.dart';
import 'package:wealth_wise/providers/subscription_provider.dart';
import 'package:wealth_wise/screens/analytics/premium_analytics_screen.dart';
import 'package:wealth_wise/screens/investments/investments_screen.dart';
import 'package:wealth_wise/screens/reports/monthly_snapshot_screen.dart';
import 'package:wealth_wise/widgets/premium_feature_prompt.dart';
import 'package:wealth_wise/constants/app_strings.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  bool _hasAccessToReports = false;
  bool _isFabExpanded = false;

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
    _checkReportsAccess();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _checkReportsAccess() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    if (user != null) {
      final userData =
          await Provider.of<DatabaseService>(context, listen: false)
              .getUserData(user.uid);

      final featureAccessController = FeatureAccessController();
      final hasAccess = await featureAccessController.hasAccess(
          userData, 'advanced_analytics');

      setState(() {
        _hasAccessToReports = hasAccess;
      });
    }
  }

  void _handleNavigationTap(int index) {
    // Check if user is trying to access the Reports tab (index 4)
    if (index == 4 && !_hasAccessToReports) {
      // Show premium prompt instead of navigating
      PremiumFeaturePrompt.showPremiumDialog(
        context,
        featureName: 'Advanced Reports',
        description:
            'Unlock detailed financial insights and reports with Premium subscription',
        icon: Icons.bar_chart,
      );
    } else {
      setState(() {
        _selectedIndex = index;
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  Widget _buildMiniFab({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 26),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 8),
        FloatingActionButton.small(
          heroTag: label,
          onPressed: onTap,
          backgroundColor: color,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            // Only update the state if the page is accessible
            if (index != 4 || _hasAccessToReports) {
              setState(() {
                _selectedIndex = index;
                _isFabExpanded = false;
              });
            } else if (index == 4) {
              // If user tries to swipe to Reports page, bounce back to previous page
              _pageController.animateToPage(
                _selectedIndex,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          },
          children: _screens,
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Expanded mini FABs
          if (_isFabExpanded) ...[
            _buildMiniFab(
              label: 'Add Income',
              icon: Icons.arrow_upward,
              color: theme.colorScheme.primary,
              onTap: () {
                setState(() => _isFabExpanded = false);
                UIHelpers.showTransactionForm(
                    context, TransactionType.income);
              },
            ),
            const SizedBox(height: 8),
            _buildMiniFab(
              label: 'Add Expense',
              icon: Icons.arrow_downward,
              color: theme.colorScheme.error,
              onTap: () {
                setState(() => _isFabExpanded = false);
                UIHelpers.showTransactionForm(
                    context, TransactionType.expense);
              },
            ),
            const SizedBox(height: 12),
          ],
          // Main FAB
          FloatingActionButton(
            onPressed: () {
              setState(() => _isFabExpanded = !_isFabExpanded);
            },
            backgroundColor: theme.colorScheme.primary,
            child: AnimatedRotation(
              turns: _isFabExpanded ? 0.125 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ],
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
        onDestinationSelected: _handleNavigationTap,
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
    final userPreferencesProvider =
        Provider.of<UserPreferencesProvider>(context);

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
            _buildGreetingSection(theme, authProvider),
            const SizedBox(height: 16.0),
            BalanceCard(
              balance: financeProvider.totalBalance,
              income: financeProvider.totalIncome,
              expenses: financeProvider.totalExpenses,
            ),
            const SizedBox(height: 16.0),

            // Streak Card
            if (financeProvider.currentStreak > 0)
              _buildStreakCard(context, financeProvider.currentStreak),

            const SizedBox(height: 8.0),

            // Personalized content based on user preferences
            if (userPreferencesProvider.userPreferences != null)
              _buildPersonalizedContent(
                  context, userPreferencesProvider.userPreferences!),

            // Budget Alerts Section
            if (financeProvider.budgetAlerts.isNotEmpty) ...[
              ...financeProvider.budgetAlerts.map((alert) =>
                  _buildBudgetAlertCard(context, alert, financeProvider)),
              const SizedBox(height: 8.0),
            ],

            // Quick Actions Section
            _buildQuickActionsSection(theme),

            const SizedBox(height: 24.0),

            // Upcoming Bills Section (premium) or teaser (free)
            _buildUpcomingBillsSection(context, financeProvider),

            // Portfolio Summary (premium) or teaser (free)
            _buildPortfolioSection(context, financeProvider),

            // Monthly Snapshot Card
            _buildMonthlySnapshotCard(context),
            const SizedBox(height: 24.0),

            // Recent Transactions
            _buildRecentTransactionsSection(theme, financeProvider),

            const SizedBox(height: 24.0),

            // Insights Section
            _buildInsightsHeader(theme),
            const SizedBox(height: 16.0),
            _buildInsightsContent(authProvider, financeProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildGreetingSection(ThemeData theme, AuthProvider authProvider) {
    if (authProvider.user == null) return const SizedBox.shrink();
    return Text(
      'Hello, ${authProvider.user!.displayName ?? 'User'}!',
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildQuickActionsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                icon: Icons.account_balance_wallet_outlined,
                title: 'Budgets',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const BudgetsScreen()),
                ),
                color: theme.colorScheme.tertiaryContainer,
                iconColor: theme.colorScheme.tertiary,
              ),
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: _buildActionCard(
                context,
                icon: Icons.savings_outlined,
                title: 'Savings Goals',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SavingsScreen()),
                ),
                color: theme.colorScheme.primaryContainer,
                iconColor: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentTransactionsSection(
      ThemeData theme, FinanceProvider financeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              child: const Text(AppStrings.kSeeAll),
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
          _buildRecentTransactionsList(theme, financeProvider),
      ],
    );
  }

  Widget _buildRecentTransactionsList(
      ThemeData theme, FinanceProvider financeProvider) {
    return Container(
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
        separatorBuilder: (context, index) => const Divider(
          height: 1,
          indent: 16.0,
          endIndent: 16.0,
        ),
        itemBuilder: (context, index) {
          final transaction = financeProvider.transactions[index];
          return _buildTransactionTile(theme, transaction);
        },
      ),
    );
  }

  Widget _buildTransactionTile(ThemeData theme, Transaction transaction) {
    final isExpense = transaction.type == TransactionType.expense;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isExpense
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.primaryContainer,
        child: Icon(
          isExpense ? Icons.arrow_downward : Icons.arrow_upward,
          color: isExpense ? theme.colorScheme.error : theme.colorScheme.primary,
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
        CurrencyFormatter.formatWithContext(context, transaction.amount),
        style: theme.textTheme.titleMedium?.copyWith(
          color: isExpense ? theme.colorScheme.error : theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: () {
        _showTransactionOptions(context, transaction);
      },
      onLongPress: () async {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        final financeProvider =
            Provider.of<FinanceProvider>(context, listen: false);
        final confirm = await UIHelpers.showConfirmationDialog(
          context: context,
          title: AppStrings.kDeleteTransaction,
          message: AppStrings.kDeleteConfirmation,
          confirmText: 'Delete',
          cancelText: 'Cancel',
        );

        if (confirm && mounted) {
          _deleteTransactionWithRefs(
              transaction, scaffoldMessenger, financeProvider);
        }
      },
    );
  }

  Widget _buildInsightsHeader(ThemeData theme) {
    return Row(
      children: [
        Text(
          'Financial Insights',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Consumer<SubscriptionProvider>(
          builder: (context, subProvider, _) {
            if (subProvider.isSubscribed) {
              return TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const PremiumAnalyticsScreen()),
                ),
                child: const Text(AppStrings.kSeeAll),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildInsightsContent(
      AuthProvider authProvider, FinanceProvider financeProvider) {
    if (authProvider.user == null) {
      return _buildEmptyState(
        context,
        'Sign in to view insights',
        'Create an account to track your finances',
        Icons.insights_outlined,
      );
    }
    if (financeProvider.transactions.isEmpty) {
      return _buildEmptyState(
        context,
        'No data available',
        'Add transactions to see your financial insights',
        Icons.insights_outlined,
      );
    }
    return _buildInsightsSection(context, financeProvider);
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
                title: const Text(AppStrings.kDeleteTransaction,
                    style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await UIHelpers.showConfirmationDialog(
                    context: context,
                    title: AppStrings.kDeleteTransaction,
                    message:
                        AppStrings.kDeleteConfirmation,
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
              _buildDetailsTitleRow(context, theme, transaction, isIncome),
              const SizedBox(height: 16),
              ..._buildDetailsInfoItems(transaction),
              if (transaction.contributesToGoal && transaction.goalId != null)
                _buildGoalProgressSection(context, theme, transaction),
              const SizedBox(height: 24),
              _buildDetailsActionButtons(context, transaction),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailsTitleRow(
    BuildContext context,
    ThemeData theme,
    Transaction transaction,
    bool isIncome,
  ) {
    return Row(
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
    );
  }

  List<Widget> _buildDetailsInfoItems(Transaction transaction) {
    return [
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
    ];
  }

  Widget _buildGoalProgressSection(
    BuildContext context,
    ThemeData theme,
    Transaction transaction,
  ) {
    return FutureBuilder<SavingGoal?>(
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
                child: LoadingAnimationUtils.smallDollarSpinner(size: 20),
              ),
            ),
          );
        }

        final goal = snapshot.data;
        if (goal == null) {
          return const DetailItem(
            icon: Icons.savings,
            title: 'Saving Goal',
            value: 'Unknown or deleted goal',
          );
        }

        return _buildGoalProgressDetails(context, theme, goal);
      },
    );
  }

  Widget _buildGoalProgressDetails(
    BuildContext context,
    ThemeData theme,
    SavingGoal goal,
  ) {
    final progress = (goal.currentAmount / goal.targetAmount * 100);
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
                  color: goal.isCompleted ? Colors.green : Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0),
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  goal.isCompleted ? Colors.green : theme.colorScheme.primary,
                ),
                minHeight: 6,
              ),
              const SizedBox(height: 4),
              Text(
                goal.isCompleted
                    ? 'Goal completed!'
                    : '${progress.toStringAsFixed(1)}% complete',
                style: TextStyle(
                  color: goal.isCompleted ? Colors.green : Colors.grey[600],
                  fontSize: 12,
                  fontWeight:
                      goal.isCompleted ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsActionButtons(
    BuildContext context,
    Transaction transaction,
  ) {
    return Row(
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
    );
  }

  Widget _buildUpcomingBillsSection(
    BuildContext context,
    FinanceProvider financeProvider,
  ) {
    return Consumer<SubscriptionProvider>(
      builder: (context, subProvider, _) {
        final isPremium = subProvider.isSubscribed;

        if (!isPremium) {
          return _buildBillsTeaser(context);
        }

        final upcoming = financeProvider.upcomingBills;
        if (upcoming.isEmpty) return const SizedBox.shrink();

        return _buildBillsList(context, upcoming);
      },
    );
  }

  Widget _buildBillsTeaser(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 60)),
        ),
        color: theme.colorScheme.primaryContainer.withValues(alpha: 20),
        child: InkWell(
          onTap: () {
            PremiumFeaturePrompt.showPremiumDialog(
              context,
              featureName: 'Bill Reminders',
              description:
                  'Never miss a payment. Track recurring bills, get due date alerts, and log payments automatically.',
              icon: Icons.receipt_long,
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.receipt_long,
                    color: theme.colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bill Reminders',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Never miss a payment — upgrade to Premium',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.lock_outline,
                    size: 18, color: theme.colorScheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBillsList(BuildContext context, List<BillReminder> upcoming) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Upcoming Bills',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const BillsScreen()),
                ),
                child: const Text(AppStrings.kSeeAll),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...upcoming.take(3).map((bill) => _buildBillCard(context, bill)),
        ],
      ),
    );
  }

  Widget _buildBillCard(BuildContext context, BillReminder bill) {
    final theme = Theme.of(context);
    final daysUntil = bill.daysUntilDue;
    final isOverdue = bill.isOverdue;
    final billStatusBg =
        _billStatusBackgroundColor(isOverdue, daysUntil, theme);
    final billStatusFg =
        _billStatusForegroundColor(isOverdue, daysUntil, theme);
    final billDueLabel = _billDueText(isOverdue, daysUntil);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 6),
      color: theme.colorScheme.surfaceContainerLow,
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: billStatusBg,
          child: Icon(
            isOverdue ? Icons.warning_amber_rounded : Icons.receipt_long,
            size: 18,
            color: billStatusFg,
          ),
        ),
        title: Text(
          bill.title,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          billDueLabel,
          style: TextStyle(
            fontSize: 12,
            color: isOverdue ? Colors.red : Colors.grey[600],
          ),
        ),
        trailing: Text(
          CurrencyFormatter.formatWithContext(context, bill.amount),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const BillsScreen()),
        ),
      ),
    );
  }

  Color _billStatusBackgroundColor(
      bool isOverdue, int daysUntil, ThemeData theme) {
    if (isOverdue) return Colors.red.withValues(alpha: 30);
    if (daysUntil <= 3) return Colors.orange.withValues(alpha: 30);
    return theme.colorScheme.primaryContainer;
  }

  Color _billStatusForegroundColor(
      bool isOverdue, int daysUntil, ThemeData theme) {
    if (isOverdue) return Colors.red;
    if (daysUntil <= 3) return Colors.orange;
    return theme.colorScheme.primary;
  }

  String _billDueText(bool isOverdue, int daysUntil) {
    if (isOverdue) return '${daysUntil.abs()} days overdue';
    if (daysUntil == 0) return 'Due today';
    return 'Due in $daysUntil days';
  }

  Widget _buildBudgetAlertCard(
    BuildContext context,
    BudgetAlert alert,
    FinanceProvider financeProvider,
  ) {
    final theme = Theme.of(context);

    Color alertColor;
    IconData alertIcon;
    switch (alert.alertType) {
      case BudgetAlertType.exceeded100:
        alertColor = theme.colorScheme.error;
        alertIcon = Icons.warning_amber_rounded;
        break;
      case BudgetAlertType.warning75:
        alertColor = Colors.orange;
        alertIcon = Icons.info_outline;
        break;
      case BudgetAlertType.predictive:
        alertColor = Colors.deepPurple;
        alertIcon = Icons.auto_graph;
        break;
    }

    return Dismissible(
      key: Key('alert_${alert.budgetId}_${alert.alertType.name}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        financeProvider.dismissBudgetAlert(alert.budgetId);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.close, color: Colors.white),
      ),
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: alertColor.withValues(alpha: 80), width: 1),
        ),
        color: alertColor.withValues(alpha: 20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(alertIcon, color: alertColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  alert.message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 18, color: Colors.grey[500]),
                onPressed: () {
                  financeProvider.dismissBudgetAlert(alert.budgetId);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInsightsSection(
      BuildContext context, FinanceProvider financeProvider) {
    final theme = Theme.of(context);

    // Basic insights available to all users
    final savingsRate = financeProvider.totalIncome > 0
        ? ((financeProvider.totalIncome - financeProvider.totalExpenses) /
                financeProvider.totalIncome *
                100)
            .toStringAsFixed(1)
        : '0.0';
    final topCategory = financeProvider.topExpenseCategory ?? 'N/A';

    return Consumer<SubscriptionProvider>(
      builder: (context, subProvider, _) {
        final isPremium = subProvider.isSubscribed;

        return Column(
          children: [
            _buildBasicInsightsRow(context, theme, savingsRate, topCategory),
            if (isPremium)
              _buildPremiumInsights(context, theme, financeProvider),
            if (!isPremium) ...[
              const SizedBox(height: 12.0),
              _buildPremiumInsightsTeaser(context),
            ],
          ],
        );
      },
    );
  }

  Widget _buildBasicInsightsRow(
      BuildContext context, ThemeData theme, String savingsRate, String topCategory) {
    return Row(
      children: [
        Expanded(
          child: _buildInsightCard(
            context,
            icon: Icons.savings_outlined,
            title: 'Savings Rate',
            value: '$savingsRate%',
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
            value: topCategory,
            color: theme.colorScheme.secondaryContainer,
            iconColor: theme.colorScheme.secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumInsights(
      BuildContext context, ThemeData theme, FinanceProvider financeProvider) {
    final healthScore = InsightsService.financialHealthScore(
      totalIncome: financeProvider.totalIncome,
      totalExpenses: financeProvider.totalExpenses,
      budgets: financeProvider.budgets,
      goals: financeProvider.savingGoals,
    );
    final healthLabel = InsightsService.healthScoreLabel(healthScore);
    final momChange =
        InsightsService.monthOverMonthChange(financeProvider.transactions);
    final adherenceScore =
        InsightsService.budgetAdherenceScore(financeProvider.budgets);

    return Column(
      children: [
        const SizedBox(height: 12.0),
        Row(
          children: [
            Expanded(
              child: _buildHealthScoreInsight(
                context,
                score: healthScore,
                label: healthLabel,
              ),
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: _buildMomChangeInsight(context, momChange, theme),
            ),
          ],
        ),
        const SizedBox(height: 12.0),
        _buildBudgetAdherenceInsight(context, adherenceScore),
      ],
    );
  }

  Widget _buildMomChangeInsight(
      BuildContext context, double? momChange, ThemeData theme) {
    final isDown = momChange != null && momChange < 0;
    String value;
    if (momChange != null) {
      final prefix = momChange >= 0 ? '+' : '';
      value = '$prefix${momChange.toStringAsFixed(1)}%';
    } else {
      value = 'No data';
    }

    return _buildInsightCard(
      context,
      icon: isDown ? Icons.trending_down : Icons.trending_up,
      title: 'vs Last Month',
      value: value,
      color: isDown ? Colors.green.shade50 : theme.colorScheme.errorContainer,
      iconColor: isDown ? Colors.green : theme.colorScheme.error,
    );
  }

  Widget _buildBudgetAdherenceInsight(
      BuildContext context, double adherenceScore) {
    Color bgColor;
    Color fgColor;
    if (adherenceScore >= 75) {
      bgColor = Colors.green.shade50;
      fgColor = Colors.green;
    } else if (adherenceScore >= 50) {
      bgColor = Colors.orange.shade50;
      fgColor = Colors.orange;
    } else {
      bgColor = Colors.red.shade50;
      fgColor = Colors.red;
    }

    return _buildInsightCard(
      context,
      icon: Icons.check_circle_outline,
      title: 'Budget Adherence',
      value: '${adherenceScore.toStringAsFixed(0)}%',
      color: bgColor,
      iconColor: fgColor,
    );
  }

  Color _healthScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.lightGreen;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  Widget _buildHealthScoreInsight(
    BuildContext context, {
    required double score,
    required String label,
  }) {
    final theme = Theme.of(context);
    final scoreColor = _healthScoreColor(score);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 4,
                    backgroundColor: scoreColor.withValues(alpha: 40),
                    valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                  ),
                  Text(
                    score.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Health Score',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
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

  Widget _buildPremiumInsightsTeaser(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 80),
          width: 1,
        ),
      ),
      color: theme.colorScheme.primaryContainer.withValues(alpha: 30),
      child: InkWell(
        onTap: () {
          PremiumFeaturePrompt.showPremiumDialog(
            context,
            featureName: 'Deep Insights',
            description:
                'Unlock Financial Health Score, spending trends, budget adherence, and savings projections with Premium.',
            icon: Icons.insights,
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.lock_outline,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unlock Deep Insights',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Health score, trends & projections',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
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

  Widget _buildStreakCard(BuildContext context, int streak) {
    final theme = Theme.of(context);

    String streakEmoji;
    String streakLabel;
    if (streak >= 90) {
      streakEmoji = '🏆';
      streakLabel = 'Legendary!';
    } else if (streak >= 30) {
      streakEmoji = '🔥';
      streakLabel = 'On fire!';
    } else if (streak >= 7) {
      streakEmoji = '⭐';
      streakLabel = 'Great streak!';
    } else {
      streakEmoji = '✨';
      streakLabel = 'Keep going!';
    }

    return Card(
      elevation: 0,
      color: Colors.orange.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Text(streakEmoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$streak-day streak',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
                    ),
                  ),
                  Text(
                    streakLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.orange.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.local_fire_department,
                color: Colors.orange.shade400, size: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildPortfolioSection(
    BuildContext context,
    FinanceProvider financeProvider,
  ) {
    return Consumer<SubscriptionProvider>(
      builder: (context, subProvider, _) {
        final isPremium = subProvider.isSubscribed;

        if (!isPremium) {
          return _buildPortfolioTeaser(context);
        }

        if (financeProvider.investments.isEmpty) {
          return const SizedBox.shrink();
        }

        return _buildPortfolioSummary(context, financeProvider);
      },
    );
  }

  Widget _buildPortfolioTeaser(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 60)),
        ),
        color: theme.colorScheme.primaryContainer.withValues(alpha: 20),
        child: InkWell(
          onTap: () {
            PremiumFeaturePrompt.showPremiumDialog(
              context,
              featureName: 'Investment Tracking',
              description:
                  'Track your investment portfolio, monitor gains & losses, and see allocation breakdowns with Premium.',
              icon: Icons.show_chart,
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.show_chart,
                    color: theme.colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Investment Tracking',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Track your portfolio — upgrade to Premium',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.lock_outline,
                    size: 18, color: theme.colorScheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPortfolioSummary(
      BuildContext context, FinanceProvider financeProvider) {
    final theme = Theme.of(context);
    final totalValue = financeProvider.portfolioTotalValue;
    final totalCost = financeProvider.portfolioTotalCost;
    final gainLoss = totalValue - totalCost;
    final gainLossPercent =
        totalCost > 0 ? (gainLoss / totalCost) * 100 : 0.0;
    final isPositive = gainLoss >= 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Portfolio',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const InvestmentsScreen()),
                ),
                child: const Text(AppStrings.kSeeAll),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildPortfolioCard(
              theme, totalValue, isPositive, gainLossPercent, financeProvider),
        ],
      ),
    );
  }

  Widget _buildPortfolioCard(ThemeData theme, double totalValue,
      bool isPositive, double gainLossPercent, FinanceProvider financeProvider) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.show_chart,
                color: theme.colorScheme.primary, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    CurrencyFormatter.formatWithContext(context, totalValue),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        isPositive ? Icons.trending_up : Icons.trending_down,
                        size: 16,
                        color: isPositive ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${isPositive ? '+' : ''}${gainLossPercent.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: isPositive ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              '${financeProvider.investments.length} holdings',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlySnapshotCard(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    // Show snapshot card in the first 7 days of the month
    if (now.day > 7) return const SizedBox.shrink();

    final lastMonth = DateTime(now.year, now.month - 1);
    final monthLabel = DateFormat('MMMM').format(lastMonth);

    return Card(
      elevation: 0,
      color: theme.colorScheme.tertiaryContainer.withValues(alpha: 60),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const MonthlySnapshotScreen()),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.calendar_month,
                  color: theme.colorScheme.tertiary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$monthLabel Snapshot Ready',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'View your monthly financial summary',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  size: 16, color: theme.colorScheme.tertiary),
            ],
          ),
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

  void _deleteTransactionWithRefs(
    Transaction transaction,
    ScaffoldMessengerState scaffoldMessenger,
    FinanceProvider financeProvider,
  ) async {
    if (!mounted) return;

    scaffoldMessenger.showSnackBar(
      const SnackBar(content: Text('Deleting transaction...')),
    );

    try {
      if (transaction.id == null || transaction.id!.isEmpty) {
        scaffoldMessenger.clearSnackBars();
        scaffoldMessenger.showSnackBar(
          const SnackBar(
              content: Text('Cannot delete: Invalid transaction ID')),
        );
        return;
      }

      debugPrint(
          'Deleting transaction: ${transaction.id} - ${transaction.title}');

      final success = await financeProvider.deleteTransaction(transaction);

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

  Widget _buildPersonalizedContent(
      BuildContext context, UserPreferences preferences) {
    // Determine what content to show based on user's primary goal
    String title;
    String message;
    IconData icon;
    Widget? actionButton;

    switch (preferences.primaryGoal) {
      case FinancialGoal.saveMoney:
        title = "Saving Money Goal";
        message =
            "Based on your spending habits, you could save \$${(_getTotalMonthlySpending() * 0.15).toStringAsFixed(2)} this month by reducing non-essential expenses.";
        icon = Icons.savings;
        actionButton = OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Create Savings Goal'),
          onPressed: () {
            // Navigate to savings goal creation
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => const SavingsScreen()));
          },
        );
        break;

      case FinancialGoal.budgetBetter:
        title = "Budget Recommendations";
        message =
            "Set up a 50/30/20 budget: 50% for needs, 30% for wants, and 20% for savings and debt repayment.";
        icon = Icons.account_balance_wallet;
        break;

      case FinancialGoal.trackExpenses:
        title = "Expense Insights";
        message =
            "You've added ${_getRecentTransactionsCount()} transactions this month. Regular tracking helps identify spending patterns.";
        icon = Icons.track_changes;
        actionButton = OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Add Transaction'),
          onPressed: () {
            // Navigate to add transaction
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const TransactionsScreen()));
          },
        );
        break;

      case FinancialGoal.payOffDebt:
        title = "Debt Reduction";
        message =
            "Using the snowball method, focus on paying off your smallest debts first for psychological wins.";
        icon = Icons.credit_card_off;
        break;

      case FinancialGoal.investForFuture:
        title = "Investment Tips";
        message = preferences.expertise == FinancialExpertise.beginner
            ? "Start with a retirement account like a 401(k) or IRA before exploring other investments."
            : "Consider diversifying your portfolio with a mix of stocks, bonds, and real estate investments.";
        icon = Icons.trending_up;
        break;

      default:
        title = "Financial Tip";
        message =
            "Track your expenses regularly to understand where your money goes.";
        icon = Icons.lightbulb_outline;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 24.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (actionButton != null) ...[
              const SizedBox(height: 16),
              actionButton,
            ],
          ],
        ),
      ),
    );
  }

  double _getTotalMonthlySpending() {
    // This would be replaced with actual data from the finance provider
    return Provider.of<FinanceProvider>(context, listen: false).totalExpenses;
  }

  int _getRecentTransactionsCount() {
    // This would be replaced with actual data from the finance provider
    return Provider.of<FinanceProvider>(context, listen: false)
        .recentTransactions
        .length;
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
