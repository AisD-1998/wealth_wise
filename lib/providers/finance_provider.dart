import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wealth_wise/models/saving_goal.dart';
import 'package:wealth_wise/models/transaction.dart' as app_model;
import 'package:wealth_wise/services/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';
import 'package:wealth_wise/models/category.dart' as app_category;
import 'package:wealth_wise/controllers/feature_access_controller.dart';
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

      // Check if user has premium status
      final isPremium = await _checkPremiumStatus();
      _logger.info('User premium status: $isPremium');

      // Direct Firestore query with more detailed error handling
      try {
        final collection =
            FirebaseFirestore.instance.collection('transactions');
        _logger.info('Collection reference created: ${collection.path}');

        // Check if collection exists
        final collectionSnapshot = await collection.limit(1).get();
        _logger
            .info('Collection exists: ${collectionSnapshot.docs.isNotEmpty}');

        // Build query
        Query query = collection.where('userId', isEqualTo: _userId);

        // For free users, limit to last 30 days if no date range is specified
        if (!isPremium) {
          final thirtyDaysAgo =
              DateTime.now().subtract(const Duration(days: 30));
          query = query.where('date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo));
          _logger.info('Free user: limiting transactions to last 30 days');
        }

        // Perform the query
        final snapshot = await query.get();
        _logger.info(
            'Retrieved ${snapshot.docs.length} transactions from database');

        // Process query results
        _transactions = [];

        // For free users, limit to 50 transactions
        final docsToProcess = !isPremium && snapshot.docs.length > 50
            ? snapshot.docs.take(50).toList()
            : snapshot.docs;

        if (!isPremium && snapshot.docs.length > 50) {
          _logger.info(
              'Free user: limiting to 50 transactions out of ${snapshot.docs.length}');
        }

        // Convert to transaction objects with careful error handling
        for (var doc in docsToProcess) {
          try {
            final data = doc.data() as Map<String, dynamic>;
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

  // Handle transaction interactions with saving goals
  Future<Map<String, dynamic>> _handleSavingGoalTransaction(
      app_model.Transaction oldTransaction,
      app_model.Transaction newTransaction) async {
    // Map to hold processing result
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

      // Calculate effective amounts that were/will be contributed
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

      // CASE 1: No old goal, but new one added
      if ((oldGoalId == null || oldGoalId.isEmpty) &&
          newGoalId != null &&
          newGoalId.isNotEmpty) {
        _logger.info('CASE 1: Adding contribution to new goal');

        // Get the new goal
        final newGoal = await getSavingGoalById(newGoalId);
        if (newGoal == null) {
          _logger.warning('New goal not found: $newGoalId');
          result['success'] = false;
          result['error'] = 'New goal not found: $newGoalId';
          return result;
        }

        result['newGoalName'] = newGoal.title;

        // Check if adding this transaction would cause the goal to be completed
        final willExceedTarget = (newGoal.currentAmount + newEffectiveAmount) >=
            newGoal.targetAmount;
        result['willExceedTarget'] = willExceedTarget;

        // Check if the goal is already completed
        if (newGoal.isCompleted) {
          _logger.warning('Adding to a completed goal: ${newGoal.title}');
          result['isCompleted'] = true;
          result['addedToCompletedGoal'] = true;
          // Still add the contribution
        }

        // Add contribution to the new goal
        await addContributionToSavingGoal(newGoal, newTransaction.amount,
            contributionPercentage: newTransaction.contributionPercentage);
        result['goalAdded'] = true;
      }

      // CASE 2: Both old and new goals exist, but they're different
      else if (oldGoalId != null &&
          oldGoalId.isNotEmpty &&
          newGoalId != null &&
          newGoalId.isNotEmpty &&
          oldGoalId != newGoalId) {
        _logger.info('CASE 2: Changing from one goal to another');

        // Get both goals
        final oldGoal = await getSavingGoalById(oldGoalId);
        final newGoal = await getSavingGoalById(newGoalId);

        if (oldGoal == null) {
          _logger.warning('Old goal not found: $oldGoalId');
          result['success'] = false;
          result['error'] = 'Old goal not found: $oldGoalId';
          return result;
        }

        if (newGoal == null) {
          _logger.warning('New goal not found: $newGoalId');
          result['success'] = false;
          result['error'] = 'New goal not found: $newGoalId';
          return result;
        }

        result['oldGoalName'] = oldGoal.title;
        result['newGoalName'] = newGoal.title;

        // Check if the new goal is already completed
        if (newGoal.isCompleted) {
          _logger.warning('Changing to a completed goal: ${newGoal.title}');
          result['isCompleted'] = true;
        }

        // Check if adding this transaction would cause the goal to be completed
        final willExceedTarget = (newGoal.currentAmount + newEffectiveAmount) >=
            newGoal.targetAmount;
        result['willExceedTarget'] = willExceedTarget;

        // Remove contribution from old goal
        // Subtract the old effective amount
        final calculatedAmount = oldGoal.currentAmount - oldEffectiveAmount;
        final double oldGoalNewAmount =
            calculatedAmount < 0.0 ? 0.0 : calculatedAmount;
        await _databaseService.updateSavingGoal(
            oldGoal.copyWith(currentAmount: oldGoalNewAmount));

        // Then add to new goal
        await addContributionToSavingGoal(newGoal, newTransaction.amount,
            contributionPercentage: newTransaction.contributionPercentage);
        result['goalChanged'] = true;
      }

      // CASE 3: Had a goal before, but now removed
      else if (oldGoalId != null &&
          oldGoalId.isNotEmpty &&
          (newGoalId == null || newGoalId.isEmpty)) {
        _logger.info('CASE 3: Removing goal from transaction');

        // Get the old goal
        final oldGoal = await getSavingGoalById(oldGoalId);
        if (oldGoal == null) {
          _logger.warning('Old goal not found: $oldGoalId');
          result['success'] = false;
          result['error'] = 'Old goal not found: $oldGoalId';
          return result;
        }

        result['oldGoalName'] = oldGoal.title;

        // Remove contribution from the old goal
        // Subtract the old effective amount, not just the old amount
        final calculatedAmount = oldGoal.currentAmount - oldEffectiveAmount;
        final double oldGoalNewAmount =
            calculatedAmount < 0.0 ? 0.0 : calculatedAmount;
        await _databaseService.updateSavingGoal(
            oldGoal.copyWith(currentAmount: oldGoalNewAmount));
        result['goalRemoved'] = true;
      }

      // CASE 4: Same goal, but amount might have changed
      else if (oldGoalId != null &&
          oldGoalId.isNotEmpty &&
          newGoalId != null &&
          newGoalId.isNotEmpty &&
          oldGoalId == newGoalId) {
        _logger.info('CASE 4: Updating same goal with new amount');

        // Get the goal
        final goal = await getSavingGoalById(newGoalId);
        if (goal == null) {
          _logger.warning('Goal not found: $newGoalId');
          result['success'] = false;
          result['error'] = 'Goal not found: $newGoalId';
          return result;
        }

        result['oldGoalName'] = goal.title;
        result['newGoalName'] = goal.title;

        // Check if the goal is already completed
        if (goal.isCompleted) {
          _logger.warning('Updating a completed goal: ${goal.title}');
          result['isCompleted'] = true;
        }

        // Calculate the new goal amount by removing the old contribution and adding the new one
        final double differenceAmount = newEffectiveAmount - oldEffectiveAmount;
        final calculatedNewAmount = goal.currentAmount + differenceAmount;
        final double updatedAmount =
            calculatedNewAmount < 0.0 ? 0.0 : calculatedNewAmount;

        _logger.info('Difference amount: $differenceAmount');
        _logger.info('New goal amount: $updatedAmount');

        // Check if updating this transaction would cause the goal to be completed
        final willExceedTarget = updatedAmount >= goal.targetAmount;
        result['willExceedTarget'] = willExceedTarget;

        // Update the goal with the new amount
        await _databaseService
            .updateSavingGoal(goal.copyWith(currentAmount: updatedAmount));
        result['goalUpdated'] = true;
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

      return result;
    } catch (e) {
      _logger.severe('Error handling saving goal transaction: $e');
      return {
        'success': false,
        'error': 'Error handling saving goal transaction: $e'
      };
    }
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
      _logger.severe('Adding transaction with goal handling');
      _logger.severe('Transaction goal ID: ${transaction.goalId}');
      _logger.severe('Provided goal ID: ${savingGoal?.id}');
      _logger.severe(
          'Contribution percentage: ${transaction.contributionPercentage}%');

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

      final String? oldGoalId = oldTransaction.goalId;
      final String? newGoalId = transaction.goalId;

      // Log transaction details
      _logger.info('oldGoalId: $oldGoalId');
      _logger.info('newGoalId: $newGoalId');

      // Process goals and update the transaction
      // This covers adding goals, changing goals, and removing goals
      if ((oldGoalId != null && oldGoalId.isNotEmpty) ||
          (newGoalId != null && newGoalId.isNotEmpty)) {
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
          return result;
        }

        // Copy goal-related results to our result object
        if (goalResult.containsKey('goalChanged') &&
            goalResult['goalChanged']) {
          result['goalChanged'] = true;
          result['oldGoalName'] = goalResult['oldGoalName'];
          result['newGoalName'] = goalResult['newGoalName'];

          final percentInfo = transaction.contributionPercentage != null &&
                  transaction.contributionPercentage! < 100
              ? " (${transaction.contributionPercentage!.toStringAsFixed(0)}% of income)"
              : "";

          if (goalResult.containsKey('isCompleted') &&
              goalResult['isCompleted']) {
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

          final percentInfo = transaction.contributionPercentage != null &&
                  transaction.contributionPercentage! < 100
              ? " (${transaction.contributionPercentage!.toStringAsFixed(0)}% of income)"
              : "";

          if (goalResult.containsKey('isCompleted') &&
              goalResult['isCompleted']) {
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

          final percentInfo = transaction.contributionPercentage != null &&
                  transaction.contributionPercentage! < 100
              ? " (${transaction.contributionPercentage!.toStringAsFixed(0)}% of income)"
              : "";

          if (goalResult.containsKey('isCompleted') &&
              goalResult['isCompleted']) {
            result['isCompleted'] = true;
            result['message'] =
                'Updated contribution to completed goal "${goalResult['newGoalName']}".$percentInfo';
          } else {
            result['message'] =
                'Updated contribution to "${goalResult['newGoalName']}".$percentInfo';
          }
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
