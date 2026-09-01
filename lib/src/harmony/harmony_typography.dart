import 'package:flutter/material.dart';
import 'harmony_colors.dart';

/// HarmonyOS Typography — HarmonyOS Sans
/// Fallback chain: HarmonyOS_Sans -> SF Pro -> Roboto
class HmosTypography {
  HmosTypography._();

  static const String family = 'HarmonyOS_Sans';

  // Display — large titles
  static const TextStyle displayLarge = TextStyle(
    fontFamily: family,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.5,
    color: HmosColors.textPrimary,
  );
  static const TextStyle displayMedium = TextStyle(
    fontFamily: family,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: HmosColors.textPrimary,
  );

  // Title
  static const TextStyle titleLarge = TextStyle(
    fontFamily: family,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: HmosColors.textPrimary,
  );
  static const TextStyle titleMedium = TextStyle(
    fontFamily: family,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.35,
    color: HmosColors.textPrimary,
  );
  static const TextStyle titleSmall = TextStyle(
    fontFamily: family,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: HmosColors.textPrimary,
  );

  // Body
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: family,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: HmosColors.textPrimary,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: family,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: HmosColors.textSecondary,
  );
  static const TextStyle bodySmall = TextStyle(
    fontFamily: family,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: HmosColors.textTertiary,
  );

  // Label
  static const TextStyle labelLarge = TextStyle(
    fontFamily: family,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: HmosColors.textPrimary,
  );
  static const TextStyle labelSmall = TextStyle(
    fontFamily: family,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.5,
    color: HmosColors.textTertiary,
  );

  // Dark variants helper
  static TextStyle dark(TextStyle s) => s.copyWith(color: HmosColors.darkTextPrimary);
}
