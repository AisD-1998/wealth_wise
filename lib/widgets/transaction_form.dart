import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:wealth_wise/models/transaction.dart';
import 'package:wealth_wise/providers/auth_provider.dart';
import 'package:wealth_wise/providers/finance_provider.dart';

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
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final userId =
        Provider.of<AuthProvider>(context, listen: false).firebaseUser?.uid;
    if (userId == null) {
      _showError('User not authenticated');
      setState(() => _isLoading = false);
      return;
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      _showError('Amount must be greater than 0');
      setState(() => _isLoading = false);
      return;
    }

    try {
      final financeProvider =
          Provider.of<FinanceProvider>(context, listen: false);
      bool success;

      // Create or update transaction
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
        );

        success = await financeProvider.addTransaction(newTransaction);
      } else {
        // Update existing transaction
        final updatedTransaction = widget.transaction!.copyWith(
          title: _titleController.text.trim(),
          amount: amount,
          date: _selectedDate,
          type: _selectedType,
          category: _selectedCategory,
          note: _noteController.text.trim(),
        );

        success = await financeProvider.updateTransaction(updatedTransaction);
      }

      if (success) {
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
    final categories = Provider.of<FinanceProvider>(context).categories;
    final categoryNames = categories.map((c) => c.name).toList();

    // Add an "Other" category if it doesn't exist
    if (!categoryNames.contains('Other')) {
      categoryNames.add('Other');
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.transaction == null
            ? 'Add Transaction'
            : 'Edit Transaction'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveTransaction,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Transaction Type Selector
                    Card(
                      margin: const EdgeInsets.only(bottom: 16.0),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => setState(() {
                                  _selectedType = TransactionType.income;
                                }),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      _selectedType == TransactionType.income
                                          ? Colors.green
                                          : Colors.grey[300],
                                  foregroundColor:
                                      _selectedType == TransactionType.income
                                          ? Colors.white
                                          : Colors.black,
                                ),
                                child: const Text('Income'),
                              ),
                            ),
                            const SizedBox(width: 8.0),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => setState(() {
                                  _selectedType = TransactionType.expense;
                                }),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      _selectedType == TransactionType.expense
                                          ? Colors.red
                                          : Colors.grey[300],
                                  foregroundColor:
                                      _selectedType == TransactionType.expense
                                          ? Colors.white
                                          : Colors.black,
                                ),
                                child: const Text('Expense'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Title Field
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),

                    // Amount Field
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter an amount';
                        }
                        final amount = double.tryParse(value);
                        if (amount == null || amount <= 0) {
                          return 'Please enter a valid amount';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),

                    // Category Dropdown (only for expenses)
                    if (_selectedType == TransactionType.expense)
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
                        ),
                        items: categoryNames
                            .map((category) => DropdownMenuItem(
                                  value: category,
                                  child: Text(category),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value;
                          });
                        },
                      ),
                    if (_selectedType == TransactionType.expense)
                      const SizedBox(height: 16.0),

                    // Date Picker
                    GestureDetector(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          DateFormat('MMM dd, yyyy').format(_selectedDate),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),

                    // Note Field
                    TextFormField(
                      controller: _noteController,
                      decoration: const InputDecoration(
                        labelText: 'Note (Optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.note),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24.0),

                    // Save Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveTransaction,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                      ),
                      child: Text(
                        widget.transaction == null
                            ? 'Add Transaction'
                            : 'Update Transaction',
                        style: const TextStyle(fontSize: 16.0),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
