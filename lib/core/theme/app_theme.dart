import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color brand = Color(0xFF1B6FE8);
  static const Color brandStrong = Color(0xFF1557C7);
  static const Color brandSoft = Color(0xFFE7F0FC);
  static const Color brandOnSoft = Color(0xFF1B3A66);
  static const Color success = Color(0xFF00A651);
  static const Color successSoft = Color(0xFFE4F6EB);
  static const Color warning = Color(0xFFE8930C);
  static const Color danger = Color(0xFFDC2626);
  static const Color pageLight = Color(0xFFF3F5F9);
  static const Color cardBorder = Color(0xFFE3E8F0);
  static const Color inputBorder = Color(0xFFD6DCE6);
  static const Color textPrimary = Color(0xFF1E2A38);
  static const Color textSecondary = Color(0xFF67788E);
  static const Color sidebarLight = Color(0xFFFFFFFF);
  static const Color sidebarDark = Color(0xFF0F172A);
  static const Color topBarDark = Color(0xFF0B1B33);
}

abstract final class AppTheme {
  static const double radius = 8;
  static const double gutter = 24;

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.brand,
          brightness: brightness,
        ).copyWith(
          onSurface: isDark ? const Color(0xFFE8EDF5) : AppColors.textPrimary,
          onSurfaceVariant: isDark
              ? const Color(0xFF9BA9BC)
              : AppColors.textSecondary,
          outline: isDark ? const Color(0xFF3B4657) : AppColors.inputBorder,
          outlineVariant: isDark
              ? const Color(0xFF2B3547)
              : AppColors.cardBorder,
          surface: isDark ? const Color(0xFF111A28) : Colors.white,
          surfaceContainerLowest: isDark
              ? const Color(0xFF0D1522)
              : Colors.white,
          surfaceContainerLow: isDark
              ? const Color(0xFF141E2E)
              : const Color(0xFFF8FAFD),
          surfaceContainerHighest: isDark
              ? const Color(0xFF1B2637)
              : const Color(0xFFEDF1F7),
          primary: isDark ? const Color(0xFF5C9BFF) : AppColors.brand,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF0B1120)
          : AppColors.pageLight,
      visualDensity: VisualDensity.comfortable,
      textTheme: _textTheme(scheme),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: isDark ? scheme.surfaceContainerHighest : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: scheme.onSurfaceVariant,
        ),
        hintStyle: TextStyle(
          fontSize: 13.5,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
        ),
        border: _border(scheme.outline),
        enabledBorder: _border(scheme.outline),
        focusedBorder: _border(scheme.primary, width: 1.4),
        errorBorder: _border(scheme.error),
        focusedErrorBorder: _border(scheme.error, width: 1.4),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: isDark ? const Color(0xFF00863F) : AppColors.success,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          textStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: isDark
              ? scheme.surfaceContainerHighest
              : AppColors.brandSoft,
          foregroundColor: isDark
              ? const Color(0xFFCBDCFA)
              : AppColors.brandOnSoft,
          side: const BorderSide(color: Colors.transparent),
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          textStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.comfortable,
          side: WidgetStatePropertyAll(
            BorderSide(color: scheme.outlineVariant),
          ),
          backgroundColor: WidgetStateProperty.resolveWith<Color>(
            (states) => states.contains(WidgetState.selected)
                ? (isDark ? scheme.primaryContainer : AppColors.brandSoft)
                : scheme.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith<Color>(
            (states) => states.contains(WidgetState.selected)
                ? (isDark ? scheme.onPrimaryContainer : AppColors.brandOnSoft)
                : scheme.onSurfaceVariant,
          ),
          textStyle: const WidgetStatePropertyAll<TextStyle>(
            TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        elevation: 6,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll<Color>(
          isDark ? const Color(0xFF16223A) : const Color(0xFFEFF4FC),
        ),
        headingTextStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        dataTextStyle: TextStyle(fontSize: 13.5, color: scheme.onSurface),
        dividerThickness: 1,
        horizontalMargin: 20,
        columnSpacing: 48,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  static OutlineInputBorder _border(Color color, {double width = 1.2}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  static TextTheme _textTheme(ColorScheme scheme) {
    return TextTheme(
      displaySmall: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: scheme.onSurface,
      ),
      headlineSmall: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: scheme.onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      titleSmall: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      bodyLarge: TextStyle(fontSize: 15, height: 1.6, color: scheme.onSurface),
      bodyMedium: TextStyle(fontSize: 14, height: 1.6, color: scheme.onSurface),
      bodySmall: TextStyle(
        fontSize: 12.5,
        height: 1.55,
        color: scheme.onSurfaceVariant,
      ),
      labelLarge: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: scheme.onSurfaceVariant,
      ),
      labelSmall: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}
