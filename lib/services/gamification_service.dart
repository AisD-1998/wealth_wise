import 'package:wealth_wise/models/achievement.dart';
import 'package:wealth_wise/models/transaction.dart';
import 'package:wealth_wise/models/budget_model.dart';
import 'package:wealth_wise/models/saving_goal.dart';

class GamificationService {
  /// All available achievements (template definitions).
  static List<Achievement> allAchievements = [
    // Free achievements (first 3)
    const Achievement(
      id: 'first_transaction',
      title: 'First Step',
      description: 'Log your first transaction',
      iconName: 'star',
    ),
    const Achievement(
      id: 'budget_master',
      title: 'Budget Master',
      description: 'Stay within all budgets for a full month',
      iconName: 'shield',
    ),
    const Achievement(
      id: 'week_warrior',
      title: 'Week Warrior',
      description: 'Log transactions for 7 consecutive days',
      iconName: 'local_fire_department',
    ),

    // Premium achievements
    const Achievement(
      id: 'savings_star',
      title: 'Savings Star',
      description: 'Complete your first saving goal',
      iconName: 'emoji_events',
      isPremium: true,
    ),
    const Achievement(
      id: 'month_maven',
      title: 'Month Maven',
      description: 'Log transactions for 30 consecutive days',
      iconName: 'military_tech',
      isPremium: true,
    ),
    const Achievement(
      id: 'big_saver',
      title: 'Big Saver',
      description: 'Save over 30% of your income in a month',
      iconName: 'savings',
      isPremium: true,
    ),
    const Achievement(
      id: 'category_pro',
      title: 'Category Pro',
      description: 'Use 5 or more expense categories',
      iconName: 'category',
      isPremium: true,
    ),
    const Achievement(
      id: 'century_club',
      title: 'Century Club',
      description: 'Log 100 transactions',
      iconName: 'hundred_mp',
      isPremium: true,
    ),
    const Achievement(
      id: 'goal_getter',
      title: 'Goal Getter',
      description: 'Create 3 saving goals',
      iconName: 'flag',
      isPremium: true,
    ),
    const Achievement(
      id: 'budget_builder',
      title: 'Budget Builder',
      description: 'Create 5 budgets',
      iconName: 'account_balance',
      isPremium: true,
    ),
    const Achievement(
      id: 'streak_legend',
      title: 'Streak Legend',
      description: 'Reach a 90-day streak',
      iconName: 'whatshot',
      isPremium: true,
    ),
    const Achievement(
      id: 'debt_free',
      title: 'In The Green',
      description: 'End a month with positive balance',
      iconName: 'trending_up',
      isPremium: true,
    ),
  ];

  /// Calculate the current streak (consecutive days with at least one transaction).
  static int calculateStreak(List<Transaction> transactions) {
    if (transactions.isEmpty) return 0;

    // Get unique dates (day-level) of transactions, sorted descending
    final uniqueDates = <DateTime>{};
    for (final t in transactions) {
      uniqueDates.add(DateTime(t.date.year, t.date.month, t.date.day));
    }
    final sortedDates = uniqueDates.toList()
      ..sort((a, b) => b.compareTo(a));

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final yesterday = todayDate.subtract(const Duration(days: 1));

    // Streak must include today or yesterday to be active
    if (sortedDates.first != todayDate && sortedDates.first != yesterday) {
      return 0;
    }

    int streak = 1;
    for (int i = 1; i < sortedDates.length; i++) {
      final diff = sortedDates[i - 1].difference(sortedDates[i]).inDays;
      if (diff == 1) {
        streak++;
      } else {
        break;
      }
    }

    return streak;
  }

  /// Check which achievements should be unlocked based on current data.
  /// Returns a list of newly unlocked achievement IDs.
  static List<String> checkAchievements({
    required List<Transaction> transactions,
    required List<Budget> budgets,
    required List<SavingGoal> goals,
    required int streak,
    required Set<String> alreadyUnlocked,
  }) {
    final newlyUnlocked = <String>[];

    // First Step - first transaction
    if (!alreadyUnlocked.contains('first_transaction') &&
        transactions.isNotEmpty) {
      newlyUnlocked.add('first_transaction');
    }

    // Budget Master - all budgets under limit
    if (!alreadyUnlocked.contains('budget_master') && budgets.isNotEmpty) {
      final allWithinBudget = budgets.every((b) => b.spent <= b.amount);
      if (allWithinBudget) {
        newlyUnlocked.add('budget_master');
      }
    }

    // Week Warrior - 7 day streak
    if (!alreadyUnlocked.contains('week_warrior') && streak >= 7) {
      newlyUnlocked.add('week_warrior');
    }

    // Savings Star - completed a goal
    if (!alreadyUnlocked.contains('savings_star')) {
      final hasCompletedGoal = goals.any((g) => g.isCompleted);
      if (hasCompletedGoal) {
        newlyUnlocked.add('savings_star');
      }
    }

    // Month Maven - 30 day streak
    if (!alreadyUnlocked.contains('month_maven') && streak >= 30) {
      newlyUnlocked.add('month_maven');
    }

    // Big Saver - savings rate > 30%
    if (!alreadyUnlocked.contains('big_saver')) {
      final now = DateTime.now();
      final thisMonthTxns = transactions.where((t) =>
          t.date.year == now.year && t.date.month == now.month);
      final income = thisMonthTxns
          .where((t) => t.type == TransactionType.income)
          .fold<double>(0, (sum, t) => sum + t.amount);
      final expenses = thisMonthTxns
          .where((t) => t.type == TransactionType.expense)
          .fold<double>(0, (sum, t) => sum + t.amount);
      if (income > 0 && (income - expenses) / income > 0.3) {
        newlyUnlocked.add('big_saver');
      }
    }

    // Category Pro - used 5+ expense categories
    if (!alreadyUnlocked.contains('category_pro')) {
      final expenseCategories = transactions
          .where((t) =>
              t.type == TransactionType.expense && t.category != null)
          .map((t) => t.category!)
          .toSet();
      if (expenseCategories.length >= 5) {
        newlyUnlocked.add('category_pro');
      }
    }

    // Century Club - 100 transactions
    if (!alreadyUnlocked.contains('century_club') &&
        transactions.length >= 100) {
      newlyUnlocked.add('century_club');
    }

    // Goal Getter - 3 saving goals
    if (!alreadyUnlocked.contains('goal_getter') && goals.length >= 3) {
      newlyUnlocked.add('goal_getter');
    }

    // Budget Builder - 5 budgets
    if (!alreadyUnlocked.contains('budget_builder') && budgets.length >= 5) {
      newlyUnlocked.add('budget_builder');
    }

    // Streak Legend - 90 day streak
    if (!alreadyUnlocked.contains('streak_legend') && streak >= 90) {
      newlyUnlocked.add('streak_legend');
    }

    // In The Green - positive balance this month
    if (!alreadyUnlocked.contains('debt_free')) {
      final now = DateTime.now();
      final thisMonthTxns = transactions.where((t) =>
          t.date.year == now.year && t.date.month == now.month);
      final income = thisMonthTxns
          .where((t) => t.type == TransactionType.income)
          .fold<double>(0, (sum, t) => sum + t.amount);
      final expenses = thisMonthTxns
          .where((t) => t.type == TransactionType.expense)
          .fold<double>(0, (sum, t) => sum + t.amount);
      if (income > expenses && income > 0) {
        newlyUnlocked.add('debt_free');
      }
    }

    return newlyUnlocked;
  }
}
