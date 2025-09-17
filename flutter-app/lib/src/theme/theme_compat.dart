import 'dart:ui';

extension ColorCompat on Color {
  Color withValues({double? alpha}) {
    if (alpha != null) {
      final clamped = alpha.clamp(0.0, 1.0).toDouble();
      return withOpacity(clamped);
    }
    return this;
  }
}
