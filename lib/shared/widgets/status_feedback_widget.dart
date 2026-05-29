import 'package:flutter/material.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';

/// Semantic widget for displaying operation status with visual affordance.
///
/// Provides clear, consistent feedback for:
/// - Loading states (with spinner)
/// - Success states (with checkmark)
/// - Error states (with error icon)
/// - Warning states (with alert icon)
/// - Info states (with info icon)
///
/// Usage:
/// ```dart
/// StatusFeedbackWidget.success(
///   message: 'Transaction saved',
///   onDismiss: () => Navigator.pop(context),
/// )
/// ```
class StatusFeedbackWidget extends StatelessWidget {
  const StatusFeedbackWidget({
    required this.status,
    required this.message,
    this.action,
    this.actionLabel = 'OK',
    this.duration = const Duration(seconds: 3),
    this.onDismiss,
    super.key,
  });

  final StatusType status;
  final String message;
  final VoidCallback? action;
  final String actionLabel;
  final Duration duration;
  final VoidCallback? onDismiss;

  factory StatusFeedbackWidget.success({
    required String message,
    VoidCallback? onDismiss,
    VoidCallback? action,
    String actionLabel = 'OK',
  }) =>
      StatusFeedbackWidget(
        status: StatusType.success,
        message: message,
        onDismiss: onDismiss,
        action: action,
        actionLabel: actionLabel,
      );

  factory StatusFeedbackWidget.error({
    required String message,
    VoidCallback? onDismiss,
    VoidCallback? action,
    String actionLabel = 'Retry',
  }) =>
      StatusFeedbackWidget(
        status: StatusType.error,
        message: message,
        onDismiss: onDismiss,
        action: action,
        actionLabel: actionLabel,
      );

  factory StatusFeedbackWidget.warning({
    required String message,
    VoidCallback? onDismiss,
    VoidCallback? action,
    String actionLabel = 'OK',
  }) =>
      StatusFeedbackWidget(
        status: StatusType.warning,
        message: message,
        onDismiss: onDismiss,
        action: action,
        actionLabel: actionLabel,
      );

  factory StatusFeedbackWidget.loading({
    required String message,
    VoidCallback? onDismiss,
  }) =>
      StatusFeedbackWidget(
        status: StatusType.loading,
        message: message,
        onDismiss: onDismiss,
        duration: const Duration(minutes: 5), // don't auto-dismiss loading
      );

  factory StatusFeedbackWidget.info({
    required String message,
    VoidCallback? onDismiss,
    VoidCallback? action,
    String actionLabel = 'OK',
  }) =>
      StatusFeedbackWidget(
        status: StatusType.info,
        message: message,
        onDismiss: onDismiss,
        action: action,
        actionLabel: actionLabel,
      );

  Color _getBackgroundColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    final cs = Theme.of(context).colorScheme;
    return switch (status) {
      StatusType.success => cs.tertiary.withValues(alpha: isDark ? 0.15 : 0.1),
      StatusType.error   => cs.error.withValues(alpha: isDark ? 0.15 : 0.1),
      StatusType.warning => AppTokens.warningOrange.withValues(alpha: isDark ? 0.15 : 0.1),
      StatusType.loading => cs.primary.withValues(alpha: isDark ? 0.15 : 0.1),
      StatusType.info    => AppTokens.infoBlue.withValues(alpha: isDark ? 0.15 : 0.1),
    };
  }

  Color _getIconColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return switch (status) {
      StatusType.success => cs.tertiary,
      StatusType.error   => cs.error,
      StatusType.warning => AppTokens.warningOrange,
      StatusType.loading => cs.primary,
      StatusType.info    => AppTokens.infoBlue,
    };
  }

  IconData _getIcon() {
    return switch (status) {
      StatusType.success => Icons.check_circle_outline,
      StatusType.error => Icons.error_outline,
      StatusType.warning => Icons.warning_amber_outlined,
      StatusType.loading => Icons.hourglass_empty,
      StatusType.info => Icons.info_outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = _getIconColor(context);
    final backgroundColor = _getBackgroundColor(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.all(Radius.circular(AppTokens.radiusMd)),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space16,
        vertical: AppTokens.space12,
      ),
      child: Row(
        children: [
          if (status == StatusType.loading)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(iconColor),
              ),
            )
          else
            Icon(
              _getIcon(),
              color: iconColor,
              size: 20,
            ),
          const SizedBox(width: AppTokens.space12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          if (action != null)
            Padding(
              padding: const EdgeInsets.only(left: AppTokens.space12),
              child: TextButton(
                onPressed: action,
                child: Text(actionLabel),
              ),
            ),
        ],
      ),
    );
  }
}

enum StatusType {
  success,
  error,
  warning,
  loading,
  info,
}

/// Helper to show status feedback in a SnackBar
class StatusFeedback {
  static void show(
    BuildContext context, {
    required StatusType status,
    required String message,
    VoidCallback? action,
    String actionLabel = 'OK',
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: StatusFeedbackWidget(
          status: status,
          message: message,
          action: action,
          actionLabel: actionLabel,
          duration: duration,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(AppTokens.space16),
      ),
    );
  }

  static void success(
    BuildContext context, {
    required String message,
    VoidCallback? action,
    String actionLabel = 'OK',
  }) =>
      show(
        context,
        status: StatusType.success,
        message: message,
        action: action,
        actionLabel: actionLabel,
        duration: const Duration(seconds: 3),
      );

  static void error(
    BuildContext context, {
    required String message,
    VoidCallback? action,
    String actionLabel = 'Retry',
  }) =>
      show(
        context,
        status: StatusType.error,
        message: message,
        action: action,
        actionLabel: actionLabel,
        duration: const Duration(seconds: 4),
      );

  static void warning(
    BuildContext context, {
    required String message,
    VoidCallback? action,
    String actionLabel = 'OK',
  }) =>
      show(
        context,
        status: StatusType.warning,
        message: message,
        action: action,
        actionLabel: actionLabel,
        duration: const Duration(seconds: 3),
      );

  static void info(
    BuildContext context, {
    required String message,
    VoidCallback? action,
    String actionLabel = 'OK',
  }) =>
      show(
        context,
        status: StatusType.info,
        message: message,
        action: action,
        actionLabel: actionLabel,
        duration: const Duration(seconds: 3),
      );
}
