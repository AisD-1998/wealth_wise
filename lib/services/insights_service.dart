import 'package:wealth_wise/models/transaction.dart' as app_model;
import 'package:wealth_wise/models/budget_model.dart';
import 'package:wealth_wise/models/saving_goal.dart';

/// Pure computation service for financial insights.
/// No state, no dependencies — takes data in, returns computed metrics.
class InsightsService {
  /// Calculate Financial Health Score (0-100).
  /// Composite of: savings rate (40pts), budget adherence (30pts), goal progress (30pts).
  static double financialHealthScore({
    required double totalIncome,
    required double totalExpenses,
    required List<Budget> budgets,
    required List<SavingGoal> goals,
  }) {
    double score = 0;

    // Savings rate component (0-40 points)
    if (totalIncome > 0) {
      final savingsRate =
          ((totalIncome - totalExpenses) / totalIncome).clamp(0.0, 1.0);
      // 20%+ savings rate = full 40 points
      score += (savingsRate / 0.20).clamp(0.0, 1.0) * 40;
    }

    // Budget adherence component (0-30 points)
    if (budgets.isNotEmpty) {
      int underBudgetCount = 0;
      for (final b in budgets) {
        if (b.spent <= b.amount) underBudgetCount++;
      }
      score += (underBudgetCount / budgets.length) * 30;
    } else {
      score += 15; // Neutral if no budgets set
    }

    // Goal progress component (0-30 points)
    if (goals.isNotEmpty) {
      double avgProgress = 0;
      for (final g in goals) {
        avgProgress +=
            (g.currentAmount / g.targetAmount).clamp(0.0, 1.0);
      }
      avgProgress /= goals.length;
      score += avgProgress * 30;
    } else {
      score += 15; // Neutral if no goals set
    }

    return score.clamp(0, 100);
  }

  /// Get the health score label.
  static String healthScoreLabel(double score) {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Fair';
    if (score >= 20) return 'Needs Work';
    return 'Getting Started';
  }

  /// Calculate month-over-month spending change as a percentage.
  /// Returns null if there's no previous month data.
  static double? monthOverMonthChange(
      List<app_model.Transaction> transactions) {
    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);

    double thisMonthExpenses = 0;
    double lastMonthExpenses = 0;

    for (final t in transactions) {
      if (t.type != app_model.TransactionType.expense) continue;
      if (!t.date.isBefore(thisMonthStart)) {
        thisMonthExpenses += t.amount;
      } else if (!t.date.isBefore(lastMonthStart) &&
          t.date.isBefore(thisMonthStart)) {
        lastMonthExpenses += t.amount;
      }
    }

    if (lastMonthExpenses == 0) return null;
    return ((thisMonthExpenses - lastMonthExpenses) / lastMonthExpenses) * 100;
  }

  /// Calculate budget adherence score (0-100%).
  /// Percentage of budgets that are under their limit.
  static double budgetAdherenceScore(List<Budget> budgets) {
    if (budgets.isEmpty) return 100;
    int underBudget = 0;
    for (final b in budgets) {
      if (b.spent <= b.amount) underBudget++;
    }
    return (underBudget / budgets.length) * 100;
  }

  /// Estimate months to reach a saving goal at current rate.
  /// Returns null if no contributions or goal is already met.
  static int? monthsToGoal(
      SavingGoal goal, List<app_model.Transaction> transactions) {
    if (goal.isCompleted) return 0;

    final stats = _goalContributionStats(goal, transactions);
    if (stats == null) return null;

    final monthlyRate = _monthlyContributionRate(stats);
    if (monthlyRate == null) return null;

    final remaining = goal.targetAmount - goal.currentAmount;
    return (remaining / monthlyRate).ceil();
  }

  /// Aggregate contribution stats for a goal from income transactions.
  static _ContributionStats? _goalContributionStats(
      SavingGoal goal, List<app_model.Transaction> transactions) {
    double totalContributed = 0;
    DateTime? firstContribution;
    DateTime? lastContribution;

    for (final t in transactions) {
      if (t.goalId != goal.id) continue;
      if (t.type != app_model.TransactionType.income) continue;

      totalContributed += t.amount * (t.contributionPercentage ?? 100) / 100;
      if (firstContribution == null || t.date.isBefore(firstContribution)) {
        firstContribution = t.date;
      }
      if (lastContribution == null || t.date.isAfter(lastContribution)) {
        lastContribution = t.date;
      }
    }

    if (totalContributed <= 0 || firstContribution == null) return null;

    return _ContributionStats(
      totalContributed: totalContributed,
      firstContribution: firstContribution,
      lastContribution: lastContribution!,
    );
  }

  /// Calculate the monthly contribution rate from stats.
  /// Returns null if history is too short or rate is non-positive.
  static double? _monthlyContributionRate(_ContributionStats stats) {
    final months =
        stats.lastContribution.difference(stats.firstContribution).inDays / 30;
    if (months < 0.5) return null; // Not enough history

    final rate = stats.totalContributed / months;
    return rate > 0 ? rate : null;
  }

  /// Get spending by weekday (0=Monday, 6=Sunday).
  /// Returns a list of 7 doubles representing total spending per weekday.
  static List<double> weekdaySpending(
      List<app_model.Transaction> transactions) {
    final spending = List.filled(7, 0.0);

    for (final t in transactions) {
      if (t.type != app_model.TransactionType.expense) continue;
      // DateTime.weekday: 1=Monday, 7=Sunday → index 0-6
      spending[t.date.weekday - 1] += t.amount;
    }

    return spending;
  }

  /// Get monthly totals for the last N months.
  /// Returns a map of { monthOffset: { 'income': x, 'expenses': y } }.
  /// monthOffset 0 = current month, 1 = last month, etc.
  static List<MonthlyTotal> monthlyTotals(
      List<app_model.Transaction> transactions,
      {int months = 6}) {
    final now = DateTime.now();
    final result = <MonthlyTotal>[];

    for (int i = months - 1; i >= 0; i--) {
      final monthStart = DateTime(now.year, now.month - i, 1);
      final monthEnd = DateTime(now.year, now.month - i + 1, 0);

      double income = 0;
      double expenses = 0;

      for (final t in transactions) {
        if (t.date.isBefore(monthStart) || t.date.isAfter(monthEnd)) continue;
        if (t.type == app_model.TransactionType.income) {
          income += t.amount;
        } else {
          expenses += t.amount;
        }
      }

      result.add(MonthlyTotal(
        month: monthStart,
        income: income,
        expenses: expenses,
      ));
    }

    return result;
  }

  /// Get spending breakdown by category for the current month.
  static Map<String, double> categoryBreakdown(
      List<app_model.Transaction> transactions) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final breakdown = <String, double>{};

    for (final t in transactions) {
      if (t.type != app_model.TransactionType.expense) continue;
      if (t.date.isBefore(monthStart)) continue;
      final cat = t.category ?? 'Uncategorized';
      breakdown[cat] = (breakdown[cat] ?? 0) + t.amount;
    }

    return breakdown;
  }
}

class MonthlyTotal {
  final DateTime month;
  final double income;
  final double expenses;

  const MonthlyTotal({
    required this.month,
    required this.income,
    required this.expenses,
  });

  double get net => income - expenses;
  double get savingsRate => income > 0 ? (net / income) * 100 : 0;
}

/// Internal data holder for goal contribution aggregation.
class _ContributionStats {
  final double totalContributed;
  final DateTime firstContribution;
  final DateTime lastContribution;

  const _ContributionStats({
    required this.totalContributed,
    required this.firstContribution,
    required this.lastContribution,
  });
}
