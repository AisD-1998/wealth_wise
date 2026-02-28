enum BudgetAlertType {
  warning75, // 75% threshold
  exceeded100, // 100% threshold
  predictive, // Premium: predicted to exceed
}

class BudgetAlert {
  final String budgetId;
  final String category;
  final double percentUsed;
  final BudgetAlertType alertType;
  final String message;
  final double? predictedOverage; // For predictive alerts

  const BudgetAlert({
    required this.budgetId,
    required this.category,
    required this.percentUsed,
    required this.alertType,
    required this.message,
    this.predictedOverage,
  });
}
