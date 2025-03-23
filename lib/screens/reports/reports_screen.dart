import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wealth_wise/models/transaction.dart';
import 'package:wealth_wise/providers/finance_provider.dart';
import 'package:intl/intl.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedTimeframe = 'Monthly';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.calendar_today),
            onSelected: (value) {
              setState(() {
                _selectedTimeframe = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'Weekly',
                child: Text('Weekly'),
              ),
              const PopupMenuItem(
                value: 'Monthly',
                child: Text('Monthly'),
              ),
              const PopupMenuItem(
                value: 'Yearly',
                child: Text('Yearly'),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Income'),
            Tab(text: 'Expenses'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(),
            _buildIncomeTab(),
            _buildExpensesTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    final financeProvider = Provider.of<FinanceProvider>(context);
    final transactions = financeProvider.transactions;

    if (transactions.isEmpty) {
      return _buildEmptyState(
        icon: Icons.bar_chart,
        title: 'No data to analyze',
        subtitle: 'Add some transactions to see reports',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overview card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Financial Summary - $_selectedTimeframe',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 24),
                  _buildSummaryRow(
                    context,
                    title: 'Total Income',
                    amount: financeProvider.totalIncome,
                    color: Colors.green,
                    icon: Icons.arrow_upward,
                  ),
                  const Divider(height: 32),
                  _buildSummaryRow(
                    context,
                    title: 'Total Expenses',
                    amount: financeProvider.totalExpenses,
                    color: Colors.red,
                    icon: Icons.arrow_downward,
                  ),
                  const Divider(height: 32),
                  _buildSummaryRow(
                    context,
                    title: 'Net Savings',
                    amount: financeProvider.totalIncome -
                        financeProvider.totalExpenses,
                    color: Theme.of(context).colorScheme.primary,
                    icon: Icons.savings,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Income vs. Expenses chart
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Income vs. Expenses',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 200,
                    child: _buildBarChart(context, transactions),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Spending insights
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Spending Insights',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 24),
                  _buildInsightItem(
                    context,
                    title: 'Top Expense Category',
                    value: financeProvider.topExpenseCategory ?? 'N/A',
                    icon: Icons.category,
                  ),
                  const Divider(height: 24),
                  _buildInsightItem(
                    context,
                    title: 'Daily Average Spending',
                    value:
                        '\$${financeProvider.dailyAverageSpending.toStringAsFixed(2)}',
                    icon: Icons.calendar_today,
                  ),
                  const Divider(height: 24),
                  _buildInsightItem(
                    context,
                    title: 'Largest Single Expense',
                    value:
                        '\$${financeProvider.largestExpense?.amount.toStringAsFixed(2) ?? 'N/A'}',
                    icon: Icons.arrow_upward,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeTab() {
    final financeProvider = Provider.of<FinanceProvider>(context);
    final incomeTransactions = financeProvider.transactions
        .where((t) => t.type == TransactionType.income)
        .toList();

    if (incomeTransactions.isEmpty) {
      return _buildEmptyState(
        icon: Icons.arrow_upward,
        title: 'No income data',
        subtitle: 'Add income transactions to see reports',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Income Breakdown',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 200,
                    child: _buildLineChart(context, incomeTransactions),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'Income Sources',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),

          const SizedBox(height: 16),

          // Income sources list
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: incomeTransactions.length,
            itemBuilder: (context, index) {
              final transaction = incomeTransactions[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_upward,
                      color: Colors.green,
                    ),
                  ),
                  title: Text(transaction.title),
                  subtitle:
                      Text(DateFormat('MMM d, yyyy').format(transaction.date)),
                  trailing: Text(
                    '\$${transaction.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesTab() {
    final financeProvider = Provider.of<FinanceProvider>(context);
    final expenseTransactions = financeProvider.transactions
        .where((t) => t.type == TransactionType.expense)
        .toList();

    if (expenseTransactions.isEmpty) {
      return _buildEmptyState(
        icon: Icons.arrow_downward,
        title: 'No expense data',
        subtitle: 'Add expense transactions to see reports',
      );
    }

    // Calculate category totals
    final categoryTotals = <String, double>{};
    for (final transaction in expenseTransactions) {
      final category = transaction.category ?? 'Uncategorized';
      categoryTotals[category] =
          (categoryTotals[category] ?? 0) + transaction.amount;
    }

    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Expense Categories',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 200,
                    child: _buildPieChart(context, categoryTotals),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'Top Expense Categories',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),

          const SizedBox(height: 16),

          // Category breakdown list
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedCategories.length,
            itemBuilder: (context, index) {
              final category = sortedCategories[index];
              final percentage =
                  (category.value / financeProvider.totalExpenses) * 100;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.category,
                      color: Colors.red,
                    ),
                  ),
                  title: Text(category.key),
                  subtitle: LinearProgressIndicator(
                    value: category.value / financeProvider.totalExpenses,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                  ),
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '\$${category.value.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    BuildContext context, {
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 26),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
          ),
        ),
        const SizedBox(width: 16),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const Spacer(),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
      ],
    );
  }

  Widget _buildInsightItem(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 26),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBarChart(BuildContext context, List<Transaction> transactions) {
    // Placeholder for bar chart
    // In a real implementation, you would process the transactions
    // and create appropriate BarChartData

    return const Center(
      child: Text('Bar Chart Placeholder'),
    );
  }

  Widget _buildLineChart(BuildContext context, List<Transaction> transactions) {
    // Placeholder for line chart
    // In a real implementation, you would process the transactions
    // and create appropriate LineChartData

    return const Center(
      child: Text('Line Chart Placeholder'),
    );
  }

  Widget _buildPieChart(
      BuildContext context, Map<String, double> categoryTotals) {
    // Placeholder for pie chart
    // In a real implementation, you would process the category totals
    // and create appropriate PieChartData

    return const Center(
      child: Text('Pie Chart Placeholder'),
    );
  }
}
