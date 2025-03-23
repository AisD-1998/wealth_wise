import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wealth_wise/models/spending_category.dart';
import 'package:wealth_wise/models/transaction.dart';
import 'package:wealth_wise/providers/finance_provider.dart';
import 'package:intl/intl.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final String _selectedTimeframe = 'Monthly';

  @override
  Widget build(BuildContext context) {
    final financeProvider = Provider.of<FinanceProvider>(context);
    final categories = financeProvider.spendingCategories;
    final transactions = financeProvider.transactions;
    final theme = Theme.of(context);

    // Filter for expenses only
    final expenses = transactions
        .where((transaction) => transaction.type == TransactionType.expense)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              _showFilterOptions(context);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Spending summary card
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Spending Overview',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        _buildTimeframeSelector(theme),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Donut chart with categories
                    SizedBox(
                      height: 200,
                      child: Row(
                        children: [
                          // Donut chart
                          Expanded(
                            flex: 3,
                            child: _buildDonutChart(categories, theme),
                          ),

                          // Categories legend
                          Expanded(
                            flex: 3,
                            child: _buildCategoriesList(categories, theme),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Expense transactions list
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Expenses',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // Show all expenses
                    },
                    child: const Text('See All'),
                  ),
                ],
              ),
            ),

            // Transactions list
            Expanded(
              child: expenses.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long,
                            size: 64,
                            color: theme.colorScheme.primary
                                .withValues(alpha: 128),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No expenses yet',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your expenses will appear here',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 153),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: expenses.length,
                      itemBuilder: (context, index) {
                        final transaction = expenses[index];
                        return _buildExpenseItem(transaction, theme);
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to add transaction
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTimeframeSelector(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 26),
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isDense: true,
          value: _selectedTimeframe,
          icon: const Icon(Icons.keyboard_arrow_down, size: 16),
          items: ['Weekly', 'Monthly', 'Yearly'].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            // Handle timeframe change
          },
        ),
      ),
    );
  }

  Widget _buildDonutChart(List<SpendingCategory> categories, ThemeData theme) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 160,
          height: 160,
          child: CustomPaint(
            painter: DonutChartPainter(categories),
            child: Container(),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '\$1,240',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Total Spent',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 153),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoriesList(
      List<SpendingCategory> categories, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: categories.map((category) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: category.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category.name,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Text(
                '${category.percentage.toInt()}%',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExpenseItem(Transaction transaction, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Category icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _getCategoryColor(transaction.category)
                    .withValues(alpha: 26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getCategoryIcon(transaction.category),
                color: _getCategoryColor(transaction.category),
              ),
            ),

            const SizedBox(width: 12),

            // Transaction details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    DateFormat('MMM d, yyyy').format(transaction.date),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 153),
                    ),
                  ),
                ],
              ),
            ),

            // Amount
            Text(
              '-\$${transaction.amount.toStringAsFixed(2)}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String? category) {
    if (category == null) return Colors.grey;

    final provider = Provider.of<FinanceProvider>(context, listen: false);
    final matchingCategory = provider.spendingCategories
        .where((cat) => cat.name.toLowerCase() == category.toLowerCase())
        .toList();

    if (matchingCategory.isNotEmpty) {
      return matchingCategory.first.color;
    }

    // Default colors based on category name
    if (category.toLowerCase().contains('shopping')) {
      return Colors.green;
    } else if (category.toLowerCase().contains('entertainment') ||
        category.toLowerCase().contains('spotify')) {
      return Colors.blue;
    } else if (category.toLowerCase().contains('software') ||
        category.toLowerCase().contains('figma')) {
      return Colors.purple;
    }

    return Colors.grey;
  }

  IconData _getCategoryIcon(String? category) {
    if (category == null) return Icons.attach_money;

    if (category.toLowerCase().contains('shopping')) {
      return Icons.shopping_cart;
    } else if (category.toLowerCase().contains('entertainment') ||
        category.toLowerCase().contains('spotify')) {
      return Icons.music_note;
    } else if (category.toLowerCase().contains('software') ||
        category.toLowerCase().contains('figma')) {
      return Icons.design_services;
    }

    return Icons.attach_money;
  }

  void _showFilterOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter Expenses',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('This Week'),
                onTap: () {
                  Navigator.pop(context);
                  // Apply filter
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month),
                title: const Text('This Month'),
                onTap: () {
                  Navigator.pop(context);
                  // Apply filter
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_view_month),
                title: const Text('This Year'),
                onTap: () {
                  Navigator.pop(context);
                  // Apply filter
                },
              ),
              ListTile(
                leading: const Icon(Icons.tune),
                title: const Text('Custom Range'),
                onTap: () {
                  Navigator.pop(context);
                  // Show date picker
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class DonutChartPainter extends CustomPainter {
  final List<SpendingCategory> categories;

  DonutChartPainter(this.categories);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    double startAngle = -90 * (3.14159 / 180); // Start from top

    for (final category in categories) {
      final paint = Paint()
        ..color = category.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20
        ..strokeCap = StrokeCap.round;

      final sweepAngle = (category.percentage / 100) * 360 * (3.14159 / 180);

      canvas.drawArc(
        rect,
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
