import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Academic Neo-Minimalism design system for Klasivo.
///
/// Color palette:
/// - Primary: Royal Indigo #3B5BDB
/// - Secondary: Amber Gold #F59F00
/// - Tertiary: Emerald #12B886
/// - Surface: Clean whites and subtle grays
/// - Font: Plus Jakarta Sans
/// - Border radius: 14

class AppTheme {
  AppTheme._();

  // ── Color Constants ──
  static const Color royalIndigo = Color(0xFF3B5BDB);
  static const Color royalIndigoLight = Color(0xFF5C7CFA);
  static const Color royalIndigoDark = Color(0xFF364FC7);

  static const Color amberGold = Color(0xFFF59F00);
  static const Color amberGoldLight = Color(0xFFFCC419);
  static const Color amberGoldDark = Color(0xFFF08C00);

  static const Color emerald = Color(0xFF12B886);
  static const Color emeraldLight = Color(0xFF38D9A9);
  static const Color emeraldDark = Color(0xFF099268);

  static const Color surfaceLight = Color(0xFFFAFBFC);
  static const Color surfaceDark = Color(0xFF1A1B1E);

  static const Color errorLight = Color(0xFFE03131);
  static const Color errorDark = Color(0xFFFF6B6B);

  // ── Design Tokens ──
  static const double radiusSm = 8.0;
  static const double radiusMd = 14.0;
  static const double radiusLg = 20.0;
  static const double radiusXl = 28.0;

  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;

  // ── Light Theme ──
  static ThemeData lightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: royalIndigo,
      primary: royalIndigo,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFEDF2FF),
      onPrimaryContainer: Color(0xFF1B2A5E),
      secondary: amberGold,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFFFF9DB),
      onSecondaryContainer: Color(0xFF664D00),
      tertiary: emerald,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFE6FCF5),
      onTertiaryContainer: Color(0xFF004D40),
      error: errorLight,
      onError: Colors.white,
      surface: surfaceLight,
      onSurface: Color(0xFF1A1B1E),
      surfaceContainerHighest: Colors.white,
      outline: Color(0xFFD0D7DE),
      outlineVariant: Color(0xFFE8ECF0),
    );

    return _buildTheme(colorScheme, Brightness.light);
  }

  // ── Dark Theme ──
  static ThemeData darkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: royalIndigo,
      brightness: Brightness.dark,
      primary: royalIndigoLight,
      onPrimary: Colors.white,
      primaryContainer: royalIndigoDark,
      onPrimaryContainer: Color(0xFFD0DFFF),
      secondary: amberGoldLight,
      onSecondary: Color(0xFF3D2E00),
      secondaryContainer: amberGoldDark,
      onSecondaryContainer: Color(0xFFFFE066),
      tertiary: emeraldLight,
      onTertiary: Color(0xFF003D2E),
      tertiaryContainer: emeraldDark,
      onTertiaryContainer: Color(0xFF63E6BE),
      error: errorDark,
      onError: Color(0xFF4C0000),
      surface: surfaceDark,
      onSurface: Color(0xFFE8ECF0),
      surfaceContainerHighest: Color(0xFF25262B),
      outline: Color(0xFF3D3F45),
      outlineVariant: Color(0xFF2C2E33),
    );

    return _buildTheme(colorScheme, Brightness.dark);
  }

  // ── Shared Theme Builder ──
  static ThemeData _buildTheme(ColorScheme colorScheme, Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(
      isLight ? ThemeData.light().textTheme : ThemeData.dark().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,
      textTheme: textTheme,

      // ── AppBar ──
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
      ),

      // ── Cards ──
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        color: colorScheme.surface,
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      ),

      // ── Elevated Button ──
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),

      // ── Filled Button ──
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),

      // ── Outlined Button ──
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          side: BorderSide(color: colorScheme.outline),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),

      // ── Text Button ──
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Input Decoration ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight
            ? const Color(0xFFF5F7FA)
            : const Color(0xFF2C2E33),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(
            color: colorScheme.error,
            width: 1.5,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(
            color: colorScheme.error,
            width: 2,
          ),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant.withOpacity(0.6),
        ),
        prefixIconColor: colorScheme.onSurfaceVariant,
        suffixIconColor: colorScheme.onSurfaceVariant,
      ),

      // ── Bottom Navigation ──
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant.withOpacity(0.6),
        selectedLabelStyle: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        elevation: 2,
      ),

      // ── Navigation Bar (Material 3) ──
      navigationBarTheme: NavigationBarThemeData(
        elevation: 2,
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 64,
      ),

      // ── Dialog ──
      dialogTheme: DialogThemeData(
        elevation: 4,
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
      ),

      // ── Snack Bar ──
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),

      // ── Chip ──
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        labelStyle: textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),

      // ── Tab Bar ──
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),

      // ── Divider ──
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      // ── Floating Action Button ──
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
    );
  }
}
