import 'package:flutter/material.dart';

/// Glass-rendering theme values that differ between dark and light modes.
/// Access via `Theme.of(context).glass.background` (see [GlassTheme]).
class GlassColors extends ThemeExtension<GlassColors> {
  const GlassColors({
    required this.background,
    required this.border,
    required this.highlight,
    required this.scaffoldStart,
    required this.scaffoldEnd,
    required this.goldOnSurface,
  });

  /// Glass card fill color (semi-transparent).
  final Color background;

  /// Glass card edge border color.
  final Color border;

  /// Top-edge shine — brighter border on top simulating light catch.
  final Color highlight;

  /// Background gradient start (top).
  final Color scaffoldStart;

  /// Background gradient end (bottom).
  final Color scaffoldEnd;

  /// Contrast-safe gold for text rendered on the current surface.
  final Color goldOnSurface;

  /// Dark theme glass values — matches brand_new_ui.js dark palette.
  static const GlassColors dark = GlassColors(
    background: Color(0xFF121212),       // cardBg dark
    border: Color(0xFF1E1E1E),           // border dark
    highlight: Color.fromRGBO(255, 255, 255, 0.06),
    scaffoldStart: Color(0xFF0A0A0A),    // bg dark
    scaffoldEnd: Color(0xFF121212),      // cardBg dark
    goldOnSurface: Color(0xFFD4AF37),    // brandGold
  );

  /// Light theme glass values — matches brand_new_ui.js light palette.
  static const GlassColors light = GlassColors(
    background: Color(0xFFFFFFFF),                       // cardBg light
    border: Color.fromRGBO(212, 175, 55, 0.50),          // brandGold/50
    highlight: Color.fromRGBO(212, 175, 55, 0.15),
    scaffoldStart: Color(0xFFFAFAF8),   // bg light
    scaffoldEnd: Color(0xFFFFFFFF),     // cardBg light
    goldOnSurface: Color(0xFF6B5A1E),
  );

  @override
  GlassColors copyWith({
    Color? background,
    Color? border,
    Color? highlight,
    Color? scaffoldStart,
    Color? scaffoldEnd,
    Color? goldOnSurface,
  }) {
    return GlassColors(
      background: background ?? this.background,
      border: border ?? this.border,
      highlight: highlight ?? this.highlight,
      scaffoldStart: scaffoldStart ?? this.scaffoldStart,
      scaffoldEnd: scaffoldEnd ?? this.scaffoldEnd,
      goldOnSurface: goldOnSurface ?? this.goldOnSurface,
    );
  }

  @override
  GlassColors lerp(covariant GlassColors? other, double t) {
    if (other == null) return this;
    return GlassColors(
      background: Color.lerp(background, other.background, t)!,
      border: Color.lerp(border, other.border, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      scaffoldStart: Color.lerp(scaffoldStart, other.scaffoldStart, t)!,
      scaffoldEnd: Color.lerp(scaffoldEnd, other.scaffoldEnd, t)!,
      goldOnSurface: Color.lerp(goldOnSurface, other.goldOnSurface, t)!,
    );
  }
}

/// Convenience accessor for [GlassColors] from any [ThemeData].
extension GlassTheme on ThemeData {
  GlassColors get glass {
    final resolved = extension<GlassColors>();
    if (resolved != null) {
      return resolved;
    }
    return brightness == Brightness.dark
        ? GlassColors.dark
        : GlassColors.light;
  }
}
