import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/services/qr_service.dart';
import '../../../providers/class_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/klasivo_card.dart';

class QrGenerateScreen extends ConsumerWidget {
  final String classId;
  const QrGenerateScreen({Key? key, required this.classId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classes = ref.watch(classesProvider);
    final classData = classes.where((c) => c.id == classId).firstOrNull;
    final teacherId = ref.watch(userIdProvider) ?? '';
    final theme = Theme.of(context);

    final qrData = QrService.generateClassQrData(
      classId: classId,
      teacherId: teacherId,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Class QR Code'), centerTitle: true),
      body: Center(
        child: KlasivoCard(
          margin: const EdgeInsets.all(24),
          variant: KlasivoCardVariant.elevated,
          child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.qr_code_2, size: 40, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  classData?.name ?? 'Unknown Class',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Students can scan this QR code to join the class',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 250,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Class ID: $classId',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11, fontFamily: 'monospace'),
                ),
              ],
            ),
      ),
    );
  }
}
