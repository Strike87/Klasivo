import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens/tokens.dart';

import '../tokens/tokens.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO DESIGN SYSTEM — "Academic Neo-Minimalism"
// Inspired by Notion, Linear, Stripe Dashboard, Duolingo polish, Apple spacing
//
// Token classes have been extracted to lib/core/tokens/ for modularity.
// Legacy aliases below ensure backward compatibility with existing imports.
// ═══════════════════════════════════════════════════════════════════════════════
//
// Token classes have been extracted to lib/core/tokens/ for modularity.
// Legacy aliases below ensure backward compatibility with existing imports.

// ─── Legacy Aliases (backward compatibility) ──────────────────────────────
// Existing code imports KlasivoColors, KlasivoRadius, etc. from theme.dart.
// These aliases ensure zero breakage across all 30+ files.

typedef KlasivoColors = AppColors;
typedef KlasivoRadius = AppRadius;
typedef KlasivoSpacing = AppSpacing;
typedef KlasivoTypography = AppTypography;

class AppTheme {
  AppTheme._();

  // ═══════════════════════════════════════════════════════════════════════════
  // LIGHT THEME
  // ═══════════════════════════════════════════════════════════════════════════
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: AppTypography.fontFamily,

    // ─── Color Scheme ──────────────────────────────────────────────────────
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primarySurface,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.secondarySurface,
      onSecondaryContainer: AppColors.secondaryDark,
      tertiary: AppColors.accent,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.accentSurface,
      onTertiaryContainer: AppColors.accentDark,
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: AppColors.errorSurface,
      onErrorContainer: AppColors.error,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightTextPrimary,
      surfaceContainerHighest: AppColors.lightBackground,
      outline: AppColors.lightBorder,
      outlineVariant: AppColors.lightDivider,
    ),

    // ─── Scaffold ──────────────────────────────────────────────────────────
    scaffoldBackgroundColor: AppColors.lightBackground,

    // ─── App Bar — Clean, minimal ─────────────────────────────────────────
    appBarTheme: const AppBarTheme(
      elevation: AppElevation.appBarResting,
      scrolledUnderElevation: AppElevation.appBarScrolled,
      backgroundColor: AppColors.lightSurface,
      foregroundColor: AppColors.lightTextPrimary,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.lightTextPrimary,
      ),
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),

    // ─── Cards — Subtle elevation, rounded corners ─────────────────────────
    cardTheme: CardThemeData(
      elevation: AppElevation.none,
      color: AppColors.lightCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.lightBorder, width: 1),
      ),
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
    ),

    // ─── Input Fields — Clean borders, comfortable padding ─────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lightSurface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.inputHorizontal,
        vertical: AppSpacing.inputVertical,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      hintStyle: const TextStyle(
        color: AppColors.lightTextTertiary,
        fontSize: 14,
      ),
      labelStyle: const TextStyle(
        color: AppColors.lightTextSecondary,
        fontSize: 14,
      ),
      floatingLabelStyle: const TextStyle(
        color: AppColors.primary,
        fontSize: 12,
      ),
    ),

    // ─── Elevated Button — Primary action ──────────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: AppElevation.none,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.buttonHorizontal,
          vertical: AppSpacing.buttonVertical,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        textStyle: AppTypography.labelLarge.copyWith(color: Colors.white),
      ),
    ),

    // ─── Outlined Button — Secondary action ────────────────────────────────
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.buttonHorizontal,
          vertical: AppSpacing.buttonVertical,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        textStyle: AppTypography.labelLarge,
      ),
    ),

    // ─── Text Button — Tertiary action ─────────────────────────────────────
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        textStyle: AppTypography.labelMedium,
      ),
    ),

    // ─── Icon Button ───────────────────────────────────────────────────────
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.lightIconDefault,
        padding: const EdgeInsets.all(AppSpacing.sm),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.iconButton),
        ),
      ),
    ),

    // ─── Floating Action Button ────────────────────────────────────────────
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: AppElevation.md,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.fab),
      ),
      extendedPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
      ),
    ),

    // ─── Bottom Navigation Bar ─────────────────────────────────────────────
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppColors.lightSurface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.lightTextTertiary,
      selectedLabelStyle: TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
      elevation: AppElevation.none,
    ),

    // ─── Navigation Bar (Material 3) ───────────────────────────────────────
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.lightSurface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.primarySurface,
      elevation: AppElevation.none,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppTypography.labelSmall.copyWith(
            color: AppColors.primary,
          );
        }
        return AppTypography.labelSmall.copyWith(
          color: AppColors.lightTextTertiary,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(
            color: AppColors.primary,
            size: 24,
          );
        }
        return const IconThemeData(
          color: AppColors.lightTextTertiary,
          size: 24,
        );
      }),
    ),

    // ─── Chip ──────────────────────────────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.lightBackground,
      selectedColor: AppColors.primarySurface,
      labelStyle: AppTypography.labelMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.badge),
        side: const BorderSide(color: AppColors.lightBorder),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.chipHorizontal,
        vertical: AppSpacing.chipVertical,
      ),
    ),

    // ─── Divider ───────────────────────────────────────────────────────────
    dividerTheme: const DividerThemeData(
      color: AppColors.lightDivider,
      thickness: 1,
      space: 1,
    ),

    // ─── Dialog ────────────────────────────────────────────────────────────
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.lightSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.dialog),
      ),
      titleTextStyle: AppTypography.titleLarge.copyWith(
        color: AppColors.lightTextPrimary,
      ),
    ),

    // ─── Snack Bar ─────────────────────────────────────────────────────────
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.lightTextPrimary,
      contentTextStyle: AppTypography.bodyMedium.copyWith(
        color: Colors.white,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.snackbar),
      ),
    ),

    // ─── Tab Bar ───────────────────────────────────────────────────────────
    tabBarTheme: TabBarThemeData(
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.lightTextTertiary,
      labelStyle: AppTypography.labelMedium,
      unselectedLabelStyle: AppTypography.bodySmall,
      indicatorColor: AppColors.primary,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: AppColors.lightDivider,
    ),

    // ─── ListTile ──────────────────────────────────────────────────────────
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppSpacing.listItemHorizontal,
        vertical: AppSpacing.listItemVertical,
      ),
      titleTextStyle: AppTypography.titleMedium,
      subtitleTextStyle: AppTypography.bodySmall,
    ),

    // ─── Switch ────────────────────────────────────────────────────────────
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primary;
        }
        return AppColors.lightTextDisabled;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primaryLight;
        }
        return AppColors.lightBorder;
      }),
    ),

    // ─── Progress Indicator ────────────────────────────────────────────────
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.lightBorder,
    ),

    // ─── Badge ─────────────────────────────────────────────────────────────
    badgeTheme: const BadgeThemeData(
      backgroundColor: AppColors.error,
      textColor: Colors.white,
    ),

    // ─── Bottom Sheet ──────────────────────────────────────────────────────
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.lightSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
    ),

    // ─── Text Theme ────────────────────────────────────────────────────────
    textTheme: AppTypography.textTheme,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // DARK THEME
  // ═══════════════════════════════════════════════════════════════════════════
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: AppTypography.fontFamily,

    colorScheme: const ColorScheme.dark(
      primary: AppColors.primaryLight,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryDark,
      onPrimaryContainer: AppColors.primarySurface,
      secondary: AppColors.secondaryLight,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.secondaryDark,
      onSecondaryContainer: AppColors.secondarySurface,
      tertiary: AppColors.accentLight,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.accentDark,
      onTertiaryContainer: AppColors.accentSurface,
      error: AppColors.errorLight,
      onError: Colors.white,
      errorContainer: Color(0xFF4A1515),
      onErrorContainer: AppColors.errorLight,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
      surfaceContainerHighest: AppColors.darkBackground,
      outline: AppColors.darkBorder,
      outlineVariant: AppColors.darkDivider,
    ),

    scaffoldBackgroundColor: AppColors.darkBackground,

    appBarTheme: const AppBarTheme(
      elevation: AppElevation.appBarResting,
      scrolledUnderElevation: AppElevation.appBarScrolled,
      backgroundColor: AppColors.darkSurface,
      foregroundColor: AppColors.darkTextPrimary,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.darkTextPrimary,
      ),
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),

    cardTheme: CardThemeData(
      elevation: AppElevation.none,
      color: AppColors.darkCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.darkBorder, width: 1),
      ),
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.inputHorizontal,
        vertical: AppSpacing.inputVertical,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.errorLight),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.errorLight, width: 1.5),
      ),
      hintStyle: const TextStyle(
        color: AppColors.darkTextTertiary,
        fontSize: 14,
      ),
      labelStyle: const TextStyle(
        color: AppColors.darkTextSecondary,
        fontSize: 14,
      ),
      floatingLabelStyle: const TextStyle(
        color: AppColors.primaryLight,
        fontSize: 12,
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        elevation: AppElevation.none,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.buttonHorizontal,
          vertical: AppSpacing.buttonVertical,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        textStyle: AppTypography.labelLarge.copyWith(color: Colors.white),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryLight,
        side: const BorderSide(color: AppColors.primaryLight, width: 1.5),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.buttonHorizontal,
          vertical: AppSpacing.buttonVertical,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        textStyle: AppTypography.labelLarge,
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryLight,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        textStyle: AppTypography.labelMedium,
      ),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      backgroundColor: AppColors.darkSurface,
      selectedItemColor: AppColors.primaryLight,
      unselectedItemColor: AppColors.darkTextTertiary,
      selectedLabelStyle: TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
      elevation: AppElevation.none,
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.darkSurface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.primaryDark,
      elevation: AppElevation.none,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppTypography.labelSmall.copyWith(
            color: AppColors.primaryLight,
          );
        }
        return AppTypography.labelSmall.copyWith(
          color: AppColors.darkTextTertiary,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(
            color: AppColors.primaryLight,
            size: 24,
          );
        }
        return const IconThemeData(
          color: AppColors.darkTextTertiary,
          size: 24,
        );
      }),
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.darkDivider,
      thickness: 1,
      space: 1,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.darkSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.dialog),
      ),
      titleTextStyle: AppTypography.titleLarge.copyWith(
        color: AppColors.darkTextPrimary,
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.darkSurface,
      contentTextStyle: AppTypography.bodyMedium.copyWith(
        color: AppColors.darkTextPrimary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.snackbar),
      ),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primaryLight;
        }
        return AppColors.darkTextDisabled;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primary;
        }
        return AppColors.darkBorder;
      }),
    ),

    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppSpacing.listItemHorizontal,
        vertical: AppSpacing.listItemVertical,
      ),
      titleTextStyle: AppTypography.titleMedium,
      subtitleTextStyle: AppTypography.bodySmall,
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.darkSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.bottomSheet),
        ),
      ),
    ),

    textTheme: AppTypography.textTheme,
  );
}
