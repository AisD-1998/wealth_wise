import 'package:cloud_firestore/cloud_firestore.dart';

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
  });

  factory Transaction.fromMap(Map<String, dynamic> map, String id) {
    return Transaction(
      id: id,
      title: map['title'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      date: (map['date'] as Timestamp).toDate(),
      type: map['type'] == 'income'
          ? TransactionType.income
          : TransactionType.expense,
      category: map['category'],
      userId: map['userId'] ?? '',
      note: map['note'],
      receiptUrl: map['receiptUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'type': type == TransactionType.income ? 'income' : 'expense',
      'category': category,
      'userId': userId,
      'note': note,
      'receiptUrl': receiptUrl,
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
    );
  }
}
