import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:logging/logging.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';

import 'package:wealth_wise/models/transaction.dart' as app_transaction;
import 'package:wealth_wise/models/budget_model.dart';
import 'package:wealth_wise/models/saving_goal.dart';
import 'package:wealth_wise/models/user.dart' as app_user;
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:wealth_wise/models/category.dart';

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
  final CollectionReference _categoriesCollection =
      FirebaseFirestore.instance.collection('categories');

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

      // Validate transaction data before saving
      if (newTransaction.userId.isEmpty) {
        throw Exception('Transaction must have a userId');
      }

      // Log transaction data for debugging
      _logger.info('Adding transaction: ${newTransaction.toDebugString()}');
      _logger.info('Transaction map data: ${newTransaction.toMap()}');

      final transactionMap = newTransaction.toMap();

      // Ensure date is a valid Timestamp
      if (transactionMap['date'] is! Timestamp) {
        transactionMap['date'] = Timestamp.fromDate(newTransaction.date);
        _logger.info('Converted date to Timestamp: ${transactionMap['date']}');
      }

      // Set the document with validated data
      await _transactionsCollection.doc(newId).set(transactionMap);
      _logger.info('Transaction added successfully with ID: $newId');

      return newTransaction;
    } catch (e) {
      _logger.warning('Error adding transaction: $e');
      rethrow;
    }
  }

  /// Update an existing transaction in the database
  Future<bool> updateTransaction(
      app_transaction.Transaction transaction) async {
    try {
      _logger.info('Updating transaction: ${transaction.id}');
      _logger.info('Transaction data: $transaction');

      if (transaction.id == null || transaction.id!.isEmpty) {
        _logger.warning('Transaction ID is required for update');
        return false;
      }

      // Verify the transaction exists
      final doc = await _transactionsCollection.doc(transaction.id).get();
      if (!doc.exists) {
        _logger.warning('Transaction not found with ID: ${transaction.id}');
        return false;
      }

      _logger.info('Existing transaction data: ${doc.data()}');

      // Verify category exists if provided
      if (transaction.category != null && transaction.category!.isNotEmpty) {
        final categoryExists = await _verifyCategoryExists(
          transaction.userId,
          transaction.category!,
        );

        if (!categoryExists) {
          _logger.warning('Category not found: ${transaction.category}');
          // We still allow the update even if category doesn't exist
        } else {
          _logger.info('Category found: ${transaction.category}');
        }
      }

      // Create a map with the proper data types
      Map<String, dynamic> updateData = {
        'title': transaction.title,
        'amount': transaction.amount,
        'date': Timestamp.fromDate(transaction.date),
        'type': transaction.type.toString().split('.').last,
        'category': transaction.category,
        'userId': transaction.userId,
        'note': transaction.note,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
        // Calculate contributesToGoal explicitly based on type and goalId
        'contributesToGoal':
            transaction.type == app_transaction.TransactionType.income &&
                transaction.goalId != null &&
                transaction.goalId!.isNotEmpty,
      };

      // Only include goalId if it's not null
      if (transaction.goalId != null) {
        updateData['goalId'] = transaction.goalId;
      }

      await _transactionsCollection.doc(transaction.id).update(updateData);

      _logger.info(
          'Updated transaction data: ${(await _transactionsCollection.doc(transaction.id).get()).data()}');
      _logger.info('Transaction updated successfully: ${transaction.id}');
      return true;
    } catch (e) {
      _logger.severe('Error updating transaction: $e');
      return false;
    }
  }

  /// Delete a transaction from the database
  Future<bool> deleteTransaction(String transactionId) async {
    if (transactionId.isEmpty) {
      _logger.warning('Attempted to delete transaction with empty ID');
      return false;
    }

    try {
      final docRef = _transactionsCollection.doc(transactionId);

      // Get the transaction before deleting it to make sure it exists
      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) {
        _logger.warning('Transaction not found: $transactionId');
        return false;
      }

      // Log transaction data before deletion for debugging
      _logger.info(
          'Deleting transaction: $transactionId with data: ${docSnapshot.data()}');

      // Delete the transaction
      await docRef.delete();

      // Verify deletion
      final verifySnapshot = await docRef.get();
      if (verifySnapshot.exists) {
        _logger.warning(
            'Failed to delete transaction: $transactionId - document still exists');
        return false;
      }

      _logger.info('Successfully deleted transaction: $transactionId');
      return true;
    } catch (e) {
      _logger.severe('Error deleting transaction: $e');
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
      // Check if the document exists first
      final doc = await _usersCollection.doc(user.uid).get();

      if (doc.exists) {
        // Update existing document
        await _usersCollection.doc(user.uid).update(user.toMap());
      } else {
        // Create new document if it doesn't exist
        await _usersCollection.doc(user.uid).set(user.toMap());
      }
    } catch (e) {
      _logger.warning('Error updating user data: $e');
    }
  }

  // Get categories for a user
  Future<List<Category>> getCategories(String userId) async {
    try {
      final query =
          await _categoriesCollection.where('userId', isEqualTo: userId).get();

      return query.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        // Add the id to the map if needed
        data['id'] = doc.id;
        return Category.fromMap(data);
      }).toList();
    } catch (e) {
      _logger.warning('Error getting categories: $e');
      return [];
    }
  }

  // Add a category
  Future<Category> addCategory(Category category) async {
    try {
      final newId = _uuid.v4();
      final newCategory = category.copyWith(id: newId);

      await _categoriesCollection.doc(newId).set(newCategory.toMap());

      return newCategory;
    } catch (e) {
      _logger.warning('Error adding category: $e');
      rethrow;
    }
  }

  // Update a category
  Future<bool> updateCategory(Category category) async {
    try {
      if (category.id.isEmpty) {
        return false;
      }

      await _categoriesCollection.doc(category.id).update(category.toMap());
      return true;
    } catch (e) {
      _logger.warning('Error updating category: $e');
      return false;
    }
  }

  // Delete a category
  Future<bool> deleteCategory(String categoryId) async {
    try {
      // Check if the category is used in any transactions first
      final categoryData = await _categoriesCollection.doc(categoryId).get();
      if (!categoryData.exists) {
        _logger.warning('Category not found: $categoryId');
        return false;
      }

      final categoryName =
          (categoryData.data() as Map<String, dynamic>)['name'] as String?;

      if (categoryName != null) {
        // Check if any transactions use this category name
        final transactionsWithCategory = await _transactionsCollection
            .where('category', isEqualTo: categoryName)
            .limit(1)
            .get();

        if (transactionsWithCategory.docs.isNotEmpty) {
          _logger.warning(
              'Cannot delete category: $categoryId ($categoryName) - it is used in transactions');
          return false;
        }
      }

      await _categoriesCollection.doc(categoryId).delete();
      return true;
    } catch (e) {
      _logger.warning('Error deleting category: $e');
      return false;
    }
  }

  // Database initialization methods
  Future<void> initializeDefaultCategories(String userId) async {
    _logger.info('Initializing default categories for user: $userId');
    try {
      // Check if user already has categories
      final existingCategories = await FirebaseFirestore.instance
          .collection('categories')
          .where('userId', isEqualTo: userId)
          .get();

      if (existingCategories.docs.isNotEmpty) {
        _logger.info(
            'User already has ${existingCategories.docs.length} categories');
        return;
      }

      // Create default categories
      _logger.info('Creating default categories for user');
      final defaultCategories = [
        // Income categories
        {
          'id': 'salary-${DateTime.now().millisecondsSinceEpoch}',
          'name': 'Salary',
          'icon': 'attach_money',
          'color': Colors.green.toARGB32(),
          'userId': userId,
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'type': 'income',
        },
        {
          'id': 'investments-${DateTime.now().millisecondsSinceEpoch}',
          'name': 'Investments',
          'icon': 'insert_chart',
          'color': Colors.blue.toARGB32(),
          'userId': userId,
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'type': 'income',
        },
        {
          'id': 'business-${DateTime.now().millisecondsSinceEpoch}',
          'name': 'Business',
          'icon': 'work',
          'color': Colors.teal.toARGB32(),
          'userId': userId,
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'type': 'income',
        },
        {
          'id': 'gifts-${DateTime.now().millisecondsSinceEpoch}',
          'name': 'Gifts',
          'icon': 'card_giftcard',
          'color': Colors.purple.toARGB32(),
          'userId': userId,
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'type': 'income',
        },
        // Expense categories
        {
          'id': 'food-${DateTime.now().millisecondsSinceEpoch}',
          'name': 'Food & Dining',
          'icon': 'restaurant',
          'color': Colors.orange.toARGB32(),
          'userId': userId,
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'type': 'expense',
        },
        {
          'id': 'housing-${DateTime.now().millisecondsSinceEpoch}',
          'name': 'Housing',
          'icon': 'home',
          'color': Colors.purple.toARGB32(),
          'userId': userId,
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'type': 'expense',
        },
        {
          'id': 'transportation-${DateTime.now().millisecondsSinceEpoch}',
          'name': 'Transportation',
          'icon': 'directions_car',
          'color': Colors.red.toARGB32(),
          'userId': userId,
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'type': 'expense',
        },
        {
          'id': 'entertainment-${DateTime.now().millisecondsSinceEpoch}',
          'name': 'Entertainment',
          'icon': 'movie',
          'color': Colors.amber.toARGB32(),
          'userId': userId,
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'type': 'expense',
        },
        {
          'id': 'utilities-${DateTime.now().millisecondsSinceEpoch}',
          'name': 'Utilities',
          'icon': 'power',
          'color': Colors.blue.toARGB32(),
          'userId': userId,
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'type': 'expense',
        },
        {
          'id': 'health-${DateTime.now().millisecondsSinceEpoch}',
          'name': 'Health',
          'icon': 'local_hospital',
          'color': Colors.red.toARGB32(),
          'userId': userId,
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'type': 'expense',
        },
      ];

      // Add default categories to Firestore
      final batch = FirebaseFirestore.instance.batch();
      for (final category in defaultCategories) {
        final docRef = FirebaseFirestore.instance
            .collection('categories')
            .doc(category['id'] as String);
        batch.set(docRef, category);
      }

      await batch.commit();
      _logger.info('Default categories created successfully');
    } catch (e) {
      _logger.severe('Error initializing default categories: $e');
      throw Exception('Failed to initialize default categories: $e');
    }
  }

  Future<bool> _verifyCategoryExists(String userId, String categoryName) async {
    try {
      final query = await _categoriesCollection
          .where('userId', isEqualTo: userId)
          .where('name', isEqualTo: categoryName)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      _logger.warning('Error checking category existence: $e');
      return false;
    }
  }
}
