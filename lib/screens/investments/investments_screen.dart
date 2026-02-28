import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:wealth_wise/models/investment.dart';
import 'package:wealth_wise/providers/finance_provider.dart';
import 'package:wealth_wise/screens/investments/add_investment_screen.dart';
import 'package:wealth_wise/utils/currency_formatter.dart';

class InvestmentsScreen extends StatelessWidget {
  const InvestmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Investments'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddInvestmentScreen()),
        ),
        child: const Icon(Icons.add),
      ),
      body: Consumer<FinanceProvider>(
        builder: (context, provider, _) {
          final investments = provider.investments;

          if (investments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.show_chart, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No investments yet',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Track your portfolio by adding holdings',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          final totalValue = provider.portfolioTotalValue;
          final totalCost = provider.portfolioTotalCost;
          final totalGainLoss = totalValue - totalCost;
          final totalGainLossPercent =
              totalCost > 0 ? (totalGainLoss / totalCost) * 100 : 0.0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Portfolio Summary Card
              Card(
                elevation: 0,
                color: theme.colorScheme.primaryContainer.withValues(alpha: 60),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        'Portfolio Value',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        CurrencyFormatter.formatWithContext(
                            context, totalValue),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            totalGainLoss >= 0
                                ? Icons.trending_up
                                : Icons.trending_down,
                            color:
                                totalGainLoss >= 0 ? Colors.green : Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${totalGainLoss >= 0 ? '+' : ''}${CurrencyFormatter.formatWithContext(context, totalGainLoss)} (${totalGainLossPercent.toStringAsFixed(1)}%)',
                            style: TextStyle(
                              color: totalGainLoss >= 0
                                  ? Colors.green
                                  : Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Allocation Pie Chart
              if (investments.length > 1) ...[
                Text(
                  'Allocation',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: _buildAllocationChart(context, investments),
                ),
                const SizedBox(height: 20),
              ],

              // Holdings
              Text(
                'Holdings',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...investments.map(
                  (inv) => _buildHoldingCard(context, inv, provider, totalValue)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAllocationChart(
      BuildContext context, List<Investment> investments) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.amber,
      Colors.indigo,
    ];

    final totalValue =
        investments.fold<double>(0, (sum, inv) => sum + inv.totalValue);

    return Row(
      children: [
        // Pie chart
        Expanded(
          child: PieChart(
            PieChartData(
              sections: investments.asMap().entries.map((entry) {
                final inv = entry.value;
                final color = colors[entry.key % colors.length];
                final percent = totalValue > 0
                    ? (inv.totalValue / totalValue * 100)
                    : 0.0;

                return PieChartSectionData(
                  color: color,
                  value: inv.totalValue,
                  title: percent >= 5 ? '${percent.toStringAsFixed(0)}%' : '',
                  radius: 50,
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList(),
              sectionsSpace: 2,
              centerSpaceRadius: 30,
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Legend
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: investments.asMap().entries.map((entry) {
              final inv = entry.value;
              final color = colors[entry.key % colors.length];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        inv.name,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildHoldingCard(
    BuildContext context,
    Investment inv,
    FinanceProvider provider,
    double totalValue,
  ) {
    final theme = Theme.of(context);
    final isGain = inv.gainLoss >= 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isGain
              ? Colors.green.withValues(alpha: 30)
              : Colors.red.withValues(alpha: 30),
          child: Icon(
            _getTypeIcon(inv.type),
            color: isGain ? Colors.green : Colors.red,
            size: 22,
          ),
        ),
        title: Text(
          inv.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Row(
          children: [
            Text(
              inv.type.label,
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            const SizedBox(width: 8),
            Text(
              '${inv.quantity} shares',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              CurrencyFormatter.formatWithContext(context, inv.totalValue),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${isGain ? '+' : ''}${inv.gainLossPercent.toStringAsFixed(1)}%',
              style: TextStyle(
                color: isGain ? Colors.green : Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => AddInvestmentScreen(existingInvestment: inv)),
        ),
        onLongPress: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete Investment'),
              content: Text('Delete "${inv.name}"? This cannot be undone.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child:
                      const Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
          if (confirm == true && inv.id != null && context.mounted) {
            await provider.deleteInvestment(inv.id!);
          }
        },
      ),
    );
  }

  IconData _getTypeIcon(InvestmentType type) {
    switch (type) {
      case InvestmentType.stock:
        return Icons.show_chart;
      case InvestmentType.etf:
        return Icons.pie_chart_outline;
      case InvestmentType.bond:
        return Icons.account_balance;
      case InvestmentType.crypto:
        return Icons.currency_bitcoin;
      case InvestmentType.realEstate:
        return Icons.home_work;
      case InvestmentType.mutualFund:
        return Icons.analytics;
      case InvestmentType.other:
        return Icons.attach_money;
    }
  }
}
