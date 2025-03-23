import 'package:flutter/material.dart';

class AppTheme {
  static const primaryColor = Color(0xFF1E88E5);
  static const secondaryColor = Color(0xFF26A69A);
  static const errorColor = Color(0xFFE53935);
  static const backgroundColor = Color(0xFFF5F5F5);
  static const cardColor = Colors.white;
  static const textPrimaryColor = Color(0xFF212121);
  static const textSecondaryColor = Color(0xFF757575);
  static const dividerColor = Color(0xFFBDBDBD);

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF3C63F9),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: Color(0xFF3C63F9)),
        titleTextStyle: TextStyle(
          color: Color(0xFF2D3142),
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3C63F9),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3C63F9)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF3C63F9),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF131418),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3C63F9),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      cardTheme: CardTheme(
        color: const Color(0xFF1C1E25),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1C1E25),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2D3142)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3C63F9)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
