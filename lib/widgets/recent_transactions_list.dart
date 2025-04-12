import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wealth_wise/models/transaction.dart';
import 'package:wealth_wise/utils/currency_formatter.dart';

class RecentTransactionsList extends StatelessWidget {
  final List<Transaction> transactions;
  final VoidCallback? onSeeAllPressed;

  const RecentTransactionsList({
    super.key,
    required this.transactions,
    this.onSeeAllPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (transactions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 48,
                color: colorScheme.onSurface.withValues(alpha: 102),
              ),
              const SizedBox(height: 16),
              Text(
                'No transactions yet',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 179),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add your first transaction to start tracking',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 153),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: transactions.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: colorScheme.outlineVariant.withValues(alpha: 128),
        indent: 72, // Aligns with the leading edge of the text
      ),
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        return _buildTransactionItem(context, transaction);
      },
    );
  }

  Widget _buildTransactionItem(BuildContext context, Transaction transaction) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine color and icon based on transaction type
    final isIncome = transaction.type == TransactionType.income;
    final iconColor = isIncome ? Colors.green : Colors.red;
    final amountColor = isIncome ? Colors.green : Colors.red;
    final backgroundIconColor = isIncome
        ? Colors.green.withValues(alpha: 26)
        : Colors.red.withValues(alpha: 26);

    // Get icon based on category or use default for the transaction type
    IconData iconData;
    if (transaction.category == 'Food & Groceries' ||
        transaction.category == 'Food') {
      iconData = Icons.restaurant;
    } else if (transaction.category == 'Transport') {
      iconData = Icons.directions_car;
    } else if (transaction.category == 'Entertainment') {
      iconData = Icons.movie;
    } else if (transaction.category == 'Health') {
      iconData = Icons.medical_services;
    } else if (transaction.category == 'Utilities') {
      iconData = Icons.power;
    } else if (transaction.category == 'Housing') {
      iconData = Icons.home;
    } else if (transaction.category == 'Education') {
      iconData = Icons.school;
    } else if (transaction.category == 'Shopping') {
      iconData = Icons.shopping_cart;
    } else {
      // Default icons based on type
      iconData = isIncome ? Icons.arrow_upward : Icons.arrow_downward;
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 8.0,
      ),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: backgroundIconColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Icon(
            iconData,
            color: iconColor,
          ),
        ),
      ),
      title: Text(
        transaction.title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          Flexible(
            child: Text(
              transaction.category ?? 'Uncategorized',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Flexible(
            child: Text(
              ' • ${DateFormat('MMM d, yyyy').format(transaction.date)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Show goal indicator for income transactions with goals
          if (transaction.contributesToGoal) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.savings_outlined,
              size: 14,
              color: colorScheme.primary,
            ),
          ]
        ],
      ),
      trailing: Text(
        '${isIncome ? '+' : '-'}${CurrencyFormatter.formatWithContext(context, transaction.amount)}',
        style: theme.textTheme.titleMedium?.copyWith(
          color: amountColor,
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: () {
        // Navigate to transaction detail or edit screen
      },
    );
  }
}
