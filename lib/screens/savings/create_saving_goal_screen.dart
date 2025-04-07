import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:wealth_wise/models/saving_goal.dart';
import 'package:wealth_wise/providers/auth_provider.dart';
import 'package:wealth_wise/providers/finance_provider.dart';
import 'package:wealth_wise/widgets/loading_indicator.dart';

class CreateSavingGoalScreen extends StatefulWidget {
  final SavingGoal? existingGoal;

  const CreateSavingGoalScreen({super.key, this.existingGoal});

  @override
  State<CreateSavingGoalScreen> createState() => _CreateSavingGoalScreenState();
}

class _CreateSavingGoalScreenState extends State<CreateSavingGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final _initialAmountController = TextEditingController();

  DateTime? _targetDate;
  String _selectedColor = '#3C63F9'; // Default color
  bool _isLoading = false;
  bool _isEditing = false;

  final List<String> _colorOptions = [
    '#3C63F9', // Blue
    '#FF3C5F', // Red
    '#2EC492', // Green
    '#F97339', // Orange
    '#9B51E0', // Purple
    '#00BCD4', // Cyan
    '#FFAB00', // Amber
    '#607D8B', // Blue Gray
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingGoal != null) {
      _isEditing = true;
      _titleController.text = widget.existingGoal!.title;
      _descriptionController.text = widget.existingGoal!.description ?? '';
      _targetAmountController.text =
          widget.existingGoal!.targetAmount.toString();
      _initialAmountController.text =
          widget.existingGoal!.currentAmount.toString();
      _targetDate = widget.existingGoal!.targetDate;
      _selectedColor = widget.existingGoal!.colorCode ?? '#3C63F9';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _targetAmountController.dispose();
    _initialAmountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null && mounted) {
      setState(() {
        _targetDate = picked;
      });
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final financeProvider =
        Provider.of<FinanceProvider>(context, listen: false);
    final userId = authProvider.firebaseUser!.uid;

    try {
      final title = _titleController.text.trim();
      final description = _descriptionController.text.trim();
      final targetAmount = double.parse(_targetAmountController.text.trim());
      final initialAmount = _initialAmountController.text.isEmpty
          ? 0.0
          : double.parse(_initialAmountController.text.trim());

      bool success;
      if (_isEditing) {
        final updatedGoal = widget.existingGoal!.copyWith(
          title: title,
          description: description.isNotEmpty ? description : null,
          targetAmount: targetAmount,
          currentAmount: initialAmount,
          targetDate: _targetDate,
          colorCode: _selectedColor,
        );
        success = await financeProvider.updateSavingGoal(updatedGoal);
      } else {
        final newGoal = SavingGoal(
          title: title,
          targetAmount: targetAmount,
          currentAmount: initialAmount,
          description: description.isNotEmpty ? description : null,
          targetDate: _targetDate,
          colorCode: _selectedColor,
          userId: userId,
        );
        success = await financeProvider.addSavingGoal(newGoal);
      }

      if (mounted) {
        if (success) {
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to ${_isEditing ? 'update' : 'create'} saving goal. Please try again.',
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

  Color _getColorFromHex(String hexColor) {
    return Color(int.parse("0xFF${hexColor.replaceAll('#', '')}"));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Saving Goal' : 'Create Saving Goal'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: LoadingIndicator(size: 50, message: 'Creating goal...'))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title input
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Goal Title',
                          hintText: 'e.g., New Car, Vacation, Emergency Fund',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),

                      // Description input
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description (Optional)',
                          hintText: 'Add details about your goal',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),

                      // Target amount input
                      TextFormField(
                        controller: _targetAmountController,
                        decoration: const InputDecoration(
                          labelText: 'Target Amount',
                          hintText: 'How much do you need to save?',
                          prefixIcon: Icon(Icons.attach_money),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a target amount';
                          }

                          final amount = double.tryParse(value);
                          if (amount == null || amount <= 0) {
                            return 'Please enter a valid amount';
                          }

                          return null;
                        },
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),

                      // Initial amount input
                      TextFormField(
                        controller: _initialAmountController,
                        decoration: const InputDecoration(
                          labelText: 'Initial Amount (Optional)',
                          hintText: 'Starting amount you already saved',
                          prefixIcon: Icon(Icons.attach_money),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return null; // Optional field
                          }

                          final amount = double.tryParse(value);
                          if (amount == null || amount < 0) {
                            return 'Please enter a valid amount';
                          }

                          final targetAmount =
                              double.tryParse(_targetAmountController.text) ??
                                  0;
                          if (amount > targetAmount) {
                            return 'Initial amount cannot be greater than target';
                          }

                          return null;
                        },
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 24),

                      // Target date selector
                      Text(
                        'Target Date (Optional)',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _selectDate(context),
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          _targetDate == null
                              ? 'Select a target date'
                              : 'Target: ${DateFormat('MMM dd, yyyy').format(_targetDate!)}',
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Color selector
                      Text(
                        'Goal Color',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _colorOptions.map((color) {
                          final isSelected = _selectedColor == color;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedColor = color;
                              });
                            },
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: _getColorFromHex(color),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                              child: isSelected
                                  ? Icon(
                                      Icons.check,
                                      color: theme.colorScheme.onPrimary,
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 32),

                      // Submit button
                      FilledButton(
                        onPressed: _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                        ),
                        child: Text(
                          _isEditing ? 'Update Goal' : 'Create Goal',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onPrimary,
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
