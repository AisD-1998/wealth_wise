import 'package:cloud_firestore/cloud_firestore.dart';

enum BillRecurrence {
  weekly,
  biweekly,
  monthly,
  quarterly,
  yearly,
}

extension BillRecurrenceLabel on BillRecurrence {
  String get label {
    switch (this) {
      case BillRecurrence.weekly:
        return 'Weekly';
      case BillRecurrence.biweekly:
        return 'Every 2 weeks';
      case BillRecurrence.monthly:
        return 'Monthly';
      case BillRecurrence.quarterly:
        return 'Quarterly';
      case BillRecurrence.yearly:
        return 'Yearly';
    }
  }

  /// Calculate the next due date from the given date.
  DateTime nextDueAfter(DateTime from) {
    switch (this) {
      case BillRecurrence.weekly:
        return from.add(const Duration(days: 7));
      case BillRecurrence.biweekly:
        return from.add(const Duration(days: 14));
      case BillRecurrence.monthly:
        return DateTime(from.year, from.month + 1, from.day);
      case BillRecurrence.quarterly:
        return DateTime(from.year, from.month + 3, from.day);
      case BillRecurrence.yearly:
        return DateTime(from.year + 1, from.month, from.day);
    }
  }
}

class BillReminder {
  final String? id;
  final String userId;
  final String title;
  final double amount;
  final DateTime dueDate;
  final BillRecurrence recurrence;
  final String? category;
  final bool isPaid;
  final String? note;

  const BillReminder({
    this.id,
    required this.userId,
    required this.title,
    required this.amount,
    required this.dueDate,
    required this.recurrence,
    this.category,
    this.isPaid = false,
    this.note,
  });

  factory BillReminder.fromMap(Map<String, dynamic> map, String id) {
    return BillReminder(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      dueDate: (map['dueDate'] as Timestamp).toDate(),
      recurrence: BillRecurrence.values.firstWhere(
        (e) => e.name == map['recurrence'],
        orElse: () => BillRecurrence.monthly,
      ),
      category: map['category'],
      isPaid: map['isPaid'] ?? false,
      note: map['note'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'amount': amount,
      'dueDate': Timestamp.fromDate(dueDate),
      'recurrence': recurrence.name,
      'category': category,
      'isPaid': isPaid,
      'note': note,
    };
  }

  BillReminder copyWith({
    String? id,
    String? userId,
    String? title,
    double? amount,
    DateTime? dueDate,
    BillRecurrence? recurrence,
    String? category,
    bool? isPaid,
    String? note,
  }) {
    return BillReminder(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      recurrence: recurrence ?? this.recurrence,
      category: category ?? this.category,
      isPaid: isPaid ?? this.isPaid,
      note: note ?? this.note,
    );
  }

  /// Whether this bill is overdue (past due date and not paid).
  bool get isOverdue =>
      !isPaid && dueDate.isBefore(DateTime.now());

  /// Whether this bill is due within the next N days.
  bool isDueSoon({int days = 3}) {
    if (isPaid) return false;
    final now = DateTime.now();
    return dueDate.isAfter(now) &&
        dueDate.isBefore(now.add(Duration(days: days)));
  }

  /// Number of days until this bill is due (negative if overdue).
  int get daysUntilDue {
    final now = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return due.difference(now).inDays;
  }
}
