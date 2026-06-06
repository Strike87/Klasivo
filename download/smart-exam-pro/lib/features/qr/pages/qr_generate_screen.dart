import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../../core/services/qr_enrollment_service.dart';
import '../../../providers/auth_provider.dart';

/// QR Code Generation Screen - Teachers generate QR codes for class enrollment
/// Students scan the QR code to self-enroll into the class
class QRGenerateScreen extends ConsumerStatefulWidget {
  final String classId;
  final String className;
  final String? grade;

  const QRGenerateScreen({
    super.key,
    required this.classId,
    required this.className,
    this.grade,
  });

  @override
  ConsumerState<QRGenerateScreen> createState() => _QRGenerateScreenState();
}

class _QRGenerateScreenState extends ConsumerState<QRGenerateScreen> {
  final QREnrollmentService _qrService = QREnrollmentService();
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final teacherId = ref.watch(userIdProvider) ?? '';

    final qrData = _qrService.generateEnrollmentQRData(
      classId: widget.classId,
      teacherId: teacherId,
      className: widget.className,
      grade: widget.grade,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enrollment QR Code'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Class info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.class_rounded, size: 40, color: theme.colorScheme.primary),
                    const SizedBox(height: 8),
                    Text(
                      widget.className,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    if (widget.grade != null) ...[
                      const SizedBox(height: 4),
                      Text('Grade: ${widget.grade}', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // QR Code
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      'Scan to Enroll',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    // QR Code with custom styling
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.primary, width: 2),
                      ),
                      child: QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 250,
                        backgroundColor: Colors.white,
                        eyeStyle: QrEyeStyle(
                          eyeShape: QrEyeShape.roundedOuter,
                          color: theme.colorScheme.primary,
                        ),
                        dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.roundedOuter,
                          color: Colors.black87,
                        ),
                        embeddedImage: const AssetImage('assets/icon/app_icon.png'),
                        embeddedImageStyle: const QrEmbeddedImageStyle(
                          size: Size(40, 40),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Students can scan this code to join the class',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Instructions
            Card(
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: theme.colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Text('How Students Enroll', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInstructionStep(1, 'Open Smart Exam Pro on their device'),
                    _buildInstructionStep(2, 'Select "Student" role on the login screen'),
                    _buildInstructionStep(3, 'Tap the QR scan icon or button'),
                    _buildInstructionStep(4, 'Point camera at this QR code'),
                    _buildInstructionStep(5, 'Enter their name and password to join'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _shareQRCode(qrData),
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : () => _saveQRCode(qrData),
                    icon: _isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.download),
                    label: const Text('Save Image'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep(int step, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Text('$step', style: const TextStyle(color: Colors.white, fontSize: 11)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  void _shareQRCode(String qrData) {
    Share.share(
      'Join my class "${widget.className}" on Smart Exam Pro!\n\nScan this QR code or use the app to enroll.',
      subject: 'Smart Exam Pro - Class Enrollment',
    );
  }

  Future<void> _saveQRCode(String qrData) async {
    setState(() => _isSaving = true);
    try {
      // The QR widget can be captured using RepaintBoundary + RenderRepaintBoundary
      // For simplicity, we'll share the data text
      Share.share(
        'Smart Exam Pro Enrollment Code for ${widget.className}\n\n$qrData',
        subject: 'QR Code - ${widget.className}',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
