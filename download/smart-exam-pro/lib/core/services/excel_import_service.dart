import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for importing data from Excel files (.xlsx)
/// Supports importing students and questions with flexible column mapping
class ExcelImportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Picks an Excel file from device storage
  /// Returns the file bytes or null if cancelled
  Future<Uint8List?> pickExcelFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true, // Important: load file data into memory
      );

      if (result != null && result.files.single.bytes != null) {
        return result.files.single.bytes;
      }
      return null;
    } catch (e) {
      debugPrint('Error picking Excel file: $e');
      return null;
    }
  }

  /// Parses Excel file bytes and returns sheet data
  /// Returns map: { 'sheetName': [List of row maps] }
  Future<Map<String, List<List<String>>>> parseExcel(Uint8List bytes) async {
    final excel = Excel.decodeBytes(bytes);
    final Map<String, List<List<String>>> sheetsData = {};

    for (final sheetName in excel.tables.keys) {
      final sheet = excel.tables[sheetName]!;
      final List<List<String>> rows = [];

      for (int i = 0; i < sheet.maxRows; i++) {
        final List<String> row = [];
        for (int j = 0; j < sheet.maxCols; j++) {
          final cell = sheet.rows[i][j];
          row.add(cell?.value?.toString() ?? '');
        }
        rows.add(row);
      }
      sheetsData[sheetName] = rows;
    }

    return sheetsData;
  }

  /// Extracts headers (first row) from parsed sheet data
  List<String> extractHeaders(List<List<String>> rows) {
    if (rows.isEmpty) return [];
    return rows.first.where((h) => h.trim().isNotEmpty).toList();
  }

  /// Extracts data rows (all rows after header) from parsed sheet data
  List<Map<String, String>> extractDataRows(
    List<List<String>> rows, {
    required List<String> headers,
  }) {
    if (rows.length <= 1) return [];

    final List<Map<String, String>> dataRows = [];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.every((cell) => cell.trim().isEmpty)) continue; // skip empty rows

      final Map<String, String> rowMap = {};
      for (int j = 0; j < headers.length && j < row.length; j++) {
        rowMap[headers[j]] = row[j].trim();
      }
      dataRows.add(rowMap);
    }
    return dataRows;
  }

  /// Maps Excel columns to target fields using column mapping
  /// columnMapping: { 'targetField': 'excelColumnName' }
  /// Returns list of mapped records
  List<Map<String, String>> mapColumns({
    required List<Map<String, String>> dataRows,
    required Map<String, String> columnMapping,
  }) {
    return dataRows.map((row) {
      final Map<String, String> mapped = {};
      columnMapping.forEach((targetField, excelColumn) {
        mapped[targetField] = row[excelColumn] ?? '';
      });
      return mapped;
    }).toList();
  }

  // ==================== STUDENT IMPORT ====================

  /// Target fields for student import
  static const List<String> studentTargetFields = [
    'fullName',
    'password',
    'grade',
  ];

  /// Default column name suggestions for auto-mapping
  static const Map<String, List<String>> studentColumnHints = {
    'fullName': ['name', 'full_name', 'fullname', 'student name', 'الاسم', 'اسم الطالب'],
    'password': ['password', 'pass', 'كلمة المرور', 'كلمة السر'],
    'grade': ['grade', 'class', 'الصف', 'المرحلة'],
  };

  /// Auto-detect column mapping by matching header names with hints
  Map<String, String> autoDetectStudentMapping(List<String> headers) {
    final Map<String, String> mapping = {};
    final lowerHeaders = headers.map((h) => h.toLowerCase().trim()).toList();

    for (final entry in studentColumnHints.entries) {
      final targetField = entry.key;
      final hints = entry.value;

      for (int i = 0; i < lowerHeaders.length; i++) {
        for (final hint in hints) {
          if (lowerHeaders[i].contains(hint)) {
            mapping[targetField] = headers[i];
            break;
          }
        }
        if (mapping.containsKey(targetField)) break;
      }
    }

    return mapping;
  }

  /// Validates mapped student data
  /// Returns list of validation errors (empty if all valid)
  List<String> validateStudentData(List<Map<String, String>> students) {
    final errors = <String>[];

    for (int i = 0; i < students.length; i++) {
      final s = students[i];
      final rowNum = i + 2; // +2 because row 1 is header, row i starts from 0

      if (s['fullName']?.trim().isEmpty ?? true) {
        errors.add('Row $rowNum: Full name is required');
      }
    }

    return errors;
  }

  /// Import students from mapped data into Firestore
  /// Returns count of successfully imported students
  Future<int> importStudents({
    required String teacherId,
    required String classId,
    required String className,
    required List<Map<String, String>> students,
    String Function(String) hashPassword, // Pass AuthService.hashPassword
  }) async {
    int imported = 0;
    final batch = _firestore.batch();

    for (final studentData in students) {
      final fullName = studentData['fullName']?.trim() ?? '';
      if (fullName.isEmpty) continue;

      final password = studentData['password']?.trim().isNotEmpty == true
          ? studentData['password']!.trim()
          : '123456'; // default password

      final grade = studentData['grade']?.trim() ?? '';

      // Generate unique student code
      final studentCode = await _generateStudentCode(teacherId);

      // Create student document
      final docRef = _firestore.collection('students').doc();
      batch.set(docRef, {
        'id': docRef.id,
        'teacherId': teacherId,
        'classId': classId,
        'className': className,
        'fullName': fullName,
        'studentCode': studentCode,
        'passwordHash': hashPassword(password),
        'grade': grade,
        'institutionId': 'default',
        'createdAt': FieldValue.serverTimestamp(),
      });

      imported++;
    }

    if (imported > 0) {
      await batch.commit();

      // Update class student count
      final classDoc = await _firestore.collection('classes').doc(classId).get();
      if (classDoc.exists) {
        final currentCount = classDoc.data()?['studentCount'] as int? ?? 0;
        await _firestore.collection('classes').doc(classId).update({
          'studentCount': currentCount + imported,
        });
      }
    }

    return imported;
  }

  /// Generates a unique student code (STU-XXXXXX format)
  Future<String> _generateStudentCode(String teacherId) async {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = DateTime.now().microsecondsSinceEpoch;

    for (int attempt = 0; attempt < 10; attempt++) {
      final code = 'STU-${List.generate(6, (i) => chars[(rng + i * 17 + attempt * 31) % chars.length]).join()}';

      final existing = await _firestore
          .collection('students')
          .where('studentCode', isEqualTo: code)
          .limit(1)
          .get();

      if (existing.docs.isEmpty) return code;
    }

    // Fallback: use timestamp-based code
    return 'STU-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
  }

  // ==================== QUESTION IMPORT ====================

  /// Target fields for question import
  static const List<String> questionTargetFields = [
    'questionText',
    'questionType', // mcq, true_false, short_answer
    'optionA',
    'optionB',
    'optionC',
    'optionD',
    'correctAnswer',
    'marks',
    'difficulty', // easy, medium, hard
    'subject',
    'tags', // comma-separated
  ];

  /// Default column name suggestions for question auto-mapping
  static const Map<String, List<String>> questionColumnHints = {
    'questionText': ['question', 'text', 'question text', 'السؤال', 'نص السؤال'],
    'questionType': ['type', 'question type', 'نوع السؤال', 'النوع'],
    'optionA': ['a', 'option a', 'a)', 'الخيار أ', 'اختيار أ'],
    'optionB': ['b', 'option b', 'b)', 'الخيار ب', 'اختيار ب'],
    'optionC': ['c', 'option c', 'c)', 'الخيار ج', 'اختيار ج'],
    'optionD': ['d', 'option d', 'd)', 'الخيار د', 'اختيار د'],
    'correctAnswer': ['answer', 'correct', 'correct answer', 'الإجابة', 'الإجابة الصحيحة'],
    'marks': ['marks', 'points', 'الدرجة', 'النقاط'],
    'difficulty': ['difficulty', 'level', 'الصعوبة', 'المستوى'],
    'subject': ['subject', 'topic', 'الموضوع', 'المادة'],
    'tags': ['tags', 'tag', 'الوسوم', 'التصنيفات'],
  };

  /// Auto-detect column mapping for questions
  Map<String, String> autoDetectQuestionMapping(List<String> headers) {
    final Map<String, String> mapping = {};
    final lowerHeaders = headers.map((h) => h.toLowerCase().trim()).toList();

    for (final entry in questionColumnHints.entries) {
      final targetField = entry.key;
      final hints = entry.value;

      for (int i = 0; i < lowerHeaders.length; i++) {
        for (final hint in hints) {
          if (lowerHeaders[i].contains(hint)) {
            mapping[targetField] = headers[i];
            break;
          }
        }
        if (mapping.containsKey(targetField)) break;
      }
    }

    return mapping;
  }

  /// Validates mapped question data
  List<String> validateQuestionData(List<Map<String, String>> questions) {
    final errors = <String>[];

    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      final rowNum = i + 2;

      if (q['questionText']?.trim().isEmpty ?? true) {
        errors.add('Row $rowNum: Question text is required');
      }

      final type = q['questionType']?.trim().toLowerCase() ?? '';
      if (type.isNotEmpty && !['mcq', 'true_false', 'true-false', 'tf', 'short_answer', 'short-answer'].contains(type)) {
        errors.add('Row $rowNum: Invalid question type "$type" (use mcq, true_false, or short_answer)');
      }

      // MCQ should have at least 2 options and a correct answer
      if (type == 'mcq') {
        if ((q['optionA']?.trim().isEmpty ?? true) || (q['optionB']?.trim().isEmpty ?? true)) {
          errors.add('Row $rowNum: MCQ questions need at least options A and B');
        }
        if (q['correctAnswer']?.trim().isEmpty ?? true) {
          errors.add('Row $rowNum: MCQ questions need a correct answer');
        }
      }
    }

    return errors;
  }

  /// Normalizes question type from Excel input to app format
  String _normalizeQuestionType(String? raw) {
    if (raw == null) return 'mcq';
    final lower = raw.trim().toLowerCase();
    if (['true_false', 'true-false', 'tf', 't/f', 'truefalse'].contains(lower)) {
      return 'true_false';
    }
    if (['short_answer', 'short-answer', 'short', 'open', 'essay'].contains(lower)) {
      return 'short_answer';
    }
    return 'mcq'; // default
  }

  /// Normalizes difficulty level
  String _normalizeDifficulty(String? raw) {
    if (raw == null) return 'medium';
    final lower = raw.trim().toLowerCase();
    if (['easy', 'سهل', 'بسيط'].contains(lower)) return 'easy';
    if (['hard', 'difficult', 'صعب', 'صعبة'].contains(lower)) return 'hard';
    return 'medium';
  }

  /// Import questions from mapped data into the question bank
  /// Returns count of successfully imported questions
  Future<int> importQuestionsToBank({
    required String teacherId,
    required List<Map<String, String>> questions,
    String? subject,
  }) async {
    int imported = 0;
    final batch = _firestore.batch();
    final timestamp = FieldValue.serverTimestamp();

    for (final qData in questions) {
      final questionText = qData['questionText']?.trim() ?? '';
      if (questionText.isEmpty) continue;

      final questionType = _normalizeQuestionType(qData['questionType']);
      final difficulty = _normalizeDifficulty(qData['difficulty']);
      final marks = int.tryParse(qData['marks']?.trim() ?? '1') ?? 1;
      final qSubject = qData['subject']?.trim() ?? subject ?? 'General';
      final tags = qData['tags']?.trim().split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList() ?? <String>[];

      // Build options for MCQ
      List<String> options = [];
      String correctAnswer = qData['correctAnswer']?.trim() ?? '';

      if (questionType == 'mcq') {
        options = [
          if (qData['optionA']?.trim().isNotEmpty ?? false) qData['optionA']!.trim(),
          if (qData['optionB']?.trim().isNotEmpty ?? false) qData['optionB']!.trim(),
          if (qData['optionC']?.trim().isNotEmpty ?? false) qData['optionC']!.trim(),
          if (qData['optionD']?.trim().isNotEmpty ?? false) qData['optionD']!.trim(),
        ];
        // If correct answer is just A/B/C/D, map to the actual option text
        if (correctAnswer.length == 1 && ['a', 'b', 'c', 'd'].contains(correctAnswer.toLowerCase())) {
          final idx = correctAnswer.toLowerCase().codeUnitAt(0) - 'a'.codeUnitAt(0);
          if (idx < options.length) {
            correctAnswer = options[idx];
          }
        }
      } else if (questionType == 'true_false') {
        options = ['True', 'False'];
        if (correctAnswer.toLowerCase() == 't' || correctAnswer.toLowerCase() == 'true') {
          correctAnswer = 'True';
        } else {
          correctAnswer = 'False';
        }
      }

      final docRef = _firestore.collection('question_bank').doc();
      batch.set(docRef, {
        'id': docRef.id,
        'institutionId': 'default',
        'teacherId': teacherId,
        'stageId': null,
        'gradeId': null,
        'classId': null,
        'subject': qSubject,
        'type': questionType,
        'difficulty': difficulty,
        'text': questionText,
        'options': options,
        'correctAnswer': correctAnswer,
        'tags': tags,
        'usageCount': 0,
        'createdAt': timestamp,
      });

      imported++;
    }

    if (imported > 0) {
      await batch.commit();
    }

    return imported;
  }

  /// Import questions from mapped data directly into an exam
  /// Returns count of successfully imported questions
  Future<int> importQuestionsToExam({
    required String teacherId,
    required String examId,
    required List<Map<String, String>> questions,
  }) async {
    int imported = 0;
    int nextOrder = 0;

    // Get current max order
    final existingQuestions = await _firestore
        .collection('questions')
        .where('examId', isEqualTo: examId)
        .orderBy('order', descending: true)
        .limit(1)
        .get();

    if (existingQuestions.docs.isNotEmpty) {
      nextOrder = (existingQuestions.docs.first.data()['order'] as int? ?? 0) + 1;
    }

    for (final qData in questions) {
      final questionText = qData['questionText']?.trim() ?? '';
      if (questionText.isEmpty) continue;

      final questionType = _normalizeQuestionType(qData['questionType']);
      final difficulty = _normalizeDifficulty(qData['difficulty']);
      final marks = int.tryParse(qData['marks']?.trim() ?? '1') ?? 1;
      final tags = qData['tags']?.trim().split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList() ?? <String>[];

      List<String> options = [];
      String correctAnswer = qData['correctAnswer']?.trim() ?? '';

      if (questionType == 'mcq') {
        options = [
          if (qData['optionA']?.trim().isNotEmpty ?? false) qData['optionA']!.trim(),
          if (qData['optionB']?.trim().isNotEmpty ?? false) qData['optionB']!.trim(),
          if (qData['optionC']?.trim().isNotEmpty ?? false) qData['optionC']!.trim(),
          if (qData['optionD']?.trim().isNotEmpty ?? false) qData['optionD']!.trim(),
        ];
        if (correctAnswer.length == 1 && ['a', 'b', 'c', 'd'].contains(correctAnswer.toLowerCase())) {
          final idx = correctAnswer.toLowerCase().codeUnitAt(0) - 'a'.codeUnitAt(0);
          if (idx < options.length) {
            correctAnswer = options[idx];
          }
        }
      } else if (questionType == 'true_false') {
        options = ['True', 'False'];
        correctAnswer = (correctAnswer.toLowerCase() == 't' || correctAnswer.toLowerCase() == 'true') ? 'True' : 'False';
      }

      final docRef = _firestore.collection('questions').doc();
      await docRef.set({
        'id': docRef.id,
        'examId': examId,
        'institutionId': 'default',
        'questionType': questionType,
        'questionText': questionText,
        'options': options,
        'correctAnswer': correctAnswer,
        'marks': marks,
        'order': nextOrder + imported,
        'difficulty': difficulty,
        'tags': tags,
        'imageUrl': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      imported++;
    }

    // Recalculate total marks after import
    if (imported > 0) {
      final allQuestions = await _firestore
          .collection('questions')
          .where('examId', isEqualTo: examId)
          .get();

      int totalMarks = 0;
      for (final doc in allQuestions.docs) {
        totalMarks += (doc.data()['marks'] as int? ?? 1);
      }

      await _firestore.collection('exams').doc(examId).update({
        'totalMarks': totalMarks,
        'questionCount': allQuestions.docs.length,
      });
    }

    return imported;
  }
}
