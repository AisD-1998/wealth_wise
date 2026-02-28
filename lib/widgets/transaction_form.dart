import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import 'package:wealth_wise/models/transaction.dart';
import 'package:wealth_wise/models/saving_goal.dart';
import 'package:wealth_wise/models/category.dart';
import 'package:wealth_wise/providers/auth_provider.dart';
import 'package:wealth_wise/providers/finance_provider.dart';
import 'package:wealth_wise/providers/category_provider.dart';
import 'package:wealth_wise/utils/ui_helpers.dart';
import 'package:wealth_wise/widgets/loading_animation_utils.dart';

extension RecurrencePatternLabel on RecurrencePattern {
  String get label {
    switch (this) {
      case RecurrencePattern.daily:
        return 'Daily';
      case RecurrencePattern.weekly:
        return 'Weekly';
      case RecurrencePattern.biweekly:
        return 'Every 2 weeks';
      case RecurrencePattern.monthly:
        return 'Monthly';
      case RecurrencePattern.yearly:
        return 'Yearly';
    }
  }
}

class TransactionForm extends StatefulWidget {
  final Transaction? transaction;
  final Function(bool)? onComplete;
  final TransactionType? initialType;

  const TransactionForm({
    super.key,
    this.transaction,
    this.onComplete,
    this.initialType,
  });

  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  final logger = Logger('TransactionForm');
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late TextEditingController _noteController;
  late TextEditingController _percentageController;

  TransactionType _selectedType = TransactionType.expense;
  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _saveToSavingsGoal = false;
  SavingGoal? _selectedSavingGoal;
  double _contributionPercentage = 100.0;
  bool _isRecurring = false;
  RecurrencePattern _recurrencePattern = RecurrencePattern.monthly;
  DateTime? _recurrenceEndDate;

  @override
  void initState() {
    super.initState();
    _initForm();

    // Add listener to amount field to update UI
    _amountController.addListener(_updateUI);
  }

  void _initForm() {
    // Initialize controllers
    _titleController =
        TextEditingController(text: widget.transaction?.title ?? '');
    _amountController = TextEditingController(
      text: widget.transaction?.amount.toString() ?? '',
    );
    _noteController =
        TextEditingController(text: widget.transaction?.note ?? '');
    _percentageController = TextEditingController(text: '100');

    // Set initial values if editing
    if (widget.transaction != null) {
      _selectedType = widget.transaction!.type;
      _selectedCategory = widget.transaction!.category;
      _selectedDate = widget.transaction!.date;
      _contributionPercentage =
          widget.transaction!.contributionPercentage ?? 100.0;
      _percentageController.text = _contributionPercentage.toStringAsFixed(0);

      _isRecurring = widget.transaction!.isRecurring;
      if (widget.transaction!.recurrencePattern != null) {
        _recurrencePattern = widget.transaction!.recurrencePattern!;
      }
      _recurrenceEndDate = widget.transaction!.recurrenceEndDate;

      logger.fine('Init form for editing transaction ${widget.transaction!.id}');
      logger.fine('Transaction type: ${widget.transaction!.type}');
      logger.fine('Transaction goal ID: ${widget.transaction!.goalId}');
      logger.fine('Contribution percentage: $_contributionPercentage');

      // Initialize saving goal fields if this is an income transaction with a goalId
      if (widget.transaction!.type == TransactionType.income) {
        if (widget.transaction!.goalId != null &&
            widget.transaction!.goalId!.isNotEmpty) {
          _saveToSavingsGoal = true;
          logger.fine(
              'Setting _saveToSavingsGoal to true for goal ID: ${widget.transaction!.goalId}');

          // We'll load the actual SavingGoal object when the widget is built
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (mounted) {
              final financeProvider =
                  Provider.of<FinanceProvider>(context, listen: false);
              final goalId = widget.transaction!.goalId!;
              logger.fine('Fetching saving goal with ID: $goalId');
              final goal = await financeProvider.getSavingGoalById(goalId);

              if (mounted && goal != null) {
                logger.fine('Found goal: ${goal.title} with ID: ${goal.id}');
                setState(() {
                  _selectedSavingGoal = goal;
                });
              } else {
                logger.fine('Goal not found with ID: $goalId');
              }
            }
          });
        } else {
          // Ensure saving goal is disabled if transaction is income but has no goal
          _saveToSavingsGoal = false;
          _selectedSavingGoal = null;
          logger.fine(
              'Income transaction has no goal, _saveToSavingsGoal set to false');
        }
      }
    } else if (widget.initialType != null) {
      _selectedType = widget.initialType!;
      logger.fine('New transaction with initial type: $_selectedType');
    }

    // Force a re-fetch of categories to ensure we have the latest data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      if (authProvider.user != null) {
        categoryProvider.loadCategoriesByUser(authProvider.user!.uid);
      }
    });
  }

  @override
  void dispose() {
    _amountController.removeListener(_updateUI);
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    _percentageController.dispose();
    super.dispose();
  }

  void _updateUI() {
    if (mounted) {
      setState(() {
        // This will cause the UI to rebuild with the new amount
      });
    }
  }

  // Show error message
  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _saveTransaction() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      setState(() => _isLoading = true);

      try {
        final userId = context.read<AuthProvider>().user?.uid;
        if (userId == null) {
          _showError('User ID not found. Please log in.');
          setState(() => _isLoading = false);
          return;
        }

        final amount = double.parse(_amountController.text);
        final transactionType = _selectedType;
        final selectedCategory = _selectedCategory;
        final selectedGoal = _saveToSavingsGoal ? _selectedSavingGoal : null;

        // Enhanced logging for debugging
        logger.fine('===== TRANSACTION SAVE DETAILS =====');
        logger.fine('Title: ${_titleController.text.trim()}');
        logger.fine('Amount: $amount');
        logger.fine('Type: $transactionType');
        logger.fine('Category: $selectedCategory');
        logger.fine('Save to goal: $_saveToSavingsGoal');

        if (selectedGoal != null) {
          logger.fine('Selected goal for contribution:');
          logger.fine('- Title: ${selectedGoal.title}');
          logger.fine('- ID: ${selectedGoal.id}');
          logger.fine('- Current Amount: ${selectedGoal.currentAmount}');
          logger.fine('- Target Amount: ${selectedGoal.targetAmount}');
        } else {
          logger.fine('No goal selected for this transaction');
        }

        final String? goalIdToUse =
            transactionType == TransactionType.income && selectedGoal != null
                ? selectedGoal.id
                : null;

        logger.fine('FINAL GOAL ID TO USE: $goalIdToUse');

        final transaction = Transaction(
          id: widget.transaction?.id,
          userId: userId,
          amount: amount,
          date: _selectedDate,
          title: _titleController.text.trim(),
          type: transactionType,
          category: selectedCategory,
          // Only set goalId for income transactions with selected goal
          goalId: goalIdToUse,
          note: _noteController.text.trim(),
          contributionPercentage:
              _saveToSavingsGoal ? _contributionPercentage : null,
          isRecurring: _isRecurring,
          recurrencePattern: _isRecurring ? _recurrencePattern : null,
          recurrenceEndDate: _isRecurring ? _recurrenceEndDate : null,
        );

        logger.fine('Transaction object goal ID: ${transaction.goalId}');
        logger.fine('===============================');

        bool success = false;
        final financeProvider =
            Provider.of<FinanceProvider>(context, listen: false);

        // Handle case where transaction is being edited
        if (widget.transaction != null) {
          logger.fine(
              'Updating existing transaction with ID: ${widget.transaction!.id}');
          logger.fine('Previous goal ID: ${widget.transaction!.goalId}');
          logger.fine('New goal ID: ${transaction.goalId}');
          final result = await financeProvider.updateTransaction(transaction);
          success = result['success'] ?? false;
        }
        // Handle case for new transaction
        else {
          logger.fine('Creating new transaction');
          if (transactionType == TransactionType.income &&
              selectedGoal != null) {
            // Use the specialized method for transactions with goals
            logger.fine(
                'Using addTransactionWithGoal method with goal ID: ${selectedGoal.id}');
            success = await financeProvider.addTransactionWithGoal(
                transaction, selectedGoal);
          } else {
            // Use regular method for transactions without goals
            logger.fine('Using regular addTransaction method (no goal)');
            success = await financeProvider.addTransaction(transaction);
          }
        }

        if (success) {
          if (mounted && widget.onComplete != null) {
            widget.onComplete!(true);
          }
          if (mounted) {
            Navigator.of(context).pop();
          }
        } else {
          final error = financeProvider.error ?? 'Failed to save transaction';
          _showError(error);
          if (mounted && widget.onComplete != null) {
            widget.onComplete!(false);
          }
        }
      } catch (e) {
        logger.fine('Error saving transaction: $e');
        _showError(e.toString());
        if (mounted && widget.onComplete != null) {
          widget.onComplete!(false);
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final financeProvider = Provider.of<FinanceProvider>(context);
    final savingGoals = financeProvider.savingGoals;

    // Get valid categories - filter by transaction type
    final allCategories = financeProvider.categories;
    final categoryType = _selectedType == TransactionType.income
        ? CategoryType.income
        : CategoryType.expense;

    final availableCategories = allCategories
        .where((category) => category.type == categoryType)
        .map((category) => category.name)
        .toSet()
        .toList();

    // Make sure _selectedCategory is valid
    if (_selectedCategory != null &&
        !availableCategories.contains(_selectedCategory)) {
      _selectedCategory = null;
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.transaction != null
              ? 'Edit Transaction'
              : 'Add ${_selectedType == TransactionType.income ? 'Income' : 'Expense'}',
        ),
        actions: [
          if (_selectedType == TransactionType.income &&
              savingGoals.isNotEmpty &&
              widget.transaction == null)
            TextButton.icon(
              onPressed: () async {
                final selectedGoal = await UIHelpers.showSavingGoalSelector(
                  context,
                  savingGoals,
                );

                if (selectedGoal != null && mounted) {
                  setState(() {
                    _titleController.text =
                        'Contribution to ${selectedGoal.title}';
                    // Find a suitable income category
                    final incomeCategories = financeProvider.categories
                        .where((c) => c.type == CategoryType.income)
                        .toList();

                    if (incomeCategories.isNotEmpty) {
                      // Try to find an 'Investments' or similar category
                      final investmentCategory = incomeCategories.firstWhere(
                        (c) =>
                            c.name.toLowerCase().contains('invest') ||
                            c.name.toLowerCase().contains('saving'),
                        orElse: () => incomeCategories.first,
                      );
                      _selectedCategory = investmentCategory.name;
                    } else {
                      _selectedCategory = 'Investments';
                    }

                    _saveToSavingsGoal = true;
                    _selectedSavingGoal = selectedGoal;
                  });
                }
              },
              icon: const Icon(Icons.savings, size: 18),
              label: const Text('Saving Goal'),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type Selector
                Center(
                  child: SegmentedButton<TransactionType>(
                    segments: const [
                      ButtonSegment<TransactionType>(
                        value: TransactionType.income,
                        label: Text('Income'),
                        icon: Icon(Icons.arrow_upward),
                      ),
                      ButtonSegment<TransactionType>(
                        value: TransactionType.expense,
                        label: Text('Expense'),
                        icon: Icon(Icons.arrow_downward),
                      ),
                    ],
                    selected: {_selectedType},
                    onSelectionChanged: (Set<TransactionType> selected) {
                      setState(() {
                        _selectedType = selected.first;
                        _selectedCategory = null;
                        // Clear saving goal selection if type is changed to expense
                        if (_selectedType == TransactionType.expense) {
                          _saveToSavingsGoal = false;
                          _selectedSavingGoal = null;
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'What is this transaction for?',
                    prefixIcon: Icon(Icons.subject),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Amount
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    hintText: 'Enter amount',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an amount';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    if (double.parse(value) <= 0) {
                      return 'Amount must be greater than 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Category
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    hintText: 'Select category',
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: availableCategories.isNotEmpty
                      ? availableCategories.map((name) {
                          return DropdownMenuItem<String>(
                            value: name,
                            child: Text(name),
                          );
                        }).toList()
                      : _selectedType == TransactionType.income
                          ? ['Salary', 'Investments', 'Gifts', 'Other Income']
                              .map((name) => DropdownMenuItem<String>(
                                    value: name,
                                    child: Text(name),
                                  ))
                              .toList()
                          : [
                              'Food & Groceries',
                              'Transportation',
                              'Entertainment',
                              'Utilities',
                              'Housing',
                              'Health',
                              'Shopping',
                              'Education',
                              'Other'
                            ]
                              .map((name) => DropdownMenuItem<String>(
                                    value: name,
                                    child: Text(name),
                                  ))
                              .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value;
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

                // Date
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('MMM dd, yyyy').format(_selectedDate)),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Notes
                TextFormField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    hintText: 'Additional details',
                    prefixIcon: Icon(Icons.note),
                  ),
                  maxLines: 2,
                ),

                // Recurring transaction toggle
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Recurring Transaction'),
                  subtitle: Text(
                    _isRecurring
                        ? 'Repeats ${_recurrencePattern.label.toLowerCase()}'
                        : 'One-time transaction',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[600]),
                  ),
                  value: _isRecurring,
                  secondary: Icon(
                    Icons.repeat,
                    color:
                        _isRecurring ? theme.colorScheme.primary : Colors.grey,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _isRecurring = value;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),

                if (_isRecurring) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<RecurrencePattern>(
                    value: _recurrencePattern,
                    decoration: const InputDecoration(
                      labelText: 'Frequency',
                      prefixIcon: Icon(Icons.schedule),
                    ),
                    items: RecurrencePattern.values
                        .map((p) => DropdownMenuItem(
                              value: p,
                              child: Text(p.label),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _recurrencePattern = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _recurrenceEndDate ??
                            DateTime.now()
                                .add(const Duration(days: 365)),
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 3650)),
                      );
                      if (picked != null) {
                        setState(() {
                          _recurrenceEndDate = picked;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'End Date (Optional)',
                        prefixIcon: const Icon(Icons.event_busy),
                        suffixIcon: _recurrenceEndDate != null
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _recurrenceEndDate = null;
                                  });
                                },
                              )
                            : null,
                      ),
                      child: Text(
                        _recurrenceEndDate != null
                            ? DateFormat('MMM dd, yyyy')
                                .format(_recurrenceEndDate!)
                            : 'No end date (repeats forever)',
                        style: TextStyle(
                          color: _recurrenceEndDate != null
                              ? null
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ],

                // Only show saving goal options for income transactions
                if (_selectedType == TransactionType.income) ...[
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Save to Saving Goal'),
                    value: _saveToSavingsGoal,
                    onChanged: savingGoals.isEmpty
                        ? null // Disable if no goals available
                        : (value) {
                            setState(() {
                              _saveToSavingsGoal = value ?? false;

                              // If turning off, clear selected goal
                              if (!_saveToSavingsGoal) {
                                _selectedSavingGoal = null;
                              }
                            });
                          },
                    controlAffinity: ListTileControlAffinity.leading,
                    subtitle: savingGoals.isEmpty
                        ? const Text(
                            'Create a saving goal first to enable this option',
                            style: TextStyle(color: Colors.grey, fontSize: 12))
                        : null,
                  ),
                  if (_saveToSavingsGoal && savingGoals.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<SavingGoal?>(
                      decoration: const InputDecoration(
                        labelText: 'Saving Goal',
                        border: OutlineInputBorder(),
                        filled: true,
                        prefixIcon: Icon(Icons.savings),
                      ),
                      value: _selectedSavingGoal,
                      items: [
                        const DropdownMenuItem<SavingGoal?>(
                          value: null,
                          child: Text('None'),
                        ),
                        ...savingGoals.map((goal) {
                          // Show if goal is completed
                          final isCompleted = goal.isCompleted;
                          return DropdownMenuItem<SavingGoal?>(
                            value: goal,
                            child: Row(
                              children: [
                                Text(goal.title),
                                const SizedBox(width: 8),
                                Text(
                                  '(${(goal.currentAmount / goal.targetAmount * 100).toStringAsFixed(0)}%)',
                                  style: TextStyle(
                                    color: isCompleted
                                        ? Colors.green
                                        : Colors.grey,
                                    fontWeight: isCompleted
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                ),
                                if (isCompleted) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.check_circle,
                                      color: Colors.green, size: 14)
                                ]
                              ],
                            ),
                          );
                        })
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedSavingGoal = value;
                          logger.fine(
                              'GOAL SELECTED: ${value?.title} (ID: ${value?.id})');
                          // Log all details of the selected goal
                          if (value != null) {
                            logger.fine('SELECTED GOAL DETAILS:');
                            logger.fine('- Title: ${value.title}');
                            logger.fine('- ID: ${value.id}');
                            logger.fine(
                                '- Current Amount: ${value.currentAmount}');
                            logger.fine(
                                '- Target Amount: ${value.targetAmount}');
                            logger.fine('- Is Completed: ${value.isCompleted}');
                            _saveToSavingsGoal = true;
                          }
                        });
                      },
                    ),
                    if (_selectedSavingGoal != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, left: 8.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: _selectedSavingGoal!.isCompleted
                                  ? Colors.orange
                                  : Colors.green,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedSavingGoal!.isCompleted
                                    ? 'Goal already completed (${_selectedSavingGoal!.currentAmount.toStringAsFixed(2)}/${_selectedSavingGoal!.targetAmount.toStringAsFixed(2)})'
                                    : 'Current progress: ${_selectedSavingGoal!.currentAmount.toStringAsFixed(2)}/${_selectedSavingGoal!.targetAmount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: _selectedSavingGoal!.isCompleted
                                      ? Colors.orange
                                      : Colors.green,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Percentage slider for contribution
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.only(left: 8.0, bottom: 4.0),
                              child: Text(
                                'Contribution Percentage: ${_contributionPercentage.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Slider(
                                    value: _contributionPercentage,
                                    min: 1,
                                    max: 100,
                                    divisions: 20,
                                    label:
                                        '${_contributionPercentage.toStringAsFixed(0)}%',
                                    onChanged: (value) {
                                      setState(() {
                                        _contributionPercentage = value;
                                        _percentageController.text =
                                            value.toStringAsFixed(0);
                                      });
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: 60,
                                  child: TextFormField(
                                    controller: _percentageController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    decoration: const InputDecoration(
                                      suffixText: '%',
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 8),
                                      isDense: true,
                                    ),
                                    onChanged: (value) {
                                      final percentage = int.tryParse(value);
                                      if (percentage != null &&
                                          percentage > 0 &&
                                          percentage <= 100) {
                                        setState(() {
                                          _contributionPercentage =
                                              percentage.toDouble();
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, left: 8.0),
                        child: Row(
                          children: [
                            Icon(
                              _selectedSavingGoal!.isCompleted
                                  ? Icons.warning
                                  : Icons.check_circle,
                              color: _selectedSavingGoal!.isCompleted
                                  ? Colors.orange
                                  : Colors.green,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _amountController.text.isEmpty
                                    ? 'Enter an amount to contribute'
                                    : _contributionPercentage < 100
                                        ? 'Contributing ${_contributionPercentage.toStringAsFixed(0)}% (\$${(double.tryParse(_amountController.text) ?? 0 * _contributionPercentage / 100).toStringAsFixed(2)}) to "${_selectedSavingGoal!.title}"'
                                        : 'Contributing \$${double.tryParse(_amountController.text)?.toStringAsFixed(2) ?? "0.00"} to "${_selectedSavingGoal!.title}"',
                                style: TextStyle(
                                  color: _selectedSavingGoal!.isCompleted
                                      ? Colors.orange
                                      : Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],

                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _saveTransaction,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: LoadingAnimationUtils.smallDollarSpinner(
                                size: 20,
                                primaryColor: Colors.white,
                              ),
                            )
                          : Text(
                              widget.transaction == null
                                  ? 'Add Transaction'
                                  : 'Update Transaction',
                            ),
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
}
