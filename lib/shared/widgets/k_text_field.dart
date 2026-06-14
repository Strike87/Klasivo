/// Klasivo v2.0 - KTextField component
/// 
/// Enhanced text field component based on klasivo_text_field.dart.
/// Supports validation, prefixes/suffixes, RTL layout,
/// and multiple input types.
library;

import "package:flutter/material.dart";

/// Klasivo text field component.
class KTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? errorMessage;
  final bool obscureText;
  final bool isEnabled;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final Widget? prefixIcon;
  final Widget? suffixIcon;

  const KTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.errorMessage,
    this.obscureText = false,
    this.isEnabled = true,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
    this.validator,
    this.prefixIcon,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      enabled: isEnabled,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorMessage,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
    );
  }
}
