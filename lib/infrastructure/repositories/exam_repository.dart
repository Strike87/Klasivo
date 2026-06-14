import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/config/app_constants.dart';
import '../firebase/firebase_repository.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// KLASIVO EXAM REPOSITORY — IExamRepository + FirestoreExamRepository
//
// Domain-driven exam data access with:
// - CRUD operations for exams and questions
// - Complex queries (by class, subject, status, teacher)
// - Real-time streaming for active exams
// - Batch operations for question management
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Domain Models ──────────────────────────────────────────────────────────

class ExamDocument implements FirebaseDocument {
  @override
  final String id;
  final String title;
  final String? description;
  final String classId;
  final String subjectId;
  final String teacherId;
  final String organizationId;
  final String status; // draft, published, active, completed
  final int duration; // in minutes
  final double totalMarks;
  final double passingMarks;
  final bool shuffleQuestions;
  final bool shuffleOptions;
  final bool showResults;
  final DateTime? startTime;
  final DateTime? endTime;
  final int questionCount;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  const ExamDocument({
    required this.id,
    required this.title,
    this.description,
    required this.classId,
    required this.subjectId,
    required this.teacherId,
    required this.organizationId,
    this.status = AppConstants.statusDraft,
    this.duration = 30,
    this.totalMarks = 100,
    this.passingMarks = 50,
    this.shuffleQuestions = false,
    this.shuffleOptions = false,
    this.showResults = true,
    this.startTime,
    this.endTime,
    this.questionCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory ExamDocument.fromFirestore(String id, Map<String, dynamic> data) {
    return ExamDocument(
      id: id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String?,
      classId: data['classId'] as String? ?? '',
      subjectId: data['subjectId'] as String? ?? '',
      teacherId: data['teacherId'] as String? ?? '',
      organizationId: data['organizationId'] as String? ?? '',
      status: data['status'] as String? ?? AppConstants.statusDraft,
      duration: data['duration'] as int? ?? 30,
      totalMarks: (data['totalMarks'] as num?)?.toDouble() ?? 100,
      passingMarks: (data['passingMarks'] as num?)?.toDouble() ?? 50,
      shuffleQuestions: data['shuffleQuestions'] as bool? ?? false,
      shuffleOptions: data['shuffleOptions'] as bool? ?? false,
      showResults: data['showResults'] as bool? ?? true,
      startTime: (data['startTime'] as Timestamp?)?.toDate(),
      endTime: (data['endTime'] as Timestamp?)?.toDate(),
      questionCount: data['questionCount'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  @override
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'classId': classId,
      'subjectId': subjectId,
      'teacherId': teacherId,
      'organizationId': organizationId,
      'status': status,
      'duration': duration,
      'totalMarks': totalMarks,
      'passingMarks': passingMarks,
      'shuffleQuestions': shuffleQuestions,
      'shuffleOptions': shuffleOptions,
      'showResults': showResults,
      'startTime': startTime != null ? Timestamp.fromDate(startTime!) : null,
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'questionCount': questionCount,
    };
  }
}

class QuestionDocument implements FirebaseDocument {
  @override
  final String id;
  final String examId;
  final String type; // multiple_choice, true_false, short_answer
  final String text;
  final List<String> options;
  final int correctOptionIndex;
  final String? correctAnswer; // For short_answer
  final double marks;
  final String difficulty; // easy, medium, hard
  final String? explanation;
  final int order;
  @override
  final DateTime? createdAt;
  @override
  final DateTime? updatedAt;

  const QuestionDocument({
    required this.id,
    required this.examId,
    required this.type,
    required this.text,
    this.options = const [],
    this.correctOptionIndex = 0,
    this.correctAnswer,
    this.marks = 1,
    this.difficulty = AppConstants.difficultyMedium,
    this.explanation,
    this.order = 0,
    this.createdAt,
    this.updatedAt,
  });

  @override
  Map<String, dynamic> toFirestore() {
    return {
      'examId': examId,
      'type': type,
      'text': text,
      'options': options,
      'correctOptionIndex': correctOptionIndex,
      'correctAnswer': correctAnswer,
      'marks': marks,
      'difficulty': difficulty,
      'explanation': explanation,
      'order': order,
    };
  }
}

// ─── Interface ──────────────────────────────────────────────────────────────

abstract class IExamRepository {
  Future<RepositoryResult<ExamDocument>> getExam(String examId);
  Future<RepositoryResult<List<ExamDocument>>> getExamsByClass(String classId);
  Future<RepositoryResult<List<ExamDocument>>> getExamsByTeacher(String teacherId);
  Future<RepositoryResult<List<ExamDocument>>> getExamsByStatus(String status);
  Future<RepositoryResult<String>> createExam(ExamDocument exam);
  Future<RepositoryResult<void>> updateExam(String examId, Map<String, dynamic> data);
  Future<RepositoryResult<void>> deleteExam(String examId);
  Stream<List<ExamDocument>> streamActiveExams(String classId);
  Future<RepositoryResult<List<QuestionDocument>>> getQuestions(String examId);
  Future<RepositoryResult<void>> saveQuestions(String examId, List<QuestionDocument> questions);
}

// ─── Firestore Implementation ───────────────────────────────────────────────

class FirestoreExamRepository extends FirebaseRepository<ExamDocument>
    implements IExamRepository {
  @override
  String get collectionPath => AppConstants.examsCollection;

  @override
  ExamDocument fromFirestore(String id, Map<String, dynamic> data) {
    return ExamDocument.fromFirestore(id, data);
  }

  @override
  Future<RepositoryResult<ExamDocument>> getExam(String examId) {
    return getById(examId);
  }

  @override
  Future<RepositoryResult<List<ExamDocument>>> getExamsByClass(String classId) {
    return getWhere(field: 'classId', value: classId);
  }

  @override
  Future<RepositoryResult<List<ExamDocument>>> getExamsByTeacher(String teacherId) {
    return getWhere(field: 'teacherId', value: teacherId);
  }

  @override
  Future<RepositoryResult<List<ExamDocument>>> getExamsByStatus(String status) {
    return getWhere(field: 'status', value: status);
  }

  @override
  Future<RepositoryResult<String>> createExam(ExamDocument exam) {
    return create(exam);
  }

  @override
  Future<RepositoryResult<void>> updateExam(String examId, Map<String, dynamic> data) {
    return update(examId, data);
  }

  @override
  Future<RepositoryResult<void>> deleteExam(String examId) {
    return delete(examId);
  }

  @override
  Stream<List<ExamDocument>> streamActiveExams(String classId) {
    return streamWhere(field: 'classId', value: classId).map((exams) {
      return exams.where((e) => e.status == AppConstants.statusActive).toList();
    });
  }

  @override
  Future<RepositoryResult<List<QuestionDocument>>> getQuestions(String examId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(AppConstants.examsCollection)
          .doc(examId)
          .collection(AppConstants.questionsCollection)
          .orderBy('order')
          .get();

      final questions = snapshot.docs.map((doc) {
        final data = doc.data();
        return QuestionDocument(
          id: doc.id,
          examId: examId,
          type: data['type'] as String? ?? AppConstants.questionTypeMultipleChoice,
          text: data['text'] as String? ?? '',
          options: List<String>.from(data['options'] as List? ?? []),
          correctOptionIndex: data['correctOptionIndex'] as int? ?? 0,
          correctAnswer: data['correctAnswer'] as String?,
          marks: (data['marks'] as num?)?.toDouble() ?? 1,
          difficulty: data['difficulty'] as String? ?? AppConstants.difficultyMedium,
          explanation: data['explanation'] as String?,
          order: data['order'] as int? ?? 0,
          createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
          updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
        );
      }).toList();

      return RepositoryResult.success(questions);
    } catch (e) {
      return RepositoryResult.failure(e.toString());
    }
  }

  @override
  Future<RepositoryResult<void>> saveQuestions(
    String examId,
    List<QuestionDocument> questions,
  ) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final questionsRef = FirebaseFirestore.instance
          .collection(AppConstants.examsCollection)
          .doc(examId)
          .collection(AppConstants.questionsCollection);

      // Delete existing questions
      final existing = await questionsRef.get();
      for (final doc in existing.docs) {
        batch.delete(doc.reference);
      }

      // Add new questions
      for (var i = 0; i < questions.length; i++) {
        final q = questions[i];
        final docRef = questionsRef.doc();
        batch.set(docRef, {
          ...q.toFirestore(),
          'order': i,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update question count on the exam
      final examRef = FirebaseFirestore.instance
          .collection(AppConstants.examsCollection)
          .doc(examId);
      batch.update(examRef, {
        'questionCount': questions.length,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return const RepositoryResult.success(null);
    } catch (e) {
      return RepositoryResult.failure(e.toString());
    }
  }
}
