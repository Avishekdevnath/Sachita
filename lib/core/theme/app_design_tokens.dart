import 'package:flutter/material.dart';

abstract final class AppTokens {
  // ---------------------------------------------------------------------------
  // Brand — Teal (primary)
  // ---------------------------------------------------------------------------
  static const Color tealPrimary = Color(0xFF1F6E6E);
  static const Color tealLight  = Color(0xFF4DA0A0);
  static const Color tealDark   = Color(0xFF154F4F);

  // ---------------------------------------------------------------------------
  // Brand — Gold (accent / border)
  // ---------------------------------------------------------------------------
  static const Color goldPrimary = Color(0xFFD4AF37);
  static const Color goldLight   = Color(0xFFEDD96A);
  static const Color goldDark    = Color(0xFFA88B1E);
  static const Color goldDeep    = Color(0xFF6B5A1E);

  // ---------------------------------------------------------------------------
  // Surfaces
  // ---------------------------------------------------------------------------
  static const Color surfaceLightBase     = Color(0xFFFAFAF8);
  static const Color surfaceLightElevated = Color(0xFFFFFFFF);

  static const Color surfaceDarkBase     = Color(0xFF0A0A0A);
  static const Color surfaceDarkElevated = Color(0xFF121212);
  static const Color surfaceDarkCard     = Color(0xFF1A1A1A);
  static const Color surfaceDarkBorder   = Color(0xFF1E1E1E);

  // ---------------------------------------------------------------------------
  // Semantic — raw values (prefer colorScheme.error / colorScheme.tertiary in widgets)
  // ---------------------------------------------------------------------------
  static const Color semanticRedLight   = Color(0xFF8B0000);
  static const Color semanticRedDark    = Color(0xFFFF6B6B);
  static const Color semanticGreenLight = Color(0xFF166534);
  static const Color semanticGreenDark  = Color(0xFF4ADE80);
  static const Color warningOrange      = Color(0xFFF59E0B);
  static const Color infoBlue           = Color(0xFF3B82F6);

  // ---------------------------------------------------------------------------
  // Gradients
  // ---------------------------------------------------------------------------
  static const LinearGradient tealGradient = LinearGradient(
    colors: [tealDark, tealPrimary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [goldDark, goldPrimary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [surfaceDarkBase, surfaceDarkElevated],
  );

  static const LinearGradient lightBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [surfaceLightBase, surfaceLightElevated],
  );

  // ---------------------------------------------------------------------------
  // Spacing (8-pt grid)
  // ---------------------------------------------------------------------------
  static const double space2  = 2.0;
  static const double space4  = 4.0;
  static const double space6  = 6.0;
  static const double space8  = 8.0;
  static const double space10 = 10.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;
  static const double space56 = 56.0;
  static const double space64 = 64.0;

  // ---------------------------------------------------------------------------
  // Border radii
  // ---------------------------------------------------------------------------
  static const double radiusSm   = 8.0;
  static const double radiusMd   = 12.0;
  static const double radiusLg   = 20.0;
  static const double radiusXl   = 28.0;
  static const double radiusFull = 999.0;

  static const BorderRadius cardRadius  = BorderRadius.all(Radius.circular(radiusLg));
  static const BorderRadius chipRadius  = BorderRadius.all(Radius.circular(radiusFull));
  static const BorderRadius inputRadius = BorderRadius.all(Radius.circular(radiusSm));

  // ---------------------------------------------------------------------------
  // Elevation
  // ---------------------------------------------------------------------------
  static const double elevationNone  = 0.0;
  static const double elevationCard  = 0.0;
  static const double elevationModal = 6.0;

  // ---------------------------------------------------------------------------
  // Glass & Backdrop
  // ---------------------------------------------------------------------------
  static const double glassBlurSigma      = 24.0;
  static const double glassBlurSigmaLight = 16.0;

  // ---------------------------------------------------------------------------
  // PIN
  // ---------------------------------------------------------------------------
  static const double pinDotSize        = 18.0;
  static const double pinDotBorderWidth = 2.0;

  // ---------------------------------------------------------------------------
  // PIN pad
  // ---------------------------------------------------------------------------
  static const double pinPadButtonAspectRatio = 1.8;
  static const double pinPadSpacing           = 8.0;

  // ---------------------------------------------------------------------------
  // Animation durations
  // ---------------------------------------------------------------------------
  static const Duration durationFast   = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Duration durationSlow   = Duration(milliseconds: 400);

  // ---------------------------------------------------------------------------
  // Icon sizes
  // ---------------------------------------------------------------------------
  static const double iconSm     = 18.0;
  static const double iconMd     = 24.0;
  static const double iconLg     = 32.0;
  static const double iconXl     = 48.0;
  static const double iconSplash = 96.0;

  // ---------------------------------------------------------------------------
  // Onboarding
  // ---------------------------------------------------------------------------
  static const double onboardingIconSize = 80.0;

  // ---------------------------------------------------------------------------
  // Opacity
  // ---------------------------------------------------------------------------
  static const double opacityDisabled = 0.5;
  static const double opacityHover    = 0.08;
  static const double opacityActive   = 0.12;
  static const double opacityFocus    = 0.16;
}
