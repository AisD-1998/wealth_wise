import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wealth_wise/models/transaction.dart';
import 'package:wealth_wise/providers/finance_provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Select timeframe',
            onSelected: (value) {
              setState(() {
                _selectedTimeframe = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'Weekly',
                child: Row(
                  children: [
                    Icon(Icons.view_week_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Weekly'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'Monthly',
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Monthly'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'Yearly',
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Yearly'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          indicatorColor: colorScheme.primary,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: colorScheme.outlineVariant,
          tabs: const [
            Tab(
              icon: Icon(Icons.pie_chart_outline),
              text: 'Overview',
            ),
            Tab(
              icon: Icon(Icons.arrow_upward_outlined),
              text: 'Income',
            ),
            Tab(
              icon: Icon(Icons.arrow_downward_outlined),
              text: 'Expenses',
            ),
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
                    height: 300,
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
                  const SizedBox(height: 16),
                  Container(
                    height: 250,
                    padding: const EdgeInsets.only(right: 16.0, bottom: 20.0),
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
                  const SizedBox(height: 16),
                  Container(
                    height: 240,
                    padding: const EdgeInsets.only(bottom: 8.0),
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

              // Find the category color from the list of categories
              final categoryName = category.key;
              Color categoryColor;

              if (categoryName == 'Other') {
                categoryColor = Colors.grey;
              } else {
                final categoryObj = financeProvider.categories
                    .where((cat) => cat.name == categoryName)
                    .firstOrNull;
                // Use the category's color or a default
                categoryColor = categoryObj?.color ?? Colors.red;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 51),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.category,
                      color: categoryColor,
                    ),
                  ),
                  title: Text(category.key),
                  subtitle: LinearProgressIndicator(
                    value: category.value / financeProvider.totalExpenses,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(categoryColor),
                  ),
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '\$${category.value.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: categoryColor,
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
    final financeProvider = Provider.of<FinanceProvider>(context);
    final totalIncome = financeProvider.totalIncome;
    final totalExpense = financeProvider.totalExpenses;
    final maxValue =
        math.max(totalIncome, totalExpense) * 1.2; // 20% additional space

    return Stack(
      children: [
        BarChart(
          BarChartData(
            alignment: BarChartAlignment.center,
            maxY: maxValue,
            minY: 0,
            barTouchData: BarTouchData(enabled: false),
            gridData: FlGridData(
              show: true,
              horizontalInterval: math.max(0.1, maxValue / 4),
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.grey.shade300,
                  strokeWidth: 1,
                );
              },
              drawVerticalLine: false,
            ),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    String text = '';
                    if (value == 0) {
                      text = 'Income';
                    } else if (value == 1) {
                      text = 'Expenses';
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        text,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 60,
                  interval: math.max(0.1, maxValue / 4),
                  getTitlesWidget: (double value, TitleMeta meta) {
                    return Text(
                      '\$${value.toInt()}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(
              show: false,
            ),
            groupsSpace: 40,
            barGroups: [
              BarChartGroupData(
                x: 0,
                barRods: [
                  BarChartRodData(
                    toY: totalIncome,
                    color: Colors.green,
                    width: 60,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxValue,
                      color: Colors.green.withValues(alpha: 26),
                    ),
                  ),
                ],
              ),
              BarChartGroupData(
                x: 1,
                barRods: [
                  BarChartRodData(
                    toY: totalExpense,
                    color: Colors.red,
                    width: 60,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxValue,
                      color: Colors.red.withValues(alpha: 26),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Add income and expense value labels above the bars
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200, width: 1),
                    ),
                    child: Text(
                      '\$${totalIncome.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              Column(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200, width: 1),
                    ),
                    child: Text(
                      '\$${totalExpense.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLineChart(BuildContext context, List<Transaction> transactions) {
    // Group transactions by date and calculate daily income totals
    final Map<DateTime, double> dailyIncomes = {};

    // Get start and end dates for the range
    final startDate = DateTime.now().subtract(const Duration(days: 30));
    final endDate = DateTime.now();

    // Initialize daily totals for all days in the range
    for (var d = startDate;
        d.isBefore(endDate) || d.isAtSameMomentAs(endDate);
        d = d.add(const Duration(days: 1))) {
      dailyIncomes[DateTime(d.year, d.month, d.day)] = 0;
    }

    // Sum up income transactions by date
    for (final transaction in transactions) {
      if (transaction.type == TransactionType.income) {
        final date = DateTime(transaction.date.year, transaction.date.month,
            transaction.date.day);
        if (date.isAfter(startDate.subtract(const Duration(days: 1))) &&
            date.isBefore(endDate.add(const Duration(days: 1)))) {
          dailyIncomes[date] = (dailyIncomes[date] ?? 0) + transaction.amount;
        }
      }
    }

    // Find the max value for better scaling
    double maxValue = 0;
    for (final amount in dailyIncomes.values) {
      if (amount > maxValue) {
        maxValue = amount;
      }
    }

    // If all values are 0, set max to 100 to avoid empty chart
    if (maxValue == 0) {
      maxValue = 100;
    }

    // Add some padding to the top
    maxValue = maxValue * 1.2;

    // Sort dates and create spot data
    final sortedDates = dailyIncomes.keys.toList()..sort();

    // Show dates at reasonable intervals (5-6 labels)
    final interval = math.max(1, (sortedDates.length / 5).round());

    // Create the spots for the line chart
    final spots = <FlSpot>[];
    for (int i = 0; i < sortedDates.length; i++) {
      final date = sortedDates[i];
      final amount = dailyIncomes[date] ?? 0;
      spots.add(FlSpot(i.toDouble(), amount));
    }

    // Calculate appropriate interval for y-axis labels
    final yLabelInterval = math.max(0.1, (maxValue / 4).roundToDouble());

    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8, right: 12),
      child: Column(
        children: [
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: math.max(0.1, yLabelInterval),
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.shade300,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: math.max(1.0, 1),
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final index = value.toInt();
                        // Only show dates at intervals
                        if (index % interval != 0) {
                          return const SizedBox.shrink();
                        }
                        if (index >= 0 && index < sortedDates.length) {
                          final date = sortedDates[index];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              DateFormat('dd/MM').format(date),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 46,
                      interval: math.max(0.1, yLabelInterval),
                      getTitlesWidget: (double value, TitleMeta meta) {
                        if (value == 0) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          '\$${value.toInt()}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                    left: BorderSide(color: Colors.grey.shade300, width: 1),
                  ),
                ),
                minX: 0,
                maxX: (sortedDates.length - 1).toDouble(),
                minY: 0, // Always start at 0 for income
                maxY: maxValue,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                      return touchedBarSpots.map((barSpot) {
                        final index = barSpot.x.toInt();
                        final date = index >= 0 && index < sortedDates.length
                            ? DateFormat('MMM d').format(sortedDates[index])
                            : '';
                        return LineTooltipItem(
                          '$date: \$${barSpot.y.toStringAsFixed(2)}',
                          const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: Colors.green,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.white,
                          strokeWidth: 2,
                          strokeColor: Colors.green,
                        );
                      },
                      checkToShowDot: (spot, barData) {
                        // Only show dots at interval points or for non-zero values
                        return spot.x.toInt() % interval == 0 || spot.y > 0;
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.green.withValues(alpha: 26),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Legend
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Daily Income',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(
      BuildContext context, Map<String, double> categoryTotals) {
    if (categoryTotals.isEmpty) {
      return const Center(
        child: Text('No expense data available'),
      );
    }

    // Sort categories by amount
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Calculate total for percentages
    final total =
        sortedCategories.fold<double>(0, (sum, entry) => sum + entry.value);

    // Get the finance provider to access category colors
    final financeProvider = Provider.of<FinanceProvider>(context);

    // Default colors for categories not found
    final defaultColors = [
      Colors.red,
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
      Colors.indigo,
      Colors.cyan,
      Colors.brown,
    ];

    // Limit the number of categories to display to avoid cluttering
    const maxCategoriesToShow = 7;
    List<MapEntry<String, double>> displayCategories;

    if (sortedCategories.length > maxCategoriesToShow) {
      displayCategories = sortedCategories.sublist(0, maxCategoriesToShow);
      // Create an "Other" category for the rest
      double otherTotal = 0;
      for (int i = maxCategoriesToShow; i < sortedCategories.length; i++) {
        otherTotal += sortedCategories[i].value;
      }
      displayCategories.add(MapEntry('Other', otherTotal));
    } else {
      displayCategories = sortedCategories;
    }

    // Create a separate legend items list with actual category colors
    final legendItems = displayCategories.map((category) {
      final categoryName = category.key;
      Color color;

      if (categoryName == 'Other') {
        color = Colors.grey;
      } else {
        // Find the category in the finance provider's categories list
        final categoryObj = financeProvider.categories
            .where((cat) => cat.name == categoryName)
            .firstOrNull;
        // Use the category's color if found, otherwise use a default
        color = categoryObj?.color ??
            defaultColors[
                displayCategories.indexOf(category) % defaultColors.length];
      }
      return MapEntry(categoryName, color);
    }).toList();

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 35,
                borderData: FlBorderData(show: false),
                sections: displayCategories.asMap().entries.map((entry) {
                  final category = entry.value;
                  final categoryName = category.key;
                  final percentage = (category.value / total) * 100;

                  // Use the same color as in the legend
                  final legendIndex = legendItems
                      .indexWhere((item) => item.key == categoryName);
                  final color = legendIndex >= 0
                      ? legendItems[legendIndex].value
                      : defaultColors[entry.key % defaultColors.length];

                  return PieChartSectionData(
                    color: color,
                    value: category.value,
                    title: '${percentage.toStringAsFixed(0)}%',
                    radius: 65,
                    titleStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: percentage < 10 ? 11 : 13,
                    ),
                    borderSide: const BorderSide(width: 1, color: Colors.white),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        // Legend with consistent colors matching the chart sections
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: Wrap(
            spacing: 24,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var legendItem in legendItems)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: legendItem.value,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        legendItem.key,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
