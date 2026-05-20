import 'package:flutter/material.dart';

class AppTheme {
  // Brand Color
  static const Color seedColor = Color(0xFFE94E1B);

  // Light Scheme Colors from design.md
  static const Color lightPrimary = Color(0xFF8F4C37);
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightPrimaryContainer = Color(0xFFFFDBD1);
  static const Color lightOnPrimaryContainer = Color(0xFF723522);
  static const Color lightSecondary = Color(0xFF77574E);
  static const Color lightSecondaryContainer = Color(0xFFFFDBD1);
  static const Color lightOnSecondary = Color(0xFFFFFFFF);
  static const Color lightOnSecondaryContainer = Color(0xFF5D4037);
  static const Color lightTertiary = Color(0xFF6B5D2F);
  static const Color lightTertiaryContainer = Color(0xFFF5E1A7);
  static const Color lightOnTertiary = Color(0xFFFFFFFF);
  static const Color lightOnTertiaryContainer = Color(0xFF524619);
  static const Color lightBackground = Color(0xFFFFF8F6);
  static const Color lightOnBackground = Color(0xFF231917);
  static const Color lightSurface = Color(0xFFFFF8F6);
  static const Color lightOnSurface = Color(0xFF231917);
  static const Color lightSurfaceVariant = Color(0xFFF5DED7);
  static const Color lightOnSurfaceVariant = Color(0xFF53433F);
  static const Color lightOutline = Color(0xFF85736E);
  static const Color lightOutlineVariant = Color(0xFFD8C2BC);
  static const Color lightError = Color(0xFFBA1A1A);
  static const Color lightOnError = Color(0xFFFFFFFF);
  static const Color lightErrorContainer = Color(0xFFFFDAD6);
  static const Color lightOnErrorContainer = Color(0xFF93000A);

  // Dark Scheme Colors from design.md
  static const Color darkPrimary = Color(0xFFFFB59F);
  static const Color darkOnPrimary = Color(0xFF561F0F);
  static const Color darkPrimaryContainer = Color(0xFF723522);
  static const Color darkOnPrimaryContainer = Color(0xFFFFDBD1);
  static const Color darkSecondary = Color(0xFFE7BDB2);
  static const Color darkSecondaryContainer = Color(0xFF5D4037);
  static const Color darkOnSecondary = Color(0xFF442A22);
  static const Color darkOnSecondaryContainer = Color(0xFFFFDBD1);
  static const Color darkTertiary = Color(0xFFD8C58D);
  static const Color darkTertiaryContainer = Color(0xFF524619);
  static const Color darkOnTertiary = Color(0xFF3A2F05);
  static const Color darkOnTertiaryContainer = Color(0xFFF5E1A7);
  static const Color darkBackground = Color(0xFF1A110F);
  static const Color darkOnBackground = Color(0xFFF1DFDA);
  static const Color darkSurface = Color(0xFF1A110F);
  static const Color darkOnSurface = Color(0xFFF1DFDA);
  static const Color darkSurfaceVariant = Color(0xFF53433F);
  static const Color darkOnSurfaceVariant = Color(0xFFD8C2BC);
  static const Color darkOutline = Color(0xFFA08C87);
  static const Color darkOutlineVariant = Color(0xFF53433F);
  static const Color darkError = Color(0xFFFFB4AB);
  static const Color darkOnError = Color(0xFF690005);
  static const Color darkErrorContainer = Color(0xFF93000A);
  static const Color darkOnErrorContainer = Color(0xFFFFDAD6);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: lightPrimary,
        onPrimary: lightOnPrimary,
        primaryContainer: lightPrimaryContainer,
        onPrimaryContainer: lightOnPrimaryContainer,
        secondary: lightSecondary,
        onSecondary: lightOnSecondary,
        secondaryContainer: lightSecondaryContainer,
        onSecondaryContainer: lightOnSecondaryContainer,
        tertiary: lightTertiary,
        onTertiary: lightOnTertiary,
        tertiaryContainer: lightTertiaryContainer,
        onTertiaryContainer: lightOnTertiaryContainer,
        error: lightError,
        onError: lightOnError,
        errorContainer: lightErrorContainer,
        onErrorContainer: lightOnErrorContainer,
        background: lightBackground,
        onBackground: lightOnBackground,
        surface: lightSurface,
        onSurface: lightOnSurface,
        surfaceVariant: lightSurfaceVariant,
        onSurfaceVariant: lightOnSurfaceVariant,
        outline: lightOutline,
        outlineVariant: lightOutlineVariant,
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightOutlineVariant, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightSurface,
        foregroundColor: lightOnSurface,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightOutlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightPrimary, width: 2),
        ),
      ),
      fontFamily: 'Outfit',
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: darkPrimary,
        onPrimary: darkOnPrimary,
        primaryContainer: darkPrimaryContainer,
        onPrimaryContainer: darkOnPrimaryContainer,
        secondary: darkSecondary,
        onSecondary: darkOnSecondary,
        secondaryContainer: darkSecondaryContainer,
        onSecondaryContainer: darkOnSecondaryContainer,
        tertiary: darkTertiary,
        onTertiary: darkOnTertiary,
        tertiaryContainer: darkTertiaryContainer,
        onTertiaryContainer: darkOnTertiaryContainer,
        error: darkError,
        onError: darkOnError,
        errorContainer: darkErrorContainer,
        onErrorContainer: darkOnErrorContainer,
        background: darkBackground,
        onBackground: darkOnBackground,
        surface: darkSurface,
        onSurface: darkOnSurface,
        surfaceVariant: darkSurfaceVariant,
        onSurfaceVariant: darkOnSurfaceVariant,
        outline: darkOutline,
        outlineVariant: darkOutlineVariant,
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkOutlineVariant, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkOnSurface,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkOutline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkOutlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkPrimary, width: 2),
        ),
      ),
      fontFamily: 'Outfit',
    );
  }
}
