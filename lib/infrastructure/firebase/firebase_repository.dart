import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO FIREBASE REPOSITORY — Base repository pattern
//
// Provides a consistent API for all Firestore repositories:
// - CRUD operations with type-safe document conversion
// - Batch operations
// - Real-time streaming
// - Offline-aware queries
// - Error handling and logging
// ═══════════════════════════════════════════════════════════════════════════════

/// Base interface for Firestore document models.
abstract class FirebaseDocument {
  String get id;
  Map<String, dynamic> toFirestore();
  DateTime? get createdAt;
  DateTime? get updatedAt;
}

/// Result of a repository operation.
class RepositoryResult<T> {
  final T? data;
  final String? error;
  final bool success;

  const RepositoryResult.success(this.data)
      : error = null,
        success = true;

  const RepositoryResult.failure(this.error)
      : data = null,
        success = false;

  bool get isFailure => !success;
}

/// Base repository providing common Firestore operations.
abstract class FirebaseRepository<T extends FirebaseDocument> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// The Firestore collection path (must be overridden).
  String get collectionPath;

  /// Convert a Firestore document to a domain model.
  T fromFirestore(String id, Map<String, dynamic> data);

  /// Get the collection reference.
  CollectionReference<Map<String, dynamic>> get collection =>
      _db.collection(collectionPath);

  // ─── Read Operations ────────────────────────────────────────────────────

  /// Get a single document by ID.
  Future<RepositoryResult<T>> getById(String id) async {
    try {
      final doc = await collection.doc(id).get();
      if (!doc.exists) {
        return const RepositoryResult.failure('Document not found');
      }
      final data = fromFirestore(doc.id, doc.data()!);
      return RepositoryResult.success(data);
    } catch (e) {
      debugPrint('[$runtimeType] getById error: $e');
      return RepositoryResult.failure(e.toString());
    }
  }

  /// Get all documents in the collection.
  Future<RepositoryResult<List<T>>> getAll({
    Query<Map<String, dynamic>>? query,
    int? limit,
  }) async {
    try {
      var q = query ?? collection;
      if (limit != null) q = q.limit(limit);

      final snapshot = await q.get();
      final items = snapshot.docs
          .map((doc) => fromFirestore(doc.id, doc.data()))
          .toList();
      return RepositoryResult.success(items);
    } catch (e) {
      debugPrint('[$runtimeType] getAll error: $e');
      return RepositoryResult.failure(e.toString());
    }
  }

  /// Get documents with a where clause.
  Future<RepositoryResult<List<T>>> getWhere({
    required String field,
    required dynamic value,
    int? limit,
  }) async {
    try {
      var query = collection.where(field, isEqualTo: value);
      if (limit != null) query = query.limit(limit);

      final snapshot = await query.get();
      final items = snapshot.docs
          .map((doc) => fromFirestore(doc.id, doc.data()))
          .toList();
      return RepositoryResult.success(items);
    } catch (e) {
      debugPrint('[$runtimeType] getWhere error: $e');
      return RepositoryResult.failure(e.toString());
    }
  }

  /// Stream a single document in real-time.
  Stream<T?> streamById(String id) {
    return collection.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return fromFirestore(doc.id, doc.data()!);
    });
  }

  /// Stream all documents in a collection.
  Stream<List<T>> streamAll({
    Query<Map<String, dynamic>>? query,
  }) {
    final q = query ?? collection;
    return q.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }

  /// Stream documents with a where clause.
  Stream<List<T>> streamWhere({
    required String field,
    required dynamic value,
  }) {
    return collection.where(field, isEqualTo: value).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }

  // ─── Write Operations ───────────────────────────────────────────────────

  /// Create a new document.
  Future<RepositoryResult<String>> create(T item) async {
    try {
      final data = item.toFirestore();
      final docRef = await collection.add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[$runtimeType] Created document: ${docRef.id}');
      return RepositoryResult.success(docRef.id);
    } catch (e) {
      debugPrint('[$runtimeType] create error: $e');
      return RepositoryResult.failure(e.toString());
    }
  }

  /// Create a document with a specific ID.
  Future<RepositoryResult<void>> createWithId(T item, String id) async {
    try {
      final data = item.toFirestore();
      await collection.doc(id).set({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[$runtimeType] Created document with id: $id');
      return const RepositoryResult.success(null);
    } catch (e) {
      debugPrint('[$runtimeType] createWithId error: $e');
      return RepositoryResult.failure(e.toString());
    }
  }

  /// Update an existing document.
  Future<RepositoryResult<void>> update(String id, Map<String, dynamic> data) async {
    try {
      await collection.doc(id).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[$runtimeType] Updated document: $id');
      return const RepositoryResult.success(null);
    } catch (e) {
      debugPrint('[$runtimeType] update error: $e');
      return RepositoryResult.failure(e.toString());
    }
  }

  /// Delete a document.
  Future<RepositoryResult<void>> delete(String id) async {
    try {
      await collection.doc(id).delete();
      debugPrint('[$runtimeType] Deleted document: $id');
      return const RepositoryResult.success(null);
    } catch (e) {
      debugPrint('[$runtimeType] delete error: $e');
      return RepositoryResult.failure(e.toString());
    }
  }

  // ─── Batch Operations ───────────────────────────────────────────────────

  /// Create multiple documents in a batch.
  Future<RepositoryResult<void>> batchCreate(List<T> items) async {
    try {
      final batch = _db.batch();
      for (final item in items) {
        final docRef = collection.doc();
        final data = item.toFirestore();
        batch.set(docRef, {
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      debugPrint('[$runtimeType] Batch created ${items.length} documents');
      return const RepositoryResult.success(null);
    } catch (e) {
      debugPrint('[$runtimeType] batchCreate error: $e');
      return RepositoryResult.failure(e.toString());
    }
  }

  /// Delete multiple documents in a batch.
  Future<RepositoryResult<void>> batchDelete(List<String> ids) async {
    try {
      final batch = _db.batch();
      for (final id in ids) {
        batch.delete(collection.doc(id));
      }
      await batch.commit();
      debugPrint('[$runtimeType] Batch deleted ${ids.length} documents');
      return const RepositoryResult.success(null);
    } catch (e) {
      debugPrint('[$runtimeType] batchDelete error: $e');
      return RepositoryResult.failure(e.toString());
    }
  }

  // ─── Pagination ─────────────────────────────────────────────────────────

  /// Get a page of documents with cursor-based pagination.
  Future<RepositoryResult<List<T>>> getPage({
    int pageSize = 20,
    DocumentSnapshot? startAfter,
    Query<Map<String, dynamic>>? query,
    String orderBy = 'createdAt',
    bool descending = true,
  }) async {
    try {
      var q = query ?? collection;
      q = q.orderBy(orderBy, descending: descending).limit(pageSize);

      if (startAfter != null) {
        q = q.startAfterDocument(startAfter);
      }

      final snapshot = await q.get();
      final items = snapshot.docs
          .map((doc) => fromFirestore(doc.id, doc.data()))
          .toList();
      return RepositoryResult.success(items);
    } catch (e) {
      debugPrint('[$runtimeType] getPage error: $e');
      return RepositoryResult.failure(e.toString());
    }
  }

  // ─── Count ──────────────────────────────────────────────────────────────

  /// Count documents matching a query.
  Future<int> count({
    String? field,
    dynamic value,
  }) async {
    try {
      var query = collection as Query<Map<String, dynamic>>;
      if (field != null) {
        query = query.where(field, isEqualTo: value);
      }
      final snapshot = await query.count().get();
      return snapshot.count;
    } catch (e) {
      debugPrint('[$runtimeType] count error: $e');
      return 0;
    }
  }
}
