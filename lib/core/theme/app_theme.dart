import 'package:flutter/material.dart';

abstract final class AppColors {
  static const seed = Color(0xFF087F70);
  static const navy = Color(0xFF0B3C5D);
  static const teal = Color(0xFF087F70);
  static const green = Color(0xFF2E8B57);
  static const mint = Color(0xFFA8D9C5);
  static const gold = Color(0xFFF4B942);
  static const surface = Colors.white;
  static const sidebar = Color(0xFF0A344D);
  static const sidebarSelected = Color(0xFF12816F);
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

ThemeData buildAppTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.seed,
        brightness: Brightness.light,
      ).copyWith(
        primary: AppColors.teal,
        onPrimary: Colors.white,
        secondary: AppColors.gold,
        onSecondary: AppColors.navy,
        tertiary: AppColors.navy,
        onTertiary: Colors.white,
        surface: AppColors.surface,
        surfaceContainerLowest: Colors.white,
        primaryContainer: const Color(0xFFDDF1E8),
        onPrimaryContainer: AppColors.navy,
        secondaryContainer: const Color(0xFFFFF1CC),
        onSecondaryContainer: const Color(0xFF493500),
        outlineVariant: const Color(0xFFCDDED6),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.surface,
    visualDensity: VisualDensity.comfortable,
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontWeight: FontWeight.w600),
      titleLarge: TextStyle(fontWeight: FontWeight.w600),
      titleMedium: TextStyle(fontWeight: FontWeight.w600),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      margin: EdgeInsets.zero,
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
  );
}
