import 'package:flutter/material.dart';

/// HarmonyOS Design Language — color tokens
/// Based on HarmonyOS NEXT / OpenHarmony human interface guidelines.
/// https://developer.harmonyos.com/cn/design
class HmosColors {
  HmosColors._();

  // Brand
  static const Color primary = Color(0xFF0A59F7); // Huawei Blue
  static const Color primaryLight = Color(0xFF3D7AFF);
  static const Color primaryDark = Color(0xFF083FB5);
  static const Color primaryContainer = Color(0xFFE8EFFF);

  // Neutrals — HarmonyOS prefers light, airy backgrounds
  static const Color background = Color(0xFFF1F3F5); // page bg
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF5F7FA);
  static const Color surfaceContainer = Color(0xFFEFF2F5);
  static const Color surfaceHigh = Color(0xFFE9EDF1);

  // Text
  static const Color textPrimary = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF5A5A5A);
  static const Color textTertiary = Color(0xFF8E8E93);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Dividers & borders — hairline 0.5px style
  static const Color divider = Color(0xFFE5E5EA);
  static const Color dividerStrong = Color(0xFFD1D1D6);
  static const Color border = Color(0x33808080); // 20%

  // Semantic
  static const Color success = Color(0xFF0EB27F);
  static const Color warning = Color(0xFFFFB020);
  static const Color error = Color(0xFFFA2A2D);
  static const Color errorContainer = Color(0xFFFFE9E9);

  // Map overlay
  static const Color scrim = Color(0x66000000);
  static const Color overlayLight = Color(0xB3FFFFFF); // 70% white for blur

  // Dark theme
  static const Color darkBackground = Color(0xFF0A0A0A);
  static const Color darkSurface = Color(0xFF1C1C1E);
  static const Color darkSurfaceVariant = Color(0xFF2C2C2E);
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFA1A1A6);
  static const Color darkDivider = Color(0xFF38383A);
}
