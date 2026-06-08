import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/config/app_constants.dart';
import '../core/services/question_service.dart';

final questionServiceProvider =
    Provider<QuestionService>((ref) => QuestionService());

final questionsStreamProvider =
    StreamProvider.family<QuerySnapshot, String>((ref, examId) {
  return ref.read(questionServiceProvider).getQuestionsStream(examId);
});

final questionsProvider =
    Provider.family<List<QuestionData>, String>((ref, examId) {
  final asyncQuestions = ref.watch(questionsStreamProvider(examId));
  return asyncQuestions.when(
    data: (snapshot) =>
        snapshot.docs.map((doc) => QuestionData.fromFirestore(doc)).toList(),
    loading: () => [],
    error: (e, st) { debugPrint('provider error: $e'); return []; },
  );
});

class QuestionData {
  final String id;
  final String examId;
  final String questionType;
  final String questionText;
  final List<String> options;
  final String correctAnswer;
  final int marks;
  final int order;
  final String? imageUrl;
  final String? difficulty;
  final String? bankQuestionId;
  final DateTime? createdAt;

  QuestionData({
    required this.id,
    required this.examId,
    required this.questionType,
    required this.questionText,
    this.options = const [],
    required this.correctAnswer,
    required this.marks,
    required this.order,
    this.imageUrl,
    this.difficulty,
    this.bankQuestionId,
    this.createdAt,
  });

  factory QuestionData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return QuestionData(
      id: doc.id,
      examId: data['examId'] ?? '',
      questionType: data['questionType'] ?? '',
      questionText: data['questionText'] ?? '',
      options: List<String>.from(data['options'] ?? []),
      correctAnswer: data['correctAnswer'] ?? '',
      marks: data['marks'] ?? 1,
      order: data['order'] ?? 0,
      imageUrl: data['imageUrl'],
      difficulty: data['difficulty'],
      bankQuestionId: data['bankQuestionId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  String get typeLabel {
    switch (questionType) {
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
    switch (questionType) {
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

  Color get typeColor {
    switch (questionType) {
      case AppConstants.questionTypeMultipleChoice:
        return const Color(0xFF2196F3);
      case AppConstants.questionTypeTrueFalse:
        return const Color(0xFF4CAF50);
      case AppConstants.questionTypeShortAnswer:
        return const Color(0xFFFF9800);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'examId': examId,
      'questionType': questionType,
      'questionText': questionText,
      'options': options,
      'correctAnswer': correctAnswer,
      'marks': marks,
      'order': order,
      'imageUrl': imageUrl,
      'difficulty': difficulty,
    };
  }
}
