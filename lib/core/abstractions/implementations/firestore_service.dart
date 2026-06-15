import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../firebase_service.dart';
import '../../services/firebase_service.dart' as native;

/// Production implementation of [IFirebaseService] that delegates to the
/// static methods on the existing [native.FirebaseService] and the
/// FirebaseFirestore SDK for streaming operations.
class FirestoreService implements IFirebaseService {
  const FirestoreService();

  // ─── Document CRUD ──────────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>?> getDocument(
    String collection,
    String docId,
  ) async {
    final snapshot =
        await native.FirebaseService.getDocument(collection, docId);
    if (!snapshot.exists) return null;
    return snapshot.data();
  }

  @override
  Future<void> setDocument(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) =>
      native.FirebaseService.setDocument(collection, docId, data);

  @override
  Future<void> updateDocument(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) =>
      native.FirebaseService.updateDocument(collection, docId, data);

  @override
  Future<void> deleteDocument(String collection, String docId) =>
      native.FirebaseService.deleteDocument(collection, docId);

  // ─── Real-time Streams ──────────────────────────────────────────────────

  @override
  Stream<Map<String, dynamic>?> documentStream(
    String collection,
    String docId,
  ) {
    return FirebaseFirestore.instance
        .collection(collection)
        .doc(docId)
        .snapshots()
        .map((snapshot) => snapshot.data());
  }

  @override
  Stream<List<Map<String, dynamic>>> collectionStream(
    String collection, {
    List<List<dynamic>>? where,
    String? orderBy,
    bool? descending,
    int? limit,
  }) {
    Query query = FirebaseFirestore.instance.collection(collection);

    // Apply where clauses.
    if (where != null) {
      for (final clause in where) {
        if (clause.length != 3) continue;
        final field = clause[0] as String;
        final operator = clause[1] as String;
        final value = clause[2];
        query = _applyWhere(query, field, operator, value);
      }
    }

    // Apply ordering.
    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending ?? false);
    }

    // Apply limit.
    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList());
  }

  // ─── Add & Batch ────────────────────────────────────────────────────────

  @override
  Future<String> addDocument(
    String collection,
    Map<String, dynamic> data,
  ) async {
    final ref = await FirebaseFirestore.instance
        .collection(collection)
        .add(data);
    return ref.id;
  }

  @override
  Future<void> batchWrite(List<WriteOperation> operations) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final op in operations) {
      final ref =
          FirebaseFirestore.instance.collection(op.collection).doc(op.docId);
      switch (op.type) {
        case 'set':
          batch.set(ref, op.data ?? {});
          break;
        case 'update':
          batch.update(ref, op.data ?? {});
          break;
        case 'delete':
          batch.delete(ref);
          break;
        default:
          throw ArgumentError('Unknown WriteOperation type: ${op.type}');
      }
    }
    await batch.commit();
  }

  // ─── Query Helpers ──────────────────────────────────────────────────────

  /// Applies a single where clause to a Firestore [Query].
  Query _applyWhere(Query query, String field, String operator, dynamic value) {
    switch (operator) {
      case '==':
        return query.where(field, isEqualTo: value);
      case '<':
        return query.where(field, isLessThan: value);
      case '<=':
        return query.where(field, isLessThanOrEqualTo: value);
      case '>':
        return query.where(field, isGreaterThan: value);
      case '>=':
        return query.where(field, isGreaterThanOrEqualTo: value);
      case 'array-contains':
        return query.where(field, arrayContains: value);
      default:
        throw ArgumentError('Unsupported Firestore operator: $operator');
    }
  }
}
