import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wealth_wise/models/category.dart' as app_category;
import 'package:wealth_wise/services/database_service.dart';
import 'package:logging/logging.dart';

class CategoryProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  final Logger _logger = Logger('CategoryProvider');

  bool _isLoading = false;
  String? _error;
  List<app_category.Category> _categories = [];

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<app_category.Category> get categories => _categories;
  bool get hasCategories => _categories.isNotEmpty;

  // Load categories for a user
  Future<void> loadCategoriesByUser(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _logger.info('Loading categories for user: $userId');
      _categories = await _databaseService.getCategories(userId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      _logger.warning('Error loading categories: $_error');
      notifyListeners();
    }
  }

  // Alias method for backward compatibility
  Future<void> loadCategories(String userId) async {
    await loadCategoriesByUser(userId);
  }

  // Get categories for a specific user
  List<app_category.Category> getCategoriesByUserId(String userId) {
    return _categories.where((c) => c.userId == userId).toList();
  }

  // Add a new category
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
      _isLoading = false;
      _logger.warning('Error adding category: $_error');
      notifyListeners();
      return false;
    }
  }

  // Update an existing category
  Future<bool> updateCategory(app_category.Category category) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _databaseService.updateCategory(category);
      if (success) {
        final index = _categories.indexWhere((c) => c.id == category.id);
        if (index != -1) {
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
      _isLoading = false;
      _logger.warning('Error updating category: $_error');
      notifyListeners();
      return false;
    }
  }

  // Delete a category
  Future<bool> deleteCategory(String categoryId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _databaseService.deleteCategory(categoryId);
      if (success) {
        _categories.removeWhere((c) => c.id == categoryId);
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _error = 'Failed to delete category. It may be in use by transactions.';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      _logger.warning('Error deleting category: $_error');
      notifyListeners();
      return false;
    }
  }

  // Get a specific category by ID
  app_category.Category? getCategoryById(String categoryId) {
    try {
      return _categories.firstWhere((c) => c.id == categoryId);
    } catch (e) {
      return null;
    }
  }

  // Reset state
  void reset() {
    _categories = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  // Error handling
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
