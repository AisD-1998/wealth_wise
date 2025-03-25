import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart' as app_model;
import '../models/saving_goal.dart';
import '../providers/finance_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/category_provider.dart';

/// Utility class for common UI helper methods
class UIHelpers {
  /// Shows a modal bottom sheet with a form to add a new transaction.
  static Future<void> showTransactionForm(
    BuildContext context,
    app_model.TransactionType type, {
    app_model.Transaction? existingTransaction,
  }) async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final dateController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();
    String? selectedCategory;
    bool contributesToGoal = false; // Add for goal contributions

    // If editing an existing transaction, pre-fill the form
    if (existingTransaction != null) {
      titleController.text = existingTransaction.title;
      amountController.text = existingTransaction.amount.toString();
      noteController.text = existingTransaction.note ?? '';
      selectedDate = existingTransaction.date;
      selectedTime = TimeOfDay.fromDateTime(existingTransaction.date);
      dateController.text = DateFormat('MMMM d, yyyy').format(selectedDate);
      selectedCategory = existingTransaction.category;
      contributesToGoal = existingTransaction
          .contributesToGoal; // Set from existing transaction
    } else {
      dateController.text = DateFormat('MMMM d, yyyy').format(selectedDate);
    }

    void saveTransaction() async {
      if (formKey.currentState!.validate()) {
        final financeProvider =
            Provider.of<FinanceProvider>(context, listen: false);
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final userId = authProvider.user?.uid;

        if (userId != null) {
          final amount = double.parse(amountController.text);
          final date = DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
            selectedTime.hour,
            selectedTime.minute,
          );

          try {
            bool success;

            if (existingTransaction != null) {
              // Update existing transaction
              final updatedTransaction = app_model.Transaction(
                id: existingTransaction.id,
                title: titleController.text,
                amount: amount,
                type: type,
                date: date,
                category: selectedCategory,
                note: noteController.text.isEmpty ? null : noteController.text,
                userId: userId,
                contributesToGoal: contributesToGoal,
              );

              success =
                  await financeProvider.updateTransaction(updatedTransaction);

              if (success) {
                // Reload data
                await financeProvider.initializeFinanceData(userId);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Transaction updated successfully')),
                  );
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(financeProvider.error ??
                            'Failed to update transaction')),
                  );
                }
              }
            } else {
              // Create new transaction
              final transaction = app_model.Transaction(
                title: titleController.text,
                amount: amount,
                type: type,
                date: date,
                category: selectedCategory,
                note: noteController.text.isEmpty ? null : noteController.text,
                userId: userId,
                contributesToGoal: contributesToGoal,
              );

              success = await financeProvider.addTransaction(transaction);

              if (success) {
                // Reload data
                await financeProvider.initializeFinanceData(userId);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Transaction added successfully')),
                  );
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(financeProvider.error ??
                            'Failed to add transaction')),
                  );
                }
              }
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            }
          }
        }
      }
    }

    Future<void> selectDate() async {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 1)),
      );
      if (picked != null && picked != selectedDate && context.mounted) {
        selectedDate = picked;
        dateController.text = DateFormat('MMMM d, yyyy').format(selectedDate);
      }
    }

    Future<void> selectTime() async {
      final TimeOfDay? picked = await showTimePicker(
        context: context,
        initialTime: selectedTime,
      );
      if (picked != null && context.mounted) {
        selectedTime = picked;
      }
    }

    final availableCategories = await getCategoriesForType(context, type);

    if (context.mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          existingTransaction != null
                              ? 'Edit ${type == app_model.TransactionType.income ? "Income" : "Expense"}'
                              : 'Add ${type == app_model.TransactionType.income ? "Income" : "Expense"}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'Title',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a title';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: amountController,
                          decoration: const InputDecoration(
                            labelText: 'Amount',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.attach_money),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}$'),
                            ),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter an amount';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Please enter a valid number';
                            }
                            if (double.parse(value) <= 0) {
                              return 'Amount must be greater than zero';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category),
                          ),
                          items: [
                            ...availableCategories.map((category) {
                              return DropdownMenuItem<String>(
                                value: category,
                                child: Text(category),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setState(() {
                              selectedCategory = value;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a category';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: selectDate,
                          child: AbsorbPointer(
                            child: TextFormField(
                              controller: dateController,
                              decoration: const InputDecoration(
                                labelText: 'Date',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.calendar_today),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select a date';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () async {
                            await selectTime();
                            setState(() {});
                          },
                          child: AbsorbPointer(
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Time',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.access_time),
                              ),
                              child: Text(selectedTime.format(context)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: noteController,
                          decoration: const InputDecoration(
                            labelText: 'Notes (Optional)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.note),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),

                        // Add checkbox for contributesToGoal - only for expense type
                        if (type == app_model.TransactionType.expense)
                          CheckboxListTile(
                            title: const Text('Contributes to saving goal'),
                            value: contributesToGoal,
                            onChanged: (newValue) {
                              setState(() {
                                contributesToGoal = newValue ?? false;
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                          ),

                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: saveTransaction,
                              child: Text(
                                existingTransaction != null ? 'Update' : 'Save',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
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
          child: const CircularProgressIndicator(),
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
                      _getIconForGoalTitle(goal.title),
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
  static IconData _getIconForGoalTitle(String title) {
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

    // Make sure categories are loaded
    await categoryProvider.loadCategoriesByUser(authProvider.user!.uid);

    // Default categories for expenses if there are none in the database
    if (categoryProvider.categories.isEmpty &&
        type == app_model.TransactionType.expense) {
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
    }

    // Default categories for income if there are none in the database
    if (categoryProvider.categories.isEmpty &&
        type == app_model.TransactionType.income) {
      return [
        'Salary',
        'Business',
        'Investments',
        'Gifts',
        'Allowance',
        'Other Income'
      ];
    }

    // Extract category names and ensure they're unique
    final Set<String> uniqueCategoryNames = categoryProvider.categories
        .map((category) => category.name)
        .toSet(); // Using toSet() to remove duplicates

    return uniqueCategoryNames.toList();
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
