import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wealth_wise/models/saving_goal.dart';
import 'package:wealth_wise/models/budget_model.dart';
import 'package:wealth_wise/models/transaction.dart' as app_model;
import 'package:wealth_wise/services/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';
import 'package:wealth_wise/models/category.dart' as app_category;
import 'package:wealth_wise/controllers/feature_access_controller.dart';
import 'package:wealth_wise/models/budget_alert.dart';
import 'package:wealth_wise/models/bill_reminder.dart';
import 'package:wealth_wise/models/investment.dart';
import 'package:wealth_wise/models/achievement.dart';
import 'package:wealth_wise/services/gamification_service.dart';
import 'package:wealth_wise/utils/currency_formatter.dart';
import '../utils/migration_helpers.dart';

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
  List<Budget> _budgets = [];
  List<app_category.Category> _categories = [];
  final Map<String, dynamic> _financialSummary = {};
  List<BudgetAlert> _budgetAlerts = [];
  List<BillReminder> _billReminders = [];
  List<Investment> _investments = [];
  int _currentStreak = 0;
  List<Achievement> _achievements = [];

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  TimeFrame get selectedTimeframe => _selectedTimeframe;
  List<BudgetAlert> get budgetAlerts => _budgetAlerts;
  List<BillReminder> get billReminders => _billReminders;
  List<Investment> get investments => _investments;
  int get currentStreak => _currentStreak;
  List<Achievement> get achievements => _achievements;

  // Portfolio getters
  double get portfolioTotalValue =>
      _investments.fold(0, (total, inv) => total + inv.totalValue);
  double get portfolioTotalCost =>
      _investments.fold(0, (total, inv) => total + inv.totalCost);

  /// Bills that are upcoming (due within 7 days) or overdue, sorted by due date.
  List<BillReminder> get upcomingBills {
    final now = DateTime.now();
    final weekFromNow = now.add(const Duration(days: 7));
    return _billReminders
        .where((b) =>
            !b.isPaid &&
            b.dueDate.isBefore(weekFromNow))
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }
  List<app_model.Transaction> get transactions => _transactions;
  List<SavingGoal> get savingGoals => _savingGoals;
  List<Budget> get budgets => _budgets;
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

      // Run category type migration if needed
      try {
        await MigrationHelpers.migrateCategoryTypes(userId);
      } catch (migrationError) {
        _logger.warning('Category migration error: $migrationError');
        // Continue with initialization even if migration fails
      }

      await fetchTransactions();
      await fetchSpendingCategories();
      await fetchSavingGoals();
      await fetchBudgets();
      await fetchBillReminders();
      await fetchInvestments();
      await processRecurringTransactions();
      final isPremium = await _checkPremiumStatus();
      checkBudgetAlerts(isPremium: isPremium);
      await _loadAndCheckGamification(isPremium);
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

  // Check if user has premium status
  Future<bool> _checkPremiumStatus() async {
    try {
      if (_userId == null || _userId!.isEmpty) return false;

      final user = await _databaseService.getUserData(_userId!);
      if (user == null) return false;

      return user.isSubscribed &&
          (user.subscriptionEndDate?.isAfter(DateTime.now()) ?? false);
    } catch (e) {
      _logger.warning('Error checking premium status: $e');
      return false;
    }
  }

  // Check if user can add more saving goals
  Future<bool> canAddSavingGoal() async {
    if (_userId == null || _userId!.isEmpty) return false;

    try {
      final isPremium = await _checkPremiumStatus();
      if (isPremium) return true;

      // For free users, check quota
      final featureAccessController = FeatureAccessController();
      final user = await _databaseService.getUserData(_userId!);
      return featureAccessController.checkQuota(
          user, 'saving_goals', _savingGoals.length);
    } catch (e) {
      _logger.warning('Error checking if user can add saving goal: $e');
      return false;
    }
  }

  // Get remaining quota for a feature
  Future<int> getRemainingQuota(String featureType) async {
    if (_userId == null || _userId!.isEmpty) return 0;

    try {
      final isPremium = await _checkPremiumStatus();
      if (isPremium) return -1; // unlimited

      final featureAccessController = FeatureAccessController();
      final user = await _databaseService.getUserData(_userId!);

      if (user == null) return 0;

      int currentCount = 0;
      switch (featureType) {
        case 'saving_goals':
          currentCount = _savingGoals.length;
          break;
        case 'custom_categories':
          currentCount = _categories.length;
          break;
        case 'transactions_per_month':
          currentCount = _transactions.length;
          break;
      }

      final quotaLimit =
          featureAccessController.getQuotaLimit(featureType, isPremium);
      return quotaLimit == -1 ? -1 : quotaLimit - currentCount;
    } catch (e) {
      _logger.warning('Error getting remaining quota: $e');
      return 0;
    }
  }

  // Load transactions
  Future<void> fetchTransactions() async {
    if (_userId == null || _userId!.isEmpty) {
      _logger.warning('Cannot fetch transactions: userId is empty');
      return;
    }

    try {
      _logger.info('Fetching transactions for user: $_userId');

      final isPremium = await _checkPremiumStatus();
      _logger.info('User premium status: $isPremium');

      final snapshot = await _buildTransactionQuery(isPremium);
      _transactions = _parseTransactionDocs(snapshot.docs, isPremium);
      _transactions.sort((a, b) => b.date.compareTo(a.date));

      if (_transactions.isEmpty) {
        _logger.warning('No valid transactions found for user: $_userId');
      } else {
        _logger.info(
            'Successfully loaded ${_transactions.length} valid transactions');
      }

      notifyListeners();
    } catch (e) {
      _logger.warning('Error fetching transactions: $e');
      _transactions = [];
      notifyListeners();
    }
  }

  Future<QuerySnapshot> _buildTransactionQuery(bool isPremium) async {
    final collection =
        FirebaseFirestore.instance.collection('transactions');
    _logger.info('Collection reference created: ${collection.path}');

    final collectionSnapshot = await collection.limit(1).get();
    _logger.info('Collection exists: ${collectionSnapshot.docs.isNotEmpty}');

    Query query = collection.where('userId', isEqualTo: _userId);

    if (!isPremium) {
      final thirtyDaysAgo =
          DateTime.now().subtract(const Duration(days: 30));
      query = query.where('date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo));
      _logger.info('Free user: limiting transactions to last 30 days');
    }

    final snapshot = await query.get();
    _logger.info(
        'Retrieved ${snapshot.docs.length} transactions from database');
    return snapshot;
  }

  List<app_model.Transaction> _parseTransactionDocs(
      List<QueryDocumentSnapshot> docs, bool isPremium) {
    final docsToProcess = !isPremium && docs.length > 50
        ? docs.take(50).toList()
        : docs;

    if (!isPremium && docs.length > 50) {
      _logger.info(
          'Free user: limiting to 50 transactions out of ${docs.length}');
    }

    final List<app_model.Transaction> result = [];

    for (var doc in docsToProcess) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        if (data['date'] is Timestamp) {
          final transaction = app_model.Transaction.fromMap(data, doc.id);
          result.add(transaction);
        } else {
          _logger.warning(
              'Document ${doc.id} has invalid date format: ${data['date']}');
        }
      } catch (docError) {
        _logger.warning('Error parsing document ${doc.id}: $docError');
      }
    }

    return result;
  }

  // Handle transaction interactions with saving goals
  Future<Map<String, dynamic>> _handleSavingGoalTransaction(
      app_model.Transaction oldTransaction,
      app_model.Transaction newTransaction) async {
    Map<String, dynamic> result = {'success': true};

    try {
      final String? oldGoalId = oldTransaction.goalId;
      final String? newGoalId = newTransaction.goalId;

      // Only process if this is an income transaction
      if (newTransaction.type != app_model.TransactionType.income &&
          oldTransaction.type != app_model.TransactionType.income) {
        _logger.info('Not an income transaction, skipping goal processing');
        return result;
      }

      _logger.info('_handleSavingGoalTransaction: Processing goals');
      _logger.info('Old goal ID: $oldGoalId');
      _logger.info('New goal ID: $newGoalId');
      _logger.info('Old amount: ${oldTransaction.amount}');
      _logger.info('New amount: ${newTransaction.amount}');
      _logger.info(
          'Old contribution %: ${oldTransaction.contributionPercentage}%');
      _logger.info(
          'New contribution %: ${newTransaction.contributionPercentage}%');

      final double oldEffectiveAmount = oldTransaction.contributesToGoal
          ? oldTransaction.amount *
              (oldTransaction.contributionPercentage ?? 100.0) /
              100.0
          : 0.0;

      final double newEffectiveAmount = newTransaction.contributesToGoal
          ? newTransaction.amount *
              (newTransaction.contributionPercentage ?? 100.0) /
              100.0
          : 0.0;

      _logger.info('Old effective contribution: $oldEffectiveAmount');
      _logger.info('New effective contribution: $newEffectiveAmount');

      final bool oldHasGoal = oldGoalId != null && oldGoalId.isNotEmpty;
      final bool newHasGoal = newGoalId != null && newGoalId.isNotEmpty;

      if (!oldHasGoal && newHasGoal) {
        result = await _handleGoalAdded(
            newGoalId, newEffectiveAmount, newTransaction, result);
      } else if (oldHasGoal && newHasGoal && oldGoalId != newGoalId) {
        result = await _handleGoalChanged(oldGoalId, newGoalId,
            oldEffectiveAmount, newEffectiveAmount, newTransaction, result);
      } else if (oldHasGoal && !newHasGoal) {
        result = await _handleGoalRemoved(
            oldGoalId, oldEffectiveAmount, result);
      } else if (oldHasGoal && newHasGoal && oldGoalId == newGoalId) {
        result = await _handleGoalAmountUpdated(
            newGoalId, oldEffectiveAmount, newEffectiveAmount, result);
      } else {
        _logger.fine('CASE 5: No relevant goal changes detected');
        _logger.fine('Old transaction type: ${oldTransaction.type}');
        _logger.fine('New transaction type: ${newTransaction.type}');
        _logger.fine('Old goal ID: $oldGoalId');
        _logger.fine('New goal ID: $newGoalId');
        _logger.fine('Old amount: ${oldTransaction.amount}');
        _logger.fine('New amount: ${newTransaction.amount}');
      }

      return result;
    } catch (e) {
      _logger.severe('Error handling saving goal transaction: $e');
      return {
        'success': false,
        'error': 'Error handling saving goal transaction: $e'
      };
    }
  }

  // CASE 1: No old goal, but new one added
  Future<Map<String, dynamic>> _handleGoalAdded(
    String newGoalId,
    double newEffectiveAmount,
    app_model.Transaction newTransaction,
    Map<String, dynamic> result,
  ) async {
    _logger.info('CASE 1: Adding contribution to new goal');

    final newGoal = await getSavingGoalById(newGoalId);
    if (newGoal == null) {
      _logger.warning('New goal not found: $newGoalId');
      return {'success': false, 'error': 'New goal not found: $newGoalId'};
    }

    result['newGoalName'] = newGoal.title;
    result['willExceedTarget'] =
        (newGoal.currentAmount + newEffectiveAmount) >= newGoal.targetAmount;

    if (newGoal.isCompleted) {
      _logger.warning('Adding to a completed goal: ${newGoal.title}');
      result['isCompleted'] = true;
      result['addedToCompletedGoal'] = true;
    }

    await addContributionToSavingGoal(newGoal, newTransaction.amount,
        contributionPercentage: newTransaction.contributionPercentage);
    result['goalAdded'] = true;
    return result;
  }

  // CASE 2: Both old and new goals exist, but they're different
  Future<Map<String, dynamic>> _handleGoalChanged(
    String oldGoalId,
    String newGoalId,
    double oldEffectiveAmount,
    double newEffectiveAmount,
    app_model.Transaction newTransaction,
    Map<String, dynamic> result,
  ) async {
    _logger.info('CASE 2: Changing from one goal to another');

    final oldGoal = await getSavingGoalById(oldGoalId);
    if (oldGoal == null) {
      _logger.warning('Old goal not found: $oldGoalId');
      return {'success': false, 'error': 'Old goal not found: $oldGoalId'};
    }

    final newGoal = await getSavingGoalById(newGoalId);
    if (newGoal == null) {
      _logger.warning('New goal not found: $newGoalId');
      return {'success': false, 'error': 'New goal not found: $newGoalId'};
    }

    result['oldGoalName'] = oldGoal.title;
    result['newGoalName'] = newGoal.title;

    if (newGoal.isCompleted) {
      _logger.warning('Changing to a completed goal: ${newGoal.title}');
      result['isCompleted'] = true;
    }

    result['willExceedTarget'] =
        (newGoal.currentAmount + newEffectiveAmount) >= newGoal.targetAmount;

    // Remove contribution from old goal
    final calculatedAmount = oldGoal.currentAmount - oldEffectiveAmount;
    final double oldGoalNewAmount =
        calculatedAmount < 0.0 ? 0.0 : calculatedAmount;
    await _databaseService.updateSavingGoal(
        oldGoal.copyWith(currentAmount: oldGoalNewAmount));

    // Then add to new goal
    await addContributionToSavingGoal(newGoal, newTransaction.amount,
        contributionPercentage: newTransaction.contributionPercentage);
    result['goalChanged'] = true;
    return result;
  }

  // CASE 3: Had a goal before, but now removed
  Future<Map<String, dynamic>> _handleGoalRemoved(
    String oldGoalId,
    double oldEffectiveAmount,
    Map<String, dynamic> result,
  ) async {
    _logger.info('CASE 3: Removing goal from transaction');

    final oldGoal = await getSavingGoalById(oldGoalId);
    if (oldGoal == null) {
      _logger.warning('Old goal not found: $oldGoalId');
      return {'success': false, 'error': 'Old goal not found: $oldGoalId'};
    }

    result['oldGoalName'] = oldGoal.title;

    final calculatedAmount = oldGoal.currentAmount - oldEffectiveAmount;
    final double oldGoalNewAmount =
        calculatedAmount < 0.0 ? 0.0 : calculatedAmount;
    await _databaseService.updateSavingGoal(
        oldGoal.copyWith(currentAmount: oldGoalNewAmount));
    result['goalRemoved'] = true;
    return result;
  }

  // CASE 4: Same goal, but amount might have changed
  Future<Map<String, dynamic>> _handleGoalAmountUpdated(
    String goalId,
    double oldEffectiveAmount,
    double newEffectiveAmount,
    Map<String, dynamic> result,
  ) async {
    _logger.info('CASE 4: Updating same goal with new amount');

    final goal = await getSavingGoalById(goalId);
    if (goal == null) {
      _logger.warning('Goal not found: $goalId');
      return {'success': false, 'error': 'Goal not found: $goalId'};
    }

    result['oldGoalName'] = goal.title;
    result['newGoalName'] = goal.title;

    if (goal.isCompleted) {
      _logger.warning('Updating a completed goal: ${goal.title}');
      result['isCompleted'] = true;
    }

    final double differenceAmount = newEffectiveAmount - oldEffectiveAmount;
    final calculatedNewAmount = goal.currentAmount + differenceAmount;
    final double updatedAmount =
        calculatedNewAmount < 0.0 ? 0.0 : calculatedNewAmount;

    _logger.info('Difference amount: $differenceAmount');
    _logger.info('New goal amount: $updatedAmount');

    result['willExceedTarget'] = updatedAmount >= goal.targetAmount;

    await _databaseService
        .updateSavingGoal(goal.copyWith(currentAmount: updatedAmount));
    result['goalUpdated'] = true;
    return result;
  }

  // Handle new transaction contribution to a saving goal
  Future<bool> addContributionToSavingGoal(SavingGoal goal, double amount,
      {double? contributionPercentage}) async {
    try {
      final double effectiveAmount =
          contributionPercentage != null && contributionPercentage < 100
              ? amount * contributionPercentage / 100
              : amount;

      _logger.info(
          'Adding contribution to goal: ${goal.id}, amount: $effectiveAmount (${contributionPercentage ?? 100}% of $amount)');

      // Verify goal exists and get latest data
      final existingGoal = await getSavingGoalById(goal.id!);
      if (existingGoal == null) {
        _error = 'Goal not found with ID: ${goal.id}';
        _logger.warning(_error!);
        return false;
      }

      // Update the goal amount
      final newAmount = existingGoal.currentAmount + effectiveAmount;
      _logger.info(
          'Updating goal amount: ${existingGoal.currentAmount} + $effectiveAmount = $newAmount');

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
      _logger.fine('Adding transaction with goal handling');
      _logger.fine('Transaction goal ID: ${transaction.goalId}');
      _logger.fine('Provided goal ID: ${savingGoal?.id}');
      _logger.fine(
          'Contribution percentage: ${transaction.contributionPercentage}%');

      // Verify the goal IDs match
      if (savingGoal != null &&
          transaction.goalId != null &&
          transaction.goalId != savingGoal.id) {
        _logger.fine(
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
        _logger.fine(
            'Transaction added, now updating goal: ${savingGoal.id} (${savingGoal.title})');

        // Add contribution to goal - use the actual goal object to ensure we're updating the right one
        final goalSuccess = await addContributionToSavingGoal(
            savingGoal, transaction.amount,
            contributionPercentage: transaction.contributionPercentage);
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
        _logger.fine('Transaction has goal ID: ${transaction.goalId}');
        final goal = await getSavingGoalById(transaction.goalId!);

        if (goal != null) {
          _logger
              .fine('Found goal for transaction: ${goal.title} (${goal.id})');
          return addTransactionWithGoal(transaction, goal);
        } else {
          _logger.warning('ERROR: Goal not found for ID: ${transaction.goalId}');
          _error = 'Goal not found with ID: ${transaction.goalId}';
          notifyListeners();
          return false;
        }
      } else {
        _logger.fine('Transaction has no goal ID or is not income type');
      }

      // Fallback to simple transaction without goal
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _databaseService.addTransaction(transaction);
      await fetchTransactions();
      checkBudgetAlerts();
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

      // Handle goal changes if applicable
      result = await _handleGoalChanges(
          oldTransaction, transaction, result);
      if (result.containsKey('_earlyReturn') && result['_earlyReturn']) {
        result.remove('_earlyReturn');
        return result;
      }

      // Persist the transaction update
      result = await _persistTransactionUpdate(transaction, result);

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

  Future<Map<String, dynamic>> _handleGoalChanges(
    app_model.Transaction oldTransaction,
    app_model.Transaction transaction,
    Map<String, dynamic> result,
  ) async {
    final String? oldGoalId = oldTransaction.goalId;
    final String? newGoalId = transaction.goalId;

    _logger.info('oldGoalId: $oldGoalId');
    _logger.info('newGoalId: $newGoalId');

    final bool hasGoalInvolved =
        (oldGoalId != null && oldGoalId.isNotEmpty) ||
        (newGoalId != null && newGoalId.isNotEmpty);

    if (!hasGoalInvolved) return result;

    _logger.info('Transaction has goal ID - handling saving goal updates');
    final goalResult =
        await _handleSavingGoalTransaction(oldTransaction, transaction);

    if (!goalResult['success']) {
      _error = goalResult['error'];
      _logger.warning(_error!);
      _isLoading = false;
      _isInTransactionUpdate = false;
      notifyListeners();
      result['success'] = false;
      result['message'] = _error!;
      result['_earlyReturn'] = true;
      return result;
    }

    result = _buildUpdateResultMessage(goalResult, transaction, result);

    // Check if the transaction will exceed the goal target
    if (goalResult.containsKey('willExceedTarget') &&
        goalResult['willExceedTarget']) {
      result['willExceedTarget'] = true;
      result['newGoalName'] = goalResult['newGoalName'];
      result['newGoalTarget'] = goalResult['newGoalTarget'];
      result['newGoalCurrent'] = goalResult['newGoalCurrent'];
      result['transactionAmount'] = goalResult['transactionAmount'];
    }

    return result;
  }

  String _buildContributionPercentInfo(app_model.Transaction transaction) {
    if (transaction.contributionPercentage != null &&
        transaction.contributionPercentage! < 100) {
      return " (${transaction.contributionPercentage!.toStringAsFixed(0)}% of income)";
    }
    return "";
  }

  Map<String, dynamic> _buildUpdateResultMessage(
    Map<String, dynamic> goalResult,
    app_model.Transaction transaction,
    Map<String, dynamic> result,
  ) {
    final percentInfo = _buildContributionPercentInfo(transaction);
    final bool isCompleted = goalResult.containsKey('isCompleted') &&
        goalResult['isCompleted'];

    if (goalResult.containsKey('goalChanged') && goalResult['goalChanged']) {
      result['goalChanged'] = true;
      result['oldGoalName'] = goalResult['oldGoalName'];
      result['newGoalName'] = goalResult['newGoalName'];

      if (isCompleted) {
        result['isCompleted'] = true;
        result['message'] =
            'Transaction moved to already completed goal "${goalResult['newGoalName']}". '
            'Goal progress updated accordingly.$percentInfo';
      } else {
        result['message'] =
            'Transaction moved from "${goalResult['oldGoalName']}" to "${goalResult['newGoalName']}".$percentInfo';
      }
    } else if (goalResult.containsKey('goalAdded') &&
        goalResult['goalAdded']) {
      result['goalAdded'] = true;
      result['newGoalName'] = goalResult['newGoalName'];

      if (isCompleted) {
        result['isCompleted'] = true;
        result['message'] =
            'Transaction added to already completed goal "${goalResult['newGoalName']}". '
            'Goal progress updated.$percentInfo';
      } else {
        result['message'] =
            'Transaction now contributes to "${goalResult['newGoalName']}".$percentInfo';
      }
    } else if (goalResult.containsKey('goalRemoved') &&
        goalResult['goalRemoved']) {
      result['goalRemoved'] = true;
      result['oldGoalName'] = goalResult['oldGoalName'];
      result['message'] =
          'Transaction no longer contributes to "${goalResult['oldGoalName']}"';
    } else if (goalResult.containsKey('goalUpdated') &&
        goalResult['goalUpdated']) {
      result['goalUpdated'] = true;
      result['newGoalName'] = goalResult['newGoalName'];

      if (isCompleted) {
        result['isCompleted'] = true;
        result['message'] =
            'Updated contribution to completed goal "${goalResult['newGoalName']}".$percentInfo';
      } else {
        result['message'] =
            'Updated contribution to "${goalResult['newGoalName']}".$percentInfo';
      }
    }

    return result;
  }

  Future<Map<String, dynamic>> _persistTransactionUpdate(
    app_model.Transaction transaction,
    Map<String, dynamic> result,
  ) async {
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

      // Check if this is an income transaction with a goal
      if (transaction.type == app_model.TransactionType.income &&
          transaction.goalId != null &&
          transaction.goalId!.isNotEmpty) {
        _logger.info(
            'Income transaction with goal ID: ${transaction.goalId} being deleted');

        // Get the associated saving goal
        final goal = await getSavingGoalById(transaction.goalId!);

        if (goal != null) {
          _logger.info(
              'Found goal: ${goal.title} with current amount ${goal.currentAmount}');

          // Calculate new amount by removing the transaction amount
          double newAmount = goal.currentAmount - transaction.amount;
          if (newAmount < 0) newAmount = 0;

          _logger
              .info('Updating goal amount: ${goal.currentAmount} → $newAmount');

          // Update the goal with the new amount
          final updatedGoal = goal.copyWith(currentAmount: newAmount);
          final updateSuccess =
              await _databaseService.updateSavingGoal(updatedGoal);

          if (updateSuccess) {
            // Update local state if successful
            final index = _savingGoals.indexWhere((g) => g.id == goal.id);
            if (index >= 0) {
              _savingGoals[index] = updatedGoal;
              _logger.info('Updated goal in memory');
            }
          } else {
            _logger.warning(
                'Failed to update goal balance when deleting transaction');
          }
        } else {
          _logger.warning(
              'Goal not found for transaction being deleted: ${transaction.goalId}');
        }
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

      // Re-fetch the transactions and saving goals to ensure everything is in sync
      await fetchTransactions();
      await fetchSavingGoals();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete transaction: $e';
      _logger.severe(_error);
      // Re-fetch to ensure UI is in sync
      await fetchTransactions();
      await fetchSavingGoals();
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
      // Check if user has premium status
      final isPremium = await _checkPremiumStatus();

      // Get all user's saving goals
      _savingGoals = await _databaseService.getSavingGoals(_userId!);

      // For free users, limit the number of goals if they somehow have more than allowed
      if (!isPremium) {
        final featureAccessController = FeatureAccessController();
        final limit =
            featureAccessController.getQuotaLimit('saving_goals', false);

        if (limit != -1 && _savingGoals.length > limit) {
          _logger.info(
              'Free user has ${_savingGoals.length} goals, limiting to $limit');
          // Keep only active goals up to the limit
          _savingGoals.sort((a, b) {
            // Sort by completion status (incomplete first) then by current amount (highest first)
            if (a.isCompleted != b.isCompleted) {
              return a.isCompleted ? 1 : -1;
            }
            return b.currentAmount.compareTo(a.currentAmount);
          });
          _savingGoals = _savingGoals.take(limit).toList();
        }
      }

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
      _logger.fine('Error adding saving goal: $_error');
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
      _logger.fine('Error updating saving goal: $_error');
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

      // Clear goalId from linked transactions before deleting
      final linkedTransactions =
          _transactions.where((t) => t.goalId == goal.id).toList();
      for (final t in linkedTransactions) {
        final updated = t.copyWith(goalId: '');
        await _databaseService.updateTransaction(updated);
      }

      final success = await _databaseService.deleteSavingGoal(goal.id!);

      if (success) {
        // Remove the goal from the list
        _savingGoals.removeWhere((g) => g.id == goal.id);
        // Refresh transactions to reflect cleared goalId references
        await fetchTransactions();

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
      _logger.fine('Error deleting saving goal: $_error');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Load budgets
  Future<void> fetchBudgets() async {
    if (_userId == null || _userId!.isEmpty) {
      return;
    }

    try {
      _budgets = await _databaseService.getBudgets(_userId!);
      notifyListeners();
    } catch (e) {
      _logger.warning('Error fetching budgets: $e');
      _budgets = [];
    }
  }

  // Add a budget
  Future<bool> addBudget(Budget budget) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newBudget = await _databaseService.createBudget(
        budget.userId,
        budget.category,
        budget.amount,
        budget.startDate,
        budget.endDate,
      );

      _budgets.add(newBudget);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _logger.fine('Error adding budget: $_error');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Update a budget
  Future<bool> updateBudget(Budget budget) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _databaseService.updateBudget(budget);

      // Replace the old budget in the list
      final index = _budgets.indexWhere((b) => b.id == budget.id);
      if (index >= 0) {
        _budgets[index] = budget;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _logger.fine('Error updating budget: $_error');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Delete a budget
  Future<bool> deleteBudget(Budget budget) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _databaseService.deleteBudget(budget.id);

      _budgets.removeWhere((b) => b.id == budget.id);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _logger.fine('Error deleting budget: $_error');
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
      // Create a transaction for the contribution (income type so
      // contributesToGoal is recognized by the Transaction model)
      final transaction = app_model.Transaction(
        userId: goal.userId,
        title: 'Contribution to ${goal.title}',
        amount: amount,
        date: DateTime.now(),
        type: app_model.TransactionType.income,
        category: 'Savings',
        note: 'Contribution to saving goal',
        goalId: goal.id,
        contributionPercentage: 100.0,
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
      _logger.fine('Error contributing to saving goal: $_error');
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
      // Check if user has premium status
      final isPremium = await _checkPremiumStatus();

      // Get all categories
      _categories = await _databaseService.getCategories(_userId!);

      // For free users, limit the number of custom categories
      if (!isPremium) {
        final featureAccessController = FeatureAccessController();
        final limit =
            featureAccessController.getQuotaLimit('custom_categories', false);

        if (limit != -1) {
          // Default category names that should always be available
          final defaultCategoryNames = [
            'Salary', 'Investments', 'Business', 'Gifts', // Income
            'Food & Dining', 'Housing', 'Transportation', 'Entertainment',
            'Utilities', 'Health', 'Other' // Expense
          ];

          // Separate default and custom categories
          final defaultCategories = _categories
              .where((c) => defaultCategoryNames.contains(c.name))
              .toList();

          final customCategories = _categories
              .where((c) => !defaultCategoryNames.contains(c.name))
              .toList();

          if (customCategories.length > limit) {
            _logger.info(
                'Free user has ${customCategories.length} custom categories, limiting to $limit');
            // Sort by most recently used
            customCategories.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
            // Keep only the most recently used ones up to the limit
            final allowedCustomCategories =
                customCategories.take(limit).toList();
            // Combine default and allowed custom categories
            _categories = [...defaultCategories, ...allowedCustomCategories];
          }
        }
      }

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
      _logger.fine('Error adding category: $_error');
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
      _logger.fine('Error updating category: $_error');
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
      _logger.fine('Error deleting category: $_error');
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
      await fetchBudgets();
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
      _logger.fine('Error updating financial summary: $e');
    }
  }

  // Get a saving goal by ID from cache or database
  Future<SavingGoal?> getSavingGoalById(String goalId) async {
    _logger.info('Getting saving goal by ID: $goalId');

    // First check in memory/cache
    final matchingGoals = _savingGoals.where((g) => g.id == goalId).toList();
    if (matchingGoals.isNotEmpty) {
      final goal = matchingGoals.first;
      _logger.info('Found goal in cache: ${goal.title}');
      _logger.info(
          'Goal amount: ${goal.currentAmount}/${goal.targetAmount}, completed: ${goal.isCompleted}');
      return goal;
    }

    // If not found in cache, try to fetch from database
    try {
      final goal = await _databaseService.getSavingGoal(goalId);
      if (goal != null) {
        _logger.info('Found goal in database: ${goal.title}');
        _logger.info(
            'Goal amount: ${goal.currentAmount}/${goal.targetAmount}, completed: ${goal.isCompleted}');
        return goal;
      } else {
        _logger.warning('Goal not found in database: $goalId');
        return null;
      }
    } catch (e) {
      _logger.severe('Failed to fetch saving goal: $e');
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
      _logger.fine(
          '===== WARNING: contributeIncomeToSavingGoal CALLED DIRECTLY =====');
      _logger.fine(
          'CRITICAL: contributeIncomeToSavingGoal called for goal: ${goal.id}, amount: $amount');
      _logger.fine(
          'GOAL INFO: ${goal.title}, Current amount: ${goal.currentAmount}, Target: ${goal.targetAmount}');
      _logger.fine('Skip if from update flag: $skipIfFromUpdate');
      _logger.fine('_isInTransactionUpdate flag: $_isInTransactionUpdate');

      // Log stack trace to help debug where this is being called from
      _logger.fine('Call stack:');
      try {
        throw Exception('Stack trace');
      } catch (e, stackTrace) {
        _logger.fine(stackTrace.toString());
      }
      _logger.fine(
          '===========================================================');

      // Safety check - never contribute to goals from transaction updates
      if (skipIfFromUpdate || _isInTransactionUpdate) {
        _logger.fine(
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
      _logger.fine(
          'CONTRIBUTING: ${existingGoal.currentAmount} + $amount = $newAmount');

      final updatedGoal = existingGoal.copyWith(currentAmount: newAmount);
      final success = await _databaseService.updateSavingGoal(updatedGoal);

      if (success) {
        _logger.fine(
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

  // ─── Budget Alerts ──────────────────────────────────────────────────

  /// Check all budgets and generate alerts for those at or near their limits.
  /// Called after every transaction add/update/delete and on init.
  /// Pass `isPremium: true` to include predictive alerts.
  void checkBudgetAlerts({bool isPremium = false}) {
    final alerts = <BudgetAlert>[];

    for (final budget in _budgets) {
      final percent = budget.percentUsed;

      if (percent >= 100) {
        alerts.add(BudgetAlert(
          budgetId: budget.id,
          category: budget.category,
          percentUsed: percent,
          alertType: BudgetAlertType.exceeded100,
          message:
              'You\'ve exceeded your ${budget.category} budget by ${CurrencyFormatter.format(budget.spent - budget.amount)}',
        ));
      } else if (percent >= 75) {
        alerts.add(BudgetAlert(
          budgetId: budget.id,
          category: budget.category,
          percentUsed: percent,
          alertType: BudgetAlertType.warning75,
          message:
              '${budget.category} budget is ${percent.toStringAsFixed(0)}% used — ${CurrencyFormatter.format(budget.remainingAmount)} remaining',
        ));
      }

      // Premium predictive alert: project if spending pace will exceed budget
      if (isPremium && percent < 100 && percent > 0) {
        final now = DateTime.now();
        final daysElapsed =
            now.difference(budget.startDate).inDays.clamp(1, 999);
        final totalDays =
            budget.endDate.difference(budget.startDate).inDays.clamp(1, 999);
        final dailyRate = budget.spent / daysElapsed;
        final projectedTotal = dailyRate * totalDays;

        if (projectedTotal > budget.amount) {
          final overage = projectedTotal - budget.amount;
          alerts.add(BudgetAlert(
            budgetId: budget.id,
            category: budget.category,
            percentUsed: percent,
            alertType: BudgetAlertType.predictive,
            message:
                'At current pace, you\'ll exceed ${budget.category} by ${CurrencyFormatter.format(overage)}',
            predictedOverage: overage,
          ));
        }
      }
    }

    _budgetAlerts = alerts;
    // Don't call notifyListeners here — caller is responsible
  }

  /// Dismiss a budget alert by its budgetId (removes from in-memory list).
  void dismissBudgetAlert(String budgetId) {
    _budgetAlerts.removeWhere((a) => a.budgetId == budgetId);
    notifyListeners();
  }

  // ─── Recurring Transactions ─────────────────────────────────────────

  /// Get all recurring transaction templates (not generated children).
  List<app_model.Transaction> get recurringTransactions {
    return _transactions
        .where((t) => t.isRecurring && t.parentTransactionId == null)
        .toList();
  }

  /// Process recurring transactions: create any entries that are due up to today.
  /// Called on app init. Finds the latest child for each recurring template,
  /// then generates entries from there up to today.
  Future<void> processRecurringTransactions() async {
    if (_userId == null || _userId!.isEmpty) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final templates = _transactions
        .where(
            (t) => t.isRecurring && t.parentTransactionId == null && !t.isPaused)
        .toList();

    if (templates.isEmpty) return;

    bool createdAny = false;

    for (final template in templates) {
      if (!_shouldGenerateTransaction(template, today)) continue;

      final generated = await _generateRecurringEntries(template, today);
      if (generated) createdAny = true;
    }

    if (createdAny) {
      await fetchTransactions();
    }
  }

  bool _shouldGenerateTransaction(
      app_model.Transaction template, DateTime today) {
    if (template.recurrenceEndDate != null &&
        template.recurrenceEndDate!.isBefore(today)) {
      return false;
    }
    return true;
  }

  Future<bool> _generateRecurringEntries(
      app_model.Transaction template, DateTime today) async {
    // Find the most recent child transaction for this template
    DateTime lastDate = template.date;
    for (final t in _transactions) {
      if (t.parentTransactionId == template.id &&
          t.date.isAfter(lastDate)) {
        lastDate = t.date;
      }
    }

    bool createdAny = false;

    // Generate entries from lastDate up to today
    DateTime? nextDate = template.nextOccurrenceAfter(lastDate);
    while (nextDate != null && !nextDate.isAfter(today)) {
      final newEntry = app_model.Transaction(
        userId: template.userId,
        title: template.title,
        amount: template.amount,
        date: nextDate,
        type: template.type,
        category: template.category,
        note: template.note,
        parentTransactionId: template.id,
        isRecurring: false, // Children are not templates
      );

      try {
        await _databaseService.addTransaction(newEntry);
        createdAny = true;
      } catch (e) {
        _logger.warning('Error creating recurring entry: $e');
      }

      nextDate = template.nextOccurrenceAfter(nextDate);
    }

    return createdAny;
  }

  /// Toggle pause/resume on a recurring transaction template.
  Future<bool> toggleRecurringPause(String transactionId) async {
    try {
      final idx = _transactions.indexWhere((t) => t.id == transactionId);
      if (idx == -1) return false;

      final template = _transactions[idx];
      if (!template.isRecurring || template.parentTransactionId != null) {
        return false;
      }

      final updated = template.copyWith(isPaused: !template.isPaused);
      final success = await _databaseService.updateTransaction(updated);
      if (success) {
        _transactions[idx] = updated;
        notifyListeners();
      }
      return success;
    } catch (e) {
      _logger.warning('Error toggling recurring pause: $e');
      return false;
    }
  }

  /// Stop a recurring transaction (remove recurrence, keep history).
  Future<bool> stopRecurring(String transactionId) async {
    try {
      final idx = _transactions.indexWhere((t) => t.id == transactionId);
      if (idx == -1) return false;

      final template = _transactions[idx];
      final updated = template.copyWith(isRecurring: false);
      final success = await _databaseService.updateTransaction(updated);
      if (success) {
        _transactions[idx] = updated;
        notifyListeners();
      }
      return success;
    } catch (e) {
      _logger.warning('Error stopping recurring: $e');
      return false;
    }
  }

  // ─── Bill Reminders ─────────────────────────────────────────────────

  Future<void> fetchBillReminders() async {
    if (_userId == null || _userId!.isEmpty) return;
    try {
      _billReminders = await _databaseService.getBillReminders(_userId!);
    } catch (e) {
      _logger.warning('Error fetching bill reminders: $e');
    }
  }

  Future<bool> addBillReminder(BillReminder bill) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _databaseService.addBillReminder(bill);
      await fetchBillReminders();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _logger.warning('Error adding bill reminder: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateBillReminder(BillReminder bill) async {
    try {
      final success = await _databaseService.updateBillReminder(bill);
      if (success) {
        await fetchBillReminders();
        notifyListeners();
      }
      return success;
    } catch (e) {
      _logger.warning('Error updating bill reminder: $e');
      return false;
    }
  }

  Future<bool> deleteBillReminder(String billId) async {
    try {
      final success = await _databaseService.deleteBillReminder(billId);
      if (success) {
        _billReminders.removeWhere((b) => b.id == billId);
        notifyListeners();
      }
      return success;
    } catch (e) {
      _logger.warning('Error deleting bill reminder: $e');
      return false;
    }
  }

  /// Mark a bill as paid and optionally create an expense transaction.
  Future<bool> markBillPaid(BillReminder bill,
      {bool createTransaction = false}) async {
    try {
      // Mark current as paid
      final updated = bill.copyWith(isPaid: true);
      final success = await _databaseService.updateBillReminder(updated);
      if (!success) return false;

      // Create expense transaction if requested
      if (createTransaction && _userId != null) {
        final transaction = app_model.Transaction(
          userId: _userId!,
          title: bill.title,
          amount: bill.amount,
          date: DateTime.now(),
          type: app_model.TransactionType.expense,
          category: bill.category,
          note: 'Bill payment',
        );
        await addTransaction(transaction);
      }

      // Create next occurrence
      final nextDue = bill.recurrence.nextDueAfter(bill.dueDate);
      final nextBill = bill.copyWith(
        id: null,
        dueDate: nextDue,
        isPaid: false,
      );
      await _databaseService.addBillReminder(nextBill);

      await fetchBillReminders();
      notifyListeners();
      return true;
    } catch (e) {
      _logger.warning('Error marking bill paid: $e');
      return false;
    }
  }

  // ─── Investments ──────────────────────────────────────────────────

  Future<void> fetchInvestments() async {
    if (_userId == null || _userId!.isEmpty) return;
    try {
      _investments = await _databaseService.getInvestments(_userId!);
    } catch (e) {
      _logger.warning('Error fetching investments: $e');
    }
  }

  Future<bool> addInvestment(Investment investment) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _databaseService.addInvestment(investment);
      await fetchInvestments();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _logger.warning('Error adding investment: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateInvestment(Investment investment) async {
    try {
      final success = await _databaseService.updateInvestment(investment);
      if (success) {
        await fetchInvestments();
        notifyListeners();
      }
      return success;
    } catch (e) {
      _logger.warning('Error updating investment: $e');
      return false;
    }
  }

  Future<bool> deleteInvestment(String investmentId) async {
    try {
      final success = await _databaseService.deleteInvestment(investmentId);
      if (success) {
        _investments.removeWhere((i) => i.id == investmentId);
        notifyListeners();
      }
      return success;
    } catch (e) {
      _logger.warning('Error deleting investment: $e');
      return false;
    }
  }

  // ─── Gamification ─────────────────────────────────────────────────

  /// Load streak and achievements from user document, then check for new ones.
  Future<void> _loadAndCheckGamification(bool isPremium) async {
    if (_userId == null || _userId!.isEmpty) return;

    try {
      // Calculate streak from transactions
      _currentStreak = GamificationService.calculateStreak(_transactions);

      // Load unlocked achievement IDs from user document
      final savedAchievements = await _databaseService.getUserFieldData(
          _userId!, 'unlockedAchievements');
      final Set<String> unlockedIds = {};
      if (savedAchievements is List) {
        for (final id in savedAchievements) {
          unlockedIds.add(id.toString());
        }
      }

      // Check for newly unlocked achievements
      final newlyUnlocked = GamificationService.checkAchievements(
        transactions: _transactions,
        budgets: _budgets,
        goals: _savingGoals,
        streak: _currentStreak,
        alreadyUnlocked: unlockedIds,
      );

      // Add newly unlocked
      unlockedIds.addAll(newlyUnlocked);

      // Build achievement list
      _achievements = GamificationService.allAchievements.map((template) {
        // Filter premium achievements for free users
        if (template.isPremium && !isPremium) {
          return template;
        }
        return template.copyWith(
          isUnlocked: unlockedIds.contains(template.id),
          unlockedAt: unlockedIds.contains(template.id) ? DateTime.now() : null,
        );
      }).toList();

      // Save streak and achievements to user document
      await _databaseService.updateUserField(
          _userId!, 'currentStreak', _currentStreak);
      await _databaseService.updateUserField(
          _userId!, 'unlockedAchievements', unlockedIds.toList());
    } catch (e) {
      _logger.warning('Error loading gamification data: $e');
    }
  }
}
