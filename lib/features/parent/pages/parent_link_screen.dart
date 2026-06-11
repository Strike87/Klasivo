import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/theme.dart';
import '../../../core/config/app_constants.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/parent_link_provider.dart';
import '../../../widgets/klasivo_button.dart';
import '../../../widgets/klasivo_toast.dart';

// ─── Parent-Student Linking Screen ────────────────────────────────────────────

class ParentLinkScreen extends ConsumerStatefulWidget {
  const ParentLinkScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ParentLinkScreen> createState() => _ParentLinkScreenState();
}

class _ParentLinkScreenState extends ConsumerState<ParentLinkScreen> {
  final List<FocusNode> _focusNodes = List.generate(8, (_) => FocusNode());
  final List<TextEditingController> _controllers =
      List.generate(8, (_) => TextEditingController());
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Auto-advance focus when a character is typed
    for (int i = 0; i < 8; i++) {
      _controllers[i].addListener(() => _onCodeCharChanged(i));
    }
  }

  void _onCodeCharChanged(int index) {
    final text = _controllers[index].text;
    if (text.length == 1 && index < 7) {
      // Move focus to the next field
      _focusNodes[index + 1].requestFocus();
    }
  }

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.dispose();
    }
    for (final ctrl in _controllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  String get _fullCode =>
      _controllers.map((c) => c.text.toUpperCase()).join();

  bool get _isCodeComplete => _fullCode.length == 8;

  Future<void> _linkChild() async {
    if (!_isCodeComplete) {
      KlasivoToast.error(context, message: 'Please enter the full 8-character code');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final parentId = ref.read(userIdProvider);
      if (parentId == null || parentId.isEmpty) {
        throw Exception('You must be logged in to link a child.');
      }

      final linkService = ref.read(parentLinkServiceProvider);
      final result = await linkService.linkParentToStudent(
        code: _fullCode,
        parentId: parentId,
      );

      if (mounted) {
        // Show success dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(KlasivoRadius.lg),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(KlasivoSpacing.lg),
                  decoration: BoxDecoration(
                    color: KlasivoColors.secondarySurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 48,
                    color: KlasivoColors.secondary,
                  ),
                ),
                const SizedBox(height: KlasivoSpacing.xxl),
                Text(
                  'Successfully Linked!',
                  style: KlasivoTypography.titleLarge.copyWith(
                    color: Theme.of(ctx).brightness == Brightness.dark
                        ? KlasivoColors.darkTextPrimary
                        : KlasivoColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: KlasivoSpacing.sm),
                Text(
                  'You are now linked to ${result['studentName'] ?? 'your child'}. You can view their results and attendance.',
                  textAlign: TextAlign.center,
                  style: KlasivoTypography.bodyMedium.copyWith(
                    color: Theme.of(ctx).brightness == Brightness.dark
                        ? KlasivoColors.darkTextSecondary
                        : KlasivoColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
            actions: [
              KlasivoButton(
                label: 'Go to Dashboard',
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.go(AppConstants.routeParentHome);
                },
                fullWidth: true,
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        KlasivoToast.error(
          context,
          message: e.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Handle keyboard backspace to move focus to previous field
  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.go(AppConstants.routeParentLogin),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: KlasivoSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: KlasivoSpacing.lg),

              // ── Header Icon ──
              Center(
                child: Container(
                  padding: const EdgeInsets.all(KlasivoSpacing.lg),
                  decoration: BoxDecoration(
                    color: KlasivoColors.secondary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(KlasivoRadius.lg),
                  ),
                  child: const Icon(
                    Icons.link_rounded,
                    size: 48,
                    color: KlasivoColors.secondary,
                  ),
                ),
              ),
              const SizedBox(height: KlasivoSpacing.xxl),

              // ── Title ──
              Center(
                child: Text(
                  'Link Your Child',
                  style: KlasivoTypography.headlineSmall.copyWith(
                    color: isDark
                        ? KlasivoColors.darkTextPrimary
                        : KlasivoColors.lightTextPrimary,
                  ),
                ),
              ),
              const SizedBox(height: KlasivoSpacing.sm),

              // ── Instructions ──
              Center(
                child: Text(
                  'Ask your child\'s teacher for a linking code.\nEnter the 8-character code below to connect.',
                  textAlign: TextAlign.center,
                  style: KlasivoTypography.bodyMedium.copyWith(
                    color: isDark
                        ? KlasivoColors.darkTextTertiary
                        : KlasivoColors.lightTextTertiary,
                  ),
                ),
              ),
              const SizedBox(height: KlasivoSpacing.xxxl),

              // ── 8-Character Code Input ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(8, (index) {
                  return SizedBox(
                    width: 38,
                    child: KeyboardListener(
                      focusNode: FocusNode(),
                      onKeyEvent: (event) => _onKeyEvent(index, event),
                      child: TextFormField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        textAlign: TextAlign.center,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: index < 7
                            ? TextInputAction.next
                            : TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z0-9]')),
                          LengthLimitingTextInputFormatter(1),
                        ],
                        style: KlasivoTypography.headlineMedium.copyWith(
                          color: isDark
                              ? KlasivoColors.darkTextPrimary
                              : KlasivoColors.lightTextPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: KlasivoSpacing.md,
                          ),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(KlasivoRadius.md),
                            borderSide: BorderSide(
                              color: isDark
                                  ? KlasivoColors.darkBorder
                                  : KlasivoColors.lightBorder,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(KlasivoRadius.md),
                            borderSide: BorderSide(
                              color: isDark
                                  ? KlasivoColors.darkBorder
                                  : KlasivoColors.lightBorder,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(KlasivoRadius.md),
                            borderSide: const BorderSide(
                              color: KlasivoColors.secondary,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: isDark
                              ? KlasivoColors.darkSurface
                              : KlasivoColors.lightSurface,
                        ),
                        onChanged: (value) {
                          if (value.isNotEmpty) {
                            _controllers[index].text =
                                value.toUpperCase();
                            if (index < 7) {
                              _focusNodes[index + 1].requestFocus();
                            } else {
                              // Last character entered — unfocus
                              _focusNodes[index].unfocus();
                            }
                          }
                          setState(() {}); // Rebuild for button state
                        },
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: KlasivoSpacing.xxxl),

              // ── Link Button ──
              KlasivoButton(
                label: 'Link',
                onPressed: _isCodeComplete ? _linkChild : null,
                loading: _isLoading,
                fullWidth: true,
                size: KlasivoButtonSize.lg,
              ),
              const SizedBox(height: KlasivoSpacing.xxl),

              // ── Skip for now ──
              Center(
                child: KlasivoButton(
                  variant: KlasivoButtonVariant.tertiary,
                  label: 'Skip for now',
                  onPressed: () {
                    context.go(AppConstants.routeParentHome);
                  },
                ),
              ),
              const SizedBox(height: KlasivoSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}
