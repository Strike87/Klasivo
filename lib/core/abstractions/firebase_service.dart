/// Describes a single write operation for [IFirebaseService.batchWrite].
class WriteOperation {
  /// Operation type: `'set'`, `'update'`, or `'delete'`.
  final String type;

  /// Firestore collection path.
  final String collection;

  /// Document ID within the collection.
  final String docId;

  /// Data payload for `'set'` and `'update'` operations.
  /// `null` for `'delete'`.
  final Map<String, dynamic>? data;

  const WriteOperation({
    required this.type,
    required this.collection,
    required this.docId,
    this.data,
  });
}

/// Abstract interface for Firebase / Firestore operations.
///
/// Provides a platform-agnostic API for CRUD operations, real-time streams,
/// and batch writes. Implementations may delegate to the real Firebase SDK
/// or an in-memory store for testing.
abstract class IFirebaseService {
  // ─── Document CRUD ──────────────────────────────────────────────────────

  /// Fetch a single document and return its data as a Map, or `null`
  /// if the document does not exist.
  Future<Map<String, dynamic>?> getDocument(
    String collection,
    String docId,
  );

  /// Set (overwrite) a document. If the document does not exist it is created.
  Future<void> setDocument(
    String collection,
    String docId,
    Map<String, dynamic> data,
  );

  /// Update an existing document with the given fields.
  Future<void> updateDocument(
    String collection,
    String docId,
    Map<String, dynamic> data,
  );

  /// Delete a document.
  Future<void> deleteDocument(String collection, String docId);

  // ─── Real-time Streams ──────────────────────────────────────────────────

  /// Stream a single document's data. Emits `null` when the document
  /// does not exist.
  Stream<Map<String, dynamic>?> documentStream(
    String collection,
    String docId,
  );

  /// Stream a collection with optional filters, ordering, and limit.
  ///
  /// [where] is a list of filter clauses where each inner list has the form
  /// `[field, operator, value]` — e.g. `[['role', '==', 'teacher']]`.
  /// Supported operators: `'=='`, `'<'`, `'<=`, `'>'`, `'>='`, `'array-contains'`.
  Stream<List<Map<String, dynamic>>> collectionStream(
    String collection, {
    List<List<dynamic>>? where,
    String? orderBy,
    bool? descending,
    int? limit,
  });

  // ─── Add & Batch ────────────────────────────────────────────────────────

  /// Add a new document with an auto-generated ID.
  /// Returns the generated document ID.
  Future<String> addDocument(
    String collection,
    Map<String, dynamic> data,
  );

  /// Execute multiple write operations in a single atomic batch.
  Future<void> batchWrite(List<WriteOperation> operations);
}
