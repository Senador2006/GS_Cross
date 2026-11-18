import 'package:material_ui/material_ui.dart';

import 'app_tokens.dart';

/// Construção centralizada dos temas (claro, escuro e alto contraste).
class AppTheme {
  AppTheme._();

  static ThemeData light({bool highContrast = false}) => _build(
    highContrast
        ? const ColorScheme.highContrastLight(
            primary: AppColors.brandDark,
            secondary: Color(0xFF5C3B00),
            error: Color(0xFF8C1D18),
          )
        : ColorScheme.fromSeed(
            seedColor: AppColors.brand,
            primary: AppColors.brand,
            secondary: const Color(0xFF8A5A00),
            error: AppColors.critical,
          ),
    highContrast: highContrast,
  );

  static ThemeData dark({bool highContrast = false}) => _build(
    highContrast
        ? const ColorScheme.highContrastDark(
            primary: Color(0xFFB2F1EE),
            secondary: Color(0xFFFFE08A),
            error: Color(0xFFFFDAD6),
          )
        : ColorScheme.fromSeed(
            seedColor: AppColors.brand,
            brightness: Brightness.dark,
            primary: AppColors.brandLight,
            error: AppColors.criticalOnDark,
          ),
    highContrast: highContrast,
  );

  static ThemeData _build(ColorScheme scheme, {required bool highContrast}) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: scheme.brightness,
    );
    final text = base.textTheme.copyWith(
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
    final borderSide = BorderSide(
      color: highContrast ? scheme.onSurface : scheme.outlineVariant,
      width: highContrast ? 2 : 1,
    );
    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 2,
        titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          side: borderSide,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: borderSide,
        ),
        errorMaxLines: 3,
        helperMaxLines: 3,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(AppSpacing.minTouch, AppSpacing.minTouch),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(AppSpacing.minTouch, AppSpacing.minTouch),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}
