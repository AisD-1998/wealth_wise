import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';

enum TransactionType {
  income,
  expense,
}

class Transaction {
  final String? id;
  final String title;
  final double amount;
  final DateTime date;
  final TransactionType type;
  final String? category;
  final String userId;
  final String? note;
  final String? receiptUrl;
  final bool includedInTotals;
  final String? goalId;
  final double?
      contributionPercentage; // Percentage of income to contribute to goal

  static final Logger _logger = Logger('Transaction');

  Transaction({
    this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.type,
    this.category,
    required this.userId,
    this.note,
    this.receiptUrl,
    this.includedInTotals = true,
    this.goalId,
    this.contributionPercentage = 100.0, // Default to 100% if not specified
  });

  factory Transaction.fromMap(Map<String, dynamic> map, String id) {
    try {
      final transaction = Transaction(
        id: id,
        title: map['title'] ?? '',
        amount: (map['amount'] ?? 0.0).toDouble(),
        date: (map['date'] as Timestamp).toDate(),
        type: map['type'] == 'income'
            ? TransactionType.income
            : TransactionType.expense,
        category: map['category'] ?? 'Other',
        userId: map['userId'] ?? '',
        note: map['note'],
        receiptUrl: map['receiptUrl'],
        includedInTotals: map['includedInTotals'] ?? true,
        goalId: map['goalId'],
        contributionPercentage:
            (map['contributionPercentage'] ?? 100.0).toDouble(),
      );
      return transaction;
    } catch (e) {
      _logger.warning('Error creating Transaction from map: $e');
      _logger.warning('Map data: $map');
      rethrow;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'type': type == TransactionType.income ? 'income' : 'expense',
      'category': category ?? 'Other',
      'userId': userId,
      'note': note,
      'receiptUrl': receiptUrl,
      'includedInTotals': includedInTotals,
      'goalId': goalId,
      'contributionPercentage': contributionPercentage,
    };
  }

  Transaction copyWith({
    String? id,
    String? title,
    double? amount,
    DateTime? date,
    TransactionType? type,
    String? category,
    String? userId,
    String? note,
    String? receiptUrl,
    bool? includedInTotals,
    String? goalId,
    double? contributionPercentage,
  }) {
    return Transaction(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      type: type ?? this.type,
      category: category ?? this.category,
      userId: userId ?? this.userId,
      note: note ?? this.note,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      includedInTotals: includedInTotals ?? this.includedInTotals,
      goalId: goalId ?? this.goalId,
      contributionPercentage:
          contributionPercentage ?? this.contributionPercentage,
    );
  }

  // For debugging purposes
  String toDebugString() {
    return 'Transaction(id: $id, title: $title, amount: $amount, date: $date, '
        'type: $type, category: $category, userId: $userId, includedInTotals: $includedInTotals, '
        'goalId: $goalId, contributionPercentage: $contributionPercentage)';
  }

  // Check if transaction contributes to a goal
  bool get contributesToGoal =>
      type == TransactionType.income && goalId != null && goalId!.isNotEmpty;

  // Calculate contribution amount based on percentage
  double get contributionAmount => contributesToGoal
      ? (amount * (contributionPercentage ?? 100.0) / 100.0)
      : 0.0;
}
