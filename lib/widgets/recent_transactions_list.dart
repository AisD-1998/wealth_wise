import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wealth_wise/models/transaction.dart';
import 'package:wealth_wise/utils/currency_formatter.dart';

class RecentTransactionsList extends StatelessWidget {
  final List<Transaction> transactions;
  final VoidCallback? onSeeAllPressed;
  final void Function(Transaction)? onTransactionTap;

  const RecentTransactionsList({
    super.key,
    required this.transactions,
    this.onSeeAllPressed,
    this.onTransactionTap,
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

  /// Map a category name to its corresponding icon, falling back to a
  /// directional arrow based on transaction type.
  static IconData _iconForCategory(String? category, bool isIncome) {
    const categoryIcons = <String, IconData>{
      'Food & Groceries': Icons.restaurant,
      'Food': Icons.restaurant,
      'Transport': Icons.directions_car,
      'Entertainment': Icons.movie,
      'Health': Icons.medical_services,
      'Utilities': Icons.power,
      'Housing': Icons.home,
      'Education': Icons.school,
      'Shopping': Icons.shopping_cart,
    };

    if (category != null && categoryIcons.containsKey(category)) {
      return categoryIcons[category]!;
    }
    return isIncome ? Icons.arrow_upward : Icons.arrow_downward;
  }

  Widget _buildTransactionItem(BuildContext context, Transaction transaction) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isIncome = transaction.type == TransactionType.income;
    final iconColor = isIncome ? Colors.green : Colors.red;
    final amountColor = isIncome ? Colors.green : Colors.red;
    final backgroundIconColor = isIncome
        ? Colors.green.withValues(alpha: 26)
        : Colors.red.withValues(alpha: 26);
    final iconData = _iconForCategory(transaction.category, isIncome);

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
      onTap: onTransactionTap != null
          ? () => onTransactionTap!(transaction)
          : null,
    );
  }
}
