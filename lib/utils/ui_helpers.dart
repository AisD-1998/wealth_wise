import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart' as app_model;
import '../models/saving_goal.dart';
import '../providers/finance_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/category_provider.dart';
import 'package:logging/logging.dart';

/// Utility class for common UI helper methods
class UIHelpers {
  static final _logger = Logger('UIHelpers');

  /// Shows a modal bottom sheet with a form to add a new transaction.
  static Future<void> showTransactionForm(
    BuildContext context,
    app_model.TransactionType type, {
    app_model.Transaction? existingTransaction,
  }) async {
    // Get providers early to avoid deactivated context issues
    final financeProvider =
        Provider.of<FinanceProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final dateController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();
    String? selectedCategory;
    bool contributesToGoal = false; // Add for goal contributions
    String? selectedGoalId; // Track the selected goal ID

    // If editing an existing transaction, pre-fill the form
    if (existingTransaction != null) {
      titleController.text = existingTransaction.title;
      amountController.text = existingTransaction.amount.toString();
      noteController.text = existingTransaction.note ?? '';
      selectedDate = existingTransaction.date;
      selectedTime = TimeOfDay.fromDateTime(existingTransaction.date);
      dateController.text = DateFormat('MMMM d, yyyy').format(selectedDate);
      selectedCategory = existingTransaction.category;
      contributesToGoal = existingTransaction.contributesToGoal;
      selectedGoalId = existingTransaction.goalId; // Set the initial goal ID
    } else {
      dateController.text = DateFormat('MMMM d, yyyy').format(selectedDate);
    }

    void saveTransaction(BuildContext innerContext) {
      if (!formKey.currentState!.validate()) {
        return;
      }

      final userId = authProvider.user?.uid;
      if (userId == null) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('User not authenticated. Please log in again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final amount = double.parse(amountController.text);
      final date = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );

      // Create the transaction object
      final transaction = app_model.Transaction(
        id: existingTransaction?.id,
        title: titleController.text,
        amount: amount,
        type: type,
        date: date,
        category: selectedCategory,
        note: noteController.text.isEmpty ? null : noteController.text,
        userId: userId,
        goalId: type == app_model.TransactionType.income && contributesToGoal
            ? selectedGoalId
            : null,
      );

      // Flag to remember whether we're updating or creating a new transaction
      final isUpdate = existingTransaction != null;

      // If this is an income transaction with a goal, check if it will exceed the goal
      if (transaction.type == app_model.TransactionType.income &&
          contributesToGoal &&
          selectedGoalId != null) {
        final matchingGoals = financeProvider.savingGoals
            .where((g) => g.id == selectedGoalId)
            .toList();

        if (matchingGoals.isNotEmpty) {
          final selectedGoal = matchingGoals.first;
          final willExceedTarget =
              (selectedGoal.currentAmount + amount) > selectedGoal.targetAmount;

          if (willExceedTarget) {
            final overAmount = (selectedGoal.currentAmount + amount) -
                selectedGoal.targetAmount;

            // Close the form first, then handle the rest
            Navigator.of(innerContext).pop();

            // Now show the dialog with parent context
            _checkGoalAndProcessTransaction(
              context: context, // Use the parent context
              selectedGoal: selectedGoal,
              amount: amount,
              overAmount: overAmount,
              transaction: transaction,
              isUpdate: isUpdate,
              userId: userId,
              financeProvider: financeProvider,
              scaffoldMessenger: scaffoldMessenger,
            );

            return;
          }
        }
      }

      // No goal check needed, just pop the form
      Navigator.of(innerContext).pop();

      // Process the transaction without any additional checks
      _processTransaction(
        transaction: transaction,
        isUpdate: isUpdate,
        userId: userId,
        financeProvider: financeProvider,
        scaffoldMessenger: scaffoldMessenger,
      );
    }

    Future<void> selectDate(
        BuildContext innerContext, StateSetter setState) async {
      final DateTime? picked = await showDatePicker(
        context: innerContext,
        initialDate: selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 1)),
      );
      if (picked != null && picked != selectedDate) {
        setState(() {
          selectedDate = picked;
          dateController.text = DateFormat('MMMM d, yyyy').format(selectedDate);
        });
      }
    }

    Future<void> selectTime(
        BuildContext innerContext, StateSetter setState) async {
      final TimeOfDay? picked = await showTimePicker(
        context: innerContext,
        initialTime: selectedTime,
      );
      if (picked != null) {
        setState(() {
          selectedTime = picked;
        });
      }
    }

    final availableCategories = await getCategoriesForType(context, type);

    if (context.mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (innerContext) {
          return StatefulBuilder(
            builder: (innerContext, setState) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(innerContext).viewInsets.bottom,
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
                            const DropdownMenuItem<String>(
                              value: '',
                              child: Text('Select a category'),
                            ),
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
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down),
                          dropdownColor:
                              Theme.of(innerContext).colorScheme.surface,
                          style: Theme.of(innerContext).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () => selectDate(innerContext, setState),
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
                          onTap: () => selectTime(innerContext, setState),
                          child: AbsorbPointer(
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Time',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.access_time),
                              ),
                              child: Text(selectedTime.format(innerContext)),
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

                        // Replace checkbox with dropdown for saving goals - only for income transactions
                        if (type == app_model.TransactionType.income &&
                            financeProvider.savingGoals.isNotEmpty) ...[
                          DropdownButtonFormField<String?>(
                            decoration: const InputDecoration(
                              labelText: 'Contribute to Saving Goal',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.savings),
                            ),
                            hint: const Text('Select a goal (optional)'),
                            value: selectedGoalId,
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('None'),
                              ),
                              ...financeProvider.savingGoals.map((goal) {
                                _logger.info(
                                    "Goal in dropdown: ${goal.title} (${goal.id})");
                                return DropdownMenuItem<String?>(
                                  value: goal.id,
                                  child: Text(goal.title),
                                );
                              }),
                            ],
                            onChanged: (goalId) {
                              setState(() {
                                selectedGoalId = goalId;
                                contributesToGoal = goalId != null;

                                if (contributesToGoal && goalId != null) {
                                  // Find the goal with this ID
                                  final matchingGoals = financeProvider
                                      .savingGoals
                                      .where((goal) => goal.id == goalId)
                                      .toList();

                                  if (matchingGoals.isNotEmpty) {
                                    final selectedGoal = matchingGoals.first;
                                    _logger.info(
                                        "Selected goal: ${selectedGoal.title} (${selectedGoal.id})");

                                    // Set the transaction title to reflect the goal contribution
                                    if (titleController.text.isEmpty ||
                                        titleController.text
                                            .startsWith('Contribution to ')) {
                                      titleController.text =
                                          'Contribution to ${selectedGoal.title}';
                                    }
                                  }
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                        ],

                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(innerContext);
                              },
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => saveTransaction(innerContext),
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
            'Other Income'
          ];
        }
      }

      // Extract category names and ensure they're unique
      final Set<String> uniqueCategoryNames = {};

      for (var category in categoryProvider.categories) {
        // Safely access name property
        final name = category.name;
        if (name.isNotEmpty) {
          uniqueCategoryNames.add(name);
        }
      }

      // Add 'Other' if not already in the list
      uniqueCategoryNames.add('Other');

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
        return ['Salary', 'Business', 'Investments', 'Other Income'];
      }
    }
  }

  // This static method handles goal confirmation and transaction processing
  static void _checkGoalAndProcessTransaction({
    required BuildContext context,
    required SavingGoal selectedGoal,
    required double amount,
    required double overAmount,
    required app_model.Transaction transaction,
    required bool isUpdate,
    required String userId,
    required FinanceProvider financeProvider,
    required ScaffoldMessengerState scaffoldMessenger,
  }) async {
    final shouldProceed = await showConfirmationDialog(
      context: context,
      title: 'Goal Will Be Exceeded',
      message:
          'This goal "${selectedGoal.title}" is already at \$${selectedGoal.currentAmount.toStringAsFixed(2)} of \$${selectedGoal.targetAmount.toStringAsFixed(2)}. Adding \$${amount.toStringAsFixed(2)} will exceed the target by \$${overAmount.toStringAsFixed(2)}. Do you wish to continue?',
      confirmText: 'Continue',
      cancelText: 'Cancel',
    );

    if (!shouldProceed) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Transaction operation canceled'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _processTransaction(
      transaction: transaction,
      isUpdate: isUpdate,
      userId: userId,
      financeProvider: financeProvider,
      scaffoldMessenger: scaffoldMessenger,
    );
  }

  // This static method handles the actual transaction processing
  static void _processTransaction({
    required app_model.Transaction transaction,
    required bool isUpdate,
    required String userId,
    required FinanceProvider financeProvider,
    required ScaffoldMessengerState scaffoldMessenger,
  }) async {
    // Show loading indicator
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
            SizedBox(width: 16),
            Text('Saving changes...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      // Process the transaction
      if (isUpdate) {
        // Update existing transaction
        final result = await financeProvider.updateTransaction(transaction);

        if (result['success']) {
          // Reload data
          await financeProvider.initializeFinanceData(userId);

          if (result['goalChanged'] ||
              result['goalAdded'] ||
              result['goalRemoved'] ||
              result['amountChanged']) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(result['message']),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            scaffoldMessenger.showSnackBar(
              const SnackBar(
                content: Text('Transaction updated successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // Create new transaction
        final success = await financeProvider.addTransaction(transaction);

        if (success) {
          // Reload data
          await financeProvider.initializeFinanceData(userId);

          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Transaction added successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content:
                  Text(financeProvider.error ?? 'Failed to add transaction'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
