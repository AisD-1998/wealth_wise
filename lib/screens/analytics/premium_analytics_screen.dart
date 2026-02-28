import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wealth_wise/controllers/feature_access_controller.dart';
import 'package:wealth_wise/providers/auth_provider.dart';
import 'package:wealth_wise/providers/finance_provider.dart';
import 'package:wealth_wise/theme/app_theme.dart';
import 'package:wealth_wise/widgets/premium_feature_prompt.dart';
import 'package:wealth_wise/utils/currency_formatter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:wealth_wise/services/database_service.dart';
import 'package:wealth_wise/services/insights_service.dart';

class PremiumAnalyticsScreen extends StatefulWidget {
  @override
  const PremiumAnalyticsScreen({super.key});

  @override
  State<PremiumAnalyticsScreen> createState() => _PremiumAnalyticsScreenState();
}

class _PremiumAnalyticsScreenState extends State<PremiumAnalyticsScreen> {
  bool _isLoading = true;
  bool _hasAccess = false;
  final _logger = Logger('PremiumAnalyticsScreen');

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    setState(() => _isLoading = true);

    try {
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
          _hasAccess = hasAccess;
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasAccess = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      _logger.warning('Error checking premium access: $e');
      setState(() {
        _hasAccess = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium Analytics'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_hasAccess
              ? _buildPremiumPrompt()
              : _buildPremiumAnalytics(),
    );
  }

  Widget _buildPremiumPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics,
            size: 64,
            color: AppTheme.primaryGreen.withValues(alpha: 180),
          ),
          const SizedBox(height: 16),
          const Text(
            'Advanced Analytics',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Unlock detailed financial insights and personalized reports with Premium subscription',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              PremiumFeaturePrompt.showPremiumDialog(
                context,
                featureName: 'Advanced Analytics',
                description:
                    'Get detailed spending insights, savings projections, and personalized financial advice with Premium.',
                icon: Icons.insights,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'Upgrade to Premium',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumAnalytics() {
    final financeProvider = Provider.of<FinanceProvider>(context);
    final transactions = financeProvider.transactions;
    final budgets = financeProvider.budgets;
    final goals = financeProvider.savingGoals;

    // Compute real insights
    final healthScore = InsightsService.financialHealthScore(
      totalIncome: financeProvider.totalIncome,
      totalExpenses: financeProvider.totalExpenses,
      budgets: budgets,
      goals: goals,
    );
    final momChange = InsightsService.monthOverMonthChange(transactions);
    final adherence = InsightsService.budgetAdherenceScore(budgets);
    final monthlyData = InsightsService.monthlyTotals(transactions, months: 6);
    final categoryData = InsightsService.categoryBreakdown(transactions);
    final weekdayData = InsightsService.weekdaySpending(transactions);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Financial Health Score
          _buildHealthScoreCard(healthScore),
          const SizedBox(height: 16),

          // Monthly spending trend (real data)
          _buildCard(
            title: 'Spending Trend (6 Months)',
            child: Column(
              children: [
                const SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  child: LineChart(_buildSpendingTrendChart(monthlyData)),
                ),
                const SizedBox(height: 16),
                if (momChange != null)
                  _buildInsightItem(
                    icon: momChange <= 0
                        ? Icons.arrow_circle_down
                        : Icons.arrow_circle_up,
                    title:
                        'Spending is ${momChange <= 0 ? 'down' : 'up'} ${momChange.abs().toStringAsFixed(1)}% from last month',
                    color: momChange <= 0 ? Colors.green : Colors.orange,
                  ),
                _buildInsightItem(
                  icon: Icons.check_circle,
                  title:
                      'Budget adherence: ${adherence.toStringAsFixed(0)}% of budgets on track',
                  color: adherence >= 75 ? Colors.green : Colors.orange,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Income vs Expenses (real data)
          _buildCard(
            title: 'Income vs Expenses',
            child: Column(
              children: [
                const SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  child: BarChart(_buildIncomeVsExpenseChart(monthlyData)),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLegendItem('Income', Colors.blue),
                    const SizedBox(width: 16),
                    _buildLegendItem('Expenses', Colors.red),
                  ],
                ),
                const SizedBox(height: 16),
                if (financeProvider.totalIncome > 0)
                  _buildInsightItem(
                    icon: Icons.savings,
                    title:
                        'Savings rate: ${((financeProvider.totalIncome - financeProvider.totalExpenses) / financeProvider.totalIncome * 100).toStringAsFixed(1)}%',
                    color: Colors.green,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Category breakdown (pie chart)
          if (categoryData.isNotEmpty)
            _buildCard(
              title: 'Spending by Category',
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: PieChart(_buildCategoryPieChart(categoryData)),
                  ),
                  const SizedBox(height: 16),
                  ...categoryData.entries.take(5).map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _getCategoryColor(
                                    categoryData.keys.toList().indexOf(e.key)),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(e.key)),
                            Text(CurrencyFormatter.formatWithContext(
                                context, e.value)),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // Weekday spending pattern
          _buildCard(
            title: 'Spending by Day of Week',
            child: Column(
              children: [
                const SizedBox(height: 8),
                SizedBox(
                  height: 160,
                  child: BarChart(_buildWeekdayChart(weekdayData)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Savings goal projections
          if (goals.isNotEmpty)
            _buildCard(
              title: 'Savings Projections',
              child: Column(
                children: goals.map((goal) {
                  final months =
                      InsightsService.monthsToGoal(goal, transactions);
                  return _buildInsightItem(
                    icon: goal.isCompleted
                        ? Icons.check_circle
                        : Icons.timelapse,
                    title: goal.isCompleted
                        ? '${goal.title} — Completed!'
                        : months != null
                            ? '${goal.title} — ~$months months to reach goal'
                            : '${goal.title} — Add contributions to see projection',
                    color: goal.isCompleted
                        ? Colors.green
                        : AppTheme.primaryGreen,
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHealthScoreCard(double score) {
    final label = InsightsService.healthScoreLabel(score);
    final color = score >= 80
        ? Colors.green
        : score >= 60
            ? AppTheme.primaryGreen
            : score >= 40
                ? Colors.orange
                : Colors.red;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 8,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                  Text(
                    score.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Financial Health Score',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold, color: color),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Based on savings, budgets & goals',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  LineChartData _buildSpendingTrendChart(List<MonthlyTotal> data) {
    final spots = data.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.expenses);
    }).toList();

    final maxY = data.fold<double>(
            0, (max, m) => m.expenses > max ? m.expenses : max) *
        1.2;

    return LineChartData(
      gridData: FlGridData(show: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index >= 0 && index < data.length) {
                return Text(
                  DateFormat('MMM').format(data[index].month),
                  style: const TextStyle(fontSize: 11),
                );
              }
              return const Text('');
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      minY: 0,
      maxY: maxY > 0 ? maxY : 100,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: AppTheme.primaryGreen,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            color: AppTheme.primaryGreen.withValues(alpha: 50),
          ),
        ),
      ],
    );
  }

  BarChartData _buildIncomeVsExpenseChart(List<MonthlyTotal> data) {
    final maxY = data.fold<double>(0, (max, m) {
          final v = m.income > m.expenses ? m.income : m.expenses;
          return v > max ? v : max;
        }) *
        1.2;

    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxY > 0 ? maxY : 100,
      gridData: FlGridData(show: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index >= 0 && index < data.length) {
                return Text(
                  DateFormat('MMM').format(data[index].month),
                  style: const TextStyle(fontSize: 11),
                );
              }
              return const Text('');
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      barGroups: data.asMap().entries.map((e) {
        return BarChartGroupData(
          x: e.key,
          barRods: [
            BarChartRodData(
              toY: e.value.income,
              color: Colors.blue,
              width: 14,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            BarChartRodData(
              toY: e.value.expenses,
              color: Colors.red,
              width: 14,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  PieChartData _buildCategoryPieChart(Map<String, double> data) {
    final total = data.values.fold<double>(0, (a, b) => a + b);
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return PieChartData(
      sectionsSpace: 2,
      centerSpaceRadius: 40,
      sections: entries.asMap().entries.map((e) {
        final percent = (e.value.value / total * 100);
        return PieChartSectionData(
          value: e.value.value,
          color: _getCategoryColor(e.key),
          title: percent >= 5 ? '${percent.toStringAsFixed(0)}%' : '',
          titleStyle: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          radius: 50,
        );
      }).toList(),
    );
  }

  BarChartData _buildWeekdayChart(List<double> data) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxY = data.fold<double>(0, (a, b) => a > b ? a : b) * 1.2;

    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxY > 0 ? maxY : 100,
      gridData: FlGridData(show: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final i = value.toInt();
              if (i >= 0 && i < 7) {
                return Text(days[i], style: const TextStyle(fontSize: 11));
              }
              return const Text('');
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      barGroups: data.asMap().entries.map((e) {
        return BarChartGroupData(
          x: e.key,
          barRods: [
            BarChartRodData(
              toY: e.value,
              color: AppTheme.secondaryBlue,
              width: 20,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Color _getCategoryColor(int index) {
    const colors = [
      Color(0xFF2E7D32), // green
      Color(0xFF1565C0), // blue
      Color(0xFFF57C00), // orange
      Color(0xFF7B1FA2), // purple
      Color(0xFFD32F2F), // red
      Color(0xFF00838F), // teal
      Color(0xFFC2185B), // pink
      Color(0xFF558B2F), // lime
      Color(0xFF4527A0), // deep purple
      Color(0xFF00695C), // dark teal
    ];
    return colors[index % colors.length];
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildInsightItem({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 26),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }
}
