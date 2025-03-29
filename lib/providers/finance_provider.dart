import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wealth_wise/models/saving_goal.dart';
import 'package:wealth_wise/models/transaction.dart' as app_model;
import 'package:wealth_wise/services/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';
import 'package:wealth_wise/models/category.dart' as app_category;

enum TimeFrame { day, week, month, year, all }

extension TimeFrameExtension on TimeFrame {
  String get label {
    switch (this) {
      case TimeFrame.day:
        return 'Today';
      case TimeFrame.week:
        return 'This Week';
      case TimeFrame.month:
        return 'This Month';
      case TimeFrame.year:
        return 'This Year';
      case TimeFrame.all:
        return 'All Time';
    }
  }

  DateTime get startDate {
    final now = DateTime.now();
    switch (this) {
      case TimeFrame.day:
        return DateTime(now.year, now.month, now.day);
      case TimeFrame.week:
        // Start of week (Sunday)
        return DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday));
      case TimeFrame.month:
        return DateTime(now.year, now.month, 1);
      case TimeFrame.year:
        return DateTime(now.year, 1, 1);
      case TimeFrame.all:
        return DateTime(2000); // Far in the past
    }
  }

  DateTime get endDate {
    return DateTime.now();
  }
}

class FinanceProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  final Logger _logger = Logger('FinanceProvider');

  // Add userId field
  String? _userId;

  // Flag to prevent goal contributions during transaction updates
  bool _isInTransactionUpdate = false;

  // State variables
  bool _isLoading = false;
  String? _error;
  TimeFrame _selectedTimeframe = TimeFrame.month;

  // Data
  List<app_model.Transaction> _transactions = [];
  List<SavingGoal> _savingGoals = [];
  List<app_category.Category> _categories = [];
  final Map<String, dynamic> _financialSummary = {};

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  TimeFrame get selectedTimeframe => _selectedTimeframe;
  List<app_model.Transaction> get transactions => _transactions;
  List<SavingGoal> get savingGoals => _savingGoals;
  List<app_category.Category> get categories => _categories;
  Map<String, dynamic> get financialSummary => _financialSummary;

  // Aliases and additional getters
  double get totalBalance => totalIncome - totalExpense;
  double get totalExpenses => totalExpense;

  // Get the top expense category
  String? get topExpenseCategory {
    if (categorySpending.isEmpty) return null;

    var entries = categorySpending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries.isNotEmpty ? entries.first.key : null;
  }

  // Get daily average spending
  double get dailyAverageSpending {
    final expenses = filteredTransactions
        .where((t) => t.type == app_model.TransactionType.expense)
        .toList();

    if (expenses.isEmpty) return 0;

    final totalDays = _selectedTimeframe.endDate
            .difference(_selectedTimeframe.startDate)
            .inDays +
        1;

    return totalExpense / totalDays;
  }

  // Get the largest expense
  app_model.Transaction? get largestExpense {
    final expenses = filteredTransactions
        .where((t) => t.type == app_model.TransactionType.expense)
        .toList();

    if (expenses.isEmpty) return null;

    expenses.sort((a, b) => b.amount.compareTo(a.amount));
    return expenses.first;
  }

  // Filtered transactions based on timeframe
  List<app_model.Transaction> get filteredTransactions {
    final start = _selectedTimeframe.startDate;
    final end = _selectedTimeframe.endDate;

    return _transactions.where((transaction) {
      return transaction.date.isAfter(start) &&
          transaction.date.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }

  // Income and expense totals for the selected timeframe
  double get totalIncome {
    return filteredTransactions
        .where(
          (t) =>
              t.type == app_model.TransactionType.income && t.includedInTotals,
        )
        .fold(0, (sumincome, item) => sumincome + item.amount);
  }

  double get totalExpense {
    return filteredTransactions
        .where(
          (t) =>
              t.type == app_model.TransactionType.expense && t.includedInTotals,
        )
        .fold(0, (sumexpense, item) => sumexpense + item.amount);
  }

  double get balance => totalIncome - totalExpense;

  // Category spending for the selected timeframe
  Map<String, double> get categorySpending {
    final Map<String, double> result = {};

    for (var transaction in filteredTransactions) {
      if (transaction.type == app_model.TransactionType.expense &&
          transaction.includedInTotals) {
        final category = transaction.category ?? 'Uncategorized';
        if (result.containsKey(category)) {
          result[category] = result[category]! + transaction.amount;
        } else {
          result[category] = transaction.amount;
        }
      }
    }

    return result;
  }

  // Recent transactions
  List<app_model.Transaction> get recentTransactions {
    final sorted = List<app_model.Transaction>.from(_transactions)
      ..sort((a, b) => b.date.compareTo(a.date));
    return sorted.take(10).toList();
  }

  // Get transactions by category
  Map<String, double> get expensesByCategory {
    final expenses = filteredTransactions
        .where(
          (t) =>
              t.type == app_model.TransactionType.expense && t.includedInTotals,
        )
        .toList();

    final Map<String, double> result = {};

    for (var transaction in expenses) {
      final category = transaction.category ?? 'Uncategorized';
      if (result.containsKey(category)) {
        result[category] = result[category]! + transaction.amount;
      } else {
        result[category] = transaction.amount;
      }
    }

    return result;
  }

  // Methods to change state
  void setTimeframe(TimeFrame timeframe) {
    _selectedTimeframe = timeframe;
    notifyListeners();
  }

  // Initialize data for a user
  Future<void> initializeFinanceData(String userId) async {
    if (userId.isEmpty) {
      return;
    }

    try {
      _userId = userId;
      await fetchTransactions();
      await fetchSpendingCategories();
      await fetchSavingGoals();
      notifyListeners();
    } catch (e) {
      // Log error but don't crash
      _logger.warning('Error initializing finance data: $e');
    }
  }

  // Method to load user finances - alias for initializeFinanceData
  Future<void> loadUserFinances(String userId) async {
    await initializeFinanceData(userId);
  }

  // Load transactions
  Future<void> fetchTransactions() async {
    if (_userId == null || _userId!.isEmpty) {
      _logger.warning('Cannot fetch transactions: userId is empty');
      return;
    }

    try {
      _logger.info('Fetching transactions for user: $_userId');

      // Direct Firestore query with more detailed error handling
      try {
        final collection = FirebaseFirestore.instance.collection(
          'transactions',
        );
        _logger.info('Collection reference created: ${collection.path}');

        // Check if collection exists
        final collectionSnapshot = await collection.limit(1).get();
        _logger.info(
          'Collection exists: ${collectionSnapshot.docs.isNotEmpty}',
        );

        // Perform query with fewer constraints initially
        final snapshot =
            await collection.where('userId', isEqualTo: _userId).get();

        _logger.info(
          'Retrieved ${snapshot.docs.length} transactions from database',
        );

        // Log individual documents for debugging
        for (var doc in snapshot.docs) {
          _logger.info('Document ID: ${doc.id}, Data: ${doc.data()}');
        }

        // Convert to transaction objects with careful error handling
        _transactions = [];
        for (var doc in snapshot.docs) {
          try {
            final data = doc.data();
            // Validate date field format before conversion
            if (data['date'] is Timestamp) {
              final transaction = app_model.Transaction.fromMap(data, doc.id);
              _transactions.add(transaction);
            } else {
              _logger.warning(
                'Document ${doc.id} has invalid date format: ${data['date']}',
              );
            }
          } catch (docError) {
            _logger.warning('Error parsing document ${doc.id}: $docError');
          }
        }

        // Sort transactions by date (newest first)
        _transactions.sort((a, b) => b.date.compareTo(a.date));

        // Debug logging
        if (_transactions.isEmpty) {
          _logger.warning('No valid transactions found for user: $_userId');
        } else {
          _logger.info(
            'Successfully loaded ${_transactions.length} valid transactions',
          );
        }
      } catch (firestoreError) {
        _logger.severe('Firestore query error: $firestoreError');
        rethrow;
      }

      notifyListeners();
    } catch (e) {
      _logger.warning('Error fetching transactions: $e');
      // Don't throw - just log and keep empty list
      _transactions = [];
      notifyListeners();
    }
  }

  // Handle transaction interactions with saving goals
  Future<Map<String, dynamic>> _handleSavingGoalTransaction(
    app_model.Transaction oldTransaction,
    app_model.Transaction newTransaction,
  ) async {
    try {
      _logger.severe('==== HANDLING SAVING GOAL TRANSACTION ====');
      _logger.severe(
          'Old transaction: ${oldTransaction.title} (${oldTransaction.id})');
      _logger.severe('Old transaction goal ID: ${oldTransaction.goalId}');
      _logger.severe('Old transaction amount: ${oldTransaction.amount}');
      _logger.severe(
          'New transaction: ${newTransaction.title} (${newTransaction.id})');
      _logger.severe('New transaction goal ID: ${newTransaction.goalId}');
      _logger.severe('New transaction amount: ${newTransaction.amount}');

      Map<String, dynamic> result = {
        'success': true,
        'goalChanged': false,
        'oldGoalName': null,
        'newGoalName': null,
        'amountChanged': false,
      };

      // Only income transactions can contribute to saving goals
      if (oldTransaction.type != app_model.TransactionType.income &&
          newTransaction.type != app_model.TransactionType.income) {
        _logger.severe('No goal handling needed - not income transactions');
        return result;
      }

      String? oldGoalId = oldTransaction.goalId;
      String? newGoalId = newTransaction.goalId;

      // Log available goals in memory
      _logger.severe('Available goals in memory:');
      for (final goal in _savingGoals) {
        _logger.severe(
            '- ${goal.title} (${goal.id}) - Amount: ${goal.currentAmount}');
      }

      // CASE 1: Same goal, different amount (e.g. edited amount)
      if (oldGoalId != null &&
          oldGoalId.isNotEmpty &&
          newGoalId != null &&
          newGoalId.isNotEmpty &&
          oldGoalId == newGoalId &&
          oldTransaction.amount != newTransaction.amount) {
        _logger.severe(
            'CASE 1: Same goal, amount changed from ${oldTransaction.amount} to ${newTransaction.amount}');

        // Get the goal
        final goal = await getSavingGoalById(oldGoalId);
        if (goal == null) {
          _logger.severe('Goal not found: $oldGoalId');
          return {'success': false, 'error': 'Goal not found: $oldGoalId'};
        }

        _logger.severe(
            'Found goal: ${goal.title} (${goal.id}) with amount ${goal.currentAmount}');

        // Calculate difference
        double difference = newTransaction.amount - oldTransaction.amount;
        double newAmount = goal.currentAmount + difference;
        if (newAmount < 0) newAmount = 0;

        _logger.severe(
            'Adjusting goal ${goal.title} by $difference: ${goal.currentAmount} → $newAmount');

        // Update goal
        final updatedGoal = goal.copyWith(currentAmount: newAmount);
        final success = await _databaseService.updateSavingGoal(updatedGoal);

        // Update local state
        if (success) {
          final index = _savingGoals.indexWhere((g) => g.id == oldGoalId);
          if (index >= 0) {
            _savingGoals[index] = updatedGoal;
            _logger.severe('Updated goal in memory');
          } else {
            _logger.severe('Goal not found in memory, adding it');
            _savingGoals.add(updatedGoal);
          }

          result['amountChanged'] = true;
          result['goalName'] = goal.title;
          result['amountDifference'] = difference;
        } else {
          _logger.severe('Failed to update goal in database');
          return {
            'success': false,
            'error': 'Failed to update goal in database'
          };
        }

        return result;
      }

      // CASE 2: Changed from one goal to another
      else if (oldGoalId != null &&
          oldGoalId.isNotEmpty &&
          newGoalId != null &&
          newGoalId.isNotEmpty &&
          oldGoalId != newGoalId) {
        _logger.severe('CASE 2: Goal changed from $oldGoalId to $newGoalId');

        // STEP 1: Remove from old goal
        final oldGoal = await getSavingGoalById(oldGoalId);
        if (oldGoal == null) {
          _logger.severe('Old goal not found: $oldGoalId');
          return {'success': false, 'error': 'Old goal not found: $oldGoalId'};
        }

        _logger.severe(
            'Found old goal: ${oldGoal.title} (${oldGoal.id}) with amount ${oldGoal.currentAmount}');

        double oldUpdatedAmount = oldGoal.currentAmount - oldTransaction.amount;
        if (oldUpdatedAmount < 0) oldUpdatedAmount = 0;

        _logger.severe(
            'Removing ${oldTransaction.amount} from ${oldGoal.title}: ${oldGoal.currentAmount} → $oldUpdatedAmount');

        final updatedOldGoal =
            oldGoal.copyWith(currentAmount: oldUpdatedAmount);
        final oldSuccess =
            await _databaseService.updateSavingGoal(updatedOldGoal);

        if (oldSuccess) {
          // Update local state
          final oldIndex = _savingGoals.indexWhere((g) => g.id == oldGoalId);
          if (oldIndex >= 0) {
            _savingGoals[oldIndex] = updatedOldGoal;
            _logger.severe('Updated old goal in memory');
          } else {
            _logger.severe('Old goal not found in memory');
          }

          // Store goal name for UI feedback
          result['oldGoalName'] = oldGoal.title;
        } else {
          _logger.severe('Failed to update old goal');
          return {'success': false, 'error': 'Failed to update old goal'};
        }

        // STEP 2: Add to new goal
        final newGoal = await getSavingGoalById(newGoalId);
        if (newGoal == null) {
          _logger.severe('New goal not found: $newGoalId');
          return {'success': false, 'error': 'New goal not found: $newGoalId'};
        }

        _logger.severe(
            'Found new goal: ${newGoal.title} (${newGoal.id}) with amount ${newGoal.currentAmount}');

        // Check if this will exceed the target amount (completing the goal)
        bool willExceedTarget =
            (newGoal.currentAmount + newTransaction.amount) >
                newGoal.targetAmount;
        if (willExceedTarget) {
          result['willExceedTarget'] = true;
          result['newGoalName'] = newGoal.title;
          result['newGoalTarget'] = newGoal.targetAmount;
          result['newGoalCurrent'] = newGoal.currentAmount;
          result['transactionAmount'] = newTransaction.amount;
        }

        double newUpdatedAmount = newGoal.currentAmount + newTransaction.amount;

        _logger.severe(
            'Adding ${newTransaction.amount} to ${newGoal.title}: ${newGoal.currentAmount} → $newUpdatedAmount');

        final updatedNewGoal =
            newGoal.copyWith(currentAmount: newUpdatedAmount);
        final newSuccess =
            await _databaseService.updateSavingGoal(updatedNewGoal);

        if (newSuccess) {
          // Update local state
          final newIndex = _savingGoals.indexWhere((g) => g.id == newGoalId);
          if (newIndex >= 0) {
            _savingGoals[newIndex] = updatedNewGoal;
            _logger.severe('Updated new goal in memory');
          } else {
            _logger.severe('New goal not found in memory, adding it');
            _savingGoals.add(updatedNewGoal);
          }

          // Store info for UI feedback
          result['goalChanged'] = true;
          result['newGoalName'] = newGoal.title;
        } else {
          _logger.severe('Failed to update new goal');
          return {'success': false, 'error': 'Failed to update new goal'};
        }

        return result;
      }

      // CASE 3: Goal removed (transaction had goal before, now it doesn't)
      else if (oldGoalId != null &&
          oldGoalId.isNotEmpty &&
          (newGoalId == null || newGoalId.isEmpty)) {
        _logger.severe(
            'CASE 3: Goal removed - removing amount from old goal $oldGoalId');

        // Remove from old goal
        final oldGoal = await getSavingGoalById(oldGoalId);
        if (oldGoal == null) {
          _logger.severe('Goal not found: $oldGoalId');
          return {'success': false, 'error': 'Goal not found: $oldGoalId'};
        }

        _logger.severe(
            'Found goal to remove amount from: ${oldGoal.title} (${oldGoal.id}) with amount ${oldGoal.currentAmount}');

        double newAmount = oldGoal.currentAmount - oldTransaction.amount;
        if (newAmount < 0) newAmount = 0;

        _logger.severe(
            'Removing ${oldTransaction.amount} from ${oldGoal.title}: ${oldGoal.currentAmount} → $newAmount');

        final updatedGoal = oldGoal.copyWith(currentAmount: newAmount);
        final success = await _databaseService.updateSavingGoal(updatedGoal);

        // Update local state
        if (success) {
          final index = _savingGoals.indexWhere((g) => g.id == oldGoalId);
          if (index >= 0) {
            _savingGoals[index] = updatedGoal;
            _logger.severe('Updated goal in memory');
          } else {
            _logger.severe('Goal not found in memory, adding it');
            _savingGoals.add(updatedGoal);
          }

          // Store info for UI feedback
          result['goalRemoved'] = true;
          result['oldGoalName'] = oldGoal.title;
        } else {
          _logger.severe('Failed to update goal in database');
          return {
            'success': false,
            'error': 'Failed to update goal in database'
          };
        }

        return result;
      }

      // CASE 4: Goal added (transaction didn't have goal before, now it does)
      else if ((oldGoalId == null || oldGoalId.isEmpty) &&
          newGoalId != null &&
          newGoalId.isNotEmpty) {
        _logger.severe(
            'CASE 4: Goal added - adding amount to new goal $newGoalId');

        // Add to new goal
        final newGoal = await getSavingGoalById(newGoalId);
        if (newGoal == null) {
          _logger.severe('Goal not found: $newGoalId');
          return {'success': false, 'error': 'Goal not found: $newGoalId'};
        }

        _logger.severe(
            'Found goal to add amount to: ${newGoal.title} (${newGoal.id}) with amount ${newGoal.currentAmount}');

        // Check if this will exceed the target amount (completing the goal)
        bool willExceedTarget =
            (newGoal.currentAmount + newTransaction.amount) >
                newGoal.targetAmount;
        if (willExceedTarget) {
          result['willExceedTarget'] = true;
          result['newGoalName'] = newGoal.title;
          result['newGoalTarget'] = newGoal.targetAmount;
          result['newGoalCurrent'] = newGoal.currentAmount;
          result['transactionAmount'] = newTransaction.amount;
        }

        double newAmount = newGoal.currentAmount + newTransaction.amount;

        _logger.severe(
            'Adding ${newTransaction.amount} to ${newGoal.title}: ${newGoal.currentAmount} → $newAmount');

        final updatedGoal = newGoal.copyWith(currentAmount: newAmount);
        final success = await _databaseService.updateSavingGoal(updatedGoal);

        // Update local state
        if (success) {
          final index = _savingGoals.indexWhere((g) => g.id == newGoalId);
          if (index >= 0) {
            _savingGoals[index] = updatedGoal;
            _logger.severe('Updated goal in memory');
          } else {
            _logger.severe('Goal not found in memory, adding it');
            _savingGoals.add(updatedGoal);
          }

          // Store info for UI feedback
          result['goalAdded'] = true;
          result['newGoalName'] = newGoal.title;
        } else {
          _logger.severe('Failed to update goal in database');
          return {
            'success': false,
            'error': 'Failed to update goal in database'
          };
        }

        return result;
      }

      // CASE 5: No relevant goal changes
      else {
        _logger.severe('CASE 5: No relevant goal changes detected');
        _logger.severe('Old transaction type: ${oldTransaction.type}');
        _logger.severe('New transaction type: ${newTransaction.type}');
        _logger.severe('Old goal ID: $oldGoalId');
        _logger.severe('New goal ID: $newGoalId');
        _logger.severe('Old amount: ${oldTransaction.amount}');
        _logger.severe('New amount: ${newTransaction.amount}');
        return result;
      }
    } catch (e) {
      _logger.severe('Error handling saving goal transaction: $e');
      return {
        'success': false,
        'error': 'Error handling saving goal transaction: $e'
      };
    }
  }

  // Handle new transaction contribution to a saving goal
  Future<bool> addContributionToSavingGoal(
      SavingGoal goal, double amount) async {
    try {
      _logger.info('Adding contribution to goal: ${goal.id}, amount: $amount');

      // Verify goal exists and get latest data
      final existingGoal = await getSavingGoalById(goal.id!);
      if (existingGoal == null) {
        _error = 'Goal not found with ID: ${goal.id}';
        _logger.warning(_error!);
        return false;
      }

      // Update the goal amount
      final newAmount = existingGoal.currentAmount + amount;
      _logger.info(
          'Updating goal amount: ${existingGoal.currentAmount} + $amount = $newAmount');

      final updatedGoal = existingGoal.copyWith(currentAmount: newAmount);
      final success = await _databaseService.updateSavingGoal(updatedGoal);

      if (success) {
        _logger.info('Goal updated successfully');

        // Update in memory
        final index = _savingGoals.indexWhere((g) => g.id == goal.id);
        if (index >= 0) {
          _savingGoals[index] = updatedGoal;
        }

        return true;
      } else {
        _error = 'Failed to update saving goal';
        _logger.warning(_error!);
        return false;
      }
    } catch (e) {
      _error = 'Error adding contribution to saving goal: $e';
      _logger.severe(_error!);
      return false;
    }
  }

  // New method to add a transaction with saving goal in one atomic operation
  Future<bool> addTransactionWithGoal(
      app_model.Transaction transaction, SavingGoal? savingGoal) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _logger.severe('Adding transaction with goal handling');
      _logger.severe('Transaction goal ID: ${transaction.goalId}');
      _logger.severe('Provided goal ID: ${savingGoal?.id}');

      // Verify the goal IDs match
      if (savingGoal != null &&
          transaction.goalId != null &&
          transaction.goalId != savingGoal.id) {
        _logger.severe(
            'ERROR: Transaction goal ID and provided goal ID do not match!');
        _error = 'Transaction goal ID and provided goal ID do not match';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // First add the transaction
      await _databaseService.addTransaction(transaction);

      // If successful and there's a goal, update the goal
      if (savingGoal != null &&
          transaction.type == app_model.TransactionType.income &&
          transaction.goalId != null &&
          transaction.goalId!.isNotEmpty) {
        _logger.severe(
            'Transaction added, now updating goal: ${savingGoal.id} (${savingGoal.title})');

        // Add contribution to goal - use the actual goal object to ensure we're updating the right one
        final goalSuccess =
            await addContributionToSavingGoal(savingGoal, transaction.amount);
        if (!goalSuccess) {
          _error = 'Transaction added but failed to update saving goal';
          _logger.warning(_error!);
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      // Refresh data
      await fetchTransactions();
      await fetchSavingGoals();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error adding transaction with goal: $e';
      _logger.severe(_error!);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Add a transaction (simplified version that uses addTransactionWithGoal)
  Future<bool> addTransaction(app_model.Transaction transaction) async {
    try {
      if (transaction.type == app_model.TransactionType.income &&
          transaction.goalId != null &&
          transaction.goalId!.isNotEmpty) {
        // Get the goal by ID
        _logger.severe('Transaction has goal ID: ${transaction.goalId}');
        final goal = await getSavingGoalById(transaction.goalId!);

        if (goal != null) {
          _logger
              .severe('Found goal for transaction: ${goal.title} (${goal.id})');
          return addTransactionWithGoal(transaction, goal);
        } else {
          _logger.severe('ERROR: Goal not found for ID: ${transaction.goalId}');
          _error = 'Goal not found with ID: ${transaction.goalId}';
          notifyListeners();
          return false;
        }
      } else {
        _logger.severe('Transaction has no goal ID or is not income type');
      }

      // Fallback to simple transaction without goal
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _databaseService.addTransaction(transaction);
      await fetchTransactions();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _logger.severe('Error in addTransaction: $_error');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Update transaction with integrated goal handling
  Future<Map<String, dynamic>> updateTransaction(
      app_model.Transaction transaction) async {
    _isLoading = true;
    _error = null;
    _isInTransactionUpdate =
        true; // Set flag to prevent additional goal contributions
    notifyListeners();

    Map<String, dynamic> result = {
      'success': false,
      'message': '',
      'goalChanged': false,
      'willExceedTarget': false,
      'oldGoalName': null,
      'newGoalName': null
    };

    try {
      _logger.info('Starting transaction update: ${transaction.id}');

      if (transaction.id == null || transaction.id!.isEmpty) {
        _error = 'Transaction ID required for update';
        _logger.warning(_error!);
        _isLoading = false;
        _isInTransactionUpdate = false;
        notifyListeners();
        result['message'] = _error!;
        return result;
      }

      // Find the original transaction
      final oldTransaction = _transactions.firstWhere(
        (t) => t.id == transaction.id,
        orElse: () => transaction,
      );

      // STEP 1: Handle saving goal changes if any
      if (oldTransaction.id != null) {
        final goalResult =
            await _handleSavingGoalTransaction(oldTransaction, transaction);

        if (!goalResult['success']) {
          _error = goalResult['error'];
          _logger.warning(_error!);
          _isLoading = false;
          _isInTransactionUpdate = false;
          notifyListeners();
          result['message'] = _error!;
          return result;
        }

        // Pass along goal change information for UI feedback
        if (goalResult['goalChanged']) {
          result['goalChanged'] = true;
          result['oldGoalName'] = goalResult['oldGoalName'];
          result['newGoalName'] = goalResult['newGoalName'];
          result['message'] =
              'Transaction moved from ${goalResult['oldGoalName']} to ${goalResult['newGoalName']}. Goal progress updated accordingly.';
        } else if (goalResult['goalAdded']) {
          result['goalAdded'] = true;
          result['newGoalName'] = goalResult['newGoalName'];
          result['message'] =
              'Transaction added to ${goalResult['newGoalName']}. Goal progress updated.';
        } else if (goalResult['goalRemoved']) {
          result['goalRemoved'] = true;
          result['oldGoalName'] = goalResult['oldGoalName'];
          result['message'] =
              'Transaction removed from ${goalResult['oldGoalName']}. Goal progress updated.';
        } else if (goalResult['amountChanged']) {
          result['amountChanged'] = true;
          result['goalName'] = goalResult['goalName'];
          result['amountDifference'] = goalResult['amountDifference'];
          String changeDirection =
              goalResult['amountDifference'] > 0 ? 'increased' : 'decreased';
          result['message'] =
              '${goalResult["goalName"]} progress $changeDirection by ${goalResult["amountDifference"].abs().toStringAsFixed(2)}.';
        }

        // Check if the transaction will exceed the goal target
        if (goalResult.containsKey('willExceedTarget') &&
            goalResult['willExceedTarget']) {
          result['willExceedTarget'] = true;
          result['newGoalName'] = goalResult['newGoalName'];
          result['newGoalTarget'] = goalResult['newGoalTarget'];
          result['newGoalCurrent'] = goalResult['newGoalCurrent'];
          result['transactionAmount'] = goalResult['transactionAmount'];
        }
      }

      // STEP 2: Update the transaction in database
      _logger.info('Now updating the transaction in database');
      final success = await _databaseService.updateTransaction(transaction);

      if (!success) {
        _error = 'Failed to update transaction in database';
        _logger.warning(_error!);
        _isLoading = false;
        _isInTransactionUpdate = false;
        notifyListeners();
        result['message'] = _error!;
        return result;
      }

      // Update in memory
      final index = _transactions.indexWhere((t) => t.id == transaction.id);
      if (index >= 0) {
        _transactions[index] = transaction;
      }

      // Refresh data
      await fetchTransactions();
      await fetchSavingGoals();

      _isLoading = false;
      _isInTransactionUpdate = false; // Reset flag
      notifyListeners();

      result['success'] = true;
      if (result['message'].isEmpty) {
        result['message'] = 'Transaction updated successfully.';
      }
      return result;
    } catch (e) {
      _error = 'Error updating transaction: $e';
      _logger.severe(_error!);
      _isLoading = false;
      _isInTransactionUpdate = false; // Reset flag
      notifyListeners();
      result['message'] = _error!;
      return result;
    }
  }

  /// Deletes a transaction
  Future<bool> deleteTransaction(app_model.Transaction transaction) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _logger.info('Deleting transaction: ${transaction.id}');

      if (transaction.id == null || transaction.id!.isEmpty) {
        _error = 'Transaction ID is required for deletion';
        _logger.warning(_error!);
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // First remove the transaction from the local list to update UI immediately
      _transactions.removeWhere((t) => t.id == transaction.id);
      notifyListeners();

      // Then delete from Firestore
      final success = await _databaseService.deleteTransaction(transaction.id!);

      if (!success) {
        _error = 'Failed to delete transaction from database';
        // If Firestore delete failed, re-fetch to restore the correct state
        await fetchTransactions();
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _logger.info('Successfully deleted transaction: ${transaction.id}');

      // Re-fetch the transactions to ensure everything is in sync
      await fetchTransactions();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete transaction: $e';
      _logger.severe(_error);
      // Re-fetch to ensure UI is in sync
      await fetchTransactions();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Load saving goals
  Future<void> fetchSavingGoals() async {
    if (_userId == null || _userId!.isEmpty) {
      return;
    }

    try {
      _savingGoals = await _databaseService.getSavingGoals(_userId!);
      notifyListeners();
    } catch (e) {
      _logger.warning('Error fetching saving goals: $e');
      // Don't throw - just log and keep empty list
      _savingGoals = [];
    }
  }

  // Add a saving goal
  Future<bool> addSavingGoal(SavingGoal goal) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newGoal = await _databaseService.addSavingGoal(goal);

      _savingGoals.add(newGoal);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error adding saving goal: $_error');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Update a saving goal
  Future<bool> updateSavingGoal(SavingGoal goal) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _databaseService.updateSavingGoal(goal);

      if (success) {
        // Replace the old goal in the list
        final index = _savingGoals.indexWhere((g) => g.id == goal.id);
        if (index >= 0) {
          _savingGoals[index] = goal;
        }

        _isLoading = false;
        notifyListeners();
        return true;
      }

      _error = 'Failed to update saving goal';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error updating saving goal: $_error');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Delete a saving goal
  Future<bool> deleteSavingGoal(SavingGoal goal) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (goal.id == null) {
        _error = 'Saving goal ID is required for deletion';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final success = await _databaseService.deleteSavingGoal(goal.id!);

      if (success) {
        // Remove the goal from the list
        _savingGoals.removeWhere((g) => g.id == goal.id);

        _isLoading = false;
        notifyListeners();
        return true;
      }

      _error = 'Failed to delete saving goal';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error deleting saving goal: $_error');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Contribute to a saving goal
  Future<bool> contributeSavingGoal(SavingGoal goal, double amount) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Create a transaction for the contribution
      final transaction = app_model.Transaction(
        userId: goal.userId,
        title: 'Contribution to ${goal.title}',
        amount: amount,
        date: DateTime.now(),
        type: app_model.TransactionType.expense,
        category: 'Savings',
        note: 'Contribution to saving goal',
        goalId: goal.id,
      );

      // Add the transaction
      await _databaseService.addTransaction(transaction);

      // Update the goal with the new amount
      final updatedGoal = goal.copyWith(
        currentAmount: goal.currentAmount + amount,
      );

      final success = await _databaseService.updateSavingGoal(updatedGoal);

      if (success) {
        // Use new fetch methods instead of old load methods
        _userId = goal.userId;
        await fetchSavingGoals();
        await fetchTransactions();

        _isLoading = false;
        notifyListeners();
        return true;
      }

      _error = 'Failed to contribute to saving goal';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error contributing to saving goal: $_error');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Load spending categories
  Future<void> fetchSpendingCategories() async {
    if (_userId == null || _userId!.isEmpty) {
      return;
    }

    try {
      _categories = await _databaseService.getCategories(_userId!);
      notifyListeners();
    } catch (e) {
      _logger.warning('Error fetching categories: $e');
      // Don't throw - just log and keep empty list
      _categories = [];
    }
  }

  // Add a category
  Future<bool> addCategory(app_category.Category category) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newCategory = await _databaseService.addCategory(category);

      _categories.add(newCategory);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error adding category: $_error');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Update a category
  Future<bool> updateCategory(app_category.Category category) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _databaseService.updateCategory(category);

      if (success) {
        // Replace the old category in the list
        final index = _categories.indexWhere((c) => c.id == category.id);
        if (index >= 0) {
          _categories[index] = category;
        }

        _isLoading = false;
        notifyListeners();
        return true;
      }

      _error = 'Failed to update category';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error updating category: $_error');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Delete a category
  Future<bool> deleteCategory(app_category.Category category) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (category.id.isEmpty) {
        _error = 'Category ID is required for deletion';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final success = await _databaseService.deleteCategory(category.id);

      if (success) {
        // Remove the category from the list
        _categories.removeWhere((c) => c.id == category.id);

        _isLoading = false;
        notifyListeners();
        return true;
      }

      _error = 'Failed to delete category';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error deleting category: $_error');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Load financial summary
  Future<void> loadFinancialSummary(String userId) async {
    if (userId.isEmpty) return;

    _userId = userId;
    try {
      await fetchTransactions();
      await fetchSavingGoals();
      await fetchSpendingCategories();
    } catch (e) {
      _logger.warning('Error loading financial summary: $e');
    }
  }

  // Reset error
  void resetError() {
    _error = null;
    notifyListeners();
  }

  // Update financial summary
  Future<void> updateFinancialSummary() async {
    if (_userId == null || _userId!.isEmpty) return;

    try {
      await fetchTransactions();
      await fetchSavingGoals();
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating financial summary: $e');
    }
  }

  // Get a saving goal by ID
  Future<SavingGoal?> getSavingGoalById(String goalId) async {
    try {
      _logger.info('Getting saving goal by ID: $goalId');

      // First, try to find the goal in the local cache
      final matchingGoals =
          _savingGoals.where((goal) => goal.id == goalId).toList();

      if (matchingGoals.isNotEmpty) {
        _logger.info('Found goal in cache: ${matchingGoals.first.title}');
        return matchingGoals.first;
      } else {
        _logger.info('Goal not found in cache, fetching from database');
        // Goal not found in cache, fetch from database
        final goal = await _databaseService.getSavingGoal(goalId);

        if (goal != null) {
          _logger.info('Found goal in database: ${goal.title}');
        } else {
          _logger.warning('Goal not found in database either: $goalId');
        }

        return goal;
      }
    } catch (e) {
      _error = 'Failed to fetch saving goal: $e';
      _logger.warning(_error);
      return null;
    }
  }

  // IMPORTANT: This is ONLY used for new transactions - not for updates
  Future<bool> contributeIncomeToSavingGoal(SavingGoal goal, double amount,
      {bool skipIfFromUpdate = false}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _logger.severe(
          '===== WARNING: contributeIncomeToSavingGoal CALLED DIRECTLY =====');
      _logger.severe(
          'CRITICAL: contributeIncomeToSavingGoal called for goal: ${goal.id}, amount: $amount');
      _logger.severe(
          'GOAL INFO: ${goal.title}, Current amount: ${goal.currentAmount}, Target: ${goal.targetAmount}');
      _logger.severe('Skip if from update flag: $skipIfFromUpdate');
      _logger.severe('_isInTransactionUpdate flag: $_isInTransactionUpdate');

      // Log stack trace to help debug where this is being called from
      _logger.severe('Call stack:');
      try {
        throw Exception('Stack trace');
      } catch (e, stackTrace) {
        _logger.severe(stackTrace.toString());
      }
      _logger.severe(
          '===========================================================');

      // Safety check - never contribute to goals from transaction updates
      if (skipIfFromUpdate || _isInTransactionUpdate) {
        _logger.severe(
            'CRITICAL: Skipping contribution since it came from an update or during transaction update');
        _isLoading = false;
        notifyListeners();
        return true;
      }

      // Double-check this goal exists
      final existingGoal = await getSavingGoalById(goal.id!);
      if (existingGoal == null) {
        _error = 'Goal not found with ID: ${goal.id}';
        _logger.severe(_error!);
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Update the goal with the new amount
      final newAmount = existingGoal.currentAmount + amount;
      _logger.severe(
          'CONTRIBUTING: ${existingGoal.currentAmount} + $amount = $newAmount');

      final updatedGoal = existingGoal.copyWith(currentAmount: newAmount);
      final success = await _databaseService.updateSavingGoal(updatedGoal);

      if (success) {
        _logger.severe(
            'CONTRIBUTION SUCCESSFUL: Goal ${goal.title} updated with new amount: $newAmount');

        // Update local state
        final index = _savingGoals.indexWhere((g) => g.id == goal.id);
        if (index >= 0) {
          _savingGoals[index] = updatedGoal;
        }

        _isLoading = false;
        notifyListeners();
        return true;
      }

      _error = 'Failed to contribute to saving goal';
      _logger.severe(_error!);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Error contributing to saving goal: $e';
      _logger.severe(_error!);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
