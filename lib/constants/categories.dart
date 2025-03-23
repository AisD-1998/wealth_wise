import 'package:flutter/material.dart';

class CategoryInfo {
  final String name;
  final IconData icon;
  final Color color;

  const CategoryInfo({
    required this.name,
    required this.icon,
    required this.color,
  });
}

// Expense categories
final Map<String, CategoryInfo> expenseCategories = {
  'food': const CategoryInfo(
    name: 'Food & Dining',
    icon: Icons.restaurant,
    color: Colors.orange,
  ),
  'transportation': const CategoryInfo(
    name: 'Transportation',
    icon: Icons.directions_car,
    color: Colors.blue,
  ),
  'entertainment': const CategoryInfo(
    name: 'Entertainment',
    icon: Icons.movie,
    color: Colors.purple,
  ),
  'shopping': const CategoryInfo(
    name: 'Shopping',
    icon: Icons.shopping_bag,
    color: Colors.pink,
  ),
  'housing': const CategoryInfo(
    name: 'Housing',
    icon: Icons.home,
    color: Colors.brown,
  ),
  'utilities': const CategoryInfo(
    name: 'Utilities',
    icon: Icons.bolt,
    color: Color(0xFFFFB300),
  ),
  'health': const CategoryInfo(
    name: 'Health',
    icon: Icons.medical_services,
    color: Colors.red,
  ),
  'education': const CategoryInfo(
    name: 'Education',
    icon: Icons.school,
    color: Colors.indigo,
  ),
  'personal': const CategoryInfo(
    name: 'Personal',
    icon: Icons.person,
    color: Colors.teal,
  ),
  'other': const CategoryInfo(
    name: 'Other',
    icon: Icons.more_horiz,
    color: Colors.grey,
  ),
};

// Income categories
final Map<String, CategoryInfo> incomeCategories = {
  'salary':
      const CategoryInfo(name: 'Salary', icon: Icons.work, color: Colors.green),
  'business': const CategoryInfo(
    name: 'Business',
    icon: Icons.business,
    color: Colors.lightBlue,
  ),
  'investments': const CategoryInfo(
    name: 'Investments',
    icon: Icons.trending_up,
    color: Colors.deepPurple,
  ),
  'gifts': const CategoryInfo(
    name: 'Gifts',
    icon: Icons.card_giftcard,
    color: Colors.amber,
  ),
  'other_income': const CategoryInfo(
    name: 'Other Income',
    icon: Icons.attach_money,
    color: Colors.lightGreen,
  ),
};
