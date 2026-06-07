import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO DESIGN SYSTEM — "Academic Neo-Minimalism"
// Inspired by Notion, Linear, Stripe Dashboard, Duolingo polish, Apple spacing
// ═══════════════════════════════════════════════════════════════════════════════

class KlasivoColors {
  // ─── Primary: Royal Indigo — Trust, Intelligence, Academic ──────────────
  static const Color primary = Color(0xFF3B5BDB);
  static const Color primaryLight = Color(0xFF5C7CFA);
  static const Color primaryDark = Color(0xFF364FC7);
  static const Color primarySurface = Color(0xFFEDF2FF); // light indigo bg

  // ─── Secondary: Emerald — Success, Attendance, Progress ────────────────
  static const Color secondary = Color(0xFF12B886);
  static const Color secondaryLight = Color(0xFF38D9A9);
  static const Color secondaryDark = Color(0xFF099268);
  static const Color secondarySurface = Color(0xFFE6FCF5); // light emerald bg

  // ─── Accent: Amber Gold — Achievements, Scores, Highlights ─────────────
  static const Color accent = Color(0xFFF59F00);
  static const Color accentLight = Color(0xFFFCC419);
  static const Color accentDark = Color(0xFFE67700);
  static const Color accentSurface = Color(0xFFFFF9DB); // light amber bg

  // ─── Semantic Colors ────────────────────────────────────────────────────
  static const Color error = Color(0xFFE03131);
  static const Color errorSurface = Color(0xFFFFE3E3);
  static const Color warning = Color(0xFFF59F00);
  static const Color warningSurface = Color(0xFFFFF9DB);
  static const Color info = Color(0xFF3B5BDB);
  static const Color infoSurface = Color(0xFFEDF2FF);

  // ─── Light Theme Surfaces ───────────────────────────────────────────────
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE9ECEF);
  static const Color lightDivider = Color(0xFFDEE2E6);
  static const Color lightTextPrimary = Color(0xFF212529);
  static const Color lightTextSecondary = Color(0xFF495057);
  static const Color lightTextTertiary = Color(0xFF868E96);
  static const Color lightTextDisabled = Color(0xFFADB5BD);
  static const Color lightIconDefault = Color(0xFF495057);

  // ─── Dark Theme Surfaces ────────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkCard = Color(0xFF1E293B);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkDivider = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);
  static const Color darkTextTertiary = Color(0xFF94A3B8);
  static const Color darkTextDisabled = Color(0xFF64748B);
  static const Color darkIconDefault = Color(0xFFCBD5E1);

  // ─── Subject Color Palette (for color-coded subjects) ───────────────────
  static const Color subjectMath = Color(0xFF3B5BDB);      // Indigo
  static const Color subjectScience = Color(0xFF12B886);    // Emerald
  static const Color subjectEnglish = Color(0xFF845EF7);    // Purple
  static const Color subjectHistory = Color(0xFFF59F00);    // Amber
  static const Color subjectArabic = Color(0xFFE64980);     // Pink
  static const Color subjectArt = Color(0xFFF76707);        // Orange
  static const Color subjectDefault = Color(0xFF495057);    // Gray
}

class KlasivoRadius {
  // ─── Rounded but not childish — Modern and professional ─────────────────
  static const double xs = 6;
  static const double sm = 8;
  static const double md = 14;   // Primary radius — the Klasivo standard
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 100; // For badges, chips, avatars
}

class KlasivoSpacing {
  // ─── Apple-inspired spacing system ──────────────────────────────────────
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double hero = 48;
}

class KlasivoTypography {
  static const String fontFamily = 'PlusJakartaSans';

  // ─── Display — For hero numbers (92% attendance) ────────────────────────
  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: -0.5,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: -0.3,
  );

  // ─── Headlines — Section titles, screen titles ──────────────────────────
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.2,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  // ─── Titles — Card titles, list items ───────────────────────────────────
  static const TextStyle titleLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  // ─── Body — Main reading text ───────────────────────────────────────────
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  // ─── Labels — Buttons, tabs, badges ─────────────────────────────────────
  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.1,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.2,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.3,
  );

  // ─── Caption — Timestamps, metadata ─────────────────────────────────────
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: 0.1,
  );
}

class AppTheme {
  // ═══════════════════════════════════════════════════════════════════════════
  // LIGHT THEME
  // ═══════════════════════════════════════════════════════════════════════════
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: KlasivoTypography.fontFamily,

    // ─── Color Scheme ──────────────────────────────────────────────────────
    colorScheme: const ColorScheme.light(
      primary: KlasivoColors.primary,
      onPrimary: Colors.white,
      primaryContainer: KlasivoColors.primarySurface,
      onPrimaryContainer: KlasivoColors.primaryDark,
      secondary: KlasivoColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: KlasivoColors.secondarySurface,
      onSecondaryContainer: KlasivoColors.secondaryDark,
      tertiary: KlasivoColors.accent,
      onTertiary: Colors.white,
      tertiaryContainer: KlasivoColors.accentSurface,
      onTertiaryContainer: KlasivoColors.accentDark,
      error: KlasivoColors.error,
      onError: Colors.white,
      errorContainer: KlasivoColors.errorSurface,
      onErrorContainer: KlasivoColors.error,
      surface: KlasivoColors.lightSurface,
      onSurface: KlasivoColors.lightTextPrimary,
      surfaceContainerHighest: KlasivoColors.lightBackground,
      outline: KlasivoColors.lightBorder,
      outlineVariant: KlasivoColors.lightDivider,
    ),

    // ─── Scaffold ──────────────────────────────────────────────────────────
    scaffoldBackgroundColor: KlasivoColors.lightBackground,

    // ─── App Bar — Clean, minimal ─────────────────────────────────────────
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0.5,
      backgroundColor: KlasivoColors.lightSurface,
      foregroundColor: KlasivoColors.lightTextPrimary,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: KlasivoTypography.fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: KlasivoColors.lightTextPrimary,
      ),
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),

    // ─── Cards — Subtle elevation, rounded corners ─────────────────────────
    cardTheme: CardTheme(
      elevation: 0,
      color: KlasivoColors.lightCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KlasivoRadius.md),
        side: const BorderSide(color: KlasivoColors.lightBorder, width: 1),
      ),
      margin: const EdgeInsets.symmetric(
        horizontal: KlasivoSpacing.lg,
        vertical: KlasivoSpacing.sm,
      ),
    ),

    // ─── Input Fields — Clean borders, comfortable padding ─────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: KlasivoColors.lightSurface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: KlasivoSpacing.lg,
        vertical: KlasivoSpacing.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KlasivoRadius.md),
        borderSide: const BorderSide(color: KlasivoColors.lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KlasivoRadius.md),
        borderSide: const BorderSide(color: KlasivoColors.lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KlasivoRadius.md),
        borderSide: const BorderSide(color: KlasivoColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KlasivoRadius.md),
        borderSide: const BorderSide(color: KlasivoColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KlasivoRadius.md),
        borderSide: const BorderSide(color: KlasivoColors.error, width: 1.5),
      ),
      hintStyle: const TextStyle(
        color: KlasivoColors.lightTextTertiary,
        fontSize: 14,
      ),
      labelStyle: const TextStyle(
        color: KlasivoColors.lightTextSecondary,
        fontSize: 14,
      ),
      floatingLabelStyle: const TextStyle(
        color: KlasivoColors.primary,
        fontSize: 12,
      ),
    ),

    // ─── Elevated Button — Primary action ──────────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: KlasivoColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: KlasivoSpacing.xxl,
          vertical: KlasivoSpacing.md + 2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KlasivoRadius.md),
        ),
        textStyle: KlasivoTypography.labelLarge.copyWith(color: Colors.white),
      ),
    ),

    // ─── Outlined Button — Secondary action ────────────────────────────────
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: KlasivoColors.primary,
        side: const BorderSide(color: KlasivoColors.primary, width: 1.5),
        padding: const EdgeInsets.symmetric(
          horizontal: KlasivoSpacing.xxl,
          vertical: KlasivoSpacing.md + 2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KlasivoRadius.md),
        ),
        textStyle: KlasivoTypography.labelLarge,
      ),
    ),

    // ─── Text Button — Tertiary action ─────────────────────────────────────
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: KlasivoColors.primary,
        padding: const EdgeInsets.symmetric(
          horizontal: KlasivoSpacing.md,
          vertical: KlasivoSpacing.sm,
        ),
        textStyle: KlasivoTypography.labelMedium,
      ),
    ),

    // ─── Icon Button ───────────────────────────────────────────────────────
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: KlasivoColors.lightIconDefault,
        padding: const EdgeInsets.all(KlasivoSpacing.sm),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KlasivoRadius.sm),
        ),
      ),
    ),

    // ─── Floating Action Button ────────────────────────────────────────────
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: KlasivoColors.primary,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KlasivoRadius.lg),
      ),
      extendedPadding: const EdgeInsets.symmetric(
        horizontal: KlasivoSpacing.xxl,
      ),
    ),

    // ─── Bottom Navigation Bar ─────────────────────────────────────────────
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      backgroundColor: KlasivoColors.lightSurface,
      selectedItemColor: KlasivoColors.primary,
      unselectedItemColor: KlasivoColors.lightTextTertiary,
      selectedLabelStyle: TextStyle(
        fontFamily: KlasivoTypography.fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily: KlasivoTypography.fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
      elevation: 0,
    ),

    // ─── Navigation Bar (Material 3) ───────────────────────────────────────
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: KlasivoColors.lightSurface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: KlasivoColors.primarySurface,
      elevation: 0,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return KlasivoTypography.labelSmall.copyWith(
            color: KlasivoColors.primary,
          );
        }
        return KlasivoTypography.labelSmall.copyWith(
          color: KlasivoColors.lightTextTertiary,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(
            color: KlasivoColors.primary,
            size: 24,
          );
        }
        return const IconThemeData(
          color: KlasivoColors.lightTextTertiary,
          size: 24,
        );
      }),
    ),

    // ─── Chip ──────────────────────────────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: KlasivoColors.lightBackground,
      selectedColor: KlasivoColors.primarySurface,
      labelStyle: KlasivoTypography.labelMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KlasivoRadius.pill),
        side: const BorderSide(color: KlasivoColors.lightBorder),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: KlasivoSpacing.md,
        vertical: KlasivoSpacing.xs,
      ),
    ),

    // ─── Divider ───────────────────────────────────────────────────────────
    dividerTheme: const DividerThemeData(
      color: KlasivoColors.lightDivider,
      thickness: 1,
      space: 1,
    ),

    // ─── Dialog ────────────────────────────────────────────────────────────
    dialogTheme: DialogTheme(
      backgroundColor: KlasivoColors.lightSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KlasivoRadius.lg),
      ),
      titleTextStyle: KlasivoTypography.titleLarge.copyWith(
        color: KlasivoColors.lightTextPrimary,
      ),
    ),

    // ─── Snack Bar ─────────────────────────────────────────────────────────
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: KlasivoColors.lightTextPrimary,
      contentTextStyle: KlasivoTypography.bodyMedium.copyWith(
        color: Colors.white,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KlasivoRadius.md),
      ),
    ),

    // ─── Tab Bar ───────────────────────────────────────────────────────────
    tabBarTheme: TabBarTheme(
      labelColor: KlasivoColors.primary,
      unselectedLabelColor: KlasivoColors.lightTextTertiary,
      labelStyle: KlasivoTypography.labelMedium,
      unselectedLabelStyle: KlasivoTypography.bodySmall,
      indicatorColor: KlasivoColors.primary,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: KlasivoColors.lightDivider,
    ),

    // ─── ListTile ──────────────────────────────────────────────────────────
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(
        horizontal: KlasivoSpacing.lg,
        vertical: KlasivoSpacing.xs,
      ),
      titleTextStyle: KlasivoTypography.titleMedium,
      subtitleTextStyle: KlasivoTypography.bodySmall,
    ),

    // ─── Switch ────────────────────────────────────────────────────────────
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return KlasivoColors.primary;
        }
        return KlasivoColors.lightTextDisabled;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return KlasivoColors.primaryLight;
        }
        return KlasivoColors.lightBorder;
      }),
    ),

    // ─── Progress Indicator ────────────────────────────────────────────────
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: KlasivoColors.primary,
      linearTrackColor: KlasivoColors.lightBorder,
    ),

    // ─── Badge ─────────────────────────────────────────────────────────────
    badgeTheme: const BadgeThemeData(
      backgroundColor: KlasivoColors.error,
      textColor: Colors.white,
    ),

    // ─── Text Theme ────────────────────────────────────────────────────────
    textTheme: const TextTheme(
      displayLarge: KlasivoTypography.displayLarge,
      displayMedium: KlasivoTypography.displayMedium,
      headlineLarge: KlasivoTypography.headlineLarge,
      headlineMedium: KlasivoTypography.headlineMedium,
      headlineSmall: KlasivoTypography.headlineSmall,
      titleLarge: KlasivoTypography.titleLarge,
      titleMedium: KlasivoTypography.titleMedium,
      titleSmall: KlasivoTypography.titleSmall,
      bodyLarge: KlasivoTypography.bodyLarge,
      bodyMedium: KlasivoTypography.bodyMedium,
      bodySmall: KlasivoTypography.bodySmall,
      labelLarge: KlasivoTypography.labelLarge,
      labelMedium: KlasivoTypography.labelMedium,
      labelSmall: KlasivoTypography.labelSmall,
    ),
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // DARK THEME
  // ═══════════════════════════════════════════════════════════════════════════
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: KlasivoTypography.fontFamily,

    colorScheme: const ColorScheme.dark(
      primary: KlasivoColors.primaryLight,
      onPrimary: Colors.white,
      primaryContainer: KlasivoColors.primaryDark,
      onPrimaryContainer: KlasivoColors.primarySurface,
      secondary: KlasivoColors.secondaryLight,
      onSecondary: Colors.white,
      secondaryContainer: KlasivoColors.secondaryDark,
      onSecondaryContainer: KlasivoColors.secondarySurface,
      tertiary: KlasivoColors.accentLight,
      onTertiary: Colors.white,
      tertiaryContainer: KlasivoColors.accentDark,
      onTertiaryContainer: KlasivoColors.accentSurface,
      error: Color(0xFFFF6B6B),
      onError: Colors.white,
      errorContainer: Color(0xFF4A1515),
      onErrorContainer: Color(0xFFFF6B6B),
      surface: KlasivoColors.darkSurface,
      onSurface: KlasivoColors.darkTextPrimary,
      surfaceContainerHighest: KlasivoColors.darkBackground,
      outline: KlasivoColors.darkBorder,
      outlineVariant: KlasivoColors.darkDivider,
    ),

    scaffoldBackgroundColor: KlasivoColors.darkBackground,

    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0.5,
      backgroundColor: KlasivoColors.darkSurface,
      foregroundColor: KlasivoColors.darkTextPrimary,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: KlasivoTypography.fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: KlasivoColors.darkTextPrimary,
      ),
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),

    cardTheme: CardTheme(
      elevation: 0,
      color: KlasivoColors.darkCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KlasivoRadius.md),
        side: const BorderSide(color: KlasivoColors.darkBorder, width: 1),
      ),
      margin: const EdgeInsets.symmetric(
        horizontal: KlasivoSpacing.lg,
        vertical: KlasivoSpacing.sm,
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: KlasivoColors.darkSurface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: KlasivoSpacing.lg,
        vertical: KlasivoSpacing.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KlasivoRadius.md),
        borderSide: const BorderSide(color: KlasivoColors.darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KlasivoRadius.md),
        borderSide: const BorderSide(color: KlasivoColors.darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KlasivoRadius.md),
        borderSide: const BorderSide(color: KlasivoColors.primaryLight, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KlasivoRadius.md),
        borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KlasivoRadius.md),
        borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1.5),
      ),
      hintStyle: const TextStyle(
        color: KlasivoColors.darkTextTertiary,
        fontSize: 14,
      ),
      labelStyle: const TextStyle(
        color: KlasivoColors.darkTextSecondary,
        fontSize: 14,
      ),
      floatingLabelStyle: const TextStyle(
        color: KlasivoColors.primaryLight,
        fontSize: 12,
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: KlasivoColors.primaryLight,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: KlasivoSpacing.xxl,
          vertical: KlasivoSpacing.md + 2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KlasivoRadius.md),
        ),
        textStyle: KlasivoTypography.labelLarge.copyWith(color: Colors.white),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: KlasivoColors.primaryLight,
        side: const BorderSide(color: KlasivoColors.primaryLight, width: 1.5),
        padding: const EdgeInsets.symmetric(
          horizontal: KlasivoSpacing.xxl,
          vertical: KlasivoSpacing.md + 2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KlasivoRadius.md),
        ),
        textStyle: KlasivoTypography.labelLarge,
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: KlasivoColors.primaryLight,
        padding: const EdgeInsets.symmetric(
          horizontal: KlasivoSpacing.md,
          vertical: KlasivoSpacing.sm,
        ),
        textStyle: KlasivoTypography.labelMedium,
      ),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      backgroundColor: KlasivoColors.darkSurface,
      selectedItemColor: KlasivoColors.primaryLight,
      unselectedItemColor: KlasivoColors.darkTextTertiary,
      selectedLabelStyle: TextStyle(
        fontFamily: KlasivoTypography.fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily: KlasivoTypography.fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
      elevation: 0,
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: KlasivoColors.darkSurface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: KlasivoColors.primaryDark,
      elevation: 0,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return KlasivoTypography.labelSmall.copyWith(
            color: KlasivoColors.primaryLight,
          );
        }
        return KlasivoTypography.labelSmall.copyWith(
          color: KlasivoColors.darkTextTertiary,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(
            color: KlasivoColors.primaryLight,
            size: 24,
          );
        }
        return const IconThemeData(
          color: KlasivoColors.darkTextTertiary,
          size: 24,
        );
      }),
    ),

    dividerTheme: const DividerThemeData(
      color: KlasivoColors.darkDivider,
      thickness: 1,
      space: 1,
    ),

    dialogTheme: DialogTheme(
      backgroundColor: KlasivoColors.darkSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KlasivoRadius.lg),
      ),
      titleTextStyle: KlasivoTypography.titleLarge.copyWith(
        color: KlasivoColors.darkTextPrimary,
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: KlasivoColors.darkSurface,
      contentTextStyle: KlasivoTypography.bodyMedium.copyWith(
        color: KlasivoColors.darkTextPrimary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KlasivoRadius.md),
      ),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return KlasivoColors.primaryLight;
        }
        return KlasivoColors.darkTextDisabled;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return KlasivoColors.primary;
        }
        return KlasivoColors.darkBorder;
      }),
    ),

    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(
        horizontal: KlasivoSpacing.lg,
        vertical: KlasivoSpacing.xs,
      ),
      titleTextStyle: KlasivoTypography.titleMedium,
      subtitleTextStyle: KlasivoTypography.bodySmall,
    ),

    textTheme: const TextTheme(
      displayLarge: KlasivoTypography.displayLarge,
      displayMedium: KlasivoTypography.displayMedium,
      headlineLarge: KlasivoTypography.headlineLarge,
      headlineMedium: KlasivoTypography.headlineMedium,
      headlineSmall: KlasivoTypography.headlineSmall,
      titleLarge: KlasivoTypography.titleLarge,
      titleMedium: KlasivoTypography.titleMedium,
      titleSmall: KlasivoTypography.titleSmall,
      bodyLarge: KlasivoTypography.bodyLarge,
      bodyMedium: KlasivoTypography.bodyMedium,
      bodySmall: KlasivoTypography.bodySmall,
      labelLarge: KlasivoTypography.labelLarge,
      labelMedium: KlasivoTypography.labelMedium,
      labelSmall: KlasivoTypography.labelSmall,
    ),
  );
}
