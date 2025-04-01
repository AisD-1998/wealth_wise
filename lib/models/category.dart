import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum to represent the category type
enum CategoryType { income, expense }

/// Extension to convert CategoryType to/from String
extension CategoryTypeExtension on CategoryType {
  String toShortString() {
    return toString().split('.').last;
  }

  static CategoryType fromString(String typeString) {
    return CategoryType.values.firstWhere(
      (e) => e.toShortString() == typeString,
      orElse: () => CategoryType.expense,
    );
  }
}

class Category {
  final String id;
  final String name;
  final String icon;
  final Color color;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final CategoryType type;

  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    required this.type,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    final Timestamp createdAtTimestamp = map['createdAt'] as Timestamp;
    final Timestamp updatedAtTimestamp = map['updatedAt'] as Timestamp;

    // Get the color value from the map
    int colorValue = 0;
    if (map['color'] is int) {
      colorValue = map['color'] as int;
    }

    // Parse the category type, defaulting to expense if not present
    CategoryType categoryType = CategoryType.expense;
    if (map.containsKey('type') && map['type'] is String) {
      categoryType = CategoryTypeExtension.fromString(map['type'] as String);
    }

    return Category(
      id: map['id'] as String,
      name: map['name'] as String,
      icon: map['icon'] as String,
      color: Color(colorValue),
      userId: map['userId'] as String,
      createdAt: createdAtTimestamp.toDate(),
      updatedAt: updatedAtTimestamp.toDate(),
      type: categoryType,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color.toARGB32(),
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'type': type.toShortString(),
    };
  }

  Category copyWith({
    String? id,
    String? name,
    String? icon,
    Color? color,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
    CategoryType? type,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      type: type ?? this.type,
    );
  }
}
