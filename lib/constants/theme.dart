import 'package:flutter/material.dart';

class AppTheme {
  // Define color system for Material 3
  static final ColorScheme _lightColorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF3C63F9), // Primary blue
    brightness: Brightness.light,
    // Custom colors for specific elements
    secondary: const Color(0xFF26A69A), // Teal for secondary actions
    error: const Color(0xFFE53935), // Red for errors
    surface: Colors.white,
    onSurface: const Color(0xFF212121),
  );

  static final ColorScheme _darkColorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF3C63F9),
    brightness: Brightness.dark,
    // Custom colors for dark mode
    secondary: const Color(0xFF26A69A),
    error: const Color(0xFFE53935),
    surface: const Color(0xFF131418),
    onSurface: Colors.white,
  );

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _lightColorScheme,
      scaffoldBackgroundColor: _lightColorScheme.surface,

      // AppBar theme with Material 3 style
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false, // Material 3 typically left-aligns titles
        backgroundColor: _lightColorScheme.surface,
        surfaceTintColor: _lightColorScheme.surfaceTint,
        foregroundColor: _lightColorScheme.onSurface,
        iconTheme: IconThemeData(color: _lightColorScheme.primary),
        titleTextStyle: TextStyle(
          color: _lightColorScheme.onSurface,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),

      // Card theme with proper elevation and shape
      cardTheme: CardTheme(
        elevation: 0, // Material 3 uses less elevation
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: _lightColorScheme.surface,
        shadowColor: _lightColorScheme.shadow,
        surfaceTintColor: _lightColorScheme.surfaceTint,
      ),

      // Navigation bar with Material 3 specs
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _lightColorScheme.surface,
        indicatorColor: _lightColorScheme.primaryContainer,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: _lightColorScheme.onPrimaryContainer);
          }
          return IconThemeData(color: _lightColorScheme.onSurfaceVariant);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: _lightColorScheme.onSurface,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            );
          }
          return TextStyle(
            color: _lightColorScheme.onSurfaceVariant,
            fontSize: 12,
          );
        }),
      ),

      // Elevated button with Material 3 style
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return _lightColorScheme.onSurface.withValues(alpha: 31);
            }
            return _lightColorScheme.primary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return _lightColorScheme.onSurface.withValues(alpha: 97);
            }
            return _lightColorScheme.onPrimary;
          }),
          elevation: WidgetStateProperty.all(0),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ),

      // Text button with Material 3 style
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return _lightColorScheme.onSurface.withValues(alpha: 97);
            }
            return _lightColorScheme.primary;
          }),
          overlayColor: WidgetStateProperty.all(
            _lightColorScheme.primary.withValues(alpha: 20),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ),

      // Filled button for secondary actions
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return _lightColorScheme.onSurface.withValues(alpha: 31);
            }
            return _lightColorScheme.secondaryContainer;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return _lightColorScheme.onSurface.withValues(alpha: 97);
            }
            return _lightColorScheme.onSecondaryContainer;
          }),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
        ),
      ),

      // FAB theme for primary actions
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _lightColorScheme.primaryContainer,
        foregroundColor: _lightColorScheme.onPrimaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Text field styling
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            _lightColorScheme.surfaceContainerHighest.withValues(alpha: 77),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _lightColorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _lightColorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _lightColorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _lightColorScheme.error),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: TextStyle(color: _lightColorScheme.onSurfaceVariant),
        hintStyle: TextStyle(
            color: _lightColorScheme.onSurfaceVariant.withValues(alpha: 153)),
      ),

      // Chip theme for categories
      chipTheme: ChipThemeData(
        backgroundColor: _lightColorScheme.surfaceContainerHighest,
        labelStyle: TextStyle(color: _lightColorScheme.onSurfaceVariant),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),

      // Dialog theme
      dialogTheme: DialogTheme(
        backgroundColor: _lightColorScheme.surface,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),

      // Bottom sheet theme
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: _lightColorScheme.surface,
        modalBackgroundColor: _lightColorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),

      // Divider theme
      dividerTheme: DividerThemeData(
        color: _lightColorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      // Switch theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _lightColorScheme.primary;
          }
          return _lightColorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _lightColorScheme.primaryContainer;
          }
          return _lightColorScheme.surfaceContainerHighest;
        }),
      ),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _darkColorScheme,
      scaffoldBackgroundColor: _darkColorScheme.surface,

      // AppBar theme
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: _darkColorScheme.surface,
        surfaceTintColor: _darkColorScheme.surfaceTint,
        foregroundColor: _darkColorScheme.onSurface,
        iconTheme: IconThemeData(color: _darkColorScheme.primary),
        titleTextStyle: TextStyle(
          color: _darkColorScheme.onSurface,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),

      // Card theme
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: _darkColorScheme.surface,
        shadowColor: _darkColorScheme.shadow,
        surfaceTintColor: _darkColorScheme.surfaceTint,
      ),

      // Navigation bar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _darkColorScheme.surface,
        indicatorColor: _darkColorScheme.primaryContainer,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: _darkColorScheme.onPrimaryContainer);
          }
          return IconThemeData(color: _darkColorScheme.onSurfaceVariant);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: _darkColorScheme.onSurface,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            );
          }
          return TextStyle(
            color: _darkColorScheme.onSurfaceVariant,
            fontSize: 12,
          );
        }),
      ),

      // Elevated button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return _darkColorScheme.onSurface.withValues(alpha: 31);
            }
            return _darkColorScheme.primary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return _darkColorScheme.onSurface.withValues(alpha: 97);
            }
            return _darkColorScheme.onPrimary;
          }),
          elevation: WidgetStateProperty.all(0),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ),

      // Text button
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return _darkColorScheme.onSurface.withValues(alpha: 97);
            }
            return _darkColorScheme.primary;
          }),
          overlayColor: WidgetStateProperty.all(
            _darkColorScheme.primary.withValues(alpha: 20),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ),

      // Filled button
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return _darkColorScheme.onSurface.withValues(alpha: 31);
            }
            return _darkColorScheme.secondaryContainer;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return _darkColorScheme.onSurface.withValues(alpha: 97);
            }
            return _darkColorScheme.onSecondaryContainer;
          }),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
        ),
      ),

      // FAB theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _darkColorScheme.primaryContainer,
        foregroundColor: _darkColorScheme.onPrimaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Text field styling
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            _darkColorScheme.surfaceContainerHighest.withValues(alpha: 77),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _darkColorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _darkColorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _darkColorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _darkColorScheme.error),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: TextStyle(color: _darkColorScheme.onSurfaceVariant),
        hintStyle: TextStyle(
            color: _darkColorScheme.onSurfaceVariant.withValues(alpha: 153)),
      ),

      // Chip theme
      chipTheme: ChipThemeData(
        backgroundColor: _darkColorScheme.surfaceContainerHighest,
        labelStyle: TextStyle(color: _darkColorScheme.onSurfaceVariant),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),

      // Dialog theme
      dialogTheme: DialogTheme(
        backgroundColor: _darkColorScheme.surface,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),

      // Bottom sheet theme
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: _darkColorScheme.surface,
        modalBackgroundColor: _darkColorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),

      // Divider theme
      dividerTheme: DividerThemeData(
        color: _darkColorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      // Switch theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _darkColorScheme.primary;
          }
          return _darkColorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _darkColorScheme.primaryContainer;
          }
          return _darkColorScheme.surfaceContainerHighest;
        }),
      ),
    );
  }
}
