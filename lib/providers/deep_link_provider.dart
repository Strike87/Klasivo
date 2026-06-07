import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_constants.dart';
import '../core/services/deep_link_service.dart';
import 'auth_provider.dart';

// ─── Service Provider ────────────────────────────────────────────────────────

final deepLinkServiceProvider =
    Provider<DeepLinkService>((ref) => DeepLinkService());

// ─── Pending Deep Link ──────────────────────────────────────────────────────
// When a deep link is received before the user is authenticated,
// we store it here and process it after login.

final pendingDeepLinkProvider = StateProvider<DeepLinkData?>((ref) => null);

// ─── Current Deep Link ──────────────────────────────────────────────────────
// The deep link currently being processed.

final currentDeepLinkProvider = StateProvider<DeepLinkData?>((ref) => null);

// ─── Join Link Resolution ───────────────────────────────────────────────────

final joinLinkResultProvider =
    FutureProvider.family<JoinLinkResult?, String>((ref, code) {
  return ref.read(deepLinkServiceProvider).resolveJoinLink(code);
});

// ─── Organization Portal Resolution ─────────────────────────────────────────

final orgPortalResultProvider =
    FutureProvider.family<OrgPortalResult?, String>((ref, slug) {
  return ref.read(deepLinkServiceProvider).resolveOrgPortal(slug);
});

// ─── Result Page Resolution ─────────────────────────────────────────────────

final resultPageResultProvider =
    FutureProvider.family<ResultPageResult?, String>((ref, resultId) {
  return ref.read(deepLinkServiceProvider).resolveResultLink(resultId);
});
