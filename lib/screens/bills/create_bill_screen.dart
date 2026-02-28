import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wealth_wise/models/bill_reminder.dart';
import 'package:wealth_wise/models/category.dart';
import 'package:wealth_wise/providers/auth_provider.dart';
import 'package:wealth_wise/providers/finance_provider.dart';

class CreateBillScreen extends StatefulWidget {
  final BillReminder? existingBill;

  const CreateBillScreen({super.key, this.existingBill});

  @override
  State<CreateBillScreen> createState() => _CreateBillScreenState();
}

class _CreateBillScreenState extends State<CreateBillScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late TextEditingController _noteController;

  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));
  BillRecurrence _recurrence = BillRecurrence.monthly;
  String? _selectedCategory;
  bool _isLoading = false;

  bool get _isEditing => widget.existingBill != null;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.existingBill?.title ?? '');
    _amountController = TextEditingController(
        text: widget.existingBill?.amount.toString() ?? '');
    _noteController =
        TextEditingController(text: widget.existingBill?.note ?? '');

    if (_isEditing) {
      _dueDate = widget.existingBill!.dueDate;
      _recurrence = widget.existingBill!.recurrence;
      _selectedCategory = widget.existingBill!.category;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final userId = context.read<AuthProvider>().user?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in first')),
      );
      setState(() => _isLoading = false);
      return;
    }

    final bill = BillReminder(
      id: widget.existingBill?.id,
      userId: userId,
      title: _titleController.text.trim(),
      amount: double.parse(_amountController.text),
      dueDate: _dueDate,
      recurrence: _recurrence,
      category: _selectedCategory,
      isPaid: widget.existingBill?.isPaid ?? false,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );

    final financeProvider =
        Provider.of<FinanceProvider>(context, listen: false);

    bool success;
    if (_isEditing) {
      success = await financeProvider.updateBillReminder(bill);
    } else {
      success = await financeProvider.addBillReminder(bill);
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save bill reminder')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final financeProvider = Provider.of<FinanceProvider>(context);
    final expenseCategories = financeProvider.categories
        .where((c) => c.type == CategoryType.expense)
        .map((c) => c.name)
        .toSet()
        .toList();

    if (_selectedCategory != null &&
        !expenseCategories.contains(_selectedCategory)) {
      _selectedCategory = null;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Bill Reminder' : 'New Bill Reminder'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Bill Name',
                  hintText: 'e.g. Netflix, Rent, Electricity',
                  prefixIcon: Icon(Icons.receipt_long),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Enter a bill name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter an amount';
                  if (double.tryParse(v) == null) return 'Invalid number';
                  if (double.parse(v) <= 0) return 'Must be > 0';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category (Optional)',
                  prefixIcon: Icon(Icons.category),
                ),
                items: expenseCategories
                    .map((name) =>
                        DropdownMenuItem(value: name, child: Text(name)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategory = v),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dueDate,
                    firstDate: DateTime.now(),
                    lastDate:
                        DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked != null) setState(() => _dueDate = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'First Due Date',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(DateFormat('MMM dd, yyyy').format(_dueDate)),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<BillRecurrence>(
                value: _recurrence,
                decoration: const InputDecoration(
                  labelText: 'Recurrence',
                  prefixIcon: Icon(Icons.repeat),
                ),
                items: BillRecurrence.values
                    .map((r) =>
                        DropdownMenuItem(value: r, child: Text(r.label)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _recurrence = v);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Note (Optional)',
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isLoading ? null : _save,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isEditing ? 'Update Bill' : 'Add Bill'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
