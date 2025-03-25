import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wealth_wise/models/expense.dart';
import 'package:wealth_wise/providers/category_provider.dart';
import 'package:intl/intl.dart';

class ExpenseListItem extends StatelessWidget {
  final Expense expense;

  const ExpenseListItem({
    super.key,
    required this.expense,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final category = categoryProvider.getCategoryById(expense.category);

    // Default colors if category not found
    final categoryColor = category?.color ?? Colors.grey;

    // Handle icon name and convert to IconData
    IconData categoryIcon = Icons.attach_money;
    if (category?.icon != null) {
      // Try to get the icon from the Icons class using reflection
      try {
        categoryIcon = IconData(
          int.tryParse(category!.icon) ??
              0xe5d3, // Default to category icon if parsing fails
          fontFamily: 'MaterialIcons',
        );
      } catch (e) {
        // Fallback to a safe default icon
        categoryIcon = Icons.attach_money;
      }
    }

    final categoryName = category?.name ?? 'Other';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Category icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: categoryColor.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                categoryIcon,
                color: categoryColor,
              ),
            ),

            const SizedBox(width: 12),

            // Expense details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        DateFormat('MMM d, yyyy').format(expense.date),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withAlpha(153),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: categoryColor.withAlpha(26),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          categoryName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: categoryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Amount
            Text(
              '-\$${expense.amount.toStringAsFixed(2)}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
