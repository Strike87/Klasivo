import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/config/app_constants.dart';
import '../firebase/firebase_repository.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO ATTENDANCE REPOSITORY — IAttendanceRepository
//
// Manages attendance data with:
// - Per-session attendance records
// - Bulk mark operations
// - Date-range queries
// - Class and student attendance summaries
// - Real-time streaming for live attendance tracking
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Domain Model ───────────────────────────────────────────────────────────

class AttendanceRecord implements FirebaseDocument {
  @override
  final String id;
  final String studentId;
  final String classId;
  final String subjectId;
  final String organizationId;
  final String status; // present, absent, late, excused
  final String markedBy; // teacher user ID
  final DateTime date;
  final String? note;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  const AttendanceRecord({
    required this.id,
    required this.studentId,
    required this.classId,
    required this.subjectId,
    required this.organizationId,
    this.status = AppConstants.attendanceStatusPresent,
    required this.markedBy,
    required this.date,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  factory AttendanceRecord.fromFirestore(String id, Map<String, dynamic> data) {
    return AttendanceRecord(
      id: id,
      studentId: data['studentId'] as String? ?? '',
      classId: data['classId'] as String? ?? '',
      subjectId: data['subjectId'] as String? ?? '',
      organizationId: data['organizationId'] as String? ?? '',
      status: data['status'] as String? ?? AppConstants.attendanceStatusPresent,
      markedBy: data['markedBy'] as String? ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: data['note'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  @override
  Map<String, dynamic> toFirestore() {
    return {
      'studentId': studentId,
      'classId': classId,
      'subjectId': subjectId,
      'organizationId': organizationId,
      'status': status,
      'markedBy': markedBy,
      'date': Timestamp.fromDate(date),
      'note': note,
    };
  }
}

/// Summary of attendance for a class on a given date.
class AttendanceSession {
  final String classId;
  final String subjectId;
  final DateTime date;
  final int totalStudents;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int excusedCount;

  const AttendanceSession({
    required this.classId,
    required this.subjectId,
    required this.date,
    required this.totalStudents,
    this.presentCount = 0,
    this.absentCount = 0,
    this.lateCount = 0,
    this.excusedCount = 0,
  });

  double get attendanceRate =>
      totalStudents > 0 ? (presentCount + lateCount + excusedCount) / totalStudents * 100 : 0;
}

// ─── Interface ──────────────────────────────────────────────────────────────

abstract class IAttendanceRepository {
  Future<RepositoryResult<AttendanceRecord>> getRecord(String recordId);
  Future<RepositoryResult<List<AttendanceRecord>>> getRecordsByClassDate(
    String classId,
    DateTime date,
  );
  Future<RepositoryResult<List<AttendanceRecord>>> getRecordsByStudent(
    String studentId, {
    DateTime? startDate,
    DateTime? endDate,
  });
  Future<RepositoryResult<List<AttendanceRecord>>> getRecordsByDateRange(
    String classId, {
    required DateTime startDate,
    required DateTime endDate,
  });
  Future<RepositoryResult<String>> markAttendance(AttendanceRecord record);
  Future<RepositoryResult<void>> bulkMarkAttendance(List<AttendanceRecord> records);
  Future<RepositoryResult<void>> updateRecord(String recordId, Map<String, dynamic> data);
  Future<RepositoryResult<AttendanceSession>> getSessionSummary(
    String classId,
    String subjectId,
    DateTime date,
  );
  Stream<List<AttendanceRecord>> streamClassAttendance(String classId, DateTime date);
}

// ─── Firestore Implementation ───────────────────────────────────────────────

class FirestoreAttendanceRepository extends FirebaseRepository<AttendanceRecord>
    implements IAttendanceRepository {
  @override
  String get collectionPath => AppConstants.attendanceCollection;

  @override
  AttendanceRecord fromFirestore(String id, Map<String, dynamic> data) {
    return AttendanceRecord.fromFirestore(id, data);
  }

  @override
  Future<RepositoryResult<AttendanceRecord>> getRecord(String recordId) {
    return getById(recordId);
  }

  @override
  Future<RepositoryResult<List<AttendanceRecord>>> getRecordsByClassDate(
    String classId,
    DateTime date,
  ) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await collection
          .where('classId', isEqualTo: classId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      final records = snapshot.docs
          .map((doc) => fromFirestore(doc.id, doc.data()))
          .toList();
      return RepositoryResult.success(records);
    } catch (e) {
      debugPrint('[AttendanceRepository] getRecordsByClassDate error: $e');
      return RepositoryResult.failure(e.toString());
    }
  }

  @override
  Future<RepositoryResult<List<AttendanceRecord>>> getRecordsByStudent(
    String studentId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = collection.where('studentId', isEqualTo: studentId);

      if (startDate != null) {
        query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final snapshot = await query.orderBy('date', descending: true).get();
      final records = snapshot.docs
          .map((doc) => fromFirestore(doc.id, doc.data()))
          .toList();
      return RepositoryResult.success(records);
    } catch (e) {
      debugPrint('[AttendanceRepository] getRecordsByStudent error: $e');
      return RepositoryResult.failure(e.toString());
    }
  }

  @override
  Future<RepositoryResult<List<AttendanceRecord>>> getRecordsByDateRange(
    String classId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final snapshot = await collection
          .where('classId', isEqualTo: classId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('date', descending: true)
          .get();

      final records = snapshot.docs
          .map((doc) => fromFirestore(doc.id, doc.data()))
          .toList();
      return RepositoryResult.success(records);
    } catch (e) {
      debugPrint('[AttendanceRepository] getRecordsByDateRange error: $e');
      return RepositoryResult.failure(e.toString());
    }
  }

  @override
  Future<RepositoryResult<String>> markAttendance(AttendanceRecord record) {
    return create(record);
  }

  @override
  Future<RepositoryResult<void>> bulkMarkAttendance(
    List<AttendanceRecord> records,
  ) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final record in records) {
        final docRef = collection.doc();
        final data = record.toFirestore();
        batch.set(docRef, {
          ...data,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      debugPrint('[AttendanceRepository] Bulk marked ${records.length} records');
      return const RepositoryResult.success(null);
    } catch (e) {
      debugPrint('[AttendanceRepository] bulkMarkAttendance error: $e');
      return RepositoryResult.failure(e.toString());
    }
  }

  @override
  Future<RepositoryResult<void>> updateRecord(
    String recordId,
    Map<String, dynamic> data,
  ) {
    return update(recordId, data);
  }

  @override
  Future<RepositoryResult<AttendanceSession>> getSessionSummary(
    String classId,
    String subjectId,
    DateTime date,
  ) async {
    try {
      final result = await getRecordsByClassDate(classId, date);

      if (result.isFailure || result.data == null) {
        return const RepositoryResult.failure('Failed to load attendance');
      }

      final records = result.data!;
      final subjectRecords = records.where((r) => r.subjectId == subjectId).toList();

      final session = AttendanceSession(
        classId: classId,
        subjectId: subjectId,
        date: date,
        totalStudents: subjectRecords.length,
        presentCount: subjectRecords.where((r) => r.status == AppConstants.attendanceStatusPresent).length,
        absentCount: subjectRecords.where((r) => r.status == AppConstants.attendanceStatusAbsent).length,
        lateCount: subjectRecords.where((r) => r.status == AppConstants.attendanceStatusLate).length,
        excusedCount: subjectRecords.where((r) => r.status == AppConstants.attendanceStatusExcused).length,
      );

      return RepositoryResult.success(session);
    } catch (e) {
      return RepositoryResult.failure(e.toString());
    }
  }

  @override
  Stream<List<AttendanceRecord>> streamClassAttendance(
    String classId,
    DateTime date,
  ) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return collection
        .where('classId', isEqualTo: classId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }
}
