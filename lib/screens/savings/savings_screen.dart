import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wealth_wise/models/saving_goal.dart';
import 'package:wealth_wise/providers/finance_provider.dart';
import 'package:wealth_wise/screens/savings/create_saving_goal_screen.dart';
import 'package:wealth_wise/widgets/custom_action_button.dart';
import 'package:wealth_wise/utils/currency_formatter.dart';

class SavingsScreen extends StatelessWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final financeProvider = Provider.of<FinanceProvider>(context);
    final savingGoals = financeProvider.savingGoals;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Savings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () {
              _showSortOptions(context);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Total savings summary card
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Savings',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          CurrencyFormatter.formatWithContext(
                              context, _calculateTotalSavings(savingGoals)),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'of ${CurrencyFormatter.formatWithContext(context, _calculateTotalGoals(savingGoals))}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(153),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: _calculateOverallProgress(savingGoals),
                      backgroundColor: theme.colorScheme.primary.withAlpha(26),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_calculateOverallProgress(savingGoals) * 100).toInt()}% of total goal',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withAlpha(153),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Saving goals section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Saving Goals',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  CustomActionButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateSavingGoalScreen(),
                        ),
                      );
                    },
                    label: 'Create Goal',
                    icon: Icons.add_circle_outline,
                    isSmall: true,
                  ),
                ],
              ),
            ),

            // Saving goals list
            Expanded(
              child: savingGoals.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.savings,
                            size: 64,
                            color: theme.colorScheme.primary.withAlpha(128),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No saving goals yet',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start by creating a new saving goal',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withAlpha(153),
                            ),
                          ),
                          const SizedBox(height: 24),
                          CustomActionButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const CreateSavingGoalScreen(),
                                ),
                              );
                            },
                            label: 'Create Goal',
                            icon: Icons.add_circle_outline,
                            isSmall: true,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: savingGoals.length,
                      itemBuilder: (context, index) {
                        final goal = savingGoals[index];
                        return _buildSavingGoalCard(goal, theme, context);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateTotalSavings(List<SavingGoal> goals) {
    return goals.fold(0, (sum, goal) => sum + goal.currentAmount);
  }

  double _calculateTotalGoals(List<SavingGoal> goals) {
    return goals.fold(0, (sum, goal) => sum + goal.targetAmount);
  }

  double _calculateOverallProgress(List<SavingGoal> goals) {
    if (goals.isEmpty) return 0;
    final totalSavings = _calculateTotalSavings(goals);
    final totalGoals = _calculateTotalGoals(goals);
    return totalGoals > 0 ? (totalSavings / totalGoals).clamp(0.0, 1.0) : 0;
  }

  Widget _buildSavingGoalCard(
      SavingGoal goal, ThemeData theme, BuildContext context) {
    final progress = goal.currentAmount / goal.targetAmount;
    final color = HexColor.fromHex(goal.colorCode ?? '#3C63F9');
    final remainingAmount = goal.targetAmount - goal.currentAmount;
    final isCompleted = goal.currentAmount >= goal.targetAmount;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Goal icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 26),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getIconData(goal.title),
                    color: color,
                    size: 24,
                  ),
                ),

                const SizedBox(width: 16),

                // Goal title and progress percentage
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (goal.description != null &&
                          goal.description!.isNotEmpty)
                        Text(
                          goal.description!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 153),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),

                // Progress percentage badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Colors.green.withValues(alpha: 26)
                        : theme.colorScheme.primary.withValues(alpha: 26),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    isCompleted ? 'Completed!' : '${(progress * 100).toInt()}%',
                    style: TextStyle(
                      color: isCompleted
                          ? Colors.green
                          : theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Progress values
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  CurrencyFormatter.formatWithContext(
                      context, goal.currentAmount),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  CurrencyFormatter.formatWithContext(
                      context, goal.targetAmount),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 153),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 26),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isCompleted ? Colors.green : color,
                ),
                minHeight: 8,
              ),
            ),

            const SizedBox(height: 16),

            // Target date and actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Remaining amount or completion message
                Expanded(
                  child: isCompleted
                      ? Text(
                          'Goal completed! 🎉',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : goal.targetDate != null
                          ? Text(
                              'Target date: ${_formatDate(goal.targetDate!)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 153),
                              ),
                            )
                          : Text(
                              '${CurrencyFormatter.formatWithContext(context, remainingAmount)} remaining',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 153),
                              ),
                            ),
                ),

                // Action buttons
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () {
                        _showGoalOptions(context, goal);
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconData(String title) {
    final String lowercaseTitle = title.toLowerCase();
    if (lowercaseTitle.contains('home') || lowercaseTitle.contains('housing')) {
      return Icons.home;
    } else if (lowercaseTitle.contains('food') ||
        lowercaseTitle.contains('grocery')) {
      return Icons.fastfood;
    } else if (lowercaseTitle.contains('vacation') ||
        lowercaseTitle.contains('travel')) {
      return Icons.beach_access;
    } else if (lowercaseTitle.contains('education') ||
        lowercaseTitle.contains('school')) {
      return Icons.school;
    } else if (lowercaseTitle.contains('car') ||
        lowercaseTitle.contains('vehicle')) {
      return Icons.directions_car;
    } else {
      return Icons.savings;
    }
  }

  String _formatDate(DateTime date) {
    final months = [
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _showSortOptions(BuildContext context) {
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
                'Sort Saving Goals',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.sort_by_alpha),
                title: const Text('Alphabetical'),
                onTap: () {
                  Navigator.pop(context);
                  // Apply sort
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_upward),
                title: const Text('Progress (Low to High)'),
                onTap: () {
                  Navigator.pop(context);
                  // Apply sort
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_downward),
                title: const Text('Progress (High to Low)'),
                onTap: () {
                  Navigator.pop(context);
                  // Apply sort
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Target Date'),
                onTap: () {
                  Navigator.pop(context);
                  // Apply sort
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showGoalOptions(BuildContext context, SavingGoal goal) {
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
                'Goal Options',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Goal'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          CreateSavingGoalScreen(existingGoal: goal),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Delete Goal',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(context, goal);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, SavingGoal goal) {
    final financeProvider =
        Provider.of<FinanceProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Goal?'),
          content: Text(
            'Are you sure you want to delete "${goal.title}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final success = await financeProvider.deleteSavingGoal(goal);
                if (context.mounted) {
                  Navigator.pop(context);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${goal.title} has been deleted'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to delete ${goal.title}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}

extension HexColor on Color {
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
