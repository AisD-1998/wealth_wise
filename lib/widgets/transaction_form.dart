import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:wealth_wise/models/transaction.dart';
import 'package:wealth_wise/models/saving_goal.dart';
import 'package:wealth_wise/providers/auth_provider.dart';
import 'package:wealth_wise/providers/finance_provider.dart';
import 'package:wealth_wise/providers/category_provider.dart';
import 'package:wealth_wise/utils/ui_helpers.dart';

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
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late TextEditingController _noteController;

  TransactionType _selectedType = TransactionType.expense;
  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  bool _saveToSavingsGoal = false;
  SavingGoal? _selectedSavingGoal;

  @override
  void initState() {
    super.initState();
    _initForm();
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

    // Set initial values if editing
    if (widget.transaction != null) {
      _selectedType = widget.transaction!.type;
      _selectedCategory = widget.transaction!.category;
      _selectedDate = widget.transaction!.date;
    } else if (widget.initialType != null) {
      _selectedType = widget.initialType!;
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
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = context.read<AuthProvider>().user?.uid;
      if (userId == null) {
        _showError('User ID not found. Please log in.');
        setState(() => _isLoading = false);
        return;
      }

      final financeProvider =
          Provider.of<FinanceProvider>(context, listen: false);

      // Also make sure we have access to the category provider
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);

      // Check if category provider has loaded categories
      if (categoryProvider.categories.isEmpty) {
        await categoryProvider.loadCategoriesByUser(userId);
      }

      if (!mounted) return;

      final double amount = double.parse(_amountController.text);
      bool success = false;

      // Log current values for debugging
      debugPrint('Transaction form - saving with category: $_selectedCategory');

      // Cleanup category value - make sure it's not ID but name
      if (_selectedCategory != null) {
        _selectedCategory = _selectedCategory!.trim();

        // If category doesn't exist in available categories, set to "Other"
        final availableCategories =
            categoryProvider.categories.map((cat) => cat.name).toSet().toList();

        if (!availableCategories.contains(_selectedCategory)) {
          debugPrint(
              'Category not found in available categories, using "Other" instead');
          _selectedCategory = "Other";
        }
      }

      if (widget.transaction == null) {
        // Create new transaction
        final newTransaction = Transaction(
          userId: userId,
          title: _titleController.text.trim(),
          amount: amount,
          date: _selectedDate,
          type: _selectedType,
          category: _selectedCategory,
          note: _noteController.text.trim(),
          goalId: _selectedType == TransactionType.income &&
                  _saveToSavingsGoal &&
                  _selectedSavingGoal != null
              ? _selectedSavingGoal!.id
              : null,
        );

        success = await financeProvider.addTransaction(newTransaction);

        // If this is an income saving goal contribution, update the saving goal too
        if (success &&
            _selectedType == TransactionType.income &&
            _saveToSavingsGoal &&
            _selectedSavingGoal != null) {
          await financeProvider.contributeIncomeToSavingGoal(
              _selectedSavingGoal!, amount);
        }
      } else {
        // Update existing transaction
        final updatedTransaction = widget.transaction!.copyWith(
          title: _titleController.text.trim(),
          amount: amount,
          date: _selectedDate,
          type: _selectedType,
          category: _selectedCategory,
          note: _noteController.text.trim(),
          goalId: _selectedType == TransactionType.income &&
                  _saveToSavingsGoal &&
                  _selectedSavingGoal != null
              ? _selectedSavingGoal!.id
              : null,
        );

        success = await financeProvider.updateTransaction(updatedTransaction);
      }

      if (success) {
        // Refresh the categories after transaction is saved to update spent amounts
        if (_selectedType == TransactionType.expense &&
            _selectedCategory != null &&
            _selectedCategory!.isNotEmpty) {
          await categoryProvider.loadCategoriesByUser(userId);
        }

        if (widget.onComplete != null) {
          widget.onComplete!(true);
        }
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        _showError(
          financeProvider.error ?? 'Failed to save transaction',
        );
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
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

    // Get valid categories
    final availableCategories = financeProvider.categories
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
                    _selectedCategory = 'Investments';
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

                // Add Saving Goal selection for Income transactions
                if (_selectedType == TransactionType.income &&
                    savingGoals.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<SavingGoal?>(
                    decoration: const InputDecoration(
                      labelText: 'Contribute to Saving Goal',
                      hintText: 'Select a goal (optional)',
                      prefixIcon: Icon(Icons.savings),
                    ),
                    value: _selectedSavingGoal,
                    items: [
                      const DropdownMenuItem<SavingGoal?>(
                        value: null,
                        child: Text('None'),
                      ),
                      ...savingGoals.map((goal) {
                        return DropdownMenuItem<SavingGoal?>(
                          value: goal,
                          child: Text(goal.title),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedSavingGoal = value;
                        _saveToSavingsGoal = value != null;

                        // Optionally set the title to reflect the goal contribution
                        if (_saveToSavingsGoal && _selectedSavingGoal != null) {
                          if (_titleController.text.isEmpty ||
                              _titleController.text
                                  .startsWith('Contribution to ')) {
                            _titleController.text =
                                'Contribution to ${_selectedSavingGoal!.title}';
                          }
                        }
                      });
                    },
                  ),
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
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
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
