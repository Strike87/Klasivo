import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/event_bus.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO EVENT BUS PROVIDERS
// Riverpod integration for the event bus with typed event streams.
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Event Bus Singleton Provider ─────────────────────────────────────────
final eventBusProvider = Provider<KlasivoEventBus>((ref) {
  final bus = KlasivoEventBus.instance;
  ref.onDispose(() => bus.dispose());
  return bus;
});

// ─── Generic Event Stream Provider ────────────────────────────────────────
// Listens to all events. Use for logging, analytics, or global handlers.
final eventStreamProvider = StreamProvider<KlasivoEvent>((ref) {
  final bus = ref.watch(eventBusProvider);
  return bus.stream;
});

// ─── Typed Event Stream Provider ──────────────────────────────────────────
// Listens to events of a specific type.
// Usage: ref.watch(typedEventStreamProvider<ExamSubmittedEvent>())
final typedEventStreamProvider = StreamProvider.family<KlasivoEvent, Type>((
  ref,
  eventType,
) {
  final bus = ref.watch(eventBusProvider);
  return bus.stream.where((event) => event.runtimeType == eventType);
});

// ─── Event Fire Helper Provider ───────────────────────────────────────────
// Convenience method to fire events from anywhere in the widget tree.
final fireEventProvider = Provider<void Function(KlasivoEvent)>((ref) {
  final bus = ref.watch(eventBusProvider);
  return bus.fire;
});
