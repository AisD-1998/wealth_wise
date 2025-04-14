import 'package:cloud_firestore/cloud_firestore.dart';

enum FinancialGoal {
  saveMoney,
  payOffDebt,
  investForFuture,
  budgetBetter,
  trackExpenses,
  other
}

enum IncomeRange {
  under25k,
  between25kAnd50k,
  between50kAnd75k,
  between75kAnd100k,
  over100k,
  preferNotToSay
}

enum FinancialExpertise { beginner, intermediate, advanced }

class UserPreferences {
  final String userId;
  final FinancialGoal primaryGoal;
  final List<FinancialGoal> secondaryGoals;
  final IncomeRange incomeRange;
  final FinancialExpertise expertise;
  final bool hasExistingBudget;
  final bool interestedInInvesting;
  final DateTime lastUpdated;

  UserPreferences({
    required this.userId,
    required this.primaryGoal,
    this.secondaryGoals = const [],
    required this.incomeRange,
    required this.expertise,
    this.hasExistingBudget = false,
    this.interestedInInvesting = false,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  factory UserPreferences.fromMap(Map<String, dynamic> map, String userId) {
    return UserPreferences(
      userId: userId,
      primaryGoal: FinancialGoal.values[map['primaryGoal'] ?? 0],
      secondaryGoals: map['secondaryGoals'] != null
          ? List<FinancialGoal>.from((map['secondaryGoals'] as List)
              .map((i) => FinancialGoal.values[i]))
          : [],
      incomeRange: IncomeRange.values[map['incomeRange'] ?? 0],
      expertise: FinancialExpertise.values[map['expertise'] ?? 0],
      hasExistingBudget: map['hasExistingBudget'] ?? false,
      interestedInInvesting: map['interestedInInvesting'] ?? false,
      lastUpdated: map['lastUpdated'] != null
          ? (map['lastUpdated'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'primaryGoal': primaryGoal.index,
      'secondaryGoals': secondaryGoals.map((goal) => goal.index).toList(),
      'incomeRange': incomeRange.index,
      'expertise': expertise.index,
      'hasExistingBudget': hasExistingBudget,
      'interestedInInvesting': interestedInInvesting,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  UserPreferences copyWith({
    String? userId,
    FinancialGoal? primaryGoal,
    List<FinancialGoal>? secondaryGoals,
    IncomeRange? incomeRange,
    FinancialExpertise? expertise,
    bool? hasExistingBudget,
    bool? interestedInInvesting,
    DateTime? lastUpdated,
  }) {
    return UserPreferences(
      userId: userId ?? this.userId,
      primaryGoal: primaryGoal ?? this.primaryGoal,
      secondaryGoals: secondaryGoals ?? this.secondaryGoals,
      incomeRange: incomeRange ?? this.incomeRange,
      expertise: expertise ?? this.expertise,
      hasExistingBudget: hasExistingBudget ?? this.hasExistingBudget,
      interestedInInvesting:
          interestedInInvesting ?? this.interestedInInvesting,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  // Helper methods to get string representations
  static String financialGoalToString(FinancialGoal goal) {
    switch (goal) {
      case FinancialGoal.saveMoney:
        return 'Save Money';
      case FinancialGoal.payOffDebt:
        return 'Pay Off Debt';
      case FinancialGoal.investForFuture:
        return 'Invest for Future';
      case FinancialGoal.budgetBetter:
        return 'Budget Better';
      case FinancialGoal.trackExpenses:
        return 'Track Expenses';
      case FinancialGoal.other:
        return 'Other';
    }
  }

  static String incomeRangeToString(IncomeRange range) {
    switch (range) {
      case IncomeRange.under25k:
        return 'Under \$25,000';
      case IncomeRange.between25kAnd50k:
        return '\$25,000 - \$50,000';
      case IncomeRange.between50kAnd75k:
        return '\$50,000 - \$75,000';
      case IncomeRange.between75kAnd100k:
        return '\$75,000 - \$100,000';
      case IncomeRange.over100k:
        return 'Over \$100,000';
      case IncomeRange.preferNotToSay:
        return 'Prefer not to say';
    }
  }

  static String expertiseToString(FinancialExpertise expertise) {
    switch (expertise) {
      case FinancialExpertise.beginner:
        return 'Beginner';
      case FinancialExpertise.intermediate:
        return 'Intermediate';
      case FinancialExpertise.advanced:
        return 'Advanced';
    }
  }
}
