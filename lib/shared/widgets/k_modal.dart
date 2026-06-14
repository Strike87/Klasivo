/// Klasivo v2.0 - KModal component
/// 
/// Enhanced modal component based on klasivo_modal.dart.
/// Supports bottom sheet and center dialog modes,
/// custom content, and RTL-aware layout.
library;

import "package:flutter/material.dart";

/// Klasivo modal component.
class KModal extends StatelessWidget {
  final String? title;
  final Widget content;
  final List<Widget>? actions;
  final KModalType type;
  final bool isDismissible;

  const KModal({
    super.key,
    this.title,
    required this.content,
    this.actions,
    this.type = KModalType.bottomSheet,
    this.isDismissible = true,
  });

  /// Show as bottom sheet.
  static Future<T?> showBottomSheet<T>({
    required BuildContext context,
    required Widget content,
    String? title,
    List<Widget>? actions,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      builder: (context) => KModal(
        title: title,
        content: content,
        actions: actions,
        type: KModalType.bottomSheet,
      ),
    );
  }

  /// Show as center dialog.
  static Future<T?> showCenterDialog<T>({
    required BuildContext context,
    required Widget content,
    String? title,
    List<Widget>? actions,
  }) {
    return showDialog<T>(
      context: context,
      builder: (context) => KModal(
        title: title,
        content: content,
        actions: actions,
        type: KModalType.centerDialog,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return switch (type) {
      KModalType.bottomSheet => _buildBottomSheet(context),
      KModalType.centerDialog => _buildCenterDialog(context),
    };
  }

  Widget _buildBottomSheet(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Text(title!, style: Theme.of(context).textTheme.titleLarge),
          if (title != null) const SizedBox(height: 16),
          content,
          if (actions != null && actions!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: actions!),
          ],
        ],
      ),
    );
  }

  Widget _buildCenterDialog(BuildContext context) {
    return AlertDialog(
      title: title != null ? Text(title!) : null,
      content: content,
      actions: actions,
    );
  }
}

enum KModalType { bottomSheet, centerDialog }
