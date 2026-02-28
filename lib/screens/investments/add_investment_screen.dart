import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wealth_wise/models/investment.dart';
import 'package:wealth_wise/providers/auth_provider.dart';
import 'package:wealth_wise/providers/finance_provider.dart';

class AddInvestmentScreen extends StatefulWidget {
  final Investment? existingInvestment;

  const AddInvestmentScreen({super.key, this.existingInvestment});

  @override
  State<AddInvestmentScreen> createState() => _AddInvestmentScreenState();
}

class _AddInvestmentScreenState extends State<AddInvestmentScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _purchasePriceController;
  late TextEditingController _currentValueController;
  late TextEditingController _quantityController;
  late TextEditingController _noteController;

  InvestmentType _type = InvestmentType.stock;
  DateTime _purchaseDate = DateTime.now();
  bool _isLoading = false;

  bool get _isEditing => widget.existingInvestment != null;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.existingInvestment?.name ?? '');
    _purchasePriceController = TextEditingController(
        text: widget.existingInvestment?.purchasePrice.toString() ?? '');
    _currentValueController = TextEditingController(
        text: widget.existingInvestment?.currentValue.toString() ?? '');
    _quantityController = TextEditingController(
        text: widget.existingInvestment?.quantity.toString() ?? '');
    _noteController =
        TextEditingController(text: widget.existingInvestment?.note ?? '');

    if (_isEditing) {
      _type = widget.existingInvestment!.type;
      _purchaseDate = widget.existingInvestment!.purchaseDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _purchasePriceController.dispose();
    _currentValueController.dispose();
    _quantityController.dispose();
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

    final investment = Investment(
      id: widget.existingInvestment?.id,
      userId: userId,
      name: _nameController.text.trim(),
      type: _type,
      purchasePrice: double.parse(_purchasePriceController.text),
      currentValue: double.parse(_currentValueController.text),
      quantity: double.parse(_quantityController.text),
      purchaseDate: _purchaseDate,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );

    final provider = Provider.of<FinanceProvider>(context, listen: false);

    bool success;
    if (_isEditing) {
      success = await provider.updateInvestment(investment);
    } else {
      success = await provider.addInvestment(investment);
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save investment')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Investment' : 'Add Investment'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. AAPL, Bitcoin, Vanguard S&P 500',
                  prefixIcon: Icon(Icons.label),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Enter a name' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<InvestmentType>(
                value: _type,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  prefixIcon: Icon(Icons.category),
                ),
                items: InvestmentType.values
                    .map((t) =>
                        DropdownMenuItem(value: t, child: Text(t.label)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _type = v);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _purchasePriceController,
                decoration: const InputDecoration(
                  labelText: 'Purchase Price (per unit)',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter purchase price';
                  if (double.tryParse(v) == null) return 'Invalid number';
                  if (double.parse(v) <= 0) return 'Must be > 0';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _currentValueController,
                decoration: const InputDecoration(
                  labelText: 'Current Value (per unit)',
                  prefixIcon: Icon(Icons.price_change),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter current value';
                  if (double.tryParse(v) == null) return 'Invalid number';
                  if (double.parse(v) < 0) return 'Must be >= 0';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  prefixIcon: Icon(Icons.numbers),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter quantity';
                  if (double.tryParse(v) == null) return 'Invalid number';
                  if (double.parse(v) <= 0) return 'Must be > 0';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _purchaseDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _purchaseDate = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Purchase Date',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child:
                      Text(DateFormat('MMM dd, yyyy').format(_purchaseDate)),
                ),
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isEditing
                            ? 'Update Investment'
                            : 'Add Investment'),
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
