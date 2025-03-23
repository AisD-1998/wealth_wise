import 'package:cloud_firestore/cloud_firestore.dart';

class SavingGoal {
  final String? id;
  final String title;
  final double targetAmount;
  final double currentAmount;
  final DateTime createdDate;
  final DateTime? targetDate;
  final String? description;
  final String? colorCode;
  final String userId;

  SavingGoal({
    this.id,
    required this.title,
    required this.targetAmount,
    this.currentAmount = 0.0,
    DateTime? createdDate,
    this.targetDate,
    this.description,
    this.colorCode,
    required this.userId,
  }) : createdDate = createdDate ?? DateTime.now();

  double get progressPercentage {
    if (targetAmount <= 0) return 0;
    double percentage = (currentAmount / targetAmount) * 100;
    return percentage > 100 ? 100 : percentage;
  }

  bool get isCompleted => currentAmount >= targetAmount;

  int get daysLeft {
    if (targetDate == null) return 0;
    final now = DateTime.now();
    return targetDate!.difference(now).inDays;
  }

  factory SavingGoal.fromMap(Map<String, dynamic> map, String id) {
    return SavingGoal(
      id: id,
      title: map['title'] ?? '',
      targetAmount: (map['targetAmount'] ?? 0.0).toDouble(),
      currentAmount: (map['currentAmount'] ?? 0.0).toDouble(),
      createdDate: (map['createdDate'] as Timestamp).toDate(),
      targetDate: map['targetDate'] != null
          ? (map['targetDate'] as Timestamp).toDate()
          : null,
      description: map['description'],
      colorCode: map['colorCode'],
      userId: map['userId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'createdDate': Timestamp.fromDate(createdDate),
      'targetDate': targetDate != null ? Timestamp.fromDate(targetDate!) : null,
      'description': description,
      'colorCode': colorCode,
      'userId': userId,
    };
  }

  SavingGoal copyWith({
    String? id,
    String? title,
    double? targetAmount,
    double? currentAmount,
    DateTime? createdDate,
    DateTime? targetDate,
    String? description,
    String? colorCode,
    String? userId,
  }) {
    return SavingGoal(
      id: id ?? this.id,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      createdDate: createdDate ?? this.createdDate,
      targetDate: targetDate ?? this.targetDate,
      description: description ?? this.description,
      colorCode: colorCode ?? this.colorCode,
      userId: userId ?? this.userId,
    );
  }
}
