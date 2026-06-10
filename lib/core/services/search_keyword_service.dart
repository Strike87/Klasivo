import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';

/// Service for managing search keywords on documents.
/// Adds a `searchKeywords` array field to documents for prefix-based search.
/// Example: "Grade 5" → ["g", "gr", "gra", "grad", "grade", "5"]
class SearchKeywordService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generate search keywords from a text string.
  /// Creates lowercase prefix tokens for each word up to 10 chars.
  List<String> generateKeywords(String text) {
    if (text.trim().isEmpty) return [];
    final keywords = <String>[];
    final words = text.toLowerCase().trim().split(RegExp(r'\s+'));

    for (final word in words) {
      // Add full word
      keywords.add(word);
      // Add prefixes (2 to word length, max 10)
      for (int i = 2; i <= word.length && i <= 10; i++) {
        keywords.add(word.substring(0, i));
      }
    }

    // Add the full lowercase string too
    keywords.add(text.toLowerCase().trim());

    return keywords.toSet().toList(); // Remove duplicates
  }

  /// Update search keywords on a document.
  /// Call this after creating or updating a document's name/title.
  Future<void> updateKeywords({
    required String collection,
    required String docId,
    required String searchText,
  }) async {
    try {
      final keywords = generateKeywords(searchText);
      await _firestore.collection(collection).doc(docId).update({
        'searchKeywords': keywords,
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Create search keywords map for embedding in a new document.
  /// Use this during document creation to include keywords from the start.
  Map<String, dynamic> keywordsField(String searchText) {
    return {'searchKeywords': generateKeywords(searchText)};
  }

  /// Search documents by keyword prefix matching.
  /// Uses Firestore `arrayContains` for efficient search.
  Stream<QuerySnapshot> search({
    required String collection,
    required String organizationId,
    required String query,
    int limit = 20,
  }) {
    final keyword = query.toLowerCase().trim();
    if (keyword.isEmpty) {
      return _firestore
          .collection(collection)
          .where('organizationId', isEqualTo: organizationId)
          .where('isArchived', isEqualTo: false)
          .limit(limit)
          .snapshots();
    }

    return _firestore
        .collection(collection)
        .where('organizationId', isEqualTo: organizationId)
        .where('isArchived', isEqualTo: false)
        .where('searchKeywords', arrayContains: keyword)
        .limit(limit)
        .snapshots();
  }

  /// Batch-update search keywords for all documents in a collection
  /// that are missing the searchKeywords field.
  Future<int> backfillKeywords({
    required String collection,
    required String nameField,
    String? organizationId,
  }) async {
    try {
      Query query = _firestore.collection(collection);
      if (organizationId != null) {
        query = query.where('organizationId', isEqualTo: organizationId);
      }

      final snapshot = await query.get();
      int updated = 0;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['searchKeywords'] == null) {
          final name = data[nameField] as String? ?? '';
          if (name.isNotEmpty) {
            batch.update(doc.reference, {'searchKeywords': generateKeywords(name)});
            updated++;
          }
        }
      }

      if (updated > 0) {
        // Firestore batches support max 500 operations
        await batch.commit();
      }

      return updated;
    } catch (e) {
      rethrow;
    }
  }
}
