import 'package:logging/logging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Utility class for handling database migrations
class MigrationHelpers {
  static final _logger = Logger('MigrationHelpers');
  static final _firestore = FirebaseFirestore.instance;

  /// Migrates existing categories to include the type field
  static Future<void> migrateCategoryTypes(String userId) async {
    _logger.info('Starting category type migration for user: $userId');
    try {
      // Get all categories for this user
      final categoriesSnapshot = await _firestore
          .collection('categories')
          .where('userId', isEqualTo: userId)
          .get();

      if (categoriesSnapshot.docs.isEmpty) {
        _logger
            .info('No categories found for user: $userId. Nothing to migrate.');
        return;
      }

      _logger.info(
          'Found ${categoriesSnapshot.docs.length} categories to migrate');

      // Common income and expense category names for automatic classification
      final incomeCategories = [
        'salary',
        'income',
        'investment',
        'dividend',
        'gift',
        'bonus',
        'refund',
        'rental',
        'allowance',
        'interest',
        'revenue',
        'paycheck',
        'reimbursement',
        'royalty',
        'pension',
        'grant',
        'commission'
      ];

      final expenseCategories = [
        'food',
        'grocery',
        'transport',
        'utility',
        'rent',
        'bill',
        'shopping',
        'entertainment',
        'health',
        'education',
        'travel',
        'subscription',
        'dining',
        'insurance',
        'tax',
        'car',
        'pet',
        'clothing',
        'household',
        'personal',
        'fitness',
        'maintenance'
      ];

      final batch = _firestore.batch();
      int updated = 0;

      for (final doc in categoriesSnapshot.docs) {
        final data = doc.data();

        // Skip if type is already set
        if (data.containsKey('type')) {
          _logger.info(
              'Category ${data['name']} already has type: ${data['type']}');
          continue;
        }

        // Try to automatically determine the category type based on name
        final name = (data['name'] as String).toLowerCase();
        String categoryType = 'expense'; // Default to expense

        // Check if it matches any income keyword
        if (incomeCategories.any((keyword) => name.contains(keyword))) {
          categoryType = 'income';
        }
        // Check if it matches any expense keyword
        else if (expenseCategories.any((keyword) => name.contains(keyword))) {
          categoryType = 'expense';
        }

        // Add the update to batch
        batch.update(doc.reference, {'type': categoryType});
        _logger.info('Categorized "${data['name']}" as $categoryType');
        updated++;
      }

      // Commit the batch update
      if (updated > 0) {
        await batch.commit();
        _logger.info(
            'Successfully migrated $updated categories for user: $userId');
      } else {
        _logger.info('No categories needed migration for user: $userId');
      }
    } catch (e) {
      _logger.severe('Error migrating category types: $e');
      throw Exception('Failed to migrate category types: $e');
    }
  }
}
