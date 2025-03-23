import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wealth_wise/models/transaction.dart';

class RecentTransactionsList extends StatelessWidget {
  final List<Transaction> transactions;

  const RecentTransactionsList({
    super.key,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: transactions.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        return _buildTransactionItem(context, transaction);
      },
    );
  }

  Widget _buildTransactionItem(BuildContext context, Transaction transaction) {
    final isExpense = transaction.type == TransactionType.expense;
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isExpense ? Colors.red.shade100 : Colors.green.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          _getIconData(transaction.category ?? transaction.title),
          color: isExpense ? Colors.red : Colors.green,
          size: 24,
        ),
      ),
      title: Text(
        transaction.title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        '${transaction.category ?? 'Uncategorized'} • ${DateFormat('MMM dd, yyyy').format(transaction.date)}',
        style: TextStyle(
          fontSize: 12,
          color: theme.colorScheme.onSurface.withValues(alpha: 153),
        ),
      ),
      trailing: Text(
        '${isExpense ? '-' : '+'}\$${transaction.amount.toStringAsFixed(2)}',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: isExpense ? Colors.red : Colors.green,
        ),
      ),
    );
  }

  IconData _getIconData(String title) {
    final String lowercaseTitle = title.toLowerCase();

    if (lowercaseTitle.contains('home') ||
        lowercaseTitle.contains('rent') ||
        lowercaseTitle.contains('mortgage')) {
      return Icons.home;
    } else if (lowercaseTitle.contains('food') ||
        lowercaseTitle.contains('grocery') ||
        lowercaseTitle.contains('restaurant')) {
      return Icons.restaurant;
    } else if (lowercaseTitle.contains('transport') ||
        lowercaseTitle.contains('gas') ||
        lowercaseTitle.contains('car')) {
      return Icons.directions_car;
    } else if (lowercaseTitle.contains('shopping') ||
        lowercaseTitle.contains('clothes')) {
      return Icons.shopping_bag;
    } else if (lowercaseTitle.contains('entertainment') ||
        lowercaseTitle.contains('movie')) {
      return Icons.movie;
    } else if (lowercaseTitle.contains('health') ||
        lowercaseTitle.contains('medical')) {
      return Icons.medical_services;
    } else if (lowercaseTitle.contains('education') ||
        lowercaseTitle.contains('school')) {
      return Icons.school;
    } else if (lowercaseTitle.contains('bill') ||
        lowercaseTitle.contains('utility')) {
      return Icons.receipt;
    } else if (lowercaseTitle.contains('salary') ||
        lowercaseTitle.contains('income')) {
      return Icons.work;
    } else {
      return isIncome(title) ? Icons.arrow_downward : Icons.arrow_upward;
    }
  }

  bool isIncome(String title) {
    final String lowercaseTitle = title.toLowerCase();
    return lowercaseTitle.contains('salary') ||
        lowercaseTitle.contains('income') ||
        lowercaseTitle.contains('refund') ||
        lowercaseTitle.contains('deposit');
  }
}
