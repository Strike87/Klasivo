import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/performance_trace_service.dart';

/// Provider for the PerformanceTraceService singleton.
final performanceTraceProvider = Provider<PerformanceTraceService>((ref) {
  return PerformanceTraceService.instance;
});

/// Whether performance monitoring is currently enabled.
final isPerformanceMonitoringEnabledProvider = Provider<bool>((ref) {
  final service = ref.watch(performanceTraceProvider);
  return service.isEnabled;
});
