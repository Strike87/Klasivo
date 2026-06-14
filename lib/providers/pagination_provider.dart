import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/pagination_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO PAGINATION PROVIDER — Riverpod-based pagination state management
//
// Provides a generic [PaginationNotifier] that wraps the [PaginationService]
// cursor-based pagination logic in a Riverpod [StateNotifier], making it
// easy to integrate paginated data into the widget tree via [ConsumerWidget].
//
// Usage:
// ```dart
// // Define a provider for a specific paginated collection
// final announcementsPaginationProvider =
//     StateNotifierProvider<PaginationNotifier<AnnouncementData>,
//         PaginatedState<AnnouncementData>>((ref) {
//   final service = PaginationService();
//   return PaginationNotifier<AnnouncementData>((cursor) => service.fetchPage(
//     collectionPath: 'organizations/$orgId/announcements',
//     fromFirestore: AnnouncementData.fromFirestore,
//     cursor: cursor,
//     pageSize: 20,
//     filters: [QueryFilter.equalTo('isActive', true)],
//   ));
// });
//
// // Consume in a widget
// class AnnouncementList extends ConsumerWidget {
//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     final state = ref.watch(announcementsPaginationProvider);
//     if (state.isLoading && state.items.isEmpty) {
//       return const KlasivoLoading();
//     }
//     return ListView.builder(
//       itemCount: state.items.length,
//       itemBuilder: (context, index) {
//         final item = state.items[index];
//         return AnnouncementCard(announcement: item);
//       },
//     );
//   }
// }
// ```
// ═══════════════════════════════════════════════════════════════════════════════

/// Immutable state representing a paginated data snapshot.
///
/// Holds all items accumulated across loaded pages, the cursor for the
/// next page request, and metadata about loading/error states.
class PaginatedState<T> {
  /// All items accumulated across loaded pages.
  final List<T> items;

  /// The document snapshot cursor for the next page request.
  ///
  /// `null` if no items have been loaded or this is the first page.
  final DocumentSnapshot? lastDocument;

  /// Whether more pages are available beyond the current items.
  final bool hasMore;

  /// Whether a page load is currently in progress.
  final bool isLoading;

  /// Error message from the last failed request, if any.
  ///
  /// Set to `null` on successful loads to clear previous errors.
  final String? error;

  const PaginatedState({
    this.items = const [],
    this.lastDocument,
    this.hasMore = true,
    this.isLoading = false,
    this.error,
  });

  /// Creates a copy of this state with the given fields replaced.
  ///
  /// Note: [error] is explicitly set (not merged) — pass `null` to clear it.
  PaginatedState<T> copyWith({
    List<T>? items,
    DocumentSnapshot? lastDocument,
    bool? hasMore,
    bool? isLoading,
    String? error,
  }) {
    return PaginatedState<T>(
      items: items ?? this.items,
      lastDocument: lastDocument ?? this.lastDocument,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Generic Riverpod [StateNotifier] for managing paginated data state.
///
/// Encapsulates the logic for loading the initial page, loading subsequent
/// pages with cursors, and refreshing the data. Subclasses or direct
/// instances can be used with [StateNotifierProvider].
///
/// The type parameter [T] represents the model type of each item
/// (e.g. `AnnouncementData`, `StudentData`).
///
/// Provide a [loader] function that fetches a [PaginatedResult] given a
/// cursor. This function typically delegates to [PaginationService.fetchPage].
class PaginationNotifier<T> extends StateNotifier<PaginatedState<T>> {
  /// The function that loads a page of data given a cursor.
  final Future<PaginatedResult<T>> Function(DocumentSnapshot? cursor) _loader;

  PaginationNotifier(this._loader) : super(const PaginatedState());

  /// Loads the first page of results, replacing all existing items.
  ///
  /// Resets [items], [lastDocument], and [hasMore] to their initial
  /// state before loading. Call this on first render or to refresh
  /// the entire list.
  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _loader(null);
      state = PaginatedState<T>(
        items: result.items,
        lastDocument: result.lastDocument,
        hasMore: result.hasMore,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Loads the next page of results, appending new items to the existing list.
  ///
  /// No-op if currently loading or if no more pages are available.
  /// On error, preserves existing items and sets the error message.
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _loader(state.lastDocument);
      state = PaginatedState<T>(
        items: [...state.items, ...result.items],
        lastDocument: result.lastDocument,
        hasMore: result.hasMore,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Convenience method that calls [loadInitial] to reset and reload.
  Future<void> refresh() async {
    await loadInitial();
  }
}
