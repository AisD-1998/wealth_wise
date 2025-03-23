import 'package:flutter/material.dart';

class SpendingCategory {
  final String? id;
  final String name;
  final double budgetLimit;
  final double spent;
  final Color color;
  final String userId;
  final String? iconName;

  SpendingCategory({
    this.id,
    required this.name,
    required this.budgetLimit,
    this.spent = 0.0,
    required this.color,
    required this.userId,
    this.iconName,
  });

  double get percentUsed {
    if (budgetLimit <= 0) return 0;
    double percentage = (spent / budgetLimit) * 100;
    return percentage > 100 ? 100 : percentage;
  }

  bool get isOverBudget => spent > budgetLimit;

  double get remaining => budgetLimit - spent;

  // Calculate percentage for pie charts and visualizations
  double get percentage => percentUsed;

  factory SpendingCategory.fromMap(Map<String, dynamic> map, String id) {
    final colorValue = map['color'] is int
        ? map['color']
        : map['color'] is String
            ? int.tryParse(map['color']) ?? Colors.blue.toARGB32()
            : Colors.blue.toARGB32();

    return SpendingCategory(
      id: id,
      name: map['name'] ?? '',
      budgetLimit: (map['budgetLimit'] ?? 0.0).toDouble(),
      spent: (map['spent'] ?? 0.0).toDouble(),
      color: Color(colorValue),
      userId: map['userId'] ?? '',
      iconName: map['iconName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'budgetLimit': budgetLimit,
      'spent': spent,
      'color': color.toARGB32(),
      'userId': userId,
      'iconName': iconName,
    };
  }

  SpendingCategory copyWith({
    String? id,
    String? name,
    double? budgetLimit,
    double? spent,
    Color? color,
    String? userId,
    String? iconName,
  }) {
    return SpendingCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      budgetLimit: budgetLimit ?? this.budgetLimit,
      spent: spent ?? this.spent,
      color: color ?? this.color,
      userId: userId ?? this.userId,
      iconName: iconName ?? this.iconName,
    );
  }
}
