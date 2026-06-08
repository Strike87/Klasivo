import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config/app_constants.dart';
import '../core/services/question_bank_service.dart';
import 'auth_provider.dart';

final questionBankServiceProvider = Provider<QuestionBankService>((ref) => QuestionBankService());

final questionBankStreamProvider = StreamProvider<QuerySnapshot>((ref) {
  final teacherId = ref.watch(userIdProvider);
  if (teacherId == null || teacherId.isEmpty) {
    return const Stream.empty();
  }
  return ref.read(questionBankServiceProvider).getQuestionBankStream(teacherId);
});

final questionBankProvider = Provider<List<QuestionBankData>>((ref) {
  final asyncQuestions = ref.watch(questionBankStreamProvider);
  return asyncQuestions.when(
    data: (snapshot) => snapshot.docs.map((doc) => QuestionBankData.fromFirestore(doc)).toList(),
    loading: () => [],
    error: (e, st) { debugPrint('provider error: $e'); return []; },
  );
});

// Filter providers
final bankSubjectFilterProvider = StateProvider<String?>((ref) => null);
final bankDifficultyFilterProvider = StateProvider<String?>((ref) => null);
final bankTypeFilterProvider = StateProvider<String?>((ref) => null);

final filteredQuestionBankProvider = Provider<List<QuestionBankData>>((ref) {
  final questions = ref.watch(questionBankProvider);
  final subjectFilter = ref.watch(bankSubjectFilterProvider);
  final difficultyFilter = ref.watch(bankDifficultyFilterProvider);
  final typeFilter = ref.watch(bankTypeFilterProvider);

  return questions.where((q) {
    if (subjectFilter != null && q.subject != subjectFilter) return false;
    if (difficultyFilter != null && q.difficulty != difficultyFilter) return false;
    if (typeFilter != null && q.type != typeFilter) return false;
    return true;
  }).toList();
});

final bankSubjectsProvider = Provider<List<String>>((ref) {
  final questions = ref.watch(questionBankProvider);
  final subjects = questions.map((q) => q.subject).where((s) => s.isNotEmpty).toSet().toList();
  subjects.sort();
  return subjects;
});

class QuestionBankData {
  final String id;
  final String teacherId;
  final String? stageId;
  final String? gradeId;
  final String? classId;
  final String subject;
  final String type;
  final String difficulty;
  final String text;
  final List<String> options;
  final String correctAnswer;
  final int marks;
  final List<String> tags;
  final String? imageUrl;
  final int usageCount;
  final String organizationId;
  final DateTime? createdAt;

  QuestionBankData({
    required this.id,
    required this.teacherId,
    this.stageId,
    this.gradeId,
    this.classId,
    required this.subject,
    required this.type,
    required this.difficulty,
    required this.text,
    this.options = const [],
    this.correctAnswer = '',
    this.marks = 1,
    this.tags = const [],
    this.imageUrl,
    this.usageCount = 0,
    this.organizationId = AppConstants.defaultInstitutionId,
    this.createdAt,
  });

  factory QuestionBankData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return QuestionBankData(
      id: doc.id,
      teacherId: data['teacherId'] ?? '',
      stageId: data['stageId'],
      gradeId: data['gradeId'],
      classId: data['classId'],
      subject: data['subject'] ?? '',
      type: data['type'] ?? AppConstants.questionTypeMultipleChoice,
      difficulty: data['difficulty'] ?? AppConstants.difficultyMedium,
      text: data['text'] ?? '',
      options: List<String>.from(data['options'] ?? []),
      correctAnswer: data['correctAnswer'] ?? '',
      marks: data['marks'] ?? 1,
      tags: List<String>.from(data['tags'] ?? []),
      imageUrl: data['imageUrl'],
      usageCount: data['usageCount'] ?? 0,
      organizationId: data['organizationId'] ?? data['institutionId'] ?? AppConstants.defaultInstitutionId,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  String get typeLabel {
    switch (type) {
      case AppConstants.questionTypeMultipleChoice:
        return 'Multiple Choice';
      case AppConstants.questionTypeTrueFalse:
        return 'True / False';
      case AppConstants.questionTypeShortAnswer:
        return 'Short Answer';
      default:
        return 'Unknown';
    }
  }

  IconData get typeIcon {
    switch (type) {
      case AppConstants.questionTypeMultipleChoice:
        return Icons.list_alt_outlined;
      case AppConstants.questionTypeTrueFalse:
        return Icons.toggle_on_outlined;
      case AppConstants.questionTypeShortAnswer:
        return Icons.short_text;
      default:
        return Icons.help_outline;
    }
  }

  Color get difficultyColor {
    switch (difficulty) {
      case AppConstants.difficultyEasy:
        return const Color(0xFF4CAF50);
      case AppConstants.difficultyMedium:
        return const Color(0xFFFF9800);
      case AppConstants.difficultyHard:
        return const Color(0xFFF44336);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teacherId': teacherId,
      'subject': subject,
      'type': type,
      'difficulty': difficulty,
      'text': text,
      'options': options,
      'correctAnswer': correctAnswer,
      'marks': marks,
      'tags': tags,
      'usageCount': usageCount,
    };
  }
}
