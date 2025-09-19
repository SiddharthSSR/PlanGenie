import 'package:flutter/material.dart';

class PlanGenieTheme {
  const PlanGenieTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2563EB),
      brightness: Brightness.light,
    ).copyWith(
      secondary: const Color(0xFF1E3A8A),
      secondaryContainer: const Color(0xFFDBEAFE),
      tertiary: const Color(0xFF1E40AF),
      tertiaryContainer: const Color(0xFFDBEAFE),
      surfaceTint: Colors.transparent,
      surface: Colors.white,
    );

    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.white,
      fontFamily: 'Modellica',
    );

    const palette = PlanGeniePalette(
      tintedSurface: Color(0xFFE6F0FF),
      tintedSurfaceBorder: Color(0xFFA3C8FF),
      primaryIndicator: Color(0xFF2563EB),
      onPrimaryIndicator: Colors.white,
      backgroundStart: Color(0xFFDBEAFE),
      backgroundEnd: Color(0xFFF5F9FF),
    );

    final textTheme = base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.15,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w400,
        height: 1.55,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );

    final outline = scheme.outlineVariant;
    final primary = scheme.primary;

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      datePickerTheme: base.datePickerTheme.copyWith(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: scheme.primary,
        headerForegroundColor: Colors.white,
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.onSurface.withValues(alpha: 0.35);
          }
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return scheme.onSurface;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary;
          }
          if (states.contains(WidgetState.hovered)) {
            return scheme.primary.withValues(alpha: 0.12);
          }
          return Colors.transparent;
        }),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: outline.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: outline.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.error),
        ),
        filled: true,
        fillColor: palette.tintedSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: outline.withValues(alpha: 0.6)),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primary
              : palette.tintedSurfaceBorder,
        ),
        checkColor: const WidgetStatePropertyAll<Color>(Colors.white),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          textStyle: textTheme.titleMedium,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[palette],
    );
  }
}

class PlanGeniePalette extends ThemeExtension<PlanGeniePalette> {
  const PlanGeniePalette({
    required this.tintedSurface,
    required this.tintedSurfaceBorder,
    required this.primaryIndicator,
    required this.onPrimaryIndicator,
    required this.backgroundStart,
    required this.backgroundEnd,
  });

  final Color tintedSurface;
  final Color tintedSurfaceBorder;
  final Color primaryIndicator;
  final Color onPrimaryIndicator;
  final Color backgroundStart;
  final Color backgroundEnd;

  @override
  PlanGeniePalette copyWith({
    Color? tintedSurface,
    Color? tintedSurfaceBorder,
    Color? primaryIndicator,
    Color? onPrimaryIndicator,
    Color? backgroundStart,
    Color? backgroundEnd,
  }) {
    return PlanGeniePalette(
      tintedSurface: tintedSurface ?? this.tintedSurface,
      tintedSurfaceBorder: tintedSurfaceBorder ?? this.tintedSurfaceBorder,
      primaryIndicator: primaryIndicator ?? this.primaryIndicator,
      onPrimaryIndicator: onPrimaryIndicator ?? this.onPrimaryIndicator,
      backgroundStart: backgroundStart ?? this.backgroundStart,
      backgroundEnd: backgroundEnd ?? this.backgroundEnd,
    );
  }

  @override
  PlanGeniePalette lerp(ThemeExtension<PlanGeniePalette>? other, double t) {
    if (other is! PlanGeniePalette) {
      return this;
    }
    return PlanGeniePalette(
      tintedSurface:
          Color.lerp(tintedSurface, other.tintedSurface, t) ?? tintedSurface,
      tintedSurfaceBorder:
          Color.lerp(tintedSurfaceBorder, other.tintedSurfaceBorder, t) ??
              tintedSurfaceBorder,
      primaryIndicator:
          Color.lerp(primaryIndicator, other.primaryIndicator, t) ??
              primaryIndicator,
      onPrimaryIndicator:
          Color.lerp(onPrimaryIndicator, other.onPrimaryIndicator, t) ??
              onPrimaryIndicator,
      backgroundStart: Color.lerp(backgroundStart, other.backgroundStart, t) ??
          backgroundStart,
      backgroundEnd:
          Color.lerp(backgroundEnd, other.backgroundEnd, t) ?? backgroundEnd,
    );
  }
}
