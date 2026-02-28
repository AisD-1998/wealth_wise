import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart' as app_model;
import '../models/saving_goal.dart';
import '../providers/auth_provider.dart';
import '../providers/category_provider.dart';
import '../models/category.dart';

import 'package:wealth_wise/widgets/loading_animation_utils.dart';
import 'package:wealth_wise/widgets/transaction_form_sheet.dart';
import 'package:wealth_wise/constants/app_strings.dart';

/// Utility class for common UI helper methods
class UIHelpers {
  /// Shows a modal bottom sheet with a form to add a new transaction.
  ///
  /// The form content is implemented by [TransactionFormSheet].
  static Future<void> showTransactionForm(
    BuildContext context,
    app_model.TransactionType type, {
    app_model.Transaction? existingTransaction,
  }) async {
    final availableCategories = await getCategoriesForType(context, type);

    if (context.mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) {
          return TransactionFormSheet(
            type: type,
            existingTransaction: existingTransaction,
            availableCategories: availableCategories,
            parentContext: context,
          );
        },
      );
    }
  }

  /// Shows a confirmation dialog with Material Design 3 styling
  static Future<bool> showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );

    // Return false if dialog was dismissed or cancelled
    return result ?? false;
  }

  /// Shows a loading indicator overlay
  static void showLoadingOverlay(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color:
                    Theme.of(context).colorScheme.shadow.withValues(alpha: 51),
                blurRadius: 12,
              ),
            ],
          ),
          child: LoadingAnimationUtils.smallDollarSpinner(size: 60),
        ),
      ),
    );
  }

  /// Shows a success message with Material Design 3 styling
  static void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Shows an error message with Material Design 3 styling
  static void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Show a dialog to select a saving goal to add funds to
  static Future<SavingGoal?> showSavingGoalSelector(
      BuildContext context, List<SavingGoal> savingGoals) async {
    if (savingGoals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You have no saving goals yet. Create one first.'),
        ),
      );
      return null;
    }

    return showDialog<SavingGoal>(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text('Select Saving Goal'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: savingGoals.length,
              itemBuilder: (context, index) {
                final goal = savingGoals[index];
                final progress = goal.currentAmount / goal.targetAmount;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        HexColor.fromHex(goal.colorCode ?? '#3C63F9'),
                    child: Icon(
                      getIconForGoalTitle(goal.title),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(goal.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '\$${goal.currentAmount.toStringAsFixed(2)} of \$${goal.targetAmount.toStringAsFixed(2)}',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor:
                            theme.colorScheme.primary.withValues(alpha: 26),
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).pop(goal);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  // Get an icon based on the goal title
  static IconData getIconForGoalTitle(String title) {
    final String lowercaseTitle = title.toLowerCase();
    if (lowercaseTitle.contains('home') || lowercaseTitle.contains('housing')) {
      return Icons.home;
    } else if (lowercaseTitle.contains('car') ||
        lowercaseTitle.contains('vehicle')) {
      return Icons.directions_car;
    } else if (lowercaseTitle.contains('vacation') ||
        lowercaseTitle.contains('travel')) {
      return Icons.beach_access;
    } else if (lowercaseTitle.contains('education') ||
        lowercaseTitle.contains('school')) {
      return Icons.school;
    } else if (lowercaseTitle.contains('emergency')) {
      return Icons.local_hospital;
    } else {
      return Icons.savings;
    }
  }

  /// Helper method to get categories for a specific transaction type
  static Future<List<String>> getCategoriesForType(
      BuildContext context, app_model.TransactionType type) async {
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.user == null) {
      return [];
    }

    // Load categories outside of build
    try {
      await categoryProvider.loadCategoriesByUser(authProvider.user!.uid);

      // Map transaction type to category type
      final categoryType = type == app_model.TransactionType.expense
          ? CategoryType.expense
          : CategoryType.income;

      // If no categories found for the user, return default categories
      if (categoryProvider.categories.isEmpty) {
        if (type == app_model.TransactionType.expense) {
          return [
            'Food & Groceries',
            'Transportation',
            'Entertainment',
            'Utilities',
            'Housing',
            'Health',
            'Shopping',
            'Education',
            'Personal Care',
            'Other'
          ];
        } else {
          return [
            'Salary',
            'Business',
            'Investments',
            'Gifts',
            'Allowance',
            AppStrings.kOtherIncome
          ];
        }
      }

      // Extract category names and ensure they're unique - filter by type
      final Set<String> uniqueCategoryNames = {};

      for (var category in categoryProvider.categories) {
        // Only include categories of the matching type
        if (category.type == categoryType) {
          // Safely access name property
          final name = category.name;
          if (name.isNotEmpty) {
            uniqueCategoryNames.add(name);
          }
        }
      }

      // Add 'Other' if not already in the list
      if (type == app_model.TransactionType.expense) {
        uniqueCategoryNames.add('Other');
      } else {
        uniqueCategoryNames.add(AppStrings.kOtherIncome);
      }

      return uniqueCategoryNames.toList();
    } catch (e) {
      // In case of error, return basic categories
      if (type == app_model.TransactionType.expense) {
        return [
          'Food & Groceries',
          'Transportation',
          'Entertainment',
          'Utilities',
          'Housing',
          'Health',
          'Other'
        ];
      } else {
        return ['Salary', 'Business', 'Investments', AppStrings.kOtherIncome];
      }
    }
  }
}

// Extension to create Color from hex string
extension HexColor on Color {
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}

// Extension to provide withValues method for Color
extension ColorExtension on Color {
  Color withValues({int? red, int? green, int? blue, int? alpha}) {
    return Color.fromARGB(
      alpha ?? a.toInt(),
      red ?? r.toInt(),
      green ?? g.toInt(),
      blue ?? b.toInt(),
    );
  }
}
