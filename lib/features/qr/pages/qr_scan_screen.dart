import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/services/qr_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/klasivo_toast.dart';

class QrScanScreen extends ConsumerStatefulWidget {
  const QrScanScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final data = QrService.parseQrData(barcode.rawValue!);
    if (data == null) {
      KlasivoToast.error(context, message: 'Invalid QR code. Please scan a class enrollment QR.');
      return;
    }

    setState(() => _isProcessing = true);
    _enrollStudent(data);
  }

  Future<void> _enrollStudent(Map<String, dynamic> data) async {
    try {
      final studentId = ref.read(userIdProvider) ?? '';
      final qrService = QrService();

      final success = await qrService.enrollStudentByQr(
        studentId: studentId,
        classId: data['classId'],
        teacherId: data['teacherId'],
      );

      if (mounted) {
        KlasivoToast.success(context, message: 'Successfully joined the class!');
        context.pop();
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) KlasivoToast.error(context, message: 'Failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Code'), centerTitle: true),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),
          // Scan overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          // Instructions
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.black54,
              child: const Text(
                'Point the camera at a class QR code to join',
                style: TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
