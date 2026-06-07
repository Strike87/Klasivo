import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import '../config/app_constants.dart';

class ExcelImportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Random _random = Random();

  Future<String?> pickExcelFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );
      if (result != null && result.files.single.path != null) {
        return result.files.single.path!;
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<ExcelParseResult> parseExcel(String filePath) async {
    try {
      final bytes = File(filePath).readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);

      final List<String> columns = [];
      final List<Map<String, String>> rows = [];

      for (final table in excel.tables.keys) {
        final sheet = excel.tables[table];
        if (sheet == null || sheet.rows.isEmpty) continue;

        final headerRow = sheet.rows.first;
        for (final cell in headerRow) {
          final value = cell?.value?.toString().trim() ?? '';
          columns.add(value);
        }

        for (int i = 1; i < sheet.rows.length; i++) {
          final row = sheet.rows[i];
          final Map<String, String> rowData = {};
          for (int j = 0; j < columns.length && j < row.length; j++) {
            rowData[columns[j]] = row[j]?.value?.toString().trim() ?? '';
          }
          if (rowData.values.any((v) => v.isNotEmpty)) {
            rows.add(rowData);
          }
        }
        break;
      }

      return ExcelParseResult(columns: columns, rows: rows);
    } catch (e) {
      rethrow;
    }
  }

  /// Extract header names from sheet data
  List<String> extractHeaders(List<List<String>> rows) {
    if (rows.isEmpty) return [];
    return rows.first.where((c) => c.isNotEmpty).toList();
  }

  /// Extract data rows (excluding header) from sheet data
  List<Map<String, String>> extractDataRows(
    List<List<String>> rows, {
    List<String>? headers,
  }) {
    final effectiveHeaders = headers ?? extractHeaders(rows);
    if (rows.length <= 1) return [];

    final List<Map<String, String>> dataRows = [];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      final Map<String, String> rowData = {};
      for (int j = 0; j < effectiveHeaders.length && j < row.length; j++) {
        rowData[effectiveHeaders[j]] = row[j];
      }
      if (rowData.values.any((v) => v.isNotEmpty)) {
        dataRows.add(rowData);
      }
    }
    return dataRows;
  }

  /// Map columns from Excel data to target fields using a column mapping
  List<Map<String, String>> mapColumns({
    required List<Map<String, String>> dataRows,
    required Map<String, String> columnMapping,
  }) {
    return dataRows.map((row) {
      final Map<String, String> mapped = {};
      columnMapping.forEach((targetField, excelColumn) {
        if (excelColumn.isNotEmpty && row.containsKey(excelColumn)) {
          mapped[targetField] = row[excelColumn] ?? '';
        }
      });
      return mapped;
    }).where((row) => row.values.any((v) => v.isNotEmpty)).toList();
  }

  Future<String> _generateStudentCode(String teacherId) async {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    String code;
    bool exists;
    do {
      code = 'STU-';
      for (int i = 0; i < 6; i++) {
        code += chars[_random.nextInt(chars.length)];
      }
      final snapshot = await _firestore
          .collection(AppConstants.studentsCollection)
          .where('studentCode', isEqualTo: code)
          .limit(1)
          .get();
      exists = snapshot.docs.isNotEmpty;
    } while (exists);
    return code;
  }

  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<ExcelImportResult> importStudents({
    required String teacherId,
    required String classId,
    required String className,
    required List<MappedStudent> students,
    String? stageId,
    String? gradeId,
    String? groupId,
    String institutionId = AppConstants.defaultInstitutionId,
  }) async {
    try {
      int successCount = 0;
      int failCount = 0;
      final List<String> errors = [];

      const batchSize = 450;
      for (int i = 0; i < students.length; i += batchSize) {
        final batch = _firestore.batch();
        final chunk = students.skip(i).take(batchSize);

        for (final student in chunk) {
          try {
            final studentCode = await _generateStudentCode(teacherId);
            final docRef = _firestore.collection(AppConstants.studentsCollection).doc();

            final password = student.password.isNotEmpty
                ? student.password
                : AppConstants.defaultStudentPassword;
            final passwordHash = hashPassword(password);

            batch.set(docRef, {
              'teacherId': teacherId,
              'classId': classId,
              'className': className,
              'fullName': student.name,
              'studentCode': studentCode,
              'passwordHash': passwordHash,
              'password': password,
              'stageId': stageId,
              'gradeId': gradeId,
              'groupId': groupId,
              'phone': student.phone,
              'email': student.email,
              'parentPhone': student.parentPhone,
              'institutionId': institutionId,
              'createdAt': FieldValue.serverTimestamp(),
            });
            successCount++;
          } catch (e) {
            failCount++;
            errors.add('${student.name} - $e');
          }
        }
        await batch.commit();
      }

      final countSnapshot = await _firestore
          .collection(AppConstants.studentsCollection)
          .where('classId', isEqualTo: classId)
          .count()
          .get();

      await _firestore
          .collection(AppConstants.classesCollection)
          .doc(classId)
          .update({'studentCount': countSnapshot.count});

      return ExcelImportResult(
        successCount: successCount,
        failCount: failCount,
        errors: errors,
      );
    } catch (e) {
      rethrow;
    }
  }
}

class ExcelParseResult {
  final List<String> columns;
  final List<Map<String, String>> rows;
  ExcelParseResult({required this.columns, required this.rows});
}

class MappedStudent {
  final String name;
  final String studentCode;
  final String className;
  final String password;
  final String phone;
  final String email;
  final String parentPhone;

  MappedStudent({
    required this.name,
    this.studentCode = '',
    this.className = '',
    this.password = '',
    this.phone = '',
    this.email = '',
    this.parentPhone = '',
  });
}

class ExcelImportResult {
  final int successCount;
  final int failCount;
  final List<String> errors;
  ExcelImportResult({required this.successCount, required this.failCount, required this.errors});
}
