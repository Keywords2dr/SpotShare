import 'package:flutter/material.dart';

class CompactUiTheme {
  static const Color defaultSeedColor = Color(0xFF006D5B);

  static ThemeData light({Color seedColor = defaultSeedColor}) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
      ),
    );
    return applyTo(base);
  }

  static ThemeData dark({Color seedColor = defaultSeedColor}) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
      ),
    );
    return applyTo(base);
  }

  static ThemeData applyTo(ThemeData base) {
    final colors = base.colorScheme;
    final compactText = _buildCompactTextTheme(base.textTheme, colors);

    return base.copyWith(
      visualDensity: VisualDensity.compact,
      textTheme: compactText,
      appBarTheme: base.appBarTheme.copyWith(
        toolbarHeight: 48,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        titleTextStyle: compactText.titleMedium?.copyWith(
          fontSize: 16.5,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.25,
          color: colors.onSurface,
        ),
        iconTheme: IconThemeData(
          size: 21,
          color: colors.onSurface,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        labelStyle: compactText.labelMedium?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 58,
        elevation: 0,
        backgroundColor: colors.surface,
        indicatorColor: colors.primaryContainer.withValues(alpha: 0.85),
        indicatorShape: const StadiumBorder(),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 20,
            color: isSelected
                ? colors.onPrimaryContainer
                : colors.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 10.5,
            height: 1.15,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? colors.primary : colors.onSurfaceVariant,
          );
        }),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        hintStyle: compactText.bodyMedium?.copyWith(
          fontSize: 13,
          color: colors.onSurfaceVariant,
        ),
      ),
      snackBarTheme: base.snackBarTheme.copyWith(
        behavior: SnackBarBehavior.floating,
        contentTextStyle: compactText.bodySmall?.copyWith(
          fontSize: 12.5,
          color: colors.onInverseSurface,
        ),
      ),
    );
  }

  static TextTheme _buildCompactTextTheme(
    TextTheme base,
    ColorScheme colors,
  ) {
    return base.copyWith(
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.35,
        height: 1.22,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
        height: 1.24,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        height: 1.25,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.28,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.28,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 14,
        height: 1.4,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 13,
        height: 1.38,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 11.5,
        height: 1.35,
        color: colors.onSurfaceVariant,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 10.5,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}