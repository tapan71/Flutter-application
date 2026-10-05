import 'package:flutter/material.dart';
import 'local_storage_service.dart';

/// ThemeService manages Light, Dark (Default), and System theme modes
/// with local persistent storage.
class ThemeService extends ChangeNotifier {
  ThemeService({ThemeMode? initialMode}) {
    if (initialMode != null) {
      _themeMode = initialMode;
    } else {
      _loadFromStorage();
    }
  }

  // Default theme mode is DARK as requested
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkModeActive {
    if (_themeMode == ThemeMode.dark) return true;
    if (_themeMode == ThemeMode.light) return false;
    // System mode: check platform brightness if available
    return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
  }

  String get themeModeName {
    switch (_themeMode) {
      case ThemeMode.dark:
        return 'Dark Mode (Default)';
      case ThemeMode.light:
        return 'Light Mode';
      case ThemeMode.system:
        return 'System Default';
    }
  }

  void _loadFromStorage() {
    final savedMode = LocalStorageService().themeMode;
    if (savedMode == 'light') {
      _themeMode = ThemeMode.light;
    } else if (savedMode == 'system') {
      _themeMode = ThemeMode.system;
    } else {
      _themeMode = ThemeMode.dark; // Default is Dark
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    String savedStr = 'dark';
    if (mode == ThemeMode.light) {
      savedStr = 'light';
    } else if (mode == ThemeMode.system) {
      savedStr = 'system';
    }

    await LocalStorageService().setThemeMode(savedStr);
  }

  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.dark) {
      await setThemeMode(ThemeMode.light);
    } else {
      await setThemeMode(ThemeMode.dark);
    }
  }

  // ==========================================
  // 🌙 DARK THEME PALETTE & CONFIGURATION (DEFAULT)
  // ==========================================
  static const darkScaffoldBg = Color(0xFF0B0F19); // Ultra-deep Obsidian Slate
  static const darkSurfaceCard = Color(0xFF161F30); // Elevated Slate 900 Card
  static const darkSurfaceCardHigh = Color(0xFF1E293B); // Slate 800 Highlight
  static const darkBorderColor = Color(0xFF2E3D56); // Clean subtle divider
  static const darkTextPrimary = Color(0xFFF8FAFC); // Crisp High-Contrast White
  static const darkTextSecondary = Color(0xFF94A3B8); // Muted Slate Gray
  static const darkPrimaryBlue = Color(0xFF3B82F6); // Electric Royal Blue
  static const darkElectricIndigo = Color(0xFF6366F1); // Radiant Electric Indigo
  static const darkAccentCyan = Color(0xFF06B6D4); // Cyan Glow Accent

  ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkScaffoldBg,
      colorScheme: const ColorScheme.dark(
        primary: darkPrimaryBlue,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFF1E3A8A),
        onPrimaryContainer: Color(0xFFDBEAFE),
        secondary: darkElectricIndigo,
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFF312E81),
        onSecondaryContainer: Color(0xFFE0E7FF),
        tertiary: darkAccentCyan,
        onTertiary: Colors.white,
        surface: darkSurfaceCard,
        onSurface: darkTextPrimary,
        surfaceContainerHighest: darkSurfaceCardHigh,
        outline: darkBorderColor,
        error: Color(0xFFF87171),
        onError: Colors.white,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: darkScaffoldBg,
        foregroundColor: darkTextPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: darkTextPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: darkTextPrimary),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: darkSurfaceCard,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: darkBorderColor, width: 1.2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorderColor, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorderColor, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkPrimaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
        ),
        hintStyle: const TextStyle(color: darkTextSecondary, fontSize: 14),
        labelStyle: const TextStyle(color: darkTextSecondary, fontSize: 14, fontWeight: FontWeight.w500),
        prefixIconColor: darkTextSecondary,
        suffixIconColor: darkTextSecondary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPrimaryBlue,
          foregroundColor: Colors.white,
          elevation: 3,
          shadowColor: darkPrimaryBlue.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: darkElectricIndigo,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: darkElectricIndigo.withValues(alpha: 0.35),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF60A5FA),
          side: const BorderSide(color: darkBorderColor, width: 1.4),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkSurfaceCardHigh,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: darkTextPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: darkBorderColor, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: darkBorderColor, width: 1.2),
        ),
        elevation: 12,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        elevation: 16,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: darkSurfaceCardHigh,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: darkElectricIndigo,
        foregroundColor: Colors.white,
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorderColor,
        thickness: 1,
        space: 1,
      ),
    );
  }

  // ==========================================
  // ☀️ LIGHT THEME PALETTE & CONFIGURATION
  // ==========================================
  static const lightScaffoldBg = Color(0xFFF8FAFC); // Slate Soft Clean Background
  static const lightSurfaceWhite = Colors.white;
  static const lightBorderSlate = Color(0xFFE2E8F0); // Subtle modern divider
  static const lightPrimaryNavy = Color(0xFF0F172A); // Deep Midnight Slate
  static const lightPrimaryBlue = Color(0xFF1E40AF); // Deep Royal Blue
  static const lightElectricIndigo = Color(0xFF2563EB); // Vibrant Electric Indigo
  static const lightAccentCyan = Color(0xFF0EA5E9); // Bright Cyan
  static const lightTextSecondary = Color(0xFF64748B); // Slate 500

  ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightScaffoldBg,
      colorScheme: const ColorScheme.light(
        primary: lightPrimaryBlue,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFDBEAFE),
        onPrimaryContainer: Color(0xFF1E40AF),
        secondary: lightElectricIndigo,
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFFE0E7FF),
        onSecondaryContainer: Color(0xFF312E81),
        tertiary: lightAccentCyan,
        onTertiary: Colors.white,
        surface: lightSurfaceWhite,
        onSurface: lightPrimaryNavy,
        surfaceContainerHighest: Color(0xFFF1F5F9),
        outline: lightBorderSlate,
        error: Color(0xFFEF4444),
        onError: Colors.white,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: lightSurfaceWhite,
        foregroundColor: lightPrimaryNavy,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: lightPrimaryNavy,
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        iconTheme: IconThemeData(color: lightPrimaryNavy),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: lightSurfaceWhite,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: lightBorderSlate, width: 1.2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightScaffoldBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightBorderSlate, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightBorderSlate, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightElectricIndigo, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
        ),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        labelStyle: const TextStyle(color: Color(0xFF475569), fontSize: 14, fontWeight: FontWeight.w500),
        prefixIconColor: const Color(0xFF64748B),
        suffixIconColor: const Color(0xFF64748B),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightPrimaryBlue,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: lightPrimaryBlue.withValues(alpha: 0.35),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: lightElectricIndigo,
          foregroundColor: Colors.white,
          elevation: 1,
          shadowColor: lightElectricIndigo.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightPrimaryBlue,
          side: const BorderSide(color: lightBorderSlate, width: 1.4),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF1F5F9),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: lightBorderSlate, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: lightSurfaceWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: lightBorderSlate, width: 1),
        ),
        elevation: 10,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: lightSurfaceWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        elevation: 12,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: lightPrimaryNavy,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: lightElectricIndigo,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      dividerTheme: const DividerThemeData(
        color: lightBorderSlate,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
