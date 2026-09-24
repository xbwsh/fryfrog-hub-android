import 'package:flutter/material.dart';

/// Design tokens matching fryfrog-hub-apple Theme.swift.
class AppColors {
  const AppColors._();

  /// Soft charcoal background in dark mode (not pure black).
  static const Color backgroundDark = Color(0xFF1C1F26);
  static const Color surfaceDark = Color(0xFF292B33);
  static const Color backgroundLight = Color(0xFFF2F2F7);
  static const Color surfaceLight = Color(0xFFEDEDF2);

  static Color background(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? backgroundDark
          : backgroundLight;

  static Color surface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? surfaceDark
          : surfaceLight;

  static const Color accent = Color(0xFF0A84FF);
  static const Color danger = Color(0xFFFF453A);
  static const Color success = Color(0xFF30D158);
  static const Color warning = Color(0xFFFF9F0A);
}
