import 'package:flutter/material.dart';

class PlanGenieTheme {
  const PlanGenieTheme._();

  static ThemeData light() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
      useMaterial3: true,
      textTheme: _typography,
    );
  }

  static const TextTheme _typography = TextTheme(
    headlineMedium: TextStyle(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    ),
    bodyLarge: TextStyle(
      height: 1.5,
    ),
  );
}
