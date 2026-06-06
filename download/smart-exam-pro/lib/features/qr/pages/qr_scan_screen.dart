import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/qr_enrollment_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../providers/exam_instance_provider.dart';
import '../../../providers/auth_provider.dart';

/// QR Code Scanner Screen - Students scan QR codes to enroll in classes
class QRScanScreen extends ConsumerStatefulWidget {
  const QRScanScreen({super.key});

  @override
  ConsumerState<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends ConsumerState<QRScanScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  final QREnrollmentService _qrService = QREnrollmentService();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController(text: '123456');
  bool _isScanning = true;
  bool _isFlashOn = false;
  bool _isEnrolling = false;
  Map<String, dynamic>? _scannedData;
  Map<String, dynamic>? _classInfo;
  String? _error;

  @override
  void dispose() {
    _scannerController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () {
              _scannerController.toggleTorch();
              setState(() => _isFlashOn = !_isFlashOn);
            },
          ),
        ],
      ),
      body: _isScanning
          ? _buildScannerView(theme)
          : _buildEnrollmentForm(theme),
    );
  }

  Widget _buildScannerView(ThemeData theme) {
    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: _onQRDetected,
        ),

        // Dark overlay with cutout
        ColorFiltered(
          colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.srcOut),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Center(
                child: Container(
                  height: 250,
                  width: 250,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Scan frame border
        Center(
          child: Container(
            height: 250,
            width: 250,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.primary, width: 3),
            ),
          ),
        ),

        // Instructions at bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: 100,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  'Point your camera at the QR code',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _showManualEntry,
                icon: const Icon(Icons.keyboard, color: Colors.white),
                label: const Text('Enter code manually', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),

        // Error banner
        if (_error != null)
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: const TextStyle(color: Colors.white, fontSize: 13))),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 18),
                    onPressed: () => setState(() => _error = null),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEnrollmentForm(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Scanned class info
          Card(
            color: Colors.green.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 48),
                  const SizedBox(height: 8),
                  const Text('QR Code Scanned!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  if (_classInfo != null) ...[
                    Text(
                      _classInfo!['className'] ?? 'Unknown Class',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (_classInfo!['grade'] != null)
                      Text('Grade: ${_classInfo!['grade']}', style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(height: 4),
                    Text(
                      '${_classInfo!['studentCount'] ?? 0} students enrolled',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          Text('Your Information', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Full Name *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Password *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock),
              helperText: 'You will use this password to log in',
            ),
            obscureText: true,
          ),
          const SizedBox(height: 24),

          FilledButton(
            onPressed: _isEnrolling ? null : _enroll,
            child: _isEnrolling
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Join Class'),
          ),
          const SizedBox(height: 12),

          OutlinedButton(
            onPressed: () {
              setState(() {
                _isScanning = true;
                _scannedData = null;
                _classInfo = null;
                _error = null;
              });
            },
            child: const Text('Scan Another QR Code'),
          ),
        ],
      ),
    );
  }

  void _onQRDetected(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    for (final barcode in barcodes) {
      if (barcode.rawValue == null) continue;

      final data = _qrService.parseEnrollmentQRData(barcode.rawValue!);
      if (data != null) {
        _scannerController.stop();
        _handleScannedData(data);
        return;
      }
    }
  }

  Future<void> _handleScannedData(Map<String, dynamic> data) async {
    setState(() => _scannedData = data);

    try {
      final isValid = await _qrService.validateQRData(data);
      if (!isValid) {
        setState(() {
          _error = 'Invalid or expired QR code';
          _isScanning = true;
        });
        _scannerController.start();
        return;
      }

      final classInfo = await _qrService.getClassInfoFromQR(data);
      setState(() {
        _classInfo = classInfo;
        _isScanning = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isScanning = true;
      });
      _scannerController.start();
    }
  }

  Future<void> _enroll() async {
    final name = _nameController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your full name')),
      );
      return;
    }
    if (password.isEmpty || password.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 4 characters')),
      );
      return;
    }

    setState(() => _isEnrolling = true);

    try {
      final studentDocId = await _qrService.enrollViaQR(
        qrData: _scannedData!,
        fullName: name,
        password: password,
        hashPassword: AuthService.hashPassword,
      );

      // Get the student data to save auth state
      final doc = await FirebaseFirestore.instance.collection('students').doc(studentDocId).get();
      if (doc.exists && mounted) {
        final data = doc.data()!;

        // Save student auth data to Hive
        final authBox = await Hive.openBox('auth_box');
        await authBox.put('isLoggedIn', true);
        await authBox.put('userRole', 'student');
        await authBox.put('userId', data['id']);
        await authBox.put('userName', data['fullName']);
        await authBox.put('studentCode', data['studentCode']);
        await authBox.put('studentClassId', data['classId']);
        await authBox.put('studentTeacherId', data['teacherId']);

        // Update Riverpod providers
        ref.read(userRoleProvider.notifier).state = 'student';
        ref.read(userNameProvider.notifier).state = data['fullName'];
        ref.read(userIdProvider.notifier).state = data['id'];
        ref.read(studentCodeProvider.notifier).state = data['studentCode'];
        ref.read(studentClassIdProvider.notifier).state = data['classId'];
        ref.read(studentTeacherIdProvider.notifier).state = data['teacherId'];

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully enrolled! Redirecting...'),
              backgroundColor: Colors.green,
            ),
          );
          context.go('/student');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enrollment failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isEnrolling = false);
    }
  }

  void _showManualEntry() {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Enrollment Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the class enrollment code provided by your teacher:'),
            const SizedBox(height: 12),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Enrollment Code',
                border: OutlineInputBorder(),
                hintText: 'Paste code here...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              final data = _qrService.parseEnrollmentQRData(codeController.text.trim());
              if (data != null) {
                _scannerController.stop();
                _handleScannedData(data);
              } else {
                setState(() => _error = 'Invalid enrollment code');
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
