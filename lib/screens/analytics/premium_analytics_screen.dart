import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wealth_wise/controllers/feature_access_controller.dart';
import 'package:wealth_wise/providers/auth_provider.dart';
import 'package:wealth_wise/theme/app_theme.dart';
import 'package:wealth_wise/widgets/premium_feature_prompt.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:wealth_wise/services/database_service.dart';

class PremiumAnalyticsScreen extends StatefulWidget {
  @override
  const PremiumAnalyticsScreen({super.key});

  @override
  State<PremiumAnalyticsScreen> createState() => _PremiumAnalyticsScreenState();
}

class _PremiumAnalyticsScreenState extends State<PremiumAnalyticsScreen> {
  bool _isLoading = true;
  bool _hasAccess = false;
  final currencyFormat = NumberFormat.currency(symbol: '\$');
  final _logger = Logger('PremiumAnalyticsScreen');

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.user;

      if (user != null) {
        // Use the user data from Firebase Auth
        final userData =
            await Provider.of<DatabaseService>(context, listen: false)
                .getUserData(user.uid);

        // Check if user has access to premium analytics
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
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Unlock detailed financial insights and personalized reports with Premium subscription',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
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
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumAnalytics() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Monthly spending trend card
          _buildCard(
            title: 'Spending Analysis',
            child: Column(
              children: [
                const SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              const months = [
                                'Jan',
                                'Feb',
                                'Mar',
                                'Apr',
                                'May',
                                'Jun',
                                'Jul',
                                'Aug',
                                'Sep',
                                'Oct',
                                'Nov',
                                'Dec'
                              ];
                              final index = value.toInt();
                              if (index >= 0 && index < 12) {
                                return Text(months[index]);
                              }
                              return const Text('');
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _getRandomSpots(),
                          isCurved: true,
                          color: AppTheme.primaryGreen,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppTheme.primaryGreen.withValues(alpha: 100),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildInsightItem(
                  icon: Icons.arrow_circle_down,
                  title: 'Your spending is down 12% from last month',
                  color: Colors.green,
                ),
                _buildInsightItem(
                  icon: Icons.warning_amber,
                  title: 'Food spending is 25% higher than your budget',
                  color: Colors.orange,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Income vs Expense card
          _buildCard(
            title: 'Income vs Expenses',
            child: Column(
              children: [
                const SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: 2000,
                      gridData: FlGridData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              switch (value.toInt()) {
                                case 0:
                                  return const Text('Jan');
                                case 1:
                                  return const Text('Feb');
                                case 2:
                                  return const Text('Mar');
                                default:
                                  return const Text('');
                              }
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: [
                        _generateBarGroup(0, 1500, 1200),
                        _generateBarGroup(1, 1300, 1100),
                        _generateBarGroup(2, 1800, 1400),
                      ],
                    ),
                  ),
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
                _buildInsightItem(
                  icon: Icons.savings,
                  title: 'Your savings rate is 23% of income',
                  color: Colors.green,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Financial insights card
          _buildCard(
            title: 'Financial Insights',
            child: Column(
              children: [
                _buildInsightItem(
                  icon: Icons.trending_up,
                  title: 'Your net worth has increased by 8% this quarter',
                  color: Colors.green,
                ),
                _buildInsightItem(
                  icon: Icons.timelapse,
                  title:
                      'At your current rate, you\'ll reach your savings goal in 7 months',
                  color: AppTheme.primaryGreen,
                ),
                _buildInsightItem(
                  icon: Icons.psychology,
                  title:
                      'Your spending habits are more consistent than 78% of users',
                  color: Colors.purple,
                ),
                _buildInsightItem(
                  icon: Icons.pie_chart,
                  title:
                      'Consider diversifying your investments for better returns',
                  color: Colors.blue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
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
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
              ),
            ),
          ),
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
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }

  List<FlSpot> _getRandomSpots() {
    // Mock data for demonstration
    return [
      const FlSpot(0, 1000),
      const FlSpot(1, 1200),
      const FlSpot(2, 1300),
      const FlSpot(3, 1100),
      const FlSpot(4, 1400),
      const FlSpot(5, 1600),
      const FlSpot(6, 1200),
      const FlSpot(7, 1500),
      const FlSpot(8, 1700),
      const FlSpot(9, 1600),
      const FlSpot(10, 1400),
      const FlSpot(11, 1800),
    ];
  }

  BarChartGroupData _generateBarGroup(int x, double income, double expense) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: income,
          color: Colors.blue,
          width: 15,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(4),
          ),
        ),
        BarChartRodData(
          toY: expense,
          color: Colors.red,
          width: 15,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(4),
          ),
        ),
      ],
    );
  }
}
