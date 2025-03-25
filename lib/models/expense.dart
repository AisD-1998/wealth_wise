class Expense {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final String category;
  final String? note;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    this.note,
  });

  Expense copyWith({
    String? id,
    String? title,
    double? amount,
    DateTime? date,
    String? category,
    String? note,
  }) {
    return Expense(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
      note: note ?? this.note,
    );
  }
}
