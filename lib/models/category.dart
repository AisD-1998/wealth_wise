import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Category {
  final String id;
  final String name;
  final String icon;
  final Color color;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    final Timestamp createdAtTimestamp = map['createdAt'] as Timestamp;
    final Timestamp updatedAtTimestamp = map['updatedAt'] as Timestamp;

    // Get the color value from the map
    int colorValue = 0;
    if (map['color'] is int) {
      colorValue = map['color'] as int;
    }

    return Category(
      id: map['id'] as String,
      name: map['name'] as String,
      icon: map['icon'] as String,
      color: Color(colorValue),
      userId: map['userId'] as String,
      createdAt: createdAtTimestamp.toDate(),
      updatedAt: updatedAtTimestamp.toDate(),
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
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
