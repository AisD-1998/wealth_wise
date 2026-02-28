import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import 'package:wealth_wise/constants/app_strings.dart';
import 'package:wealth_wise/models/saving_goal.dart';
import 'package:wealth_wise/models/transaction.dart' as app_model;
import 'package:wealth_wise/providers/auth_provider.dart';
import 'package:wealth_wise/providers/finance_provider.dart';
import 'package:wealth_wise/utils/ui_helpers.dart';
import 'package:wealth_wise/widgets/loading_animation_utils.dart';

/// Groups goal-related transaction parameters to reduce method parameter count.
class GoalTransactionParams {
  final SavingGoal selectedGoal;
  final double amount;
  final double overAmount;
  final app_model.Transaction transaction;
  final bool isUpdate;
  final String userId;
  final bool isCompleted;

  const GoalTransactionParams({
    required this.selectedGoal,
    required this.amount,
    required this.overAmount,
    required this.transaction,
    required this.isUpdate,
    required this.userId,
    required this.isCompleted,
  });
}

/// A StatefulWidget that contains the transaction form previously inlined in
/// [UIHelpers.showTransactionForm]. It is shown inside a modal bottom sheet.
class TransactionFormSheet extends StatefulWidget {
  final app_model.TransactionType type;
  final app_model.Transaction? existingTransaction;
  final List<String> availableCategories;

  /// The parent context from which the bottom sheet was launched, used for
  /// dialogs that need to outlive the bottom sheet itself.
  final BuildContext parentContext;

  const TransactionFormSheet({
    super.key,
    required this.type,
    required this.availableCategories,
    required this.parentContext,
    this.existingTransaction,
  });

  @override
  State<TransactionFormSheet> createState() => _TransactionFormSheetState();
}

class _TransactionFormSheetState extends State<TransactionFormSheet> {
  static final _logger = Logger('TransactionFormSheet');

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late final TextEditingController _dateController;
  late final TextEditingController _percentageController;

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  String? _selectedCategory;
  bool _contributesToGoal = false;
  String? _selectedGoalId;
  double _contributionPercentage = 100.0;

  late final FinanceProvider _financeProvider;
  late final AuthProvider _authProvider;
  late final ScaffoldMessengerState _scaffoldMessenger;

  @override
  void initState() {
    super.initState();
    _financeProvider =
        Provider.of<FinanceProvider>(widget.parentContext, listen: false);
    _authProvider =
        Provider.of<AuthProvider>(widget.parentContext, listen: false);
    _scaffoldMessenger = ScaffoldMessenger.of(widget.parentContext);
    _initializeForm();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    _dateController.dispose();
    _percentageController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  void _initializeForm() {
    _titleController = TextEditingController();
    _amountController = TextEditingController();
    _noteController = TextEditingController();
    _dateController = TextEditingController();
    _percentageController = TextEditingController(text: '100');

    _selectedDate = DateTime.now();
    _selectedTime = TimeOfDay.now();

    final existing = widget.existingTransaction;
    if (existing != null) {
      _titleController.text = existing.title;
      _amountController.text = existing.amount.toString();
      _noteController.text = existing.note ?? '';
      _selectedDate = existing.date;
      _selectedTime = TimeOfDay.fromDateTime(existing.date);
      _dateController.text =
          DateFormat(AppStrings.kDateFormatLong).format(_selectedDate);
      _selectedCategory = existing.category;
      _contributesToGoal = existing.contributesToGoal;
      _selectedGoalId = existing.goalId;
      _contributionPercentage = existing.contributionPercentage ?? 100.0;
      _percentageController.text =
          _contributionPercentage.toStringAsFixed(0);
    } else {
      _dateController.text =
          DateFormat(AppStrings.kDateFormatLong).format(_selectedDate);
    }
  }

  // ---------------------------------------------------------------------------
  // Date / Time pickers
  // ---------------------------------------------------------------------------

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text =
            DateFormat(AppStrings.kDateFormatLong).format(_selectedDate);
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Build helpers
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    final typeLabel = widget.type == app_model.TransactionType.income
        ? 'Income'
        : 'Expense';
    final action = widget.existingTransaction != null ? 'Edit' : 'Add';
    return Text(
      '$action $typeLabel',
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildTitleField() {
    return TextFormField(
      controller: _titleController,
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
    );
  }

  Widget _buildAmountField() {
    return TextFormField(
      controller: _amountController,
      decoration: const InputDecoration(
        labelText: 'Amount',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.attach_money),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          // ignore: deprecated_member_use
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
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedCategory,
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
        ...widget.availableCategories.map((category) {
          return DropdownMenuItem<String>(
            value: category,
            child: Text(category),
          );
        }),
      ],
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
      isExpanded: true,
      icon: const Icon(Icons.arrow_drop_down),
      dropdownColor: Theme.of(context).colorScheme.surface,
      style: Theme.of(context).textTheme.bodyLarge,
    );
  }

  Widget _buildDateField() {
    return GestureDetector(
      onTap: _selectDate,
      child: AbsorbPointer(
        child: TextFormField(
          controller: _dateController,
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
    );
  }

  Widget _buildTimeField() {
    return GestureDetector(
      onTap: _selectTime,
      child: AbsorbPointer(
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Time',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.access_time),
          ),
          child: Text(_selectedTime.format(context)),
        ),
      ),
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _noteController,
      decoration: const InputDecoration(
        labelText: 'Notes (Optional)',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.note),
      ),
      maxLines: 3,
    );
  }

  // ---------------------------------------------------------------------------
  // Saving-goal section
  // ---------------------------------------------------------------------------

  List<Widget> _buildSavingGoalSection() {
    if (widget.type != app_model.TransactionType.income ||
        _financeProvider.savingGoals.isEmpty) {
      return [];
    }
    return [
      _buildGoalDropdown(),
      if (_contributesToGoal) ...[
        const SizedBox(height: 16),
        _buildPercentageSlider(),
      ],
      const SizedBox(height: 16),
    ];
  }

  Widget _buildGoalDropdown() {
    return DropdownButtonFormField<String?>(
      decoration: const InputDecoration(
        labelText: 'Contribute to Saving Goal',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.savings),
      ),
      hint: const Text('Select a goal (optional)'),
      initialValue: _selectedGoalId,
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('None'),
        ),
        ..._financeProvider.savingGoals.map(_buildGoalDropdownItem),
      ],
      onChanged: _onGoalChanged,
    );
  }

  DropdownMenuItem<String?> _buildGoalDropdownItem(SavingGoal goal) {
    _logger.info("Goal in dropdown: ${goal.title} (${goal.id})");
    return DropdownMenuItem<String?>(
      value: goal.id,
      child: Row(
        children: [
          Text(
            goal.title,
            style: goal.isCompleted
                ? TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  )
                : null,
          ),
          if (goal.isCompleted) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 50),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Completed',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _onGoalChanged(String? goalId) {
    setState(() {
      _selectedGoalId = goalId;
      _contributesToGoal = goalId != null;

      if (_contributesToGoal && goalId != null) {
        final matchingGoals = _financeProvider.savingGoals
            .where((goal) => goal.id == goalId)
            .toList();

        if (matchingGoals.isNotEmpty) {
          final selectedGoal = matchingGoals.first;
          _logger.info(
              "Selected goal: ${selectedGoal.title} (${selectedGoal.id})");

          if (selectedGoal.isCompleted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Warning: "${selectedGoal.title}" is already completed. Adding more funds will exceed the target amount.'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 5),
                action: SnackBarAction(label: 'OK', onPressed: () {}),
              ),
            );
          }

          if (_titleController.text.isEmpty ||
              _titleController.text.startsWith('Contribution to ')) {
            _titleController.text =
                'Contribution to ${selectedGoal.title}';
          }
        }
      }
    });
  }

  Widget _buildPercentageSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
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
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  final percentage = int.tryParse(value);
                  if (percentage != null &&
                      percentage > 0 &&
                      percentage <= 100) {
                    setState(() {
                      _contributionPercentage = percentage.toDouble();
                    });
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_amountController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(
              _contributionPercentage < 100
                  ? 'Will contribute ${_contributionPercentage.toStringAsFixed(0)}% (\$${((double.tryParse(_amountController.text) ?? 0) * _contributionPercentage / 100).toStringAsFixed(2)}) to goal'
                  : 'Will contribute the full amount to goal',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Action buttons
  // ---------------------------------------------------------------------------

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saveTransaction,
          child: Text(
            widget.existingTransaction != null ? 'Update' : 'Save',
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Save / process logic
  // ---------------------------------------------------------------------------

  void _saveTransaction() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final userId = _authProvider.user?.uid;
    if (userId == null) {
      _scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('User not authenticated. Please log in again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final amount = double.parse(_amountController.text);
    final date = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final transaction = app_model.Transaction(
      id: widget.existingTransaction?.id,
      title: _titleController.text,
      amount: amount,
      type: widget.type,
      date: date,
      category: _selectedCategory,
      note: _noteController.text.isEmpty ? null : _noteController.text,
      userId: userId,
      goalId: widget.type == app_model.TransactionType.income &&
              _contributesToGoal
          ? _selectedGoalId
          : null,
      contributionPercentage:
          widget.type == app_model.TransactionType.income &&
                  _contributesToGoal
              ? _contributionPercentage
              : null,
    );

    final isUpdate = widget.existingTransaction != null;

    if (_shouldCheckGoalExceed(transaction)) {
      _handleGoalExceed(transaction, amount, isUpdate, userId);
      return;
    }

    Navigator.of(context).pop();

    _processTransaction(
      transaction: transaction,
      isUpdate: isUpdate,
      userId: userId,
    );
  }

  bool _shouldCheckGoalExceed(app_model.Transaction transaction) {
    return transaction.type == app_model.TransactionType.income &&
        _contributesToGoal &&
        _selectedGoalId != null;
  }

  void _handleGoalExceed(
    app_model.Transaction transaction,
    double amount,
    bool isUpdate,
    String userId,
  ) {
    final matchingGoals = _financeProvider.savingGoals
        .where((g) => g.id == _selectedGoalId)
        .toList();

    if (matchingGoals.isEmpty) {
      Navigator.of(context).pop();
      _processTransaction(
        transaction: transaction,
        isUpdate: isUpdate,
        userId: userId,
      );
      return;
    }

    final selectedGoal = matchingGoals.first;
    final isCompleted = selectedGoal.isCompleted;
    final double contributionAmount =
        amount * (_contributionPercentage / 100.0);
    final willExceedTarget =
        (selectedGoal.currentAmount + contributionAmount) >
            selectedGoal.targetAmount;

    if (isCompleted || willExceedTarget) {
      final overAmount =
          (selectedGoal.currentAmount + contributionAmount) -
              selectedGoal.targetAmount;

      Navigator.of(context).pop();

      _checkGoalAndProcessTransaction(
        params: GoalTransactionParams(
          selectedGoal: selectedGoal,
          amount: contributionAmount,
          overAmount: overAmount,
          transaction: transaction,
          isUpdate: isUpdate,
          userId: userId,
          isCompleted: isCompleted,
        ),
      );
      return;
    }

    Navigator.of(context).pop();

    _processTransaction(
      transaction: transaction,
      isUpdate: isUpdate,
      userId: userId,
    );
  }

  void _checkGoalAndProcessTransaction({
    required GoalTransactionParams params,
  }) async {
    String percentageInfo = "";
    if (params.transaction.contributionPercentage != null &&
        params.transaction.contributionPercentage! < 100) {
      percentageInfo =
          " (${params.transaction.contributionPercentage!.toStringAsFixed(0)}% of the income)";
    }

    final title = params.isCompleted
        ? 'Goal Already Completed'
        : 'Goal Will Be Exceeded';
    final message = params.isCompleted
        ? 'The goal "${params.selectedGoal.title}" is already completed with \$${params.selectedGoal.currentAmount.toStringAsFixed(2)} of \$${params.selectedGoal.targetAmount.toStringAsFixed(2)}. Adding \$${params.amount.toStringAsFixed(2)}$percentageInfo will exceed the target by \$${params.overAmount.toStringAsFixed(2)}. Do you wish to continue?'
        : 'This goal "${params.selectedGoal.title}" is already at \$${params.selectedGoal.currentAmount.toStringAsFixed(2)} of \$${params.selectedGoal.targetAmount.toStringAsFixed(2)}. Adding \$${params.amount.toStringAsFixed(2)}$percentageInfo will exceed the target by \$${params.overAmount.toStringAsFixed(2)}. Do you wish to continue?';

    final shouldProceed = await UIHelpers.showConfirmationDialog(
      context: widget.parentContext,
      title: title,
      message: message,
      confirmText: 'Continue',
      cancelText: 'Cancel',
    );

    if (!shouldProceed) {
      _scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Transaction operation canceled'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _processTransaction(
      transaction: params.transaction,
      isUpdate: params.isUpdate,
      userId: params.userId,
    );
  }

  void _processTransaction({
    required app_model.Transaction transaction,
    required bool isUpdate,
    required String userId,
  }) async {
    _scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            LoadingAnimationUtils.smallDollarSpinner(size: 20),
            const SizedBox(width: 16),
            const Text('Saving changes...'),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      if (isUpdate) {
        _processUpdate(transaction, userId);
      } else {
        _processCreate(transaction, userId);
      }
    } catch (e) {
      _scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _processUpdate(
    app_model.Transaction transaction,
    String userId,
  ) async {
    final result = await _financeProvider.updateTransaction(transaction);

    if (result['success']) {
      await _financeProvider.initializeFinanceData(userId);
      _showUpdateSuccessMessage(result, transaction);
    } else {
      _scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showUpdateSuccessMessage(
    Map<String, dynamic> result,
    app_model.Transaction transaction,
  ) {
    if (result.containsKey('isCompleted') && result['isCompleted']) {
      _scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    } else if (result['goalChanged'] ||
        result['goalAdded'] ||
        result['goalRemoved'] ||
        result['amountChanged']) {
      String message = result['message'];
      if (transaction.contributesToGoal &&
          transaction.contributionPercentage != null &&
          transaction.contributionPercentage! < 100) {
        message +=
            ' (${transaction.contributionPercentage?.toStringAsFixed(0)}% of income)';
      }
      _scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      _scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Transaction updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _processCreate(
    app_model.Transaction transaction,
    String userId,
  ) async {
    final success = await _financeProvider.addTransaction(transaction);

    if (success) {
      await _financeProvider.initializeFinanceData(userId);

      String message = 'Transaction added successfully';
      if (transaction.contributesToGoal) {
        if (transaction.contributionPercentage != null &&
            transaction.contributionPercentage! < 100) {
          message =
              'Transaction added with ${transaction.contributionPercentage?.toStringAsFixed(0)}% contribution to saving goal';
        } else {
          message = 'Transaction added with contribution to saving goal';
        }
      }

      _scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      _scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
              _financeProvider.error ?? 'Failed to add transaction'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildTitleField(),
              const SizedBox(height: 16),
              _buildAmountField(),
              const SizedBox(height: 16),
              _buildCategoryDropdown(),
              const SizedBox(height: 16),
              _buildDateField(),
              const SizedBox(height: 16),
              _buildTimeField(),
              const SizedBox(height: 16),
              _buildNotesField(),
              const SizedBox(height: 16),
              ..._buildSavingGoalSection(),
              const SizedBox(height: 24),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }
}
