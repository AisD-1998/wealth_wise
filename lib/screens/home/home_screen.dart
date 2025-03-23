import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wealth_wise/models/transaction.dart';
import 'package:wealth_wise/providers/auth_provider.dart';
import 'package:wealth_wise/providers/finance_provider.dart';
import 'package:wealth_wise/screens/expenses/expenses_screen.dart';
import 'package:wealth_wise/screens/savings/savings_screen.dart';
import 'package:wealth_wise/services/auth_service.dart';
import 'package:wealth_wise/widgets/balance_card.dart';
import 'package:wealth_wise/widgets/recent_transactions_list.dart';
import 'package:wealth_wise/widgets/transaction_form.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  final List<Widget> _screens = [
    const DashboardScreen(),
    const ExpensesScreen(),
    const SavingsScreen(),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: _screens,
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
            icon: Icon(Icons.money_off_outlined),
            selectedIcon: Icon(Icons.money_off),
            label: 'Expenses',
          ),
          NavigationDestination(
            icon: Icon(Icons.savings_outlined),
            selectedIcon: Icon(Icons.savings),
            label: 'Savings',
          ),
        ],
      ),
    );
  }
}

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
    final financeProvider = Provider.of<FinanceProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'WealthWise',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (authProvider.user != null)
              Text(
                'Hello, ${authProvider.user!.displayName ?? 'User'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // Show notifications
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            if (authProvider.user != null) {
              await financeProvider
                  .initializeFinanceData(authProvider.user!.uid);
            }
          },
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Balance Card
              BalanceCard(
                balance: financeProvider.totalBalance,
                income: financeProvider.totalIncome,
                expenses: financeProvider.totalExpenses,
              ),

              const SizedBox(height: 24),

              // Quick Actions
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Actions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildQuickActionButton(
                        context,
                        icon: Icons.add,
                        label: 'Add Expense',
                        onTap: () => _showTransactionForm(
                            context, TransactionType.expense),
                        color: Colors.red.shade100,
                        iconColor: Colors.red,
                      ),
                      _buildQuickActionButton(
                        context,
                        icon: Icons.arrow_upward,
                        label: 'Add Income',
                        onTap: () => _showTransactionForm(
                            context, TransactionType.income),
                        color: Colors.green.shade100,
                        iconColor: Colors.green,
                      ),
                      _buildQuickActionButton(
                        context,
                        icon: Icons.savings_outlined,
                        label: 'New Goal',
                        onTap: () {
                          Navigator.pushNamed(context, '/saving/add');
                        },
                        color: Colors.blue.shade100,
                        iconColor: Colors.blue,
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Recent Transactions
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Transactions',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      TextButton(
                        onPressed: () {
                          // Navigate to all transactions
                          Navigator.pushNamed(context, '/transactions');
                        },
                        child: const Text('See All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  financeProvider.transactions.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 48,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No transactions yet',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        color: Colors.grey.shade600,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Add your first transaction to start tracking',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Colors.grey.shade500,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : RecentTransactionsList(
                          transactions:
                              financeProvider.transactions.take(5).toList(),
                        ),
                ],
              ),

              const SizedBox(height: 24),

              // Financial Insights
              if (financeProvider.transactions.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Financial Insights',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _buildInsightCard(
                      context,
                      icon: Icons.trending_down,
                      title: 'Top Expense Category',
                      value: financeProvider.topExpenseCategory ?? 'No data',
                      color: Colors.orange.shade100,
                      iconColor: Colors.orange,
                    ),
                    const SizedBox(height: 12),
                    _buildInsightCard(
                      context,
                      icon: Icons.calendar_today,
                      title: 'Daily Average Spending',
                      value:
                          '\$${financeProvider.dailyAverageSpending.toStringAsFixed(2)}',
                      color: Colors.purple.shade100,
                      iconColor: Colors.purple,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTransactionForm(context, TransactionType.expense),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    required Color iconColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTransactionForm(BuildContext context, TransactionType type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => TransactionForm(initialType: type),
    );
  }
}
