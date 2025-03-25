import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wealth_wise/models/expense.dart';
import 'package:wealth_wise/models/category.dart';
import 'package:wealth_wise/providers/expense_provider.dart';
import 'package:wealth_wise/providers/category_provider.dart';
import 'package:wealth_wise/providers/auth_provider.dart';
import 'package:wealth_wise/widgets/custom_action_button.dart';

class ExpenseForm extends StatefulWidget {
  final Expense? expense;

  const ExpenseForm({
    super.key,
    this.expense,
  });

  @override
  State<ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<ExpenseForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();

    // Load categories when form is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId =
          Provider.of<AuthProvider>(context, listen: false).user?.uid;
      if (userId != null) {
        Provider.of<CategoryProvider>(context, listen: false)
            .loadCategories(userId);
      }

      if (widget.expense != null) {
        _titleController.text = widget.expense!.title;
        _amountController.text = widget.expense!.amount.toString();
        _noteController.text = widget.expense!.note ?? '';
        _selectedCategoryId = widget.expense!.category;
        _selectedDate = widget.expense!.date;
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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      // If no category is selected, use the first one
      final categoryId = _selectedCategoryId ??
          (Provider.of<CategoryProvider>(context, listen: false)
                  .categories
                  .isNotEmpty
              ? Provider.of<CategoryProvider>(context, listen: false)
                  .categories
                  .first
                  .id
              : 'other');

      final expense = Expense(
        id: widget.expense?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text,
        amount: double.parse(_amountController.text),
        date: _selectedDate,
        category: categoryId,
        note: _noteController.text.isEmpty ? null : _noteController.text,
      );

      final expenseProvider =
          Provider.of<ExpenseProvider>(context, listen: false);
      if (widget.expense != null) {
        expenseProvider.updateExpense(expense);
      } else {
        expenseProvider.addExpense(expense);
      }

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = Provider.of<CategoryProvider>(context).categories;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.expense == null ? 'Add Expense' : 'Edit Expense',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Title field
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Amount field
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category dropdown with new categories
              DropdownButtonFormField<String>(
                value: _selectedCategoryId,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: categories.isEmpty
                    ? [
                        const DropdownMenuItem<String>(
                          value: 'other',
                          child: Text('Other'),
                        )
                      ]
                    : categories.map((Category category) {
                        // Handle icon name and convert to IconData
                        IconData iconData;
                        try {
                          iconData = IconData(
                            int.tryParse(category.icon) ?? 0xe5d3,
                            fontFamily: 'MaterialIcons',
                          );
                        } catch (e) {
                          // Fallback to a safe default icon
                          iconData = Icons.category;
                        }

                        return DropdownMenuItem<String>(
                          value: category.id,
                          child: Row(
                            children: [
                              Icon(
                                iconData,
                                color: category.color,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(category.name),
                            ],
                          ),
                        );
                      }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedCategoryId = newValue;
                    });
                  }
                },
                hint: const Text('Select a category'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a category';
                  }
                  return null;
                },
              ),

              // Add link to manage categories
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/categories');
                    },
                    icon: const Icon(Icons.settings, size: 16),
                    label: const Text('Manage Categories'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 0),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Date picker
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Note field
              TextFormField(
                controller: _noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Submit button
              CustomActionButton(
                onPressed: _submitForm,
                label: widget.expense == null ? 'Add Expense' : 'Save Changes',
                icon: widget.expense == null
                    ? Icons.add_circle_outline
                    : Icons.save,
                isSmall: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
