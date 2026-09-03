import 'package:flutter/material.dart';

/// Official Google Maps Design Tokens & Material You Palette
class GoogleMapsColors {
  GoogleMapsColors._();

  // Primary Brand Colors
  static const Color googleBlue = Color(0xFF1A73E8);
  static const Color googleBlueDark = Color(0xFF8AB4F8);
  static const Color googleRed = Color(0xFFEA4335);
  static const Color googleRedDark = Color(0xFFF28B82);
  static const Color googleYellow = Color(0xFFFBBC05);
  static const Color googleYellowDark = Color(0xFFFDD663);
  static const Color googleGreen = Color(0xFF34A853);
  static const Color googleGreenDark = Color(0xFF81C995);

  // Surface & Neutral (Light)
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F3F4);
  static const Color surfaceContainer = Color(0xFFF8F9FA);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFE8F0FE);
  static const Color onPrimaryContainer = Color(0xFF1967D2);
  static const Color textPrimary = Color(0xFF202124);
  static const Color textSecondary = Color(0xFF5F6368);
  static const Color textTertiary = Color(0xFF80868B);
  static const Color divider = Color(0xFFDADCE0);
  static const Color searchBarBg = Color(0xFFFFFFFF);
  static const Color chipBackground = Color(0xFFFFFFFF);
  static const Color chipBorder = Color(0xFFDADCE0);

  // Surface & Neutral (Dark)
  static const Color darkBackground = Color(0xFF1F1F1F);
  static const Color darkSurface = Color(0xFF242526);
  static const Color darkSurfaceVariant = Color(0xFF303134);
  static const Color darkSurfaceContainer = Color(0xFF3C4043);
  static const Color darkPrimaryContainer = Color(0xFF1A3B66);
  static const Color darkOnPrimaryContainer = Color(0xFFD2E3FC);
  static const Color darkTextPrimary = Color(0xFFE8EAED);
  static const Color darkTextSecondary = Color(0xFF9AA0A6);
  static const Color darkTextTertiary = Color(0xFF5F6368);
  static const Color darkDivider = Color(0xFF3C4043);
  static const Color darkSearchBarBg = Color(0xFF303134);
  static const Color darkChipBackground = Color(0xFF303134);
  static const Color darkChipBorder = Color(0xFF5F6368);

  // Functional Map Colors
  static const Color routePolyline = Color(0xFF4285F4);
  static const Color routePolylineCasing = Color(0xFF1967D2);
  static const Color trafficGreen = Color(0xFF0F9D58);
  static const Color trafficOrange = Color(0xFFFF9800);
  static const Color trafficRed = Color(0xFFDB4437);
  static const Color trafficDarkRed = Color(0xFF8B0000);
  static const Color locationBlue = Color(0xFF1A73E8);
  static const Color locationAccuracyRing = Color(0x331A73E8);
}

/// Google Sans Typography Hierarchy
class GoogleSansTypography {
  GoogleSansTypography._();

  static const String fontFamily = 'Google Sans';

  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: GoogleMapsColors.textPrimary,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: GoogleMapsColors.textPrimary,
  );

  static const TextStyle titleLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
    color: GoogleMapsColors.textPrimary,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    color: GoogleMapsColors.textPrimary,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    color: GoogleMapsColors.textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: GoogleMapsColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: GoogleMapsColors.textSecondary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: GoogleMapsColors.textTertiary,
  );

  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    color: GoogleMapsColors.textPrimary,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    color: GoogleMapsColors.textSecondary,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
    color: GoogleMapsColors.textTertiary,
  );
}

/// Official Google Maps Theme Configuration
class GoogleMapsTheme {
  GoogleMapsTheme._();

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: GoogleSansTypography.fontFamily,
      brightness: Brightness.light,
      scaffoldBackgroundColor: GoogleMapsColors.surface,
      colorScheme: const ColorScheme.light(
        primary: GoogleMapsColors.googleBlue,
        onPrimary: Colors.white,
        primaryContainer: GoogleMapsColors.primaryContainer,
        onPrimaryContainer: GoogleMapsColors.onPrimaryContainer,
        secondary: GoogleMapsColors.googleGreen,
        onSecondary: Colors.white,
        error: GoogleMapsColors.googleRed,
        onError: Colors.white,
        surface: GoogleMapsColors.surface,
        onSurface: GoogleMapsColors.textPrimary,
        surfaceContainerHighest: GoogleMapsColors.surfaceVariant,
        outline: GoogleMapsColors.divider,
      ),
      textTheme: const TextTheme(
        displayLarge: GoogleSansTypography.displayLarge,
        displayMedium: GoogleSansTypography.displayMedium,
        titleLarge: GoogleSansTypography.titleLarge,
        titleMedium: GoogleSansTypography.titleMedium,
        titleSmall: GoogleSansTypography.titleSmall,
        bodyLarge: GoogleSansTypography.bodyLarge,
        bodyMedium: GoogleSansTypography.bodyMedium,
        bodySmall: GoogleSansTypography.bodySmall,
        labelLarge: GoogleSansTypography.labelLarge,
        labelMedium: GoogleSansTypography.labelMedium,
        labelSmall: GoogleSansTypography.labelSmall,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: GoogleMapsColors.googleBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: GoogleSansTypography.labelLarge.copyWith(color: Colors.white),
        ),
      ),
      cardTheme: const CardTheme(
        color: GoogleMapsColors.surface,
        elevation: 2,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: GoogleSansTypography.fontFamily,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: GoogleMapsColors.darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: GoogleMapsColors.googleBlueDark,
        onPrimary: Color(0xFF041E49),
        primaryContainer: GoogleMapsColors.darkPrimaryContainer,
        onPrimaryContainer: GoogleMapsColors.darkOnPrimaryContainer,
        secondary: GoogleMapsColors.googleGreenDark,
        onSecondary: Color(0xFF003915),
        error: GoogleMapsColors.googleRedDark,
        onError: Color(0xFF601410),
        surface: GoogleMapsColors.darkSurface,
        onSurface: GoogleMapsColors.darkTextPrimary,
        surfaceContainerHighest: GoogleMapsColors.darkSurfaceVariant,
        outline: GoogleMapsColors.darkDivider,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleSansTypography.displayLarge.copyWith(color: GoogleMapsColors.darkTextPrimary),
        displayMedium: GoogleSansTypography.displayMedium.copyWith(color: GoogleMapsColors.darkTextPrimary),
        titleLarge: GoogleSansTypography.titleLarge.copyWith(color: GoogleMapsColors.darkTextPrimary),
        titleMedium: GoogleSansTypography.titleMedium.copyWith(color: GoogleMapsColors.darkTextPrimary),
        titleSmall: GoogleSansTypography.titleSmall.copyWith(color: GoogleMapsColors.darkTextPrimary),
        bodyLarge: GoogleSansTypography.bodyLarge.copyWith(color: GoogleMapsColors.darkTextPrimary),
        bodyMedium: GoogleSansTypography.bodyMedium.copyWith(color: GoogleMapsColors.darkTextSecondary),
        bodySmall: GoogleSansTypography.bodySmall.copyWith(color: GoogleMapsColors.darkTextTertiary),
        labelLarge: GoogleSansTypography.labelLarge.copyWith(color: GoogleMapsColors.darkTextPrimary),
        labelMedium: GoogleSansTypography.labelMedium.copyWith(color: GoogleMapsColors.darkTextSecondary),
        labelSmall: GoogleSansTypography.labelSmall.copyWith(color: GoogleMapsColors.darkTextTertiary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: GoogleMapsColors.googleBlueDark,
          foregroundColor: const Color(0xFF041E49),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: GoogleSansTypography.labelLarge.copyWith(color: const Color(0xFF041E49)),
        ),
      ),
      cardTheme: const CardTheme(
        color: GoogleMapsColors.darkSurface,
        elevation: 2,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
    );
  }
}
