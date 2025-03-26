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
        return DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday));
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
        .where((t) =>
            t.type == app_model.TransactionType.income && t.includedInTotals)
        .fold(0, (sumincome, item) => sumincome + item.amount);
  }

  double get totalExpense {
    return filteredTransactions
        .where((t) =>
            t.type == app_model.TransactionType.expense && t.includedInTotals)
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
        .where((t) =>
            t.type == app_model.TransactionType.expense && t.includedInTotals)
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
        final collection =
            FirebaseFirestore.instance.collection('transactions');
        _logger.info('Collection reference created: ${collection.path}');

        // Check if collection exists
        final collectionSnapshot = await collection.limit(1).get();
        _logger
            .info('Collection exists: ${collectionSnapshot.docs.isNotEmpty}');

        // Perform query with fewer constraints initially
        final snapshot =
            await collection.where('userId', isEqualTo: _userId).get();

        _logger.info(
            'Retrieved ${snapshot.docs.length} transactions from database');

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
                  'Document ${doc.id} has invalid date format: ${data['date']}');
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
              'Successfully loaded ${_transactions.length} valid transactions');
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

  // Add a transaction
  Future<bool> addTransaction(app_model.Transaction transaction) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _databaseService.addTransaction(transaction);

      // Update category spent amount if it's an expense with a category
      if (transaction.type == app_model.TransactionType.expense &&
          transaction.category != null &&
          transaction.category!.isNotEmpty) {
        // This will be handled by the database service's _updateCategorySpent method
        // which is called within addTransaction
      }

      await fetchTransactions();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Updates an existing transaction
  Future<bool> updateTransaction(app_model.Transaction transaction) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _logger.info('Updating transaction: ${transaction.id}');

      if (transaction.id == null || transaction.id!.isEmpty) {
        _error = 'Transaction ID is required for update';
        _logger.warning(_error!);
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Store the old transaction for potential rollback
      final oldTransaction = _transactions.firstWhere(
        (t) => t.id == transaction.id,
        orElse: () => transaction,
      );

      // Update in local state first for immediate UI feedback
      final index = _transactions.indexWhere((t) => t.id == transaction.id);
      if (index >= 0) {
        _transactions[index] = transaction;
        notifyListeners();
      } else {
        _logger
            .warning('Transaction not found in local state: ${transaction.id}');
      }

      // Update in Firestore with retry mechanism
      bool success = false;
      int retryCount = 0;
      const maxRetries = 3;

      while (!success && retryCount < maxRetries) {
        try {
          success = await _databaseService.updateTransaction(transaction);
          if (success) break;
          retryCount++;
          await Future.delayed(Duration(milliseconds: 300 * retryCount));
        } catch (e) {
          _logger.warning('Retry ${retryCount + 1} failed: $e');
          retryCount++;
          if (retryCount >= maxRetries) {
            rethrow; // Rethrow after max retries
          }
          await Future.delayed(Duration(milliseconds: 300 * retryCount));
        }
      }

      if (!success) {
        _error =
            'Failed to update transaction in database after $maxRetries attempts';
        _logger.warning(_error!);

        // Rollback local state if database update fails
        if (index >= 0) {
          _transactions[index] = oldTransaction;
          notifyListeners();
        }

        _isLoading = false;
        notifyListeners();
        return false;
      }

      _logger.info('Transaction updated successfully: ${transaction.id}');

      // Re-fetch the transactions to ensure everything is in sync
      await fetchTransactions();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update transaction: $e';
      _logger.severe(_error);

      // Re-fetch to ensure UI is in sync
      await fetchTransactions();

      _isLoading = false;
      notifyListeners();
      return false;
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
          goalId: goal.id);

      // Add the transaction
      await _databaseService.addTransaction(transaction);

      // Update the goal with the new amount
      final updatedGoal =
          goal.copyWith(currentAmount: goal.currentAmount + amount);

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
      // First, check if the goal is in the local cache
      final cachedGoal = _savingGoals.firstWhere(
        (goal) => goal.id == goalId,
        orElse: () => SavingGoal(
            id: '',
            title: '',
            targetAmount: 0,
            userId: ''), // Return a dummy goal that will be ignored
      );

      // Check that we actually got a valid goal with the right ID
      if (cachedGoal.id == goalId) {
        return cachedGoal;
      }
    } catch (e) {
      // Goal not found in cache, fetch from database
      _logger.warning('Error finding goal in cache: $e');
    }

    // If we're here, goal wasn't in the cache or there was an error
    try {
      return await _databaseService.getSavingGoal(goalId);
    } catch (e) {
      _error = 'Failed to fetch saving goal: $e';
      _logger.warning(_error);
      return null;
    }
  }

  // Contribute income to a saving goal (for income transactions)
  Future<bool> contributeIncomeToSavingGoal(
      SavingGoal goal, double amount) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _logger.info(
          'Contributing income to saving goal: ${goal.id}, amount: $amount');

      // Update the goal with the new amount
      final updatedGoal =
          goal.copyWith(currentAmount: goal.currentAmount + amount);

      final success = await _databaseService.updateSavingGoal(updatedGoal);

      if (success) {
        // Update local state
        final index = _savingGoals.indexWhere((g) => g.id == goal.id);
        if (index >= 0) {
          _savingGoals[index] = updatedGoal;
        }

        _isLoading = false;
        notifyListeners();
        return true;
      }

      _error = 'Failed to contribute income to saving goal';
      _logger.warning(_error!);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Error contributing income to saving goal: $e';
      _logger.severe(_error!);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
