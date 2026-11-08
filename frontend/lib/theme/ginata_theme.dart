import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class GinataColors {
  // Brand Forest Green & Sage (Apple Elegance meets Kenyan Estate Warmth)
  static const Color primary = Color(0xFF003329);
  static const Color primaryContainer = Color(0xFF134237);
  static const Color primaryLight = Color(0xFF2E6356);
  static const Color secondary = Color(0xFF466557);
  static const Color secondaryContainer = Color(0xFFD8EFE4);
  static const Color onSecondaryContainer = Color(0xFF2C4E40);

  // Apple-style Canvas & Card Surfaces
  static const Color background = Color(0xFFF7F8FA); // Crisp clean Apple light background
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSubdued = Color(0xFFF2F4F7);
  static const Color surfaceContainer = Color(0xFFEAECF0);
  static const Color surfaceContainerLow = Color(0xFFF8F9FB);
  static const Color surfaceContainerHigh = Color(0xFFE4E7EC);
  static const Color outline = Color(0xFF98A2B3);
  static const Color outlineVariant = Color(0xFFE4E7EC);

  // Modern Typography (Deep Slate & Charcoal)
  static const Color textPrimary = Color(0xFF101828);
  static const Color textSecondary = Color(0xFF475467);
  static const Color textMuted = Color(0xFF667085);

  // Semantic Accents
  static const Color warningOchre = Color(0xFFB54708);
  static const Color warningContainer = Color(0xFFFEF0C7);
  static const Color alertTerracotta = Color(0xFFD92D20);
  static const Color errorContainer = Color(0xFFFEE4E2);
  static const Color brassGold = Color(0xFFB89758);
  static const Color successSage = Color(0xFF079455);
  static const Color successContainer = Color(0xFFD1FADF);
}

class GinataFormatters {
  static final NumberFormat _kesFormat = NumberFormat.currency(
    symbol: 'KES ',
    decimalDigits: 0,
  );

  static final NumberFormat _kesFormatDecimals = NumberFormat.currency(
    symbol: 'KES ',
    decimalDigits: 2,
  );

  static String formatKES(dynamic amount, {bool showDecimals = false}) {
    if (amount == null) return 'KES 0';
    final numVal = num.tryParse(amount.toString()) ?? 0;
    if (showDecimals) {
      return _kesFormatDecimals.format(numVal);
    }
    return _kesFormat.format(numVal);
  }

  static String formatDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('MMM d, yyyy').format(date);
  }

  static String formatShortDate(DateTime? date) {
    if (date == null) return '';
    return DateFormat('MMM d').format(date);
  }
}

ThemeData buildGinataTheme() {
  final base = ThemeData.light();
  return base.copyWith(
    splashFactory: InkSparkle.splashFactory,
    scaffoldBackgroundColor: GinataColors.background,
    primaryColor: GinataColors.primary,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: GinataColors.primary,
      onPrimary: Colors.white,
      primaryContainer: GinataColors.primaryContainer,
      onPrimaryContainer: Colors.white,
      secondary: GinataColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: GinataColors.secondaryContainer,
      onSecondaryContainer: GinataColors.onSecondaryContainer,
      error: GinataColors.alertTerracotta,
      onError: Colors.white,
      surface: GinataColors.surface,
      onSurface: GinataColors.textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: GinataColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: GinataColors.textPrimary),
      titleTextStyle: TextStyle(
        color: GinataColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
    ),
    cardTheme: CardThemeData(
      color: GinataColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0x15101828), width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0x20101828)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0x20101828)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: GinataColors.primary, width: 1.5),
      ),
      hintStyle: const TextStyle(color: GinataColors.textMuted, fontSize: 13),
      labelStyle: const TextStyle(color: GinataColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: GinataColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: -0.2),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: GinataColors.primary,
        side: const BorderSide(color: Color(0x28101828), width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
