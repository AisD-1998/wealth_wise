import 'package:flutter/material.dart';

class BalanceCard extends StatelessWidget {
  final double balance;
  final double income;
  final double expenses;

  const BalanceCard({
    super.key,
    required this.balance,
    required this.income,
    required this.expenses,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withValues(alpha: 179),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Balance',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '\$${balance.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildBalanceItem(
                    context,
                    title: 'Income',
                    amount: income,
                    isPositive: true,
                  ),
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: Colors.white30,
                ),
                Expanded(
                  child: _buildBalanceItem(
                    context,
                    title: 'Expenses',
                    amount: expenses,
                    isPositive: false,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceItem(
    BuildContext context, {
    required String title,
    required double amount,
    required bool isPositive,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${isPositive ? '+' : '-'}\$${amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: isPositive ? Colors.green.shade100 : Colors.red.shade100,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
