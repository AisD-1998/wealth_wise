import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:wealth_wise/providers/finance_provider.dart';
import 'package:wealth_wise/providers/subscription_provider.dart';
import 'package:wealth_wise/utils/currency_formatter.dart';
import 'package:wealth_wise/widgets/premium_feature_prompt.dart';

class MonthlySnapshotScreen extends StatefulWidget {
  const MonthlySnapshotScreen({super.key});

  @override
  State<MonthlySnapshotScreen> createState() => _MonthlySnapshotScreenState();
}

class _MonthlySnapshotScreenState extends State<MonthlySnapshotScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _shareSnapshot() async {
    setState(() => _isSharing = true);
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/wealthwise_snapshot_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'My monthly financial snapshot from WealthWise',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Widget _buildSnapshotHeader(ThemeData theme, String monthLabel) {
    return Center(
      child: Column(
        children: [
          Icon(
            Icons.calendar_month,
            size: 40,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text(
            monthLabel,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Financial Snapshot',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBasicStats(
    BuildContext context,
    double income,
    double expenses,
    double netSavings,
    double savingsRate,
  ) {
    return [
      _buildStatRow(
        context, 'Total Income',
        CurrencyFormatter.formatWithContext(context, income), Colors.green,
      ),
      const SizedBox(height: 12),
      _buildStatRow(
        context, 'Total Expenses',
        CurrencyFormatter.formatWithContext(context, expenses), Colors.red,
      ),
      const SizedBox(height: 12),
      _buildStatRow(
        context, 'Net Savings',
        CurrencyFormatter.formatWithContext(context, netSavings),
        netSavings >= 0 ? Colors.green : Colors.red,
      ),
      const SizedBox(height: 12),
      _buildStatRow(
        context, 'Savings Rate',
        '${savingsRate.toStringAsFixed(1)}%',
        savingsRate >= 20 ? Colors.green : Colors.orange,
      ),
    ];
  }

  List<Widget> _buildTopCategoriesSection(
    BuildContext context,
    ThemeData theme,
    List<MapEntry<String, double>> topCategories,
    double expenses,
  ) {
    return [
      Text(
        'Top Spending Categories',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 8),
      if (topCategories.isEmpty)
        Text('No expenses recorded',
            style: TextStyle(color: Colors.grey[500]))
      else
        ...topCategories.take(3).map((entry) {
          final percent =
              expenses > 0 ? (entry.value / expenses * 100) : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(child: Text(entry.key)),
                Text(
                  '${CurrencyFormatter.formatWithContext(context, entry.value)} (${percent.toStringAsFixed(0)}%)',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          );
        }),
    ];
  }

  List<Widget> _buildGoalProgressSection(ThemeData theme, FinanceProvider provider) {
    return [
      Text(
        'Goal Progress',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 8),
      ...provider.savingGoals.take(3).map((goal) {
        final progress = goal.targetAmount > 0
            ? (goal.currentAmount / goal.targetAmount * 100)
            : 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(goal.title)),
                  Text(
                    '${progress.toStringAsFixed(0)}%',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: (progress / 100).clamp(0.0, 1.0),
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  goal.isCompleted
                      ? Colors.green
                      : theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        );
      }),
    ];
  }

  List<Widget> _buildPremiumContent(
    BuildContext context,
    ThemeData theme,
    FinanceProvider provider,
    List<MapEntry<String, double>> topCategories,
    double expenses,
    int withinBudget,
    int lastMonthTxnCount,
  ) {
    final budgets = provider.budgets;
    return [
      const SizedBox(height: 24),
      const Divider(),
      const SizedBox(height: 16),
      ..._buildTopCategoriesSection(context, theme, topCategories, expenses),
      const SizedBox(height: 16),
      if (budgets.isNotEmpty) ...[
        _buildStatRow(
          context, 'Budget Adherence',
          '$withinBudget / ${budgets.length} within budget',
          withinBudget == budgets.length ? Colors.green : Colors.orange,
        ),
        const SizedBox(height: 12),
      ],
      if (provider.savingGoals.isNotEmpty)
        ..._buildGoalProgressSection(theme, provider),
      const SizedBox(height: 16),
      _buildStatRow(
        context, 'Transactions',
        '$lastMonthTxnCount total', theme.colorScheme.primary,
      ),
    ];
  }

  Widget _buildFreeUserTeaser(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.primaryContainer.withValues(alpha: 30),
        child: InkWell(
          onTap: () {
            PremiumFeaturePrompt.showPremiumDialog(
              context,
              featureName: 'Full Monthly Snapshot',
              description:
                  'Upgrade to Premium for detailed category breakdowns, budget adherence, goal progress, and shareable snapshots.',
              icon: Icons.calendar_month,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.lock_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Upgrade for full breakdown & sharing',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<FinanceProvider>(context);
    final subProvider = Provider.of<SubscriptionProvider>(context);
    final isPremium = subProvider.isSubscribed;

    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1);
    final monthLabel = DateFormat('MMMM yyyy').format(lastMonth);

    final lastMonthTxns = provider.transactions.where((t) {
      return t.date.year == lastMonth.year && t.date.month == lastMonth.month;
    }).toList();

    final income = lastMonthTxns
        .where((t) => t.type.toString().contains('income'))
        .fold<double>(0, (sum, t) => sum + t.amount);
    final expenses = lastMonthTxns
        .where((t) => t.type.toString().contains('expense'))
        .fold<double>(0, (sum, t) => sum + t.amount);
    final netSavings = income - expenses;
    final savingsRate = income > 0 ? (netSavings / income * 100) : 0.0;

    final categoryMap = <String, double>{};
    for (final t in lastMonthTxns) {
      if (t.type.toString().contains('expense')) {
        final cat = t.category ?? 'Uncategorized';
        categoryMap[cat] = (categoryMap[cat] ?? 0) + t.amount;
      }
    }
    final topCategories = categoryMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final budgets = provider.budgets;
    final withinBudget = budgets.where((b) => b.spent <= b.amount).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Snapshot'),
        actions: [
          if (isPremium)
            IconButton(
              icon: _isSharing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share),
              onPressed: _isSharing ? null : _shareSnapshot,
              tooltip: 'Share as Image',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: RepaintBoundary(
          key: _repaintKey,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSnapshotHeader(theme, monthLabel),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                ..._buildBasicStats(
                    context, income, expenses, netSavings, savingsRate),
                if (isPremium)
                  ..._buildPremiumContent(
                    context, theme, provider, topCategories,
                    expenses, withinBudget, lastMonthTxns.length,
                  )
                else
                  _buildFreeUserTeaser(theme),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'WealthWise',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
