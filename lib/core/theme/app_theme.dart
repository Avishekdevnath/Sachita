import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sanchita/core/theme/app_design_tokens.dart';
import 'package:sanchita/core/theme/glass_colors.dart';

class AppTheme {
  const AppTheme._();

  static TextTheme _buildTextTheme(TextTheme base) {
    // Playfair Display for display/headline — luxury editorial feel
    // Inter for title/body/label — readability at all sizes
    final playfair = GoogleFonts.playfairDisplayTextTheme(base);
    final inter = GoogleFonts.interTextTheme(base);
    return inter.copyWith(
      displayLarge: playfair.displayLarge,
      displayMedium: playfair.displayMedium,
      displaySmall: playfair.displaySmall,
      headlineLarge: playfair.headlineLarge,
      headlineMedium: playfair.headlineMedium,
      headlineSmall: playfair.headlineSmall,
    );
  }

  static ThemeData _buildTheme(
    ColorScheme colorScheme,
    GlassColors glassColors,
  ) {
    final base = ThemeData(colorScheme: colorScheme, useMaterial3: true);
    final textTheme = _buildTextTheme(base.textTheme);

    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: glassColors.scaffoldStart,
      extensions: <ThemeExtension<dynamic>>[glassColors],
      cardTheme: const CardThemeData(
        elevation: AppTokens.elevationCard,
        shape: RoundedRectangleBorder(borderRadius: AppTokens.cardRadius),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: glassColors.scaffoldStart,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: glassColors.scaffoldEnd,
        indicatorColor: AppTokens.tealPrimary.withValues(alpha: 0.20),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppTokens.radiusMd)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: glassColors.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space16,
          vertical: AppTokens.space12,
        ),
        border: const OutlineInputBorder(
          borderRadius: AppTokens.inputRadius,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppTokens.inputRadius,
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppTokens.inputRadius,
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppTokens.inputRadius,
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppTokens.inputRadius,
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        floatingLabelStyle: TextStyle(color: colorScheme.primary),
      ),
      dividerTheme: const DividerThemeData(space: 1, thickness: 1),
      chipTheme: const ChipThemeData(
        shape: StadiumBorder(),
        padding: EdgeInsets.symmetric(horizontal: AppTokens.space8),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.all(Radius.circular(AppTokens.radiusMd)),
          ),
          overlayColor: AppTokens.goldPrimary.withValues(
            alpha: AppTokens.opacityHover,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.all(Radius.circular(AppTokens.radiusMd)),
          ),
          overlayColor: colorScheme.primary.withValues(
            alpha: AppTokens.opacityHover,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.all(Radius.circular(AppTokens.radiusMd)),
          ),
          overlayColor: colorScheme.primary.withValues(
            alpha: AppTokens.opacityHover,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          overlayColor: colorScheme.primary.withValues(
            alpha: AppTokens.opacityHover,
          ),
        ),
      ),
    );
  }

  static final ThemeData lightTheme = _buildTheme(
    ColorScheme.fromSeed(
      seedColor: AppTokens.tealPrimary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppTokens.tealPrimary,
      secondary: AppTokens.goldPrimary,
      tertiary: AppTokens.semanticGreenLight,
      error: AppTokens.semanticRedLight,
      surface: AppTokens.surfaceLightBase,
      surfaceContainer: AppTokens.surfaceLightElevated,
    ),
    GlassColors.light,
  );

  static final ThemeData darkTheme = _buildTheme(
    ColorScheme.fromSeed(
      seedColor: AppTokens.tealPrimary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppTokens.tealPrimary,
      secondary: AppTokens.goldPrimary,
      tertiary: AppTokens.semanticGreenDark,
      error: AppTokens.semanticRedDark,
      surface: AppTokens.surfaceDarkBase,
      surfaceContainer: AppTokens.surfaceDarkElevated,
    ),
    GlassColors.dark,
  );
}
