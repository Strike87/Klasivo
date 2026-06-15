import 'dart:async';
import '../firebase_service.dart';

/// Mock implementation of [IFirebaseService] backed by in-memory maps.
///
/// Supports CRUD, real-time streams via [StreamController], and batch writes.
/// Stream controllers are created lazily and broadcast to all subscribers.
class MockFirebaseService implements IFirebaseService {
  /// In-memory store: collection → docId → data.
  final Map<String, Map<String, Map<String, dynamic>>> _store = {};

  /// Active stream controllers for document streams.
  final Map<String, StreamController<Map<String, dynamic>?>> _docControllers =
      {};

  /// Active stream controllers for collection streams.
  final Map<String, StreamController<List<Map<String, dynamic>>>>
      _colControllers = {};

  // ─── Internal Helpers ───────────────────────────────────────────────────

  Map<String, Map<String, dynamic>> _collection(String name) {
    return _store.putIfAbsent(name, () => {});
  }

  String _docKey(String collection, String docId) =>
      '$collection/$docId';

  void _notifyDoc(String collection, String docId) {
    final key = _docKey(collection, docId);
    final controller = _docControllers[key];
    if (controller != null && !controller.isClosed) {
      final data = _collection(collection)[docId];
      controller.add(data != null ? Map<String, dynamic>.from(data) : null);
    }
  }

  void _notifyCollection(String collection) {
    final controller = _colControllers[collection];
    if (controller != null && !controller.isClosed) {
      controller.add(
        _collection(collection)
            .values
            .map((d) => Map<String, dynamic>.from(d))
            .toList(),
      );
    }
  }

  // ─── Seed Data (for tests) ─────────────────────────────────────────────

  /// Seed a document directly into the in-memory store.
  void seedDocument(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) {
    _collection(collection)[docId] = Map<String, dynamic>.from(data);
  }

  /// Get raw document data (for assertions).
  Map<String, dynamic>? getDocumentData(String collection, String docId) {
    return _collection(collection)[docId];
  }

  /// Get all documents in a collection (for assertions).
  Map<String, Map<String, dynamic>> getCollectionData(String collection) {
    return Map<String, Map<String, dynamic>>.from(_collection(collection));
  }

  // ─── IFirebaseService ───────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>?> getDocument(
    String collection,
    String docId,
  ) async {
    final data = _collection(collection)[docId];
    return data != null ? Map<String, dynamic>.from(data) : null;
  }

  @override
  Future<void> setDocument(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    _collection(collection)[docId] = Map<String, dynamic>.from(data);
    _notifyDoc(collection, docId);
    _notifyCollection(collection);
  }

  @override
  Future<void> updateDocument(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    final existing = _collection(collection)[docId];
    if (existing == null) {
      throw Exception('Document $collection/$docId does not exist.');
    }
    existing.addAll(data);
    _notifyDoc(collection, docId);
    _notifyCollection(collection);
  }

  @override
  Future<void> deleteDocument(String collection, String docId) async {
    _collection(collection).remove(docId);
    _notifyDoc(collection, docId);
    _notifyCollection(collection);
  }

  @override
  Stream<Map<String, dynamic>?> documentStream(
    String collection,
    String docId,
  ) {
    final key = _docKey(collection, docId);
    final controller = _docControllers.putIfAbsent(
      key,
      () => StreamController<Map<String, dynamic>?>.broadcast(),
    );
    // Emit current value immediately.
    final data = _collection(collection)[docId];
    controller.add(data != null ? Map<String, dynamic>.from(data) : null);
    return controller.stream;
  }

  @override
  Stream<List<Map<String, dynamic>>> collectionStream(
    String collection, {
    List<List<dynamic>>? where,
    String? orderBy,
    bool? descending,
    int? limit,
  }) {
    final controller = _colControllers.putIfAbsent(
      collection,
      () => StreamController<List<Map<String, dynamic>>>.broadcast(),
    );

    // Build filtered list and emit.
    var docs = _collection(collection)
        .values
        .map((d) => Map<String, dynamic>.from(d))
        .toList();

    docs = _applyFilters(docs, where);

    if (orderBy != null) {
      docs.sort((a, b) {
        final av = a[orderBy];
        final bv = b[orderBy];
        final cmp = _compareValues(av, bv);
        return descending == true ? -cmp : cmp;
      });
    }

    if (limit != null) {
      docs = docs.take(limit).toList();
    }

    controller.add(docs);
    return controller.stream;
  }

  @override
  Future<String> addDocument(
    String collection,
    Map<String, dynamic> data,
  ) async {
    final docId = 'doc_${DateTime.now().microsecondsSinceEpoch}';
    await setDocument(collection, docId, data);
    return docId;
  }

  @override
  Future<void> batchWrite(List<WriteOperation> operations) async {
    for (final op in operations) {
      switch (op.type) {
        case 'set':
          await setDocument(op.collection, op.docId, op.data ?? {});
          break;
        case 'update':
          await updateDocument(op.collection, op.docId, op.data ?? {});
          break;
        case 'delete':
          await deleteDocument(op.collection, op.docId);
          break;
        default:
          throw ArgumentError('Unknown WriteOperation type: ${op.type}');
      }
    }
  }

  // ─── Filter Helpers ─────────────────────────────────────────────────────

  List<Map<String, dynamic>> _applyFilters(
    List<Map<String, dynamic>> docs,
    List<List<dynamic>>? where,
  ) {
    if (where == null || where.isEmpty) return docs;

    return docs.where((doc) {
      for (final clause in where) {
        if (clause.length != 3) continue;
        final field = clause[0] as String;
        final operator = clause[1] as String;
        final value = clause[2];
        final fieldValue = doc[field];

        if (!_evaluateOperator(fieldValue, operator, value)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  bool _evaluateOperator(dynamic fieldValue, String operator, dynamic value) {
    switch (operator) {
      case '==':
        return fieldValue == value;
      case '<':
        return _compareValues(fieldValue, value) < 0;
      case '<=':
        return _compareValues(fieldValue, value) <= 0;
      case '>':
        return _compareValues(fieldValue, value) > 0;
      case '>=':
        return _compareValues(fieldValue, value) >= 0;
      case 'array-contains':
        if (fieldValue is List) return fieldValue.contains(value);
        return false;
      default:
        return false;
    }
  }

  int _compareValues(dynamic a, dynamic b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    if (a is Comparable && b is Comparable) {
      return a.compareTo(b);
    }
    return 0;
  }

  // ─── Cleanup ────────────────────────────────────────────────────────────

  /// Close all stream controllers and clear the store.
  void reset() {
    for (final c in _docControllers.values) {
      c.close();
    }
    for (final c in _colControllers.values) {
      c.close();
    }
    _docControllers.clear();
    _colControllers.clear();
    _store.clear();
  }
}
