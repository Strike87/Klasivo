import 'package:flutter/material.dart';
import '../core/tokens/tokens.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO TEXT FIELD — Unified text input with consistent styling
// Supports prefix/suffix icons, helpers, counters, and validation states.
// ═══════════════════════════════════════════════════════════════════════════════

class KlasivoTextField extends StatelessWidget {
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final int maxLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final VoidCallback? onTap;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputAction? textInputAction;
  final String? initialValue;
  final AutovalidateMode? autovalidateMode;

  /// When true, renders a borderless text field suitable for AppBar titles
  /// or inline search fields. Removes all borders, fill color, and padding
  /// for a clean, embedded appearance.
  final bool borderless;

  /// When true, the field auto-focuses when first rendered.
  /// Useful for search fields in AppBars.
  final bool autofocus;

  const KlasivoTextField({
    Key? key,
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
    this.maxLength,
    this.onChanged,
    this.validator,
    this.onTap,
    this.prefixIcon,
    this.suffixIcon,
    this.textInputAction,
    this.initialValue,
    this.autovalidateMode,
    this.borderless = false,
    this.autofocus = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      obscureText: obscureText,
      enabled: enabled,
      readOnly: readOnly,
      maxLines: maxLines,
      maxLength: maxLength,
      onChanged: onChanged,
      validator: validator,
      onTap: onTap,
      textInputAction: textInputAction,
      initialValue: initialValue,
      autovalidateMode: autovalidateMode,
      autofocus: autofocus,
      style: AppTypography.bodyMedium.copyWith(
        color: enabled
            ? AppColors.textPrimary(Theme.of(context).brightness)
            : AppColors.textDisabled(Theme.of(context).brightness),
      ),
      decoration: borderless
          ? InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              hintStyle: AppTypography.bodyMedium.copyWith(
                color: AppColors.textTertiary(Theme.of(context).brightness),
              ),
              counterText: '',
            )
          : InputDecoration(
              labelText: label,
              hintText: hint,
              helperText: helperText,
              errorText: errorText,
              prefixIcon: prefixIcon != null
                  ? Icon(prefixIcon, size: AppSpacing.iconSizeMd)
                  : null,
              suffixIcon: suffixIcon,
              counterText: '', // Hide counter by default
            ),
    );
  }
}
