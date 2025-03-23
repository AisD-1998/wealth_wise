import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wealth_wise/models/saving_goal.dart';
import 'package:wealth_wise/models/spending_category.dart';
import 'package:wealth_wise/models/transaction.dart';
import 'package:wealth_wise/services/database_service.dart';

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

  // State variables
  bool _isLoading = false;
  String? _error;
  TimeFrame _selectedTimeframe = TimeFrame.month;

  // Data
  List<Transaction> _transactions = [];
  List<SavingGoal> _savingGoals = [];
  List<SpendingCategory> _categories = [];
  Map<String, dynamic> _financialSummary = {};

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  TimeFrame get selectedTimeframe => _selectedTimeframe;
  List<Transaction> get transactions => _transactions;
  List<SavingGoal> get savingGoals => _savingGoals;
  List<SpendingCategory> get categories => _categories;
  Map<String, dynamic> get financialSummary => _financialSummary;

  // Aliases and additional getters
  List<SpendingCategory> get spendingCategories => _categories;
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
        .where((t) => t.type == TransactionType.expense)
        .toList();

    if (expenses.isEmpty) return 0;

    final totalDays = _selectedTimeframe.endDate
            .difference(_selectedTimeframe.startDate)
            .inDays +
        1;

    return totalExpense / totalDays;
  }

  // Get the largest expense
  Transaction? get largestExpense {
    final expenses = filteredTransactions
        .where((t) => t.type == TransactionType.expense)
        .toList();

    if (expenses.isEmpty) return null;

    expenses.sort((a, b) => b.amount.compareTo(a.amount));
    return expenses.first;
  }

  // Filtered transactions based on timeframe
  List<Transaction> get filteredTransactions {
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
        .where((t) => t.type == TransactionType.income)
        .fold(0, (sum, t) => sum + t.amount);
  }

  double get totalExpense {
    return filteredTransactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0, (sum, t) => sum + t.amount);
  }

  double get balance => totalIncome - totalExpense;

  // Category spending for the selected timeframe
  Map<String, double> get categorySpending {
    final Map<String, double> result = {};

    for (var transaction in filteredTransactions) {
      if (transaction.type == TransactionType.expense) {
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
  List<Transaction> get recentTransactions {
    final sorted = List<Transaction>.from(_transactions)
      ..sort((a, b) => b.date.compareTo(a.date));
    return sorted.take(10).toList();
  }

  // Methods to change state
  void setTimeframe(TimeFrame timeframe) {
    _selectedTimeframe = timeframe;
    notifyListeners();
  }

  // Initialize data for a user
  Future<void> initializeFinanceData(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load transactions, saving goals, and categories
      await Future.wait([
        loadTransactions(userId),
        loadSavingGoals(userId),
        loadCategories(userId),
      ]);

      await loadFinancialSummary(userId);

      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error initializing finance data: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Method to load user finances - alias for initializeFinanceData
  Future<void> loadUserFinances(String userId) async {
    await initializeFinanceData(userId);
  }

  // Load transactions
  Future<void> loadTransactions(String userId) async {
    try {
      _transactions = await _databaseService.getTransactions(userId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading transactions: $_error');
    }
  }

  // Add a transaction
  Future<bool> addTransaction(Transaction transaction) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newTransaction = await _databaseService.addTransaction(transaction);

      _transactions.add(newTransaction);
      await loadFinancialSummary(transaction.userId);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error adding transaction: $_error');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Update a transaction
  Future<bool> updateTransaction(Transaction transaction) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _databaseService.updateTransaction(transaction);

      if (success) {
        // Replace the old transaction in the list
        final index = _transactions.indexWhere((t) => t.id == transaction.id);
        if (index >= 0) {
          _transactions[index] = transaction;
        }

        await loadFinancialSummary(transaction.userId);
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _error = 'Failed to update transaction';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error updating transaction: $_error');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Delete a transaction
  Future<bool> deleteTransaction(Transaction transaction) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (transaction.id == null) {
        _error = 'Transaction ID is required for deletion';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final success = await _databaseService.deleteTransaction(transaction.id!);

      if (success) {
        // Remove the transaction from the list
        _transactions.removeWhere((t) => t.id == transaction.id);

        await loadFinancialSummary(transaction.userId);
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _error = 'Failed to delete transaction';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error deleting transaction: $_error');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Load saving goals
  Future<void> loadSavingGoals(String userId) async {
    try {
      _savingGoals = await _databaseService.getSavingGoals(userId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading saving goals: $_error');
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
      final transaction = Transaction(
          userId: goal.userId,
          title: 'Contribution to ${goal.title}',
          amount: amount,
          date: DateTime.now(),
          type: TransactionType.expense,
          category: 'Savings',
          note: 'Contribution to saving goal');

      // Add the transaction
      await _databaseService.addTransaction(transaction);

      // Update the goal with the new amount
      final updatedGoal =
          goal.copyWith(currentAmount: goal.currentAmount + amount);

      final success = await _databaseService.updateSavingGoal(updatedGoal);

      if (success) {
        // Refresh data
        await loadSavingGoals(goal.userId);
        await loadTransactions(goal.userId);
        await loadFinancialSummary(goal.userId);

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
  Future<void> loadCategories(String userId) async {
    try {
      _categories = await _databaseService.getSpendingCategories(userId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading categories: $_error');
    }
  }

  // Add a spending category
  Future<bool> addCategory(SpendingCategory category) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newCategory = await _databaseService.addSpendingCategory(category);

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

  // Update a spending category
  Future<bool> updateCategory(SpendingCategory category) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _databaseService.updateSpendingCategory(category);

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

  // Delete a spending category
  Future<bool> deleteCategory(SpendingCategory category) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (category.id == null) {
        _error = 'Category ID is required for deletion';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final success =
          await _databaseService.deleteSpendingCategory(category.id!);

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
    try {
      // Get current date and previous month
      final now = DateTime.now();
      final currentMonthStart = DateTime(now.year, now.month, 1);
      final previousMonthStart = DateTime(
          now.month > 1 ? now.year : now.year - 1,
          now.month > 1 ? now.month - 1 : 12,
          1);
      final previousMonthEnd =
          currentMonthStart.subtract(const Duration(days: 1));

      // Get transactions for current and previous month
      final currentMonthTransactions = await _databaseService
          .getTransactions(userId, startDate: currentMonthStart, endDate: now);

      final previousMonthTransactions = await _databaseService.getTransactions(
          userId,
          startDate: previousMonthStart,
          endDate: previousMonthEnd);

      // Calculate income and expenses for current month
      double currentIncome = 0;
      double currentExpenses = 0;

      for (var transaction in currentMonthTransactions) {
        if (transaction.type == TransactionType.income) {
          currentIncome += transaction.amount;
        } else {
          currentExpenses += transaction.amount;
        }
      }

      // Calculate income and expenses for previous month
      double previousIncome = 0;
      double previousExpenses = 0;

      for (var transaction in previousMonthTransactions) {
        if (transaction.type == TransactionType.income) {
          previousIncome += transaction.amount;
        } else {
          previousExpenses += transaction.amount;
        }
      }

      // Calculate changes compared to previous month
      final incomeChange = previousIncome != 0
          ? ((currentIncome - previousIncome) / previousIncome) * 100
          : 0;

      final expensesChange = previousExpenses != 0
          ? ((currentExpenses - previousExpenses) / previousExpenses) * 100
          : 0;

      // Get top spending categories for current month
      final categorySpending = this.categorySpending;

      // Sort categories by amount
      final sortedCategories = categorySpending.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Get top 3 categories or less if there are fewer categories
      final topCategories = sortedCategories.take(3).map((entry) {
        return {
          'category': entry.key,
          'amount': entry.value,
          'percentage':
              currentExpenses > 0 ? (entry.value / currentExpenses) * 100 : 0,
        };
      }).toList();

      _financialSummary = {
        'currentMonth': {
          'income': currentIncome,
          'expenses': currentExpenses,
          'balance': currentIncome - currentExpenses,
        },
        'previousMonth': {
          'income': previousIncome,
          'expenses': previousExpenses,
          'balance': previousIncome - previousExpenses,
        },
        'changes': {
          'income': incomeChange,
          'expenses': expensesChange,
        },
        'topCategories': topCategories,
      };

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading financial summary: $_error');
    }
  }

  // Reset error
  void resetError() {
    _error = null;
    notifyListeners();
  }
}
