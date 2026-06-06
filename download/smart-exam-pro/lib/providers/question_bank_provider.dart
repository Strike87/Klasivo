import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/services/question_bank_service.dart';

// ==================== SERVICE PROVIDER ====================

final questionBankServiceProvider = Provider<QuestionBankService>((ref) {
  return QuestionBankService();
});

// ==================== STREAM PROVIDERS ====================

/// Stream all bank questions for the current teacher
final questionBankStreamProvider = StreamProvider<QuerySnapshot>((ref) {
  final teacherId = ref.watch(teacherIdForBankProvider);
  if (teacherId == null) {
    return const Stream.empty();
  }
  return ref.read(questionBankServiceProvider).getQuestionsStream(teacherId);
});

/// Stream bank questions filtered by subject
final questionBankBySubjectProvider = StreamProvider.family<QuerySnapshot, String>((ref, subject) {
  final teacherId = ref.watch(teacherIdForBankProvider);
  if (teacherId == null) return const Stream.empty();
  return ref.read(questionBankServiceProvider).getQuestionsBySubject(teacherId, subject);
});

/// Stream bank questions filtered by difficulty
final questionBankByDifficultyProvider = StreamProvider.family<QuerySnapshot, String>((ref, difficulty) {
  final teacherId = ref.watch(teacherIdForBankProvider);
  if (teacherId == null) return const Stream.empty();
  return ref.read(questionBankServiceProvider).getQuestionsByDifficulty(teacherId, difficulty);
});

// ==================== STATE PROVIDERS ====================

/// Current teacher ID for bank queries
final teacherIdForBankProvider = StateProvider<String?>((ref) => null);

/// Selected subject filter
final bankSubjectFilterProvider = StateProvider<String?>((ref) => null);

/// Selected difficulty filter
final bankDifficultyFilterProvider = StateProvider<String?>((ref) => null);

/// Selected type filter
final bankTypeFilterProvider = StateProvider<String?>((ref) => null);

/// Search query
final bankSearchQueryProvider = StateProvider<String>((ref) => '');

/// Selected bank questions (for bulk import to exam)
final selectedBankQuestionsProvider = StateProvider<Set<String>>((ref) => {});

/// Target exam ID for importing bank questions
final bankImportExamIdProvider = StateProvider<String?>((ref) => null);

// ==================== DATA MODELS ====================

class QuestionBankData {
  final String id;
  final String? institutionId;
  final String? teacherId;
  final String? stageId;
  final String? gradeId;
  final String? classId;
  final String subject;
  final String type;
  final String difficulty;
  final String text;
  final List<String> options;
  final String correctAnswer;
  final List<String> tags;
  final int marks;
  final int usageCount;
  final DateTime? createdAt;

  QuestionBankData({
    required this.id,
    this.institutionId,
    this.teacherId,
    this.stageId,
    this.gradeId,
    this.classId,
    this.subject = 'General',
    this.type = 'mcq',
    this.difficulty = 'medium',
    this.text = '',
    this.options = const [],
    this.correctAnswer = '',
    this.tags = const [],
    this.marks = 1,
    this.usageCount = 0,
    this.createdAt,
  });

  factory QuestionBankData.fromFirestore(Map<String, dynamic> data) {
    return QuestionBankData(
      id: data['id'] as String? ?? '',
      institutionId: data['institutionId'] as String?,
      teacherId: data['teacherId'] as String?,
      stageId: data['stageId'] as String?,
      gradeId: data['gradeId'] as String?,
      classId: data['classId'] as String?,
      subject: data['subject'] as String? ?? 'General',
      type: data['type'] as String? ?? 'mcq',
      difficulty: data['difficulty'] as String? ?? 'medium',
      text: data['text'] as String? ?? '',
      options: (data['options'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      correctAnswer: data['correctAnswer'] as String? ?? '',
      tags: (data['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      marks: data['marks'] as int? ?? 1,
      usageCount: data['usageCount'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'institutionId': institutionId ?? 'default',
      'teacherId': teacherId,
      'stageId': stageId,
      'gradeId': gradeId,
      'classId': classId,
      'subject': subject,
      'type': type,
      'difficulty': difficulty,
      'text': text,
      'options': options,
      'correctAnswer': correctAnswer,
      'tags': tags,
      'marks': marks,
      'usageCount': usageCount,
    };
  }

  String get typeLabel {
    switch (type) {
      case 'mcq':
        return 'Multiple Choice';
      case 'true_false':
        return 'True / False';
      case 'short_answer':
        return 'Short Answer';
      default:
        return type;
    }
  }

  String get difficultyLabel {
    switch (difficulty) {
      case 'easy':
        return 'Easy';
      case 'medium':
        return 'Medium';
      case 'hard':
        return 'Hard';
      default:
        return difficulty;
    }
  }

  int get difficultyColor {
    switch (difficulty) {
      case 'easy':
        return 0xFF4CAF50; // Green
      case 'medium':
        return 0xFFFF9800; // Orange
      case 'hard':
        return 0xFFF44336; // Red
      default:
        return 0xFF9E9E9E; // Grey
    }
  }
}

/// Computed list of question bank data
final questionBankListProvider = Provider<List<QuestionBankData>>((ref) {
  final stream = ref.watch(questionBankStreamProvider);
  final subjectFilter = ref.watch(bankSubjectFilterProvider);
  final difficultyFilter = ref.watch(bankDifficultyFilterProvider);
  final typeFilter = ref.watch(bankTypeFilterProvider);
  final searchQuery = ref.watch(bankSearchQueryProvider);

  return stream.when(
    data: (snapshot) {
      var questions = snapshot.docs
          .map((doc) => QuestionBankData.fromFirestore(doc.data() as Map<String, dynamic>))
          .toList();

      // Apply filters
      if (subjectFilter != null) {
        questions = questions.where((q) => q.subject == subjectFilter).toList();
      }
      if (difficultyFilter != null) {
        questions = questions.where((q) => q.difficulty == difficultyFilter).toList();
      }
      if (typeFilter != null) {
        questions = questions.where((q) => q.type == typeFilter).toList();
      }

      // Apply search
      if (searchQuery.isNotEmpty) {
        final lowerQuery = searchQuery.toLowerCase();
        questions = questions.where((q) {
          return q.text.toLowerCase().contains(lowerQuery) ||
              q.subject.toLowerCase().contains(lowerQuery) ||
              q.tags.any((t) => t.toLowerCase().contains(lowerQuery));
        }).toList();
      }

      return questions;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Total bank question count
final questionBankCountProvider = Provider<int>((ref) {
  return ref.watch(questionBankListProvider).length;
});

/// Available subjects (for filter dropdown)
final bankSubjectsProvider = FutureProvider<List<String>>((ref) async {
  final teacherId = ref.read(teacherIdForBankProvider);
  if (teacherId == null) return [];
  return ref.read(questionBankServiceProvider).getSubjects(teacherId);
});

/// Question count by subject
final bankCountBySubjectProvider = FutureProvider<Map<String, int>>((ref) async {
  final teacherId = ref.read(teacherIdForBankProvider);
  if (teacherId == null) return {};
  return ref.read(questionBankServiceProvider).getCountBySubject(teacherId);
});
