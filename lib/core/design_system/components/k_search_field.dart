import 'dart:async';
import 'package:flutter/material.dart';
import '../tokens/tokens.dart';
import '../../localization/rtl_support.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// K SEARCH FIELD — Debounced search field for the Klasivo Design System
//
// Features:
// - Debounced onChanged callback
// - Clear button
// - Search icon
// - RTL-aware text direction
// - Loading indicator
// ═══════════════════════════════════════════════════════════════════════════════

/// A search field with debounced input, clear button, loading indicator,
/// and RTL-aware layout.
///
/// Uses [AppColors], [AppSpacing], [AppRadius], [AppTypography], and
/// [AppDurations] tokens exclusively — no hardcoded values.
///
/// Example:
/// ```dart
/// KSearchField(
///   hintText: 'Search students...',
///   debounceDuration: AppDurations.searchDebounce,
///   onChanged: (query) => performSearch(query),
/// )
/// ```
class KSearchField extends StatefulWidget {
  /// Hint text displayed when the field is empty.
  final String? hintText;

  /// Callback fired after the debounce duration elapses with no new input.
  final ValueChanged<String>? onChanged;

  /// Debounce duration (defaults to [AppDurations.searchDebounce]).
  final Duration debounceDuration;

  /// Optional controller for the text field.
  final TextEditingController? controller;

  /// Whether the search is currently in a loading state.
  final bool loading;

  /// Whether the field is enabled.
  final bool enabled;

  /// Focus node for the text field.
  final FocusNode? focusNode;

  /// Whether to autofocus the field when first rendered.
  final bool autofocus;

  /// Callback when the clear button is pressed (after the field is cleared).
  final VoidCallback? onCleared;

  /// Callback when the submit action is triggered.
  final ValueChanged<String>? onSubmitted;

  const KSearchField({
    super.key,
    this.hintText,
    this.onChanged,
    this.debounceDuration = AppDurations.searchDebounce,
    this.controller,
    this.loading = false,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    this.onCleared,
    this.onSubmitted,
  });

  @override
  State<KSearchField> createState() => _KSearchFieldState();
}

class _KSearchFieldState extends State<KSearchField> {
  late TextEditingController _controller;
  Timer? _debounceTimer;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _hasText = _controller.text.isNotEmpty;
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }

    if (widget.onChanged != null) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(widget.debounceDuration, () {
        widget.onChanged!(_controller.text);
      });
    }
  }

  void _clearField() {
    _controller.clear();
    _debounceTimer?.cancel();
    widget.onCleared?.call();
    if (widget.onChanged != null) {
      widget.onChanged!('');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isRtl = context.isRTL;

    return TextField(
      controller: _controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      textInputAction: TextInputAction.search,
      onSubmitted: widget.onSubmitted,
      style: AppTypography.bodyMedium.copyWith(
        color: widget.enabled
            ? AppColors.textPrimary(theme.brightness)
            : AppColors.textDisabled(theme.brightness),
      ),
      textDirection: isRtl ? TextDirection.rtl : null,
      decoration: InputDecoration(
        hintText: widget.hintText ?? 'Search...',
        hintStyle: AppTypography.bodyMedium.copyWith(
          color: AppColors.textTertiary(theme.brightness),
        ),
        prefixIcon: Padding(
          padding: EdgeInsetsDirectional.only(
            start: AppSpacing.inputHorizontal,
            end: AppSpacing.sm,
          ),
          child: widget.loading
              ? SizedBox(
                  width: AppSpacing.iconSizeMd,
                  height: AppSpacing.iconSizeMd,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(
                      AppColors.textTertiary(theme.brightness),
                    ),
                  ),
                )
              : Icon(
                  Icons.search_rounded,
                  size: AppSpacing.iconSizeMd,
                  color: AppColors.textTertiary(theme.brightness),
                ),
        ),
        suffixIcon: _hasText && !widget.loading
            ? IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: AppSpacing.iconSizeMd,
                  color: AppColors.textTertiary(theme.brightness),
                ),
                onPressed: _clearField,
                tooltip: 'Clear search',
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              )
            : null,
        filled: true,
        fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.inputHorizontal,
          vertical: AppSpacing.inputVertical,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 1.5,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkBorder.withOpacity(0.5)
                : AppColors.lightBorder.withOpacity(0.5),
          ),
        ),
      ),
    );
  }
}
