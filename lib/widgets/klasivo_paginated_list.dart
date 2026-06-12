import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/config/theme.dart';
import '../core/services/pagination_service.dart';
import 'common_widgets.dart';
import 'klasivo_components.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO PAGINATED LIST — Reusable infinite-scroll list widget
//
// A self-contained paginated list that handles:
// - Initial data loading
// - Cursor-based infinite scroll (loads next page automatically)
// - Pull-to-refresh (resets to first page)
// - Loading, error, and empty states using Klasivo design tokens
// - Optional separator between items
//
// Usage:
// ```dart
// KlasivoPaginatedList<AnnouncementData>(
//   loader: (cursor) => paginationService.fetchPage(
//     collectionPath: 'organizations/$orgId/announcements',
//     fromFirestore: AnnouncementData.fromFirestore,
//     cursor: cursor,
//     pageSize: 20,
//     filters: [QueryFilter.equalTo('isActive', true)],
//   ),
//   itemBuilder: (context, announcement, index) {
//     return AnnouncementCard(announcement: announcement);
//   },
// )
// ```
// ═══════════════════════════════════════════════════════════════════════════════

/// Callback type for loading a page of data.
///
/// Receives the [DocumentSnapshot] cursor from the previous page,
/// or `null` for the first page. Returns a [PaginatedResult] containing
/// the fetched items and pagination metadata.
typedef PageLoader<T> = Future<PaginatedResult<T>> Function(
  DocumentSnapshot? cursor,
);

/// A reusable paginated list widget with infinite scroll and pull-to-refresh.
///
/// Manages its own loading state internally. Provide a [PageLoader] function
/// that knows how to fetch a page given a cursor, and an [itemBuilder] to
/// render each item.
///
/// The widget automatically:
/// - Loads the first page on initialization
/// - Triggers [PageLoader] for the next page when the user scrolls near the bottom
/// - Shows a loading indicator at the bottom while fetching more items
/// - Resets and reloads on pull-to-refresh
/// - Displays appropriate empty, error, and loading states
class KlasivoPaginatedList<T> extends StatefulWidget {
  /// Function that loads a page of data given a cursor.
  final PageLoader<T> loader;

  /// Builder function for each item in the list.
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// Widget to display when the list is empty.
  ///
  /// Defaults to [KlasivoEmptyState] with an inbox icon.
  final Widget? emptyWidget;

  /// Widget to display during the initial load.
  ///
  /// Defaults to [KlasivoLoading].
  final Widget? loadingWidget;

  /// Widget to display when an error occurs and the list is empty.
  ///
  /// Defaults to [ErrorWidgetCustom] with a retry button.
  final Widget? errorWidget;

  /// Number of items per page. Used for informational purposes;
  /// the actual page size is controlled by the [PageLoader].
  final int pageSize;

  /// Padding around the list. Defaults to screen horizontal padding.
  final EdgeInsetsGeometry? padding;

  /// Optional external scroll controller.
  final ScrollController? scrollController;

  /// Whether the list should shrink-wrap its contents.
  ///
  /// Set to `true` when embedding inside another scrollable widget.
  final bool shrinkWrap;

  /// Scroll physics for the list view.
  final ScrollPhysics? physics;

  /// Widget to render between list items as a separator.
  ///
  /// Defaults to a [SizedBox] with [KlasivoSpacing.stackSm] height.
  final Widget? separator;

  const KlasivoPaginatedList({
    Key? key,
    required this.loader,
    required this.itemBuilder,
    this.emptyWidget,
    this.loadingWidget,
    this.errorWidget,
    this.pageSize = 20,
    this.padding,
    this.scrollController,
    this.shrinkWrap = false,
    this.physics,
    this.separator,
  }) : super(key: key);

  @override
  State<KlasivoPaginatedList<T>> createState() =>
      _KlasivoPaginatedListState<T>();
}

class _KlasivoPaginatedListState<T> extends State<KlasivoPaginatedList<T>> {
  /// All items loaded across all pages so far.
  final List<T> _items = [];

  /// The cursor for the next page request.
  DocumentSnapshot? _lastDocument;

  /// Whether more pages are available beyond the current list.
  bool _hasMore = true;

  /// Whether a page load is currently in progress.
  bool _isLoading = false;

  /// Error message from the last failed request, if any.
  String? _error;

  /// Whether this is the first page load (not yet completed).
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  /// Loads the first page of results, resetting all state.
  Future<void> _loadInitial() async {
    setState(() {
      _isInitialLoad = true;
      _error = null;
    });

    try {
      final result = await widget.loader(null);
      if (!mounted) return;
      setState(() {
        _items.clear();
        _items.addAll(result.items);
        _lastDocument = result.lastDocument;
        _hasMore = result.hasMore;
        _isInitialLoad = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isInitialLoad = false;
      });
    }
  }

  /// Loads the next page of results, appending items to the existing list.
  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await widget.loader(_lastDocument);
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _lastDocument = result.lastDocument;
        _hasMore = result.hasMore;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Pull-to-refresh handler — resets to the first page.
  Future<void> _refresh() async {
    await _loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    // ─── Initial loading state ─────────────────────────────────────────────
    if (_isInitialLoad) {
      return widget.loadingWidget ??
          const KlasivoLoading(message: 'Loading...');
    }

    // ─── Error state (only when list is empty) ─────────────────────────────
    if (_error != null && _items.isEmpty) {
      return widget.errorWidget ??
          ErrorWidgetCustom(
            message: _error!,
            onRetry: _loadInitial,
          );
    }

    // ─── Empty state ───────────────────────────────────────────────────────
    if (_items.isEmpty) {
      return widget.emptyWidget ??
          const KlasivoEmptyState(
            icon: Icons.inbox_outlined,
            title: 'No items found',
            subtitle: 'There are no items to display right now.',
          );
    }

    // ─── List with infinite scroll ─────────────────────────────────────────
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        controller: widget.scrollController,
        padding: widget.padding ??
            const EdgeInsets.all(KlasivoSpacing.screenHorizontal),
        shrinkWrap: widget.shrinkWrap,
        physics: widget.physics,
        itemCount: _items.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, __) => widget.separator ??
            const SizedBox(height: KlasivoSpacing.stackSm),
        itemBuilder: (context, index) {
          // Loading indicator at the bottom triggers the next page load
          if (index == _items.length) {
            _loadMore();
            return Padding(
              padding: const EdgeInsets.symmetric(
                vertical: KlasivoSpacing.lg,
              ),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: KlasivoColors.primary,
                  ),
                ),
              ),
            );
          }

          return widget.itemBuilder(context, _items[index], index);
        },
      ),
    );
  }
}
