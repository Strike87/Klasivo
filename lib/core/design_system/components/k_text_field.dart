import 'package:flutter/material.dart';
import '../tokens/tokens.dart';
import '../../localization/rtl_support.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// K TEXT FIELD — Text field component for the Klasivo Design System
//
// Features:
// - Variants: outlined, filled, underline
// - Label, hint, helper text, error text
// - Prefix/suffix icons
// - RTL-aware text direction
// - Character counter
// - Validation support
// ═══════════════════════════════════════════════════════════════════════════════

/// Text field visual variant within the Klasivo Design System.
enum KTextFieldVariant {
  /// Outlined border — standard form inputs.
  outlined,

  /// Filled background — compact forms, search fields.
  filled,

  /// Underline only — minimal style, settings, inline edits.
  underline,
}

/// A text field component supporting multiple variants, validation,
/// RTL-aware layout, and character counting.
///
/// Uses [AppColors], [AppSpacing], [AppRadius], [AppTypography] tokens
/// exclusively — no hardcoded values.
///
/// Example:
/// ```dart
/// KTextField(
///   label: 'Student Name',
///   variant: KTextFieldVariant.outlined,
///   prefixIcon: Icons.person_outline,
///   validator: (v) => v!.isEmpty ? 'Required' : null,
/// )
/// ```
class KTextField extends StatelessWidget {
  /// The text field variant determining border style.
  final KTextFieldVariant variant;

  /// Floating label text.
  final String? label;

  /// Hint text shown when the field is empty.
  final String? hint;

  /// Helper text displayed below the field.
  final String? helperText;

  /// Error text displayed below the field (overrides helperText).
  final String? errorText;

  /// Text editing controller.
  final TextEditingController? controller;

  /// Focus node.
  final FocusNode? focusNode;

  /// Keyboard type.
  final TextInputType? keyboardType;

  /// Whether the text should be obscured (passwords).
  final bool obscureText;

  /// Whether the field is enabled.
  final bool enabled;

  /// Whether the field is read-only.
  final bool readOnly;

  /// Maximum number of lines (null for unlimited).
  final int? maxLines;

  /// Minimum number of lines.
  final int minLines;

  /// Maximum character count (enables counter).
  final int? maxLength;

  /// Callback when text changes.
  final ValueChanged<String>? onChanged;

  /// Form field validator.
  final FormFieldValidator<String>? validator;

  /// Callback when field is tapped.
  final VoidCallback? onTap;

  /// Prefix icon.
  final IconData? prefixIcon;

  /// Suffix icon widget.
  final Widget? suffixIcon;

  /// Text input action (e.g., next, done).
  final TextInputAction? textInputAction;

  /// Initial value (used when no controller is provided).
  final String? initialValue;

  /// Autovalidate mode.
  final AutovalidateMode? autovalidateMode;

  /// Whether the field should autofocus.
  final bool autofocus;

  /// Text capitalization.
  final TextCapitalization textCapitalization;

  /// Text align (defaults to start, respects RTL).
  final TextAlign textAlign;

  const KTextField({
    super.key,
    this.variant = KTextFieldVariant.outlined,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.controller,
    this.focusNode,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines = 1,
    this.maxLength,
    this.onChanged,
    this.validator,
    this.onTap,
    this.prefixIcon,
    this.suffixIcon,
    this.textInputAction,
    this.initialValue,
    this.autovalidateMode,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isRtl = context.isRTL;

    final textStyle = AppTypography.bodyMedium.copyWith(
      color: enabled
          ? AppColors.textPrimary(theme.brightness)
          : AppColors.textDisabled(theme.brightness),
    );

    final hintStyle = AppTypography.bodyMedium.copyWith(
      color: AppColors.textTertiary(theme.brightness),
    );

    final labelStyle = AppTypography.labelMedium.copyWith(
      color: errorText != null
          ? AppColors.error
          : AppColors.textSecondary(theme.brightness),
    );

    final helperStyle = AppTypography.bodySmall.copyWith(
      color: errorText != null
          ? AppColors.error
          : AppColors.textTertiary(theme.brightness),
    );

    final counterStyle = AppTypography.caption.copyWith(
      color: AppColors.textTertiary(theme.brightness),
    );

    // Build decoration based on variant
    final decoration = _buildDecoration(
      isDark: isDark,
      isRtl: isRtl,
      textStyle: textStyle,
      hintStyle: hintStyle,
      labelStyle: labelStyle,
      helperStyle: helperStyle,
      counterStyle: counterStyle,
    );

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      obscureText: obscureText,
      enabled: enabled,
      readOnly: readOnly,
      maxLines: obscureText ? 1 : maxLines,
      minLines: minLines,
      maxLength: maxLength,
      onChanged: onChanged,
      validator: validator,
      onTap: onTap,
      textInputAction: textInputAction,
      initialValue: initialValue,
      autovalidateMode: autovalidateMode,
      autofocus: autofocus,
      textCapitalization: textCapitalization,
      textAlign: textAlign,
      textDirection: isRtl ? TextDirection.rtl : null,
      style: textStyle,
      decoration: decoration,
    );
  }

  /// Builds the input decoration based on the current variant.
  InputDecoration _buildDecoration({
    required bool isDark,
    required bool isRtl,
    required TextStyle textStyle,
    required TextStyle hintStyle,
    required TextStyle labelStyle,
    required TextStyle helperStyle,
    required TextStyle counterStyle,
  }) {
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final fillColor = isDark ? AppColors.darkSurface : AppColors.lightBackground;
    final errorBorderSide = const BorderSide(color: AppColors.error, width: 1.5);
    final focusedBorderSide = const BorderSide(color: AppColors.primary, width: 1.5);
    final enabledBorderSide = BorderSide(color: borderColor, width: 1);
    final disabledBorderSide = BorderSide(color: borderColor.withOpacity(0.5), width: 1);

    final prefixIconWidget = prefixIcon != null
        ? Padding(
            padding: EdgeInsetsDirectional.only(
              start: AppSpacing.inputHorizontal - AppSpacing.sm,
              end: AppSpacing.sm,
            ),
            child: Icon(
              prefixIcon,
              size: AppSpacing.iconSizeMd,
              color: errorText != null
                  ? AppColors.error
                  : AppColors.textTertiary(isDark ? Brightness.dark : Brightness.light),
            ),
          )
        : null;

    return switch (variant) {
      KTextFieldVariant.outlined => InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helperText,
          errorText: errorText,
          labelStyle: labelStyle,
          hintStyle: hintStyle,
          helperStyle: helperStyle,
          counterStyle: counterStyle,
          prefixIcon: prefixIconWidget,
          suffixIcon: suffixIcon,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.inputHorizontal,
            vertical: AppSpacing.inputVertical,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: enabledBorderSide,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: enabledBorderSide,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: focusedBorderSide,
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: errorBorderSide,
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: const BorderSide(color: AppColors.errorDark, width: 2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: disabledBorderSide,
          ),
        ),
      KTextFieldVariant.filled => InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helperText,
          errorText: errorText,
          labelStyle: labelStyle,
          hintStyle: hintStyle,
          helperStyle: helperStyle,
          counterStyle: counterStyle,
          prefixIcon: prefixIconWidget,
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: fillColor,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.inputHorizontal,
            vertical: AppSpacing.inputVertical,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: focusedBorderSide,
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: errorBorderSide,
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: const BorderSide(color: AppColors.errorDark, width: 2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input),
            borderSide: BorderSide.none,
          ),
        ),
      KTextFieldVariant.underline => InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helperText,
          errorText: errorText,
          labelStyle: labelStyle,
          hintStyle: hintStyle,
          helperStyle: helperStyle,
          counterStyle: counterStyle,
          prefixIcon: prefixIconWidget,
          suffixIcon: suffixIcon,
          filled: false,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.inputHorizontal,
            vertical: AppSpacing.inputVertical,
          ),
          border: UnderlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            borderSide: enabledBorderSide,
          ),
          enabledBorder: UnderlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            borderSide: enabledBorderSide,
          ),
          focusedBorder: UnderlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            borderSide: focusedBorderSide,
          ),
          errorBorder: UnderlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            borderSide: errorBorderSide,
          ),
          focusedErrorBorder: UnderlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            borderSide: const BorderSide(color: AppColors.errorDark, width: 2),
          ),
          disabledBorder: UnderlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            borderSide: disabledBorderSide,
          ),
        ),
    };
  }
}
