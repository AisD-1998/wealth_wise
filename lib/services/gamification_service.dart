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

  /// Returns this month's income and expenses from the given transactions.
  static ({double income, double expenses}) _thisMonthTotals(
      List<Transaction> transactions) {
    final now = DateTime.now();
    final thisMonthTxns = transactions.where(
        (t) => t.date.year == now.year && t.date.month == now.month);
    final income = thisMonthTxns
        .where((t) => t.type == TransactionType.income)
        .fold<double>(0, (sum, t) => sum + t.amount);
    final expenses = thisMonthTxns
        .where((t) => t.type == TransactionType.expense)
        .fold<double>(0, (sum, t) => sum + t.amount);
    return (income: income, expenses: expenses);
  }

  static bool _checkFirstTransaction(List<Transaction> transactions) {
    return transactions.isNotEmpty;
  }

  static bool _checkBudgetMaster(List<Budget> budgets) {
    return budgets.isNotEmpty && budgets.every((b) => b.spent <= b.amount);
  }

  static bool _checkWeekWarrior(int streak) {
    return streak >= 7;
  }

  static bool _checkSavingsStar(List<SavingGoal> goals) {
    return goals.any((g) => g.isCompleted);
  }

  static bool _checkMonthMaven(int streak) {
    return streak >= 30;
  }

  static bool _checkBigSaver(List<Transaction> transactions) {
    final totals = _thisMonthTotals(transactions);
    return totals.income > 0 &&
        (totals.income - totals.expenses) / totals.income > 0.3;
  }

  static bool _checkCategoryPro(List<Transaction> transactions) {
    final expenseCategories = transactions
        .where(
            (t) => t.type == TransactionType.expense && t.category != null)
        .map((t) => t.category!)
        .toSet();
    return expenseCategories.length >= 5;
  }

  static bool _checkCenturyClub(List<Transaction> transactions) {
    return transactions.length >= 100;
  }

  static bool _checkGoalGetter(List<SavingGoal> goals) {
    return goals.length >= 3;
  }

  static bool _checkBudgetBuilder(List<Budget> budgets) {
    return budgets.length >= 5;
  }

  static bool _checkStreakLegend(int streak) {
    return streak >= 90;
  }

  static bool _checkDebtFree(List<Transaction> transactions) {
    final totals = _thisMonthTotals(transactions);
    return totals.income > totals.expenses && totals.income > 0;
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
    final checks = <String, bool Function()>{
      'first_transaction': () => _checkFirstTransaction(transactions),
      'budget_master': () => _checkBudgetMaster(budgets),
      'week_warrior': () => _checkWeekWarrior(streak),
      'savings_star': () => _checkSavingsStar(goals),
      'month_maven': () => _checkMonthMaven(streak),
      'big_saver': () => _checkBigSaver(transactions),
      'category_pro': () => _checkCategoryPro(transactions),
      'century_club': () => _checkCenturyClub(transactions),
      'goal_getter': () => _checkGoalGetter(goals),
      'budget_builder': () => _checkBudgetBuilder(budgets),
      'streak_legend': () => _checkStreakLegend(streak),
      'debt_free': () => _checkDebtFree(transactions),
    };

    final newlyUnlocked = <String>[];
    for (final entry in checks.entries) {
      if (!alreadyUnlocked.contains(entry.key) && entry.value()) {
        newlyUnlocked.add(entry.key);
      }
    }

    return newlyUnlocked;
  }
}
