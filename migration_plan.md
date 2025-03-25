# WealthWise Model Cleanup and Database Migration Plan

## Current Issues

1. **Duplicate Category Models:**
   - `Category` model (newer, in active use by CategoryProvider)
   - `SpendingCategory` model (older, used by FinanceProvider)

2. **Model Overlaps:**
   - Both models track similar data but with different fields
   - Transactions reference categories by ID strings, not by model type

3. **Unused or Redundant Models:**
   - The `Expense` model appears to be a simplified version of `Transaction`

## Migration Plan

### 1. Consolidate Category Models

We'll keep `Category` as the primary model and extend it with the budget tracking features from `SpendingCategory`:

```dart
// Updated Category model
class Category {
  final String id;
  final String name;
  final String icon;
  final Color color;
  final String userId;
  final double budgetLimit;  // Added from SpendingCategory
  final double spent;        // Added from SpendingCategory
  final DateTime createdAt;
  final DateTime updatedAt;

  // Computed properties from SpendingCategory
  double get percentUsed {
    if (budgetLimit <= 0) return 0;
    double percentage = (spent / budgetLimit) * 100;
    return percentage > 100 ? 100 : percentage;
  }

  bool get isOverBudget => spent > budgetLimit;
  double get remaining => budgetLimit - spent;

  // Constructor, fromMap, toMap, copyWith methods...
}
```

### 2. Update Providers

1. **Update CategoryProvider:**
   - Extend to include budget management methods
   - Add methods to update spent amounts

2. **Modify FinanceProvider:**
   - Remove SpendingCategory references
   - Update to work with the consolidated Category model

### 3. Database Migration Steps

1. **Create A New Categories Collection:**
   - Create a new `unified_categories` collection

2. **Migrate Existing Data:**
   - Merge data from both `categories` and `spendingCategories` collections
   - For each category in either collection:
     - Create a new document in `unified_categories`
     - Use `Category` model schema with budget tracking fields
     - Preserve existing IDs and relationships

3. **Update Transaction References:**
   - Ensure all transactions reference the correct category IDs
   - Validate and fix any broken references

4. **Database Validation:**
   - Verify all data was migrated correctly
   - Run data integrity checks

5. **Cleanup:**
   - Once validated, remove old collections

### 4. UI Updates

1. **Update CategoryScreen:**
   - Add budget limit management UI 
   - Include spent amount visualizations

2. **Update Transaction Forms:**
   - Ensure they use the unified Category model

### 5. Code Cleanup

1. **Remove Deprecated Models:**
   - Delete `SpendingCategory` model
   - Consider removing `Expense` model if unused

2. **Update Imports:**
   - Fix all imports across the app
   - Remove unused imports

## Implementation Sequence

1. Create the consolidated Category model
2. Update providers to use the new model
3. Create migration code to move data to the new structure
4. Run the migration on a test database
5. Verify data integrity
6. Update UI components
7. Run migration on production database
8. Clean up deprecated code

## Database Structure After Migration

```
/users/
  /{userId}/
    email: string
    displayName: string
    ... other user fields

/categories/
  /{categoryId}/
    name: string
    icon: string
    color: int
    userId: string
    budgetLimit: double
    spent: double
    createdAt: timestamp
    updatedAt: timestamp

/transactions/
  /{transactionId}/
    title: string
    amount: double
    date: timestamp
    type: string ('income' or 'expense')
    category: string (categoryId)
    userId: string
    ... other transaction fields

/savingGoals/
  /{goalId}/
    ... saving goal fields
```

This migration will create a cleaner, more maintainable codebase and database structure while preserving all existing functionality. 