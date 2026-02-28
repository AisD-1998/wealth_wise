import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:wealth_wise/models/budget_model.dart';
import 'package:wealth_wise/providers/auth_provider.dart';
import 'package:wealth_wise/providers/finance_provider.dart';

class CreateBudgetScreen extends StatefulWidget {
  final Budget? existingBudget;

  const CreateBudgetScreen({super.key, this.existingBudget});

  @override
  State<CreateBudgetScreen> createState() => _CreateBudgetScreenState();
}

class _CreateBudgetScreenState extends State<CreateBudgetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  String? _selectedCategory;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isLoading = false;
  bool _isEditing = false;

  static const List<String> _expenseCategories = [
    'Food & Groceries',
    'Transportation',
    'Entertainment',
    'Utilities',
    'Housing',
    'Health',
    'Shopping',
    'Education',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();

    if (widget.existingBudget != null) {
      _isEditing = true;
      _selectedCategory = widget.existingBudget!.category;
      _amountController.text = widget.existingBudget!.amount.toString();
      _startDate = widget.existingBudget!.startDate;
      _endDate = widget.existingBudget!.endDate;
    } else {
      // Default to current month start/end
      _startDate = DateTime(now.year, now.month, 1);
      _endDate = DateTime(now.year, now.month + 1, 0); // Last day of month
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null && mounted) {
      setState(() {
        _startDate = picked;
        // If end date is before start date, reset it
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? (_startDate ?? DateTime.now()),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null && mounted) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  /// Validates form fields and date selections.
  /// Returns true if all validations pass, false otherwise.
  bool _validateForm() {
    if (!_formKey.currentState!.validate()) {
      return false;
    }

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start and end dates')),
      );
      return false;
    }

    if (_endDate!.isBefore(_startDate!) ||
        _endDate!.isAtSameMomentAs(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date must be after start date')),
      );
      return false;
    }

    return true;
  }

  /// Saves the budget (creates or updates) and returns success status.
  Future<bool> _saveBudget(
    FinanceProvider financeProvider,
    String userId,
    double amount,
  ) async {
    if (_isEditing) {
      final updatedBudget = widget.existingBudget!.copyWith(
        category: _selectedCategory,
        amount: amount,
        startDate: _startDate,
        endDate: _endDate,
      );
      return await financeProvider.updateBudget(updatedBudget);
    } else {
      final newBudget = Budget(
        id: '',
        userId: userId,
        category: _selectedCategory!,
        amount: amount,
        spent: 0.0,
        startDate: _startDate!,
        endDate: _endDate!,
        createdAt: DateTime.now(),
      );
      return await financeProvider.addBudget(newBudget);
    }
  }

  void _submit() async {
    if (!_validateForm()) return;

    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final financeProvider =
        Provider.of<FinanceProvider>(context, listen: false);
    final userId = authProvider.firebaseUser!.uid;

    try {
      final amount = double.parse(_amountController.text.trim());
      final success = await _saveBudget(financeProvider, userId, amount);

      if (mounted) {
        if (success) {
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to ${_isEditing ? 'update' : 'create'} budget. Please try again.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatDateLabel(DateTime? date, String placeholder) {
    if (date == null) return placeholder;
    return DateFormat('MMM dd, yyyy').format(date);
  }

  String _submitButtonLabel() {
    return _isEditing ? 'Update Budget' : 'Create Budget';
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedCategory,
      decoration: const InputDecoration(
        labelText: 'Category',
        hintText: 'Select a category',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.category),
      ),
      items: _expenseCategories.map((category) {
        return DropdownMenuItem<String>(
          value: category,
          child: Text(category),
        );
      }).toList(),
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
    );
  }

  Widget _buildAmountField() {
    return TextFormField(
      controller: _amountController,
      decoration: const InputDecoration(
        labelText: 'Budget Amount',
        hintText: 'Enter budget amount',
        prefixIcon: Icon(Icons.attach_money),
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter a budget amount';
        }
        final amount = double.tryParse(value);
        if (amount == null || amount <= 0) {
          return 'Please enter a valid amount greater than 0';
        }
        return null;
      },
      textInputAction: TextInputAction.done,
    );
  }

  Widget _buildDateSelector(
    ThemeData theme, {
    required String label,
    required DateTime? date,
    required String placeholder,
    required VoidCallback onPressed,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.calendar_today),
          label: Text(_formatDateLabel(date, placeholder)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(ThemeData theme) {
    return FilledButton(
      onPressed: _submit,
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 56),
      ),
      child: Text(
        _submitButtonLabel(),
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onPrimary,
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCategoryDropdown(),
            const SizedBox(height: 16),
            _buildAmountField(),
            const SizedBox(height: 24),
            _buildDateSelector(
              theme,
              label: 'Start Date',
              date: _startDate,
              placeholder: 'Select start date',
              onPressed: () => _selectStartDate(context),
            ),
            const SizedBox(height: 16),
            _buildDateSelector(
              theme,
              label: 'End Date',
              date: _endDate,
              placeholder: 'Select end date',
              onPressed: () => _selectEndDate(context),
            ),
            const SizedBox(height: 32),
            _buildSubmitButton(theme),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Budget' : 'Create Budget'),
      ),
      body: SafeArea(
        child: _buildBody(theme),
      ),
    );
  }
}
