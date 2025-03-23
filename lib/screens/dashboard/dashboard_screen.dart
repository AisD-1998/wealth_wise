// ignore_for_file: unused_import, unused_element, unused_local_variable
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:wealth_wise/providers/auth_provider.dart';
import 'package:wealth_wise/screens/transactions/add_transaction_screen.dart';
import 'package:wealth_wise/screens/budgeting/budgets_screen.dart';
import 'package:wealth_wise/screens/savings/saving_goals_screen.dart';
import 'package:wealth_wise/screens/reporting/reports_screen.dart';
import 'package:wealth_wise/screens/settings/settings_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  // Test Firestore connection
  Future<void> _testFirestore(BuildContext context) async {
    try {
      // Test write operation
      await FirebaseFirestore.instance.collection('test_collection').add({
        'timestamp': FieldValue.serverTimestamp(),
        'test': 'data',
      });

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully wrote to Firestore!')),
        );
      }
    } catch (e) {
      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('WealthWise'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // Open notifications
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Dashboard will be shown here'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _testFirestore(context),
              child: const Text('Test Firestore Connection'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddTransactionScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.savings), label: 'Budgets'),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
        ],
        onTap: (index) {
          switch (index) {
            case 0:
              // Already on dashboard
              break;
            case 1:
              // Navigate to transactions
              break;
            case 2:
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BudgetsScreen()),
              );
              break;
            case 3:
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ReportsScreen()),
              );
              break;
          }
        },
      ),
    );
  }

  Widget _buildBalanceCard(
    BuildContext context,
    String title,
    String amount,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(title, style: const TextStyle(color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            amount,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpendingChart(BuildContext context) {
    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sections: [
            PieChartSectionData(
              color: Colors.blue,
              value: 35,
              title: '35%',
              radius: 60,
              titleStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            PieChartSectionData(
              color: Colors.green,
              value: 25,
              title: '25%',
              radius: 60,
              titleStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            PieChartSectionData(
              color: Colors.orange,
              value: 20,
              title: '20%',
              radius: 60,
              titleStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            PieChartSectionData(
              color: Colors.red,
              value: 15,
              title: '15%',
              radius: 60,
              titleStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            PieChartSectionData(
              color: Colors.purple,
              value: 5,
              title: '5%',
              radius: 60,
              titleStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          centerSpaceRadius: 40,
          sectionsSpace: 2,
        ),
      ),
    );
  }

  Widget _buildRecentTransactions(BuildContext context) {
    return Column(
      children: [
        _buildTransactionItem(
          context,
          'Grocery Store',
          'Food & Groceries',
          '-\$54.35',
          '2h ago',
          Icons.shopping_cart,
          Colors.green,
        ),
        const Divider(),
        _buildTransactionItem(
          context,
          'Netflix Subscription',
          'Entertainment',
          '-\$14.99',
          'Yesterday',
          Icons.movie,
          Colors.red,
        ),
        const Divider(),
        _buildTransactionItem(
          context,
          'Monthly Salary',
          'Income',
          '+\$2,850.00',
          '2 days ago',
          Icons.work,
          Colors.blue,
        ),
      ],
    );
  }

  Widget _buildTransactionItem(
    BuildContext context,
    String title,
    String category,
    String amount,
    String time,
    IconData icon,
    Color iconColor,
  ) {
    final theme = Theme.of(context);
    final isIncome = amount.startsWith('+');

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: iconColor.withAlpha(50),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title),
      subtitle: Text(category),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            amount,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isIncome ? Colors.green : null,
            ),
          ),
          Text(
            time,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetProgress(BuildContext context) {
    return Column(
      children: [
        _buildBudgetItem(context, 'Food & Groceries', 450, 600, Colors.green),
        const SizedBox(height: 12),
        _buildBudgetItem(context, 'Transportation', 180, 200, Colors.orange),
        const SizedBox(height: 12),
        _buildBudgetItem(context, 'Entertainment', 250, 200, Colors.red),
      ],
    );
  }

  Widget _buildBudgetItem(
    BuildContext context,
    String category,
    double spent,
    double limit,
    Color color,
  ) {
    final theme = Theme.of(context);
    final progress = (spent / limit).clamp(0.0, 1.0);
    final isOverBudget = spent > limit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(category),
            Text(
              '\$${spent.toInt()} / \$${limit.toInt()}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isOverBudget ? Colors.red : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          color: isOverBudget ? Colors.red : color,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  Widget _buildSavingGoals(BuildContext context) {
    return Column(
      children: [
        _buildSavingsItem(context, 'Vacation Fund', 1500, 5000, Colors.blue),
        const SizedBox(height: 12),
        _buildSavingsItem(context, 'Emergency Fund', 7500, 10000, Colors.green),
        const SizedBox(height: 12),
        _buildSavingsItem(context, 'New Car', 3200, 20000, Colors.purple),
      ],
    );
  }

  Widget _buildSavingsItem(
    BuildContext context,
    String goal,
    double saved,
    double target,
    Color color,
  ) {
    final theme = Theme.of(context);
    final progress = (saved / target).clamp(0.0, 1.0);
    final percentage = (progress * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(75),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(goal, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('$percentage%'),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: color,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          Text(
            'Saved: \$${saved.toInt()} of \$${target.toInt()}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
