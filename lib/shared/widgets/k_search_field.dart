import 'package:flutter/material.dart';
import '../../core/tokens/tokens.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO SEARCH FIELD — Design-system search field using AppColors,
// AppSpacing, AppRadius, AppTypography tokens.
// ═══════════════════════════════════════════════════════════════════════════════

class KSearchField extends StatefulWidget {
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool autofocus;
  final IconData prefixIcon;
  final IconData clearIcon;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final InputDecoration? decoration;

  const KSearchField({
    super.key,
    this.hintText,
    this.onChanged,
    this.onClear,
    this.controller,
    this.focusNode,
    this.autofocus = false,
    this.prefixIcon = Icons.search_rounded,
    this.clearIcon = Icons.close_rounded,
    this.padding,
    this.borderRadius,
    this.decoration,
  });

  @override
  State<KSearchField> createState() => _KSearchFieldState();
}

class _KSearchFieldState extends State<KSearchField> {
  late TextEditingController _controller;
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
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.removeListener(_onTextChanged);
    }
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
    widget.onChanged?.call(_controller.text);
  }

  void _onClear() {
    _controller.clear();
    widget.onClear?.call();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final radius = widget.borderRadius ?? AppRadius.input;

    return Padding(
      padding: widget.padding ??
          const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenHorizontal,
            vertical: AppSpacing.sm,
          ),
      child: TextField(
        controller: _controller,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        style: AppTypography.bodyMedium.copyWith(
          color: AppColors.textPrimary(brightness),
        ),
        decoration: widget.decoration ??
            InputDecoration(
              hintText: widget.hintText ?? 'Search...',
              hintStyle: AppTypography.bodyMedium.copyWith(
                color: AppColors.textTertiary(brightness),
              ),
              prefixIcon: Icon(
                widget.prefixIcon,
                color: AppColors.textTertiary(brightness),
                size: AppSpacing.iconSizeMd,
              ),
              suffixIcon: _hasText
                  ? IconButton(
                      icon: Icon(
                        widget.clearIcon,
                        color: AppColors.textTertiary(brightness),
                        size: AppSpacing.iconSizeMd,
                      ),
                      onPressed: _onClear,
                      splashRadius: AppSpacing.iconSizeMd,
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surface(brightness),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.inputHorizontal,
                vertical: AppSpacing.inputVertical,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radius),
                borderSide: BorderSide(
                  color: AppColors.border(brightness),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radius),
                borderSide: BorderSide(
                  color: AppColors.border(brightness),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(radius),
                borderSide: BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
            ),
      ),
    );
  }
}
