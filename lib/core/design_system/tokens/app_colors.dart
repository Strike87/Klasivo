import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO COLOR TOKENS — "Academic Neo-Minimalism" Palette
// Every color in the system is defined here. No hardcoded colors elsewhere.
// Inspired by Notion, Linear, Stripe Dashboard, Duolingo polish, Apple spacing
// ═══════════════════════════════════════════════════════════════════════════════

class AppColors {
  AppColors._();

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
  static const Color errorLight = Color(0xFFFF6B6B);
  static const Color errorDark = Color(0xFFC92A2A);
  static const Color errorSurface = Color(0xFFFFE3E3);

  static const Color warning = Color(0xFFF59F00);
  static const Color warningLight = Color(0xFFFCC419);
  static const Color warningDark = Color(0xFFE67700);
  static const Color warningSurface = Color(0xFFFFF9DB);

  static const Color info = Color(0xFF3B5BDB);
  static const Color infoLight = Color(0xFF5C7CFA);
  static const Color infoDark = Color(0xFF364FC7);
  static const Color infoSurface = Color(0xFFEDF2FF);

  static const Color success = Color(0xFF12B886);
  static const Color successLight = Color(0xFF38D9A9);
  static const Color successDark = Color(0xFF099268);
  static const Color successSurface = Color(0xFFE6FCF5);

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
  static const Color lightSkeleton = Color(0xFFE9ECEF); // shimmer / skeleton

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
  static const Color darkSkeleton = Color(0xFF334155); // shimmer / skeleton

  // ─── Subject Color Palette (for color-coded subjects) ───────────────────
  static const Color subjectMath = Color(0xFF3B5BDB);      // Indigo
  static const Color subjectScience = Color(0xFF12B886);    // Emerald
  static const Color subjectEnglish = Color(0xFF845EF7);    // Purple
  static const Color subjectHistory = Color(0xFFF59F00);    // Amber
  static const Color subjectArabic = Color(0xFFE64980);     // Pink
  static const Color subjectArt = Color(0xFFF76707);        // Orange
  static const Color subjectPhysics = Color(0xFF1098AD);    // Cyan
  static const Color subjectChemistry = Color(0xFFAE3EC9);  // Violet
  static const Color subjectBiology = Color(0xFF2B8A3E);    // Green
  static const Color subjectGeography = Color(0xFFE8590C);  // Deep Orange
  static const Color subjectDefault = Color(0xFF495057);    // Gray

  // ─── Role Color Palette (for role-based avatars/badges) ─────────────────
  static const Color roleOwner = Color(0xFF3B5BDB);       // Indigo
  static const Color roleAdmin = Color(0xFF845EF7);       // Purple
  static const Color roleTeacher = Color(0xFF12B886);     // Emerald
  static const Color roleStudent = Color(0xFFF59F00);     // Amber
  static const Color roleParent = Color(0xFFE64980);      // Pink
  static const Color roleCampusManager = Color(0xFF1098AD); // Cyan
  static const Color roleObserver = Color(0xFF868E96);    // Gray
  static const Color roleSuperAdmin = Color(0xFFE03131);  // Red

  // ─── Priority Colors (for assignments, tasks, tickets) ──────────────────
  static const Color priorityLow = Color(0xFF12B886);
  static const Color priorityMedium = Color(0xFFF59F00);
  static const Color priorityHigh = Color(0xFFE8590C);
  static const Color priorityUrgent = Color(0xFFE03131);

  // ─── Utility ────────────────────────────────────────────────────────────
  static const Color overlay = Color(0x52000000);   // 32% black overlay
  static const Color overlayLight = Color(0x29000000); // 16% black overlay
  static const Color scrim = Color(0x80000000);     // 50% black for modals

  // ─── Helper: Resolve color based on brightness ──────────────────────────
  static Color resolve({
    required Brightness brightness,
    required Color light,
    required Color dark,
  }) {
    return brightness == Brightness.dark ? dark : light;
  }

  // ─── Helper: Get text color by variant ──────────────────────────────────
  static Color textPrimary(Brightness brightness) =>
      resolve(brightness: brightness, light: lightTextPrimary, dark: darkTextPrimary);

  static Color textSecondary(Brightness brightness) =>
      resolve(brightness: brightness, light: lightTextSecondary, dark: darkTextSecondary);

  static Color textTertiary(Brightness brightness) =>
      resolve(brightness: brightness, light: lightTextTertiary, dark: darkTextTertiary);

  static Color textDisabled(Brightness brightness) =>
      resolve(brightness: brightness, light: lightTextDisabled, dark: darkTextDisabled);

  static Color border(Brightness brightness) =>
      resolve(brightness: brightness, light: lightBorder, dark: darkBorder);

  static Color divider(Brightness brightness) =>
      resolve(brightness: brightness, light: lightDivider, dark: darkDivider);

  static Color background(Brightness brightness) =>
      resolve(brightness: brightness, light: lightBackground, dark: darkBackground);

  static Color surface(Brightness brightness) =>
      resolve(brightness: brightness, light: lightSurface, dark: darkSurface);

  static Color card(Brightness brightness) =>
      resolve(brightness: brightness, light: lightCard, dark: darkCard);

  static Color skeleton(Brightness brightness) =>
      resolve(brightness: brightness, light: lightSkeleton, dark: darkSkeleton);

  // ─── Helper: Get subject color by name ──────────────────────────────────
  static Color subjectColor(String subjectName) {
    switch (subjectName.toLowerCase()) {
      case 'math':
      case 'mathematics':
        return subjectMath;
      case 'science':
        return subjectScience;
      case 'english':
        return subjectEnglish;
      case 'history':
        return subjectHistory;
      case 'arabic':
        return subjectArabic;
      case 'art':
        return subjectArt;
      case 'physics':
        return subjectPhysics;
      case 'chemistry':
        return subjectChemistry;
      case 'biology':
        return subjectBiology;
      case 'geography':
        return subjectGeography;
      default:
        return subjectDefault;
    }
  }

  // ─── Helper: Get role color by role name ────────────────────────────────
  static Color roleColor(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return roleOwner;
      case 'admin':
        return roleAdmin;
      case 'teacher':
        return roleTeacher;
      case 'student':
        return roleStudent;
      case 'parent':
        return roleParent;
      case 'campus_manager':
        return roleCampusManager;
      case 'observer':
        return roleObserver;
      case 'super_admin':
        return roleSuperAdmin;
      default:
        return subjectDefault;
    }
  }
}
