import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/services/excel_import_service.dart';
import '../core/services/auth_service.dart';

// ==================== SERVICE PROVIDERS ====================

final excelImportServiceProvider = Provider<ExcelImportService>((ref) {
  return ExcelImportService();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// ==================== IMPORT STATE ====================

/// Holds the currently loaded Excel file bytes
final excelFileBytesProvider = StateProvider<Uint8List?>((ref) => null);

/// Holds the currently parsed sheet data
final excelSheetDataProvider = StateProvider<Map<String, List<List<String>>>>((ref) => {});

/// Currently selected sheet name
final selectedSheetProvider = StateProvider<String>((ref) => '');

/// Column mapping for student import: { targetField: excelColumnName }
final studentColumnMappingProvider = StateProvider<Map<String, String>>((ref) => {});

/// Column mapping for question import: { targetField: excelColumnName }
final questionColumnMappingProvider = StateProvider<Map<String, String>>((ref) => {});

/// Parsed and mapped student data (ready for import)
final mappedStudentDataProvider = Provider<List<Map<String, String>>>((ref) {
  final sheetData = ref.watch(excelSheetDataProvider);
  final selectedSheet = ref.watch(selectedSheetProvider);
  final mapping = ref.watch(studentColumnMappingProvider);

  if (selectedSheet.isEmpty || !sheetData.containsKey(selectedSheet) || mapping.isEmpty) {
    return [];
  }

  final service = ref.read(excelImportServiceProvider);
  final rows = sheetData[selectedSheet]!;
  final headers = service.extractHeaders(rows);
  final dataRows = service.extractDataRows(rows, headers: headers);

  return service.mapColumns(
    dataRows: dataRows,
    columnMapping: mapping,
  );
});

/// Parsed and mapped question data (ready for import)
final mappedQuestionDataProvider = Provider<List<Map<String, String>>>((ref) {
  final sheetData = ref.watch(excelSheetDataProvider);
  final selectedSheet = ref.watch(selectedSheetProvider);
  final mapping = ref.watch(questionColumnMappingProvider);

  if (selectedSheet.isEmpty || !sheetData.containsKey(selectedSheet) || mapping.isEmpty) {
    return [];
  }

  final service = ref.read(excelImportServiceProvider);
  final rows = sheetData[selectedSheet]!;
  final headers = service.extractHeaders(rows);
  final dataRows = service.extractDataRows(rows, headers: headers);

  return service.mapColumns(
    dataRows: dataRows,
    columnMapping: mapping,
  );
});

/// Import mode: students or questions
enum ImportMode { students, questions }

final importModeProvider = StateProvider<ImportMode>((ref) => ImportMode.students);

/// Target class ID for student import
final importTargetClassIdProvider = StateProvider<String?>((ref) => null);

/// Target class name for student import
final importTargetClassNameProvider = StateProvider<String?>((ref) => null);

/// Target exam ID for question import
final importTargetExamIdProvider = StateProvider<String?>((ref) => null);

/// Import question to bank or directly to exam
enum QuestionImportTarget { bank, exam }

final questionImportTargetProvider = StateProvider<QuestionImportTarget>((ref) => QuestionImportTarget.bank);

/// Subject for question import
final importSubjectProvider = StateProvider<String>((ref) => 'General');

/// Import progress (0.0 to 1.0)
final importProgressProvider = StateProvider<double>((ref) => 0.0);

/// Import status message
final importStatusMessageProvider = StateProvider<String>((ref) => '');

/// Validation errors
final validationErrorsProvider = StateProvider<List<String>>((ref) => []);

/// Whether import is in progress
final isImportingProvider = StateProvider<bool>((ref) => false);
