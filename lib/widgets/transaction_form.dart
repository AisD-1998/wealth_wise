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

    // Set initial values if editing
    if (widget.transaction != null) {
      _selectedType = widget.transaction!.type;
      _selectedCategory = widget.transaction!.category;
      _selectedDate = widget.transaction!.date;

      debugPrint('Init form for editing transaction ${widget.transaction!.id}');
      debugPrint('Transaction type: ${widget.transaction!.type}');
      debugPrint('Transaction goal ID: ${widget.transaction!.goalId}');

      // Initialize saving goal fields if this is an income transaction with a goalId
      if (widget.transaction!.type == TransactionType.income) {
        if (widget.transaction!.goalId != null &&
            widget.transaction!.goalId!.isNotEmpty) {
          _saveToSavingsGoal = true;
          debugPrint(
              'Setting _saveToSavingsGoal to true for goal ID: ${widget.transaction!.goalId}');

          // We'll load the actual SavingGoal object when the widget is built
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (mounted) {
              final financeProvider =
                  Provider.of<FinanceProvider>(context, listen: false);
              final goalId = widget.transaction!.goalId!;
              debugPrint('Fetching saving goal with ID: $goalId');
              final goal = await financeProvider.getSavingGoalById(goalId);

              if (mounted && goal != null) {
                debugPrint('Found goal: ${goal.title} with ID: ${goal.id}');
                setState(() {
                  _selectedSavingGoal = goal;
                });
              } else {
                debugPrint('Goal not found with ID: $goalId');
              }
            }
          });
        } else {
          // Ensure saving goal is disabled if transaction is income but has no goal
          _saveToSavingsGoal = false;
          _selectedSavingGoal = null;
          debugPrint(
              'Income transaction has no goal, _saveToSavingsGoal set to false');
        }
      }
    } else if (widget.initialType != null) {
      _selectedType = widget.initialType!;
      debugPrint('New transaction with initial type: $_selectedType');
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
        debugPrint('===== TRANSACTION SAVE DETAILS =====');
        debugPrint('Title: ${_titleController.text.trim()}');
        debugPrint('Amount: $amount');
        debugPrint('Type: $transactionType');
        debugPrint('Category: $selectedCategory');
        debugPrint('Save to goal: $_saveToSavingsGoal');

        if (selectedGoal != null) {
          debugPrint('Selected goal for contribution:');
          debugPrint('- Title: ${selectedGoal.title}');
          debugPrint('- ID: ${selectedGoal.id}');
          debugPrint('- Current Amount: ${selectedGoal.currentAmount}');
          debugPrint('- Target Amount: ${selectedGoal.targetAmount}');
        } else {
          debugPrint('No goal selected for this transaction');
        }

        final String? goalIdToUse =
            transactionType == TransactionType.income && selectedGoal != null
                ? selectedGoal.id
                : null;

        debugPrint('FINAL GOAL ID TO USE: $goalIdToUse');

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
        );

        debugPrint('Transaction object goal ID: ${transaction.goalId}');
        debugPrint('===============================');

        bool success = false;
        final financeProvider =
            Provider.of<FinanceProvider>(context, listen: false);

        // Handle case where transaction is being edited
        if (widget.transaction != null) {
          debugPrint(
              'Updating existing transaction with ID: ${widget.transaction!.id}');
          debugPrint('Previous goal ID: ${widget.transaction!.goalId}');
          debugPrint('New goal ID: ${transaction.goalId}');
          final result = await financeProvider.updateTransaction(transaction);
          success = result['success'] ?? false;
        }
        // Handle case for new transaction
        else {
          debugPrint('Creating new transaction');
          if (transactionType == TransactionType.income &&
              selectedGoal != null) {
            // Use the specialized method for transactions with goals
            debugPrint(
                'Using addTransactionWithGoal method with goal ID: ${selectedGoal.id}');
            success = await financeProvider.addTransactionWithGoal(
                transaction, selectedGoal);
          } else {
            // Use regular method for transactions without goals
            debugPrint('Using regular addTransaction method (no goal)');
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
        debugPrint('Error saving transaction: $e');
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

                // Only show saving goal options for income transactions
                if (_selectedType == TransactionType.income) ...[
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    title: const Text('Save to Saving Goal'),
                    value: _saveToSavingsGoal,
                    onChanged: (value) {
                      setState(() {
                        _saveToSavingsGoal = value ?? false;

                        // If turning off, clear selected goal
                        if (!_saveToSavingsGoal) {
                          _selectedSavingGoal = null;
                        }
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  if (_saveToSavingsGoal && savingGoals.isNotEmpty) ...[
                    DropdownButtonFormField<SavingGoal?>(
                      decoration: InputDecoration(
                        labelText: 'Saving Goal',
                        border: OutlineInputBorder(),
                        filled: true,
                        prefixIcon: Icon(Icons.savings),
                        helperText: _selectedSavingGoal != null
                            ? 'Current balance: \$${_selectedSavingGoal!.currentAmount.toStringAsFixed(2)}'
                            : 'Select a goal to contribute to',
                      ),
                      value: _selectedSavingGoal,
                      items: [
                        const DropdownMenuItem<SavingGoal?>(
                          value: null,
                          child: Text('None'),
                        ),
                        ...savingGoals.map((goal) {
                          // Add detailed logging for each goal in the dropdown
                          debugPrint(
                              'DROPDOWN GOAL: ${goal.title} (ID: ${goal.id})');
                          return DropdownMenuItem<SavingGoal?>(
                            value: goal,
                            child: Row(
                              children: [
                                Text(goal.title),
                                const SizedBox(width: 8),
                                Text(
                                  '(${(goal.currentAmount / goal.targetAmount * 100).toStringAsFixed(0)}%)',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        })
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedSavingGoal = value;
                          debugPrint(
                              'GOAL SELECTED: ${value?.title} (ID: ${value?.id})');
                          // Log all details of the selected goal
                          if (value != null) {
                            debugPrint('SELECTED GOAL DETAILS:');
                            debugPrint('- Title: ${value.title}');
                            debugPrint('- ID: ${value.id}');
                            debugPrint(
                                '- Current Amount: ${value.currentAmount}');
                            debugPrint(
                                '- Target Amount: ${value.targetAmount}');
                            _saveToSavingsGoal = true;
                          }
                        });
                      },
                    ),
                    if (_selectedSavingGoal != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Contributing \$${_amountController.text.isEmpty ? "0.00" : double.tryParse(_amountController.text)?.toStringAsFixed(2) ?? "0.00"} to "${_selectedSavingGoal!.title}"',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
