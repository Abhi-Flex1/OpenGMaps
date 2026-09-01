import 'package:flutter/material.dart';
import 'harmony_colors.dart';
import 'harmony_typography.dart';

/// HarmonyOS ThemeData builder — light & dark
/// Follows HMOS NEXT spatial, motion, and depth principles:
/// - Large corner radii (16-24)
/// - Soft shadows, not harsh elevation
/// - Emphasis via typography weight, not color overload
class HmosTheme {
  HmosTheme._();

  static const double radiusSmall = 12;
  static const double radiusMedium = 16;
  static const double radiusLarge = 20;
  static const double radiusXLarge = 24;
  static const double radiusFull = 999;

  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: HmosColors.primary,
      onPrimary: HmosColors.textOnPrimary,
      primaryContainer: HmosColors.primaryContainer,
      surface: HmosColors.surface,
      onSurface: HmosColors.textPrimary,
      // ignore: deprecated_member_use
      background: HmosColors.background,
      // ignore: deprecated_member_use
      onBackground: HmosColors.textPrimary,
      error: HmosColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: HmosColors.background,
      fontFamily: HmosTypography.family,
      // AppBar — HMOS prefers no elevation, large title
      appBarTheme: const AppBarTheme(
        backgroundColor: HmosColors.surface,
        foregroundColor: HmosColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: HmosTypography.titleMedium,
      ),
      // Card — HMOS “Material” is soft, rounded, subtle shadow
      // cardTheme removed for cross-SDK compat (CardTheme vs CardThemeData renamed in Flutter 3.16+)
      // HmosCard uses manual decoration.
      // Bottom sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: HmosColors.surface,
        modalBackgroundColor: HmosColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXLarge)),
        ),
        elevation: 0,
      ),
      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: HmosColors.surfaceVariant,
        selectedColor: HmosColors.primaryContainer,
        labelStyle: HmosTypography.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusFull)),
        side: const BorderSide(color: HmosColors.divider),
      ),
      // Input
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: HmosColors.surfaceVariant,
        hintStyle: HmosTypography.bodyMedium.copyWith(color: HmosColors.textTertiary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: HmosColors.primary, width: 1.5),
        ),
      ),
      // FAB — HMOS uses large rounded rect, not circle
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: HmosColors.surface,
        foregroundColor: HmosColors.primary,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
      // ListTile
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: HmosColors.textSecondary,
      ),
      dividerColor: HmosColors.divider,
      dividerTheme: const DividerThemeData(color: HmosColors.divider, thickness: 0.5, space: 1),
      textTheme: const TextTheme(
        displayLarge: HmosTypography.displayLarge,
        displayMedium: HmosTypography.displayMedium,
        titleLarge: HmosTypography.titleLarge,
        titleMedium: HmosTypography.titleMedium,
        titleSmall: HmosTypography.titleSmall,
        bodyLarge: HmosTypography.bodyLarge,
        bodyMedium: HmosTypography.bodyMedium,
        bodySmall: HmosTypography.bodySmall,
        labelLarge: HmosTypography.labelLarge,
        labelSmall: HmosTypography.labelSmall,
      ),
    );
  }

  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: HmosColors.primaryLight,
      onPrimary: Colors.white,
      surface: HmosColors.darkSurface,
      onSurface: HmosColors.darkTextPrimary,
      // ignore: deprecated_member_use
      background: HmosColors.darkBackground,
      // ignore: deprecated_member_use
      onBackground: HmosColors.darkTextPrimary,
      error: HmosColors.error,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: HmosColors.darkBackground,
      fontFamily: HmosTypography.family,
      appBarTheme: const AppBarTheme(
        backgroundColor: HmosColors.darkSurface,
        foregroundColor: HmosColors.darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: HmosTypography.family,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: HmosColors.darkTextPrimary,
        ),
      ),
      // cardTheme removed for cross-SDK compat
      dividerColor: HmosColors.darkDivider,
      textTheme: TextTheme(
        displayLarge: HmosTypography.displayLarge.copyWith(color: HmosColors.darkTextPrimary),
        titleMedium: HmosTypography.titleMedium.copyWith(color: HmosColors.darkTextPrimary),
        bodyLarge: HmosTypography.bodyLarge.copyWith(color: HmosColors.darkTextPrimary),
        bodyMedium: HmosTypography.bodyMedium.copyWith(color: HmosColors.darkTextSecondary),
      ),
    );
  }
}
