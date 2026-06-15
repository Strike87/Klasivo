import 'package:cloud_firestore/cloud_firestore.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO PAGINATION SERVICE — Generic cursor-based Firestore pagination
//
// Provides a reusable, type-safe way to paginate through Firestore collections
// using document cursors (startAfterDocument) instead of offset-based pagination.
//
// Cursor-based pagination is Firestore's recommended approach because:
// - It avoids the performance cost of skipping documents
// - It remains consistent even when documents are added/removed between pages
// - It works efficiently with filtered and ordered queries
// ═══════════════════════════════════════════════════════════════════════════════

/// Result of a paginated Firestore query.
///
/// Contains the fetched [items], the [lastDocument] cursor for fetching
/// the next page, and a [hasMore] flag indicating whether additional
/// pages are available.
class PaginatedResult<T> {
  /// The list of items fetched in this page.
  final List<T> items;

  /// The document snapshot of the last item in this page.
  ///
  /// Pass this as the [cursor] parameter to [PaginationService.fetchPage]
  /// to retrieve the next page of results. `null` if no items were returned.
  final DocumentSnapshot? lastDocument;

  /// Whether there are more documents available beyond this page.
  ///
  /// Determined by requesting `pageSize + 1` documents from Firestore
  /// and checking if the extra document was returned.
  final bool hasMore;

  const PaginatedResult({
    required this.items,
    this.lastDocument,
    this.hasMore = false,
  });
}

/// Generic Firestore pagination service using cursor-based pagination.
///
/// Usage:
/// ```dart
/// final paginationService = PaginationService();
///
/// // First page
/// final result = await paginationService.fetchPage(
///   collectionPath: 'organizations/org123/announcements',
///   fromFirestore: AnnouncementData.fromFirestore,
///   pageSize: 20,
///   filters: [QueryFilter.equalTo('isActive', true)],
/// );
///
/// // Next page
/// if (result.hasMore) {
///   final nextResult = await paginationService.fetchPage(
///     collectionPath: 'organizations/org123/announcements',
///     fromFirestore: AnnouncementData.fromFirestore,
///     cursor: result.lastDocument,
///     pageSize: 20,
///     filters: [QueryFilter.equalTo('isActive', true)],
///   );
/// }
/// ```
class PaginationService {
  final FirebaseFirestore _firestore;

  PaginationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Fetches a page of documents from a Firestore collection.
  ///
  /// [collectionPath] - Full Firestore collection path (e.g. 'organizations/orgId/announcements').
  /// [fromFirestore] - Factory function to convert a [DocumentSnapshot] to model type [T].
  /// [cursor] - The last document snapshot from the previous page. Pass `null` for the first page.
  /// [pageSize] - Number of documents per page. Defaults to 20.
  /// [orderBy] - Field name to order results by. Defaults to 'createdAt'.
  /// [descending] - Sort direction. `true` = newest first. Defaults to `true`.
  /// [filters] - Optional list of [QueryFilter] constraints to apply before ordering.
  ///
  /// Internally requests `pageSize + 1` documents to determine [PaginatedResult.hasMore]
  /// without requiring an additional query.
  Future<PaginatedResult<T>> fetchPage<T>({
    required String collectionPath,
    required T Function(DocumentSnapshot doc) fromFirestore,
    DocumentSnapshot? cursor,
    int pageSize = 20,
    String orderBy = 'createdAt',
    bool descending = true,
    List<QueryFilter> filters = const [],
  }) async {
    Query query = _firestore.collection(collectionPath);

    // Apply filters before ordering (Firestore requirement)
    for (final filter in filters) {
      if (filter.isWhereIn) {
        query = query.where(filter.field, whereIn: filter.values);
      } else if (filter.isNotEqualTo != null) {
        query = query.where(filter.field, isNotEqualTo: filter.isNotEqualTo);
      } else if (filter.isLessThan != null) {
        query = query.where(filter.field, isLessThan: filter.isLessThan);
      } else if (filter.isGreaterThan != null) {
        query = query.where(filter.field, isGreaterThan: filter.isGreaterThan);
      } else if (filter.isNull != null) {
        query = query.where(filter.field, isNull: filter.isNull);
      } else {
        query = query.where(filter.field, isEqualTo: filter.value);
      }
    }

    // Apply ordering
    query = query.orderBy(orderBy, descending: descending);

    // Apply cursor for subsequent pages
    if (cursor != null) {
      query = query.startAfterDocument(cursor);
    }

    // Fetch one extra document to determine if there are more pages
    query = query.limit(pageSize + 1);

    final snapshot = await query.get();
    final docs = snapshot.docs;
    final hasMore = docs.length > pageSize;
    final items = docs.take(pageSize).map(fromFirestore).toList();
    final lastDoc = items.isNotEmpty ? docs[items.length - 1] : null;

    return PaginatedResult<T>(
      items: items,
      lastDocument: lastDoc,
      hasMore: hasMore,
    );
  }

  /// Creates a real-time paginated stream from a Firestore collection.
  ///
  /// Unlike [fetchPage], this returns a [Stream] that emits the current
  /// list of items whenever the underlying data changes. It does not
  /// support cursor-based pagination for subsequent pages — it simply
  /// listens to the first [limit] documents matching the query.
  ///
  /// Use this for live-updating lists that only need the first page
  /// of results (e.g. a "recent items" preview).
  ///
  /// [collectionPath] - Full Firestore collection path.
  /// [fromFirestore] - Factory function to convert a [DocumentSnapshot] to model type [T].
  /// [limit] - Maximum number of documents to stream. Defaults to 20.
  /// [orderBy] - Field name to order results by. Defaults to 'createdAt'.
  /// [descending] - Sort direction. `true` = newest first. Defaults to `true`.
  /// [filters] - Optional list of [QueryFilter] constraints.
  Stream<List<T>> streamPage<T>({
    required String collectionPath,
    required T Function(DocumentSnapshot doc) fromFirestore,
    int limit = 20,
    String orderBy = 'createdAt',
    bool descending = true,
    List<QueryFilter> filters = const [],
  }) {
    Query query = _firestore.collection(collectionPath);

    for (final filter in filters) {
      if (filter.isWhereIn) {
        query = query.where(filter.field, whereIn: filter.values);
      } else if (filter.isNotEqualTo != null) {
        query = query.where(filter.field, isNotEqualTo: filter.isNotEqualTo);
      } else if (filter.isLessThan != null) {
        query = query.where(filter.field, isLessThan: filter.isLessThan);
      } else if (filter.isGreaterThan != null) {
        query = query.where(filter.field, isGreaterThan: filter.isGreaterThan);
      } else if (filter.isNull != null) {
        query = query.where(filter.field, isNull: filter.isNull);
      } else {
        query = query.where(filter.field, isEqualTo: filter.value);
      }
    }

    query = query.orderBy(orderBy, descending: descending).limit(limit);

    return query.snapshots().map(
      (snapshot) => snapshot.docs.map(fromFirestore).toList(),
    );
  }
}

/// Filter descriptor for Firestore queries.
///
/// Provides a declarative way to specify query constraints that can be
/// passed to [PaginationService.fetchPage] and [PaginationService.streamPage].
///
/// Firestore allows inequality filters on only one field at a time. If you
/// need multiple equality filters, use [QueryFilter.equalTo] for each.
///
/// Example:
/// ```dart
/// final filters = [
///   QueryFilter.equalTo('organizationId', 'org123'),
///   QueryFilter.equalTo('isActive', true),
///   QueryFilter.inList('status', ['draft', 'published']),
/// ];
/// ```
class QueryFilter {
  /// The field path to filter on (e.g. 'organizationId', 'createdAt').
  final String field;

  /// Value for equality filter (`isEqualTo`).
  final dynamic value;

  /// List of values for `whereIn` filter.
  final List<dynamic>? values;

  /// Value for `isNotEqualTo` filter.
  final dynamic isNotEqualTo;

  /// Value for `isLessThan` filter.
  final dynamic isLessThan;

  /// Value for `isGreaterThan` filter.
  final dynamic isGreaterThan;

  /// Value for `isNull` filter.
  final bool? isNull;

  const QueryFilter({
    required this.field,
    this.value,
    this.values,
    this.isNotEqualTo,
    this.isLessThan,
    this.isGreaterThan,
    this.isNull,
  });

  /// Whether this filter uses `whereIn` (list-based matching).
  bool get isWhereIn => values != null;

  // ─── Convenience Constructors ─────────────────────────────────────────────

  /// Creates an equality filter (`field == value`).
  factory QueryFilter.equalTo(String field, dynamic value) =>
      QueryFilter(field: field, value: value);

  /// Creates a list membership filter (`field in values`).
  factory QueryFilter.inList(String field, List<dynamic> values) =>
      QueryFilter(field: field, values: values);

  /// Creates a not-equal filter (`field != value`).
  factory QueryFilter.notEqualTo(String field, dynamic value) =>
      QueryFilter(field: field, isNotEqualTo: value);

  /// Creates a less-than filter (`field < value`).
  factory QueryFilter.lessThan(String field, dynamic value) =>
      QueryFilter(field: field, isLessThan: value);

  /// Creates a greater-than filter (`field > value`).
  factory QueryFilter.greaterThan(String field, dynamic value) =>
      QueryFilter(field: field, isGreaterThan: value);

  /// Creates a null-check filter (`field isNull`).
  factory QueryFilter.isNullValue(String field, bool isNull) =>
      QueryFilter(field: field, isNull: isNull);
}
