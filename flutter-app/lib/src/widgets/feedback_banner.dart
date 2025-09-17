import 'package:flutter/material.dart';


enum FeedbackBannerVariant { info, success, error }

class FeedbackBanner extends StatelessWidget {
  const FeedbackBanner({
    required this.message,
    this.variant = FeedbackBannerVariant.info,
    super.key,
  });

  final String message;
  final FeedbackBannerVariant variant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    late final Color background;
    late final Color iconColor;
    late final IconData icon;

    switch (variant) {
      case FeedbackBannerVariant.success:
        background =
            colorScheme.primaryContainer.withAlpha((0.7 * 255).round());
        iconColor = colorScheme.primary;
        icon = Icons.check_circle_outline;
        break;
      case FeedbackBannerVariant.error:
        background = colorScheme.errorContainer.withAlpha((0.85 * 255).round());
        iconColor = colorScheme.error;
        icon = Icons.error_outline;
        break;
      case FeedbackBannerVariant.info:
        background = colorScheme.surface.withAlpha((0.8 * 255).round());
        iconColor = colorScheme.primary;
        icon = Icons.info_outline;
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
