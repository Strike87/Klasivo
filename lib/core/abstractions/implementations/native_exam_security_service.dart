import '../exam_security_service.dart';
import '../../services/exam_security_service.dart' as native;

/// Production implementation of [IExamSecurityService] that delegates
/// to the static methods on the existing [native.ExamSecurityService].
class NativeExamSecurityService implements IExamSecurityService {
  const NativeExamSecurityService();

  @override
  bool get isLockdownActive => native.ExamSecurityService.isLockdownActive;

  @override
  Future<void> enableScreenshotProtection() =>
      native.ExamSecurityService.enableScreenshotProtection();

  @override
  Future<void> disableScreenshotProtection() =>
      native.ExamSecurityService.disableScreenshotProtection();

  @override
  Future<void> lockPortrait() =>
      native.ExamSecurityService.lockPortrait();

  @override
  Future<void> unlockOrientation() =>
      native.ExamSecurityService.unlockOrientation();

  @override
  Future<void> enterFullScreen() =>
      native.ExamSecurityService.enterFullScreen();

  @override
  Future<void> exitFullScreen() =>
      native.ExamSecurityService.exitFullScreen();

  @override
  void startClipboardMonitoring() =>
      native.ExamSecurityService.startClipboardMonitoring();

  @override
  void stopClipboardMonitoring() =>
      native.ExamSecurityService.stopClipboardMonitoring();

  @override
  Future<void> enterLockdownMode({
    void Function(String type, String? details)? onViolation,
  }) =>
      native.ExamSecurityService.enterLockdownMode(onViolation: onViolation);

  @override
  Future<void> exitLockdownMode() =>
      native.ExamSecurityService.exitLockdownMode();

  @override
  void reportViolation(String type, {String? details}) =>
      native.ExamSecurityService.reportViolation(type, details: details);

  @override
  Map<String, bool> getLockdownStatus() =>
      native.ExamSecurityService.getLockdownStatus();

  @override
  Future<void> enableAll() => native.ExamSecurityService.enableAll();

  @override
  Future<void> disableAll() => native.ExamSecurityService.disableAll();
}
