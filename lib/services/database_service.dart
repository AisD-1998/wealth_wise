import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:logging/logging.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';

import 'package:wealth_wise/models/transaction.dart' as app_transaction;
import 'package:wealth_wise/models/budget_model.dart';
import 'package:wealth_wise/models/saving_goal.dart';
import 'package:wealth_wise/models/user.dart' as app_user;
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:wealth_wise/models/spending_category.dart';

class DatabaseService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Logger _logger = Logger('DatabaseService');
  final Uuid _uuid = const Uuid();
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;

  // Collections
  final CollectionReference _usersCollection =
      FirebaseFirestore.instance.collection('users');
  final CollectionReference _transactionsCollection =
      FirebaseFirestore.instance.collection('transactions');
  final CollectionReference _budgetsCollection =
      FirebaseFirestore.instance.collection('budgets');
  final CollectionReference _savingsGoalsCollection =
      FirebaseFirestore.instance.collection('savingGoals');
  final CollectionReference _spendingCategoriesCollection =
      FirebaseFirestore.instance.collection('spendingCategories');

  // Transactions
  Future<List<app_transaction.Transaction>> getTransactions(String userId,
      {DateTime? startDate, DateTime? endDate}) async {
    try {
      Query query = _transactionsCollection.where('userId', isEqualTo: userId);

      // Add date filters if provided
      if (startDate != null) {
        query = query.where('date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        query = query.where('date',
            isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final querySnapshot = await query.get();
      return querySnapshot.docs.map((doc) {
        return app_transaction.Transaction.fromMap(
            doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      _logger.warning('Error getting transactions: $e');
      return [];
    }
  }

  Future<List<app_transaction.Transaction>> getTransactionsForMonth(
    String userId,
    DateTime date,
  ) async {
    try {
      DateTime startOfMonth = DateTime(date.year, date.month, 1);
      DateTime endOfMonth = DateTime(
        date.year,
        date.month + 1,
        0,
        23,
        59,
        59,
      );

      final query = await _transactionsCollection
          .where('userId', isEqualTo: userId)
          .where(
            'date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
          )
          .where(
            'date',
            isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth),
          )
          .orderBy('date', descending: true)
          .get();

      return query.docs
          .map(
            (doc) => app_transaction.Transaction.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ),
          )
          .toList();
    } catch (e) {
      _logger.warning('Error getting transactions for month: $e');
      return [];
    }
  }

  Future<app_transaction.Transaction> addTransaction(
      app_transaction.Transaction transaction) async {
    try {
      final newId = _uuid.v4();
      final newTransaction = transaction.copyWith(id: newId);

      await _transactionsCollection.doc(newId).set(newTransaction.toMap());

      // Update budget if it's an expense
      if (newTransaction.type == app_transaction.TransactionType.expense &&
          newTransaction.category != null) {
        await _updateBudgetSpent(
          newTransaction.userId,
          newTransaction.category,
          newTransaction.amount,
        );
      }

      return newTransaction;
    } catch (e) {
      _logger.warning('Error adding transaction: $e');
      rethrow;
    }
  }

  Future<bool> updateTransaction(
      app_transaction.Transaction transaction) async {
    try {
      if (transaction.id == null) {
        return false;
      }

      // Get the old transaction to update balances correctly
      final docSnapshot =
          await _transactionsCollection.doc(transaction.id).get();
      if (docSnapshot.exists) {
        final oldTransaction = app_transaction.Transaction.fromMap(
            docSnapshot.data() as Map<String, dynamic>, transaction.id!);

        // Revert the old transaction's effect on balance
        await _updateUserBalance(
            transaction.userId,
            oldTransaction.copyWith(
                amount: -oldTransaction.amount,
                type: oldTransaction.type ==
                        app_transaction.TransactionType.income
                    ? app_transaction.TransactionType.expense
                    : app_transaction.TransactionType.income));

        // Revert the old transaction's effect on category spent
        if (oldTransaction.category != null &&
            oldTransaction.type == app_transaction.TransactionType.expense) {
          await _updateCategorySpent(oldTransaction.userId,
              oldTransaction.category, -oldTransaction.amount);
        }
      }

      // Update the transaction in Firestore
      await _transactionsCollection
          .doc(transaction.id)
          .update(transaction.toMap());

      // Apply the new transaction's effect on balance
      await _updateUserBalance(transaction.userId, transaction);

      // Apply the new transaction's effect on category spent
      if (transaction.category != null &&
          transaction.type == app_transaction.TransactionType.expense) {
        await _updateCategorySpent(
            transaction.userId, transaction.category, transaction.amount);
      }

      return true;
    } catch (e) {
      _logger.warning('Error updating transaction: $e');
      return false;
    }
  }

  Future<bool> deleteTransaction(String transactionId) async {
    try {
      // Get the transaction to handle budget updates
      final doc = await _transactionsCollection.doc(transactionId).get();

      if (doc.exists) {
        final transaction = app_transaction.Transaction.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );

        // If it's an expense, update the budget
        if (transaction.type == app_transaction.TransactionType.expense &&
            transaction.category != null) {
          await _updateBudgetSpent(
            transaction.userId,
            transaction.category,
            -transaction.amount,
          );
        }

        // Delete the transaction
        await _transactionsCollection.doc(transactionId).delete();

        // Update user balance (reverse the transaction effect)
        await _updateUserBalance(
            transaction.userId,
            transaction.copyWith(
                amount: -transaction.amount,
                type: transaction.type == app_transaction.TransactionType.income
                    ? app_transaction.TransactionType.expense
                    : app_transaction.TransactionType.income));

        // Update category spent if applicable
        if (transaction.category != null &&
            transaction.type == app_transaction.TransactionType.expense) {
          await _updateCategorySpent(
              transaction.userId, transaction.category, -transaction.amount);
        }

        return true;
      }
      return false;
    } catch (e) {
      _logger.warning('Error deleting transaction: $e');
      return false;
    }
  }

  Future<Map<String, double>> getExpenseSummaryByCategory(
    String userId,
    DateTime date,
  ) async {
    try {
      List<app_transaction.Transaction> transactions =
          await getTransactionsForMonth(userId, date);

      List<app_transaction.Transaction> expenses = transactions
          .where((transaction) =>
              transaction.type == app_transaction.TransactionType.expense)
          .toList();

      Map<String, double> summary = {};
      for (var expense in expenses) {
        String category = expense.category ?? 'Uncategorized';
        if (summary.containsKey(category)) {
          summary[category] = summary[category]! + expense.amount;
        } else {
          summary[category] = expense.amount;
        }
      }

      return summary;
    } catch (e) {
      _logger.warning('Error getting expense summary: $e');
      rethrow;
    }
  }

  // Budgets
  Future<List<Budget>> getBudgets(String userId) async {
    try {
      final query =
          await _budgetsCollection.where('userId', isEqualTo: userId).get();

      return query.docs
          .map((doc) => Budget.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _logger.warning('Error getting budgets: $e');
      rethrow;
    }
  }

  Future<List<Budget>> getCurrentBudgets(String userId) async {
    try {
      DateTime now = DateTime.now();
      final query = await _budgetsCollection
          .where('userId', isEqualTo: userId)
          .where('startDate', isLessThanOrEqualTo: now)
          .where('endDate', isGreaterThanOrEqualTo: now)
          .get();

      return query.docs
          .map((doc) => Budget.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _logger.warning('Error getting current budgets: $e');
      rethrow;
    }
  }

  Future<Budget> createBudget(
    String userId,
    String category,
    double amount,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      String id = _uuid.v4();

      Budget budget = Budget(
        id: id,
        userId: userId,
        category: category,
        amount: amount,
        spent: 0,
        startDate: startDate,
        endDate: endDate,
        createdAt: DateTime.now(),
      );

      await _budgetsCollection.doc(id).set(budget.toMap());

      return budget;
    } catch (e) {
      _logger.warning('Error creating budget: $e');
      rethrow;
    }
  }

  Future<void> updateBudget(Budget budget) async {
    try {
      await _budgetsCollection.doc(budget.id).update(budget.toMap());
    } catch (e) {
      _logger.warning('Error updating budget: $e');
      rethrow;
    }
  }

  Future<void> deleteBudget(String budgetId) async {
    try {
      await _budgetsCollection.doc(budgetId).delete();
    } catch (e) {
      _logger.warning('Error deleting budget: $e');
      rethrow;
    }
  }

  Future<void> _updateBudgetSpent(
    String userId,
    String? category,
    double amount,
  ) async {
    if (category == null) return;

    try {
      // Get the current month's budget for this category
      DateTime now = DateTime.now();
      int year = now.year;
      int month = now.month;

      final query = await _budgetsCollection
          .where('userId', isEqualTo: userId)
          .where('category', isEqualTo: category)
          .where('year', isEqualTo: year)
          .where('month', isEqualTo: month)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        DocumentSnapshot doc = query.docs.first;
        Budget budget = Budget.fromMap(doc.data() as Map<String, dynamic>);
        double newSpent = budget.spent + amount;

        if (newSpent < 0) newSpent = 0;

        await _budgetsCollection.doc(doc.id).update({
          'spent': newSpent,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      _logger.warning('Error updating budget spent: $e');
    }
  }

  // Savings Goals
  Future<List<SavingGoal>> getSavingGoals(String userId) async {
    try {
      final query = await _savingsGoalsCollection
          .where('userId', isEqualTo: userId)
          .orderBy('createdDate', descending: true)
          .get();

      return query.docs
          .map((doc) => SavingGoal.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ))
          .toList();
    } catch (e) {
      _logger.warning('Error getting saving goals: $e');
      return [];
    }
  }

  Future<SavingGoal> addSavingGoal(SavingGoal goal) async {
    try {
      final newId = _uuid.v4();
      final newGoal = goal.copyWith(id: newId);

      await _savingsGoalsCollection.doc(newId).set(newGoal.toMap());

      return newGoal;
    } catch (e) {
      _logger.warning('Error adding saving goal: $e');
      rethrow;
    }
  }

  Future<bool> updateSavingGoal(SavingGoal goal) async {
    try {
      if (goal.id == null) {
        return false;
      }

      await _savingsGoalsCollection.doc(goal.id).update(goal.toMap());
      return true;
    } catch (e) {
      _logger.warning('Error updating saving goal: $e');
      return false;
    }
  }

  Future<bool> deleteSavingGoal(String goalId) async {
    try {
      await _savingsGoalsCollection.doc(goalId).delete();
      return true;
    } catch (e) {
      _logger.warning('Error deleting saving goal: $e');
      return false;
    }
  }

  Future<SavingGoal?> getSavingGoal(String id) async {
    try {
      DocumentSnapshot doc = await _savingsGoalsCollection.doc(id).get();

      if (doc.exists) {
        return SavingGoal.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      _logger.warning('Error getting saving goal: $e');
      rethrow;
    }
  }

  // Upload a file to Firebase Storage
  Future<String?> uploadFile(File file, String path) async {
    try {
      final ref = _storage.ref().child(path);
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      _logger.warning('Error uploading file: $e');
      return null;
    }
  }

  // Delete a file from Firebase Storage
  Future<void> deleteFile(String fileUrl) async {
    try {
      final ref = _storage.refFromURL(fileUrl);
      await ref.delete();
    } catch (e) {
      _logger.warning('Error deleting file: $e');
    }
  }

  // Get user from firestore
  Future<app_user.User?> getCurrentUser() async {
    try {
      final authUser = _auth.currentUser;
      if (authUser == null) return null;

      final doc = await _usersCollection.doc(authUser.uid).get();
      if (doc.exists) {
        return app_user.User.fromMap(
            doc.data() as Map<String, dynamic>, doc.id);
      } else {
        // Create a new user if it doesn't exist
        final newUser = app_user.User(
          uid: authUser.uid,
          email: authUser.email ?? '',
          displayName: authUser.displayName,
          photoUrl: authUser.photoURL,
          createdAt: DateTime.now(),
        );
        await _usersCollection.doc(authUser.uid).set(newUser.toMap());
        return newUser;
      }
    } catch (e) {
      _logger.warning('Error getting current user: $e');
      return null;
    }
  }

  // Get user data by user ID
  Future<app_user.User?> getUserData(String userId) async {
    try {
      final doc = await _usersCollection.doc(userId).get();
      if (doc.exists) {
        return app_user.User.fromMap(
            doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      _logger.warning('Error getting user data: $e');
      return null;
    }
  }

  // Update user data
  Future<void> updateUserData(app_user.User user) async {
    try {
      await _usersCollection.doc(user.uid).update(user.toMap());
    } catch (e) {
      _logger.warning('Error updating user data: $e');
    }
  }

  // Get spending categories for a user
  Future<List<SpendingCategory>> getSpendingCategories(String userId) async {
    try {
      final query = await _spendingCategoriesCollection
          .where('userId', isEqualTo: userId)
          .get();

      return query.docs
          .map((doc) => SpendingCategory.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ))
          .toList();
    } catch (e) {
      _logger.warning('Error getting spending categories: $e');
      return [];
    }
  }

  // Add a spending category
  Future<SpendingCategory> addSpendingCategory(
      SpendingCategory category) async {
    try {
      final newId = _uuid.v4();
      final newCategory = category.copyWith(id: newId);

      await _spendingCategoriesCollection.doc(newId).set(newCategory.toMap());

      return newCategory;
    } catch (e) {
      _logger.warning('Error adding spending category: $e');
      rethrow;
    }
  }

  // Update a spending category
  Future<bool> updateSpendingCategory(SpendingCategory category) async {
    try {
      if (category.id == null) {
        return false;
      }

      await _spendingCategoriesCollection
          .doc(category.id)
          .update(category.toMap());
      return true;
    } catch (e) {
      _logger.warning('Error updating spending category: $e');
      return false;
    }
  }

  // Delete a spending category
  Future<bool> deleteSpendingCategory(String categoryId) async {
    try {
      await _spendingCategoriesCollection.doc(categoryId).delete();
      return true;
    } catch (e) {
      _logger.warning('Error deleting spending category: $e');
      return false;
    }
  }

  // Helper method to update user balance
  Future<void> _updateUserBalance(
      String userId, app_transaction.Transaction transaction) async {
    try {
      final userData = await getUserData(userId);
      if (userData == null) return;

      double newBalance = userData.balance;

      // Update balance based on transaction type
      if (transaction.type == app_transaction.TransactionType.income) {
        newBalance += transaction.amount;
      } else {
        newBalance -= transaction.amount;
      }

      // Update the user's balance
      await updateUserData(userData.copyWith(balance: newBalance));
    } catch (e) {
      _logger.warning('Error updating user balance: $e');
    }
  }

  // Helper method to update category spent amount
  Future<void> _updateCategorySpent(
      String userId, String? category, double amount) async {
    try {
      if (category == null) return;

      // Get all categories for the user
      final querySnapshot = await _spendingCategoriesCollection
          .where('userId', isEqualTo: userId)
          .where('name', isEqualTo: category)
          .get();

      if (querySnapshot.docs.isEmpty) return;

      // Get the first matching category
      final doc = querySnapshot.docs.first;
      final categoryData =
          SpendingCategory.fromMap(doc.data() as Map<String, dynamic>, doc.id);

      // Update the spent amount
      final updatedSpent = categoryData.spent + amount;
      await _spendingCategoriesCollection.doc(doc.id).update({
        'spent':
            updatedSpent > 0 ? updatedSpent : 0, // Ensure spent is not negative
      });
    } catch (e) {
      _logger.warning('Error updating category spent: $e');
    }
  }

  // Database migrations
  Future<void> runMigrations(String userId) async {
    _logger.info('Running database migrations for user: $userId');

    try {
      // Create default spending categories if they don't exist
      await _createDefaultCategories(userId);

      // Initialize user's financial summary if it doesn't exist
      await _createInitialSavingGoal(userId);

      _logger.info('Database migrations completed successfully');
    } catch (e) {
      _logger.severe('Error running migrations: $e');
      throw Exception('Failed to run database migrations: $e');
    }
  }

  Future<void> _createDefaultCategories(String userId) async {
    try {
      // Check if user already has categories
      final existingCategories = await _spendingCategoriesCollection
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      // If user already has categories, skip creation
      if (existingCategories.docs.isNotEmpty) {
        _logger.info('User already has spending categories, skipping creation');
        return;
      }

      // Default categories with their colors and icons
      final defaultCategories = [
        {
          'name': 'Food & Groceries',
          'budgetLimit': 500.0,
          'spent': 0.0,
          'color': 0xFF4CAF50, // Green
          'userId': userId,
          'iconName': 'restaurant'
        },
        {
          'name': 'Transport',
          'budgetLimit': 300.0,
          'spent': 0.0,
          'color': 0xFF2196F3, // Blue
          'userId': userId,
          'iconName': 'directions_car'
        },
        {
          'name': 'Entertainment',
          'budgetLimit': 200.0,
          'spent': 0.0,
          'color': 0xFF9C27B0, // Purple
          'userId': userId,
          'iconName': 'movie'
        },
        {
          'name': 'Utilities',
          'budgetLimit': 350.0,
          'spent': 0.0,
          'color': 0xFFFF9800, // Orange
          'userId': userId,
          'iconName': 'power'
        },
        {
          'name': 'Health',
          'budgetLimit': 250.0,
          'spent': 0.0,
          'color': 0xFFF44336, // Red
          'userId': userId,
          'iconName': 'medical_services'
        },
        {
          'name': 'Other',
          'budgetLimit': 400.0,
          'spent': 0.0,
          'color': 0xFF607D8B, // Blue Grey
          'userId': userId,
          'iconName': 'category'
        },
      ];

      // Add each category to Firestore
      final batch = FirebaseFirestore.instance.batch();
      for (var category in defaultCategories) {
        final docRef = _spendingCategoriesCollection.doc();
        batch.set(docRef, category);
      }

      await batch.commit();
      _logger.info('Created default spending categories for user: $userId');
    } catch (e) {
      _logger.warning('Error creating default categories: $e');
      rethrow;
    }
  }

  Future<void> _createInitialSavingGoal(String userId) async {
    try {
      // Check if user already has any saving goals
      final existingGoals = await _savingsGoalsCollection
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      // If user already has goals, skip creation
      if (existingGoals.docs.isNotEmpty) {
        _logger.info('User already has saving goals, skipping creation');
        return;
      }

      // Create an initial saving goal as an example
      final exampleGoal = {
        'title': 'Emergency Fund',
        'description': 'For unexpected expenses',
        'targetAmount': 1000.0,
        'currentAmount': 0.0,
        'userId': userId,
        'targetDate':
            Timestamp.fromDate(DateTime.now().add(const Duration(days: 180))),
        'createdDate': Timestamp.fromDate(DateTime.now()),
      };

      await _savingsGoalsCollection.add(exampleGoal);
      _logger.info('Created initial saving goal for user: $userId');
    } catch (e) {
      _logger.warning('Error creating initial saving goal: $e');
      rethrow;
    }
  }
}
