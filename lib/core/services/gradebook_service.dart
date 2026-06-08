import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_constants.dart';

class GradebookService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ─── Gradebook Categories ──────────────────────────────────────────────

  Future<String> createCategory({
    required String organizationId,
    required String classId,
    required String name,
    required String type,
    required double weight,
  }) async {
    try {
      final docRef = await _firestore
          .collection(AppConstants.gradebookCategoriesCollection)
          .add({
        'organizationId': organizationId,
        'classId': classId,
        'name': name,
        'type': type,
        'weight': weight,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateCategory({
    required String categoryId,
    String? name,
    String? type,
    double? weight,
  }) async {
    try {
      final data = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (name != null) data['name'] = name;
      if (type != null) data['type'] = type;
      if (weight != null) data['weight'] = weight;

      await _firestore
          .collection(AppConstants.gradebookCategoriesCollection)
          .doc(categoryId)
          .update(data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    try {
      // Delete all entries in this category
      final entriesSnapshot = await _firestore
          .collection(AppConstants.gradebookEntriesCollection)
          .where('categoryId', isEqualTo: categoryId)
          .get();

      final batch = _firestore.batch();
      for (final doc in entriesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_firestore
          .collection(AppConstants.gradebookCategoriesCollection)
          .doc(categoryId));
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  Stream<QuerySnapshot> getCategoriesByClassStream(
      String organizationId, String classId) {
    return _firestore
        .collection(AppConstants.gradebookCategoriesCollection)
        .where('organizationId', isEqualTo: organizationId)
        .where('classId', isEqualTo: classId)
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  // ─── Gradebook Entries ─────────────────────────────────────────────────

  Future<String> createEntry({
    required String organizationId,
    required String classId,
    required String studentId,
    required String categoryId,
    required String title,
    required double score,
    required double maxScore,
    String? examId,
    String? assignmentId,
    String? gradedBy,
  }) async {
    try {
      final docRef = await _firestore
          .collection(AppConstants.gradebookEntriesCollection)
          .add({
        'organizationId': organizationId,
        'classId': classId,
        'studentId': studentId,
        'categoryId': categoryId,
        'title': title,
        'score': score,
        'maxScore': maxScore,
        'examId': examId,
        'assignmentId': assignmentId,
        'gradedBy': gradedBy,
        'feedback': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateEntry({
    required String entryId,
    String? title,
    double? score,
    double? maxScore,
    String? feedback,
  }) async {
    try {
      final data = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (title != null) data['title'] = title;
      if (score != null) data['score'] = score;
      if (maxScore != null) data['maxScore'] = maxScore;
      if (feedback != null) data['feedback'] = feedback;

      await _firestore
          .collection(AppConstants.gradebookEntriesCollection)
          .doc(entryId)
          .update(data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteEntry(String entryId) async {
    try {
      await _firestore
          .collection(AppConstants.gradebookEntriesCollection)
          .doc(entryId)
          .delete();
    } catch (e) {
      rethrow;
    }
  }

  Stream<QuerySnapshot> getEntriesByClassStream(
      String organizationId, String classId) {
    return _firestore
        .collection(AppConstants.gradebookEntriesCollection)
        .where('organizationId', isEqualTo: organizationId)
        .where('classId', isEqualTo: classId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getEntriesByStudentStream(
      String organizationId, String classId, String studentId) {
    return _firestore
        .collection(AppConstants.gradebookEntriesCollection)
        .where('organizationId', isEqualTo: organizationId)
        .where('classId', isEqualTo: classId)
        .where('studentId', isEqualTo: studentId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getEntriesByCategoryStream(
      String organizationId, String classId, String categoryId) {
    return _firestore
        .collection(AppConstants.gradebookEntriesCollection)
        .where('organizationId', isEqualTo: organizationId)
        .where('classId', isEqualTo: classId)
        .where('categoryId', isEqualTo: categoryId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ─── Student Grade Summary ─────────────────────────────────────────────

  Future<Map<String, dynamic>> getStudentGradeSummary({
    required String organizationId,
    required String classId,
    required String studentId,
  }) async {
    try {
      // Fetch all categories for this class
      final categoriesSnapshot = await _firestore
          .collection(AppConstants.gradebookCategoriesCollection)
          .where('organizationId', isEqualTo: organizationId)
          .where('classId', isEqualTo: classId)
          .get();

      // Fetch all entries for this student in this class
      final entriesSnapshot = await _firestore
          .collection(AppConstants.gradebookEntriesCollection)
          .where('organizationId', isEqualTo: organizationId)
          .where('classId', isEqualTo: classId)
          .where('studentId', isEqualTo: studentId)
          .get();

      // Group entries by category
      final entriesByCategory = <String, List<QueryDocumentSnapshot>>{};
      for (final doc in entriesSnapshot.docs) {
        final categoryId = doc.data()['categoryId'] as String? ?? '';
        entriesByCategory.putIfAbsent(categoryId, () => []).add(doc);
      }

      // Build category summaries
      final categories = <Map<String, dynamic>>[];
      double totalWeight = 0.0;
      double weightedSum = 0.0;
      int totalEntries = entriesSnapshot.docs.length;

      for (final catDoc in categoriesSnapshot.docs) {
        final catData = catDoc.data();
        final catId = catDoc.id;
        final catName = catData['name'] as String? ?? '';
        final catWeight = (catData['weight'] as num?)?.toDouble() ?? 0.0;

        final catEntries = entriesByCategory[catId] ?? [];

        double catSum = 0.0;
        double catMaxSum = 0.0;
        for (final entryDoc in catEntries) {
          final entryData = entryDoc.data();
          catSum += (entryData['score'] as num?)?.toDouble() ?? 0.0;
          catMaxSum += (entryData['maxScore'] as num?)?.toDouble() ?? 0.0;
        }

        final catAverage = catMaxSum > 0 ? (catSum / catMaxSum) * 100 : 0.0;

        categories.add({
          'name': catName,
          'weight': catWeight,
          'average': double.parse(catAverage.toStringAsFixed(1)),
          'entries': catEntries.length,
        });

        weightedSum += (catAverage / 100) * catWeight;
        totalWeight += catWeight;
      }

      final weightedAverage =
          totalWeight > 0 ? (weightedSum / totalWeight) * 100 : 0.0;

      // Calculate class rank: compare this student's weighted average against all
      // students in the class
      int classRank = 0;

      // Get all unique student IDs in this class from entries
      final allEntriesSnapshot = await _firestore
          .collection(AppConstants.gradebookEntriesCollection)
          .where('organizationId', isEqualTo: organizationId)
          .where('classId', isEqualTo: classId)
          .get();

      // Group all entries by student
      final allEntriesByStudent = <String, List<QueryDocumentSnapshot>>{};
      for (final doc in allEntriesSnapshot.docs) {
        final sId = doc.data()['studentId'] as String? ?? '';
        allEntriesByStudent.putIfAbsent(sId, () => []).add(doc);
      }

      // Calculate each student's weighted average
      final studentAverages = <MapEntry<String, double>>[];
      for (final studentEntry in allEntriesByStudent.entries) {
        final sId = studentEntry.key;
        final sDocs = studentEntry.value;

        // Group this student's entries by category
        final sEntriesByCategory = <String, List<QueryDocumentSnapshot>>{};
        for (final doc in sDocs) {
          final cId = doc.data()['categoryId'] as String? ?? '';
          sEntriesByCategory.putIfAbsent(cId, () => []).add(doc);
        }

        double sWeightedSum = 0.0;
        double sTotalWeight = 0.0;

        for (final catDoc in categoriesSnapshot.docs) {
          final catData = catDoc.data();
          final catId = catDoc.id;
          final catWeight = (catData['weight'] as num?)?.toDouble() ?? 0.0;

          final sCatEntries = sEntriesByCategory[catId] ?? [];

          double sCatSum = 0.0;
          double sCatMaxSum = 0.0;
          for (final entryDoc in sCatEntries) {
            final entryData = entryDoc.data();
            sCatSum += (entryData['score'] as num?)?.toDouble() ?? 0.0;
            sCatMaxSum += (entryData['maxScore'] as num?)?.toDouble() ?? 0.0;
          }

          final sCatAverage = sCatMaxSum > 0 ? (sCatSum / sCatMaxSum) * 100 : 0.0;
          sWeightedSum += (sCatAverage / 100) * catWeight;
          sTotalWeight += catWeight;
        }

        final sWeightedAverage =
            sTotalWeight > 0 ? (sWeightedSum / sTotalWeight) * 100 : 0.0;

        studentAverages.add(MapEntry(sId, sWeightedAverage));
      }

      // Sort descending by average to determine rank
      studentAverages.sort((a, b) => b.value.compareTo(a.value));

      for (int i = 0; i < studentAverages.length; i++) {
        if (studentAverages[i].key == studentId) {
          classRank = i + 1;
          break;
        }
      }

      return {
        'weightedAverage': double.parse(weightedAverage.toStringAsFixed(1)),
        'categories': categories,
        'totalEntries': totalEntries,
        'classRank': classRank,
      };
    } catch (e) {
      rethrow;
    }
  }
}
