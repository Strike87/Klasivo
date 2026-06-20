import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'password_hasher.dart';

class ExcelImportService {
  // P0-10 PATCH: client-side hashPassword() and direct Firestore batch.set()
  // removed. The old implementation had two separate problems:
  //
  //   1. It wrote a plaintext 'password' field and a weak client-computed
  //      SHA-256 'passwordHash' directly into the users collection.
  //   2. It NEVER created a Firebase Auth account — only a Firestore doc.
  //      Since loginStudent() authenticates via
  //      FirebaseAuth.signInWithEmailAndPassword() first (see auth_service.dart),
  //      every student imported through this path was unable to log in at all.
  //
  // Fix: route each row through the same createStudent Cloud Function that
  // addStudent() (student_service.dart) already uses for single-student
  // creation. createStudent uses the Admin SDK to create the Auth account,
  // scrypt-hash the password (functions/src/utils/passwordHash.ts), and
  // write the Firestore doc — all server-side, bypassing the client write
  // path entirely (Firestore rules block direct client writes to this
  // collection: `allow create: if request.auth.uid == userId`).
  //
  // Calls run with bounded concurrency (_maxConcurrentCreates at a time)
  // rather than one big Future.wait — createStudent does Auth account
  // creation + Firestore writes + notifications per call, so unbounded
  // parallelism for a large spreadsheet could exhaust the function's
  // maxInstances (10) and start failing requests instead of queuing them.
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');

  static const int _maxConcurrentCreates = 5;

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

  Future<ExcelImportResult> importStudents({
    required String organizationId,
    required String classId,
    required List<MappedStudent> students,
    // ignore: avoid_unused_constructor_parameters
    String createdBy = '', // No longer used — createStudent derives the
    // creator from the authenticated caller's request.auth.uid server-side.
    // Kept as a parameter so excel_import_screen.dart doesn't need an
    // unrelated signature change as part of this fix.
  }) async {
    int successCount = 0;
    int failCount = 0;
    final List<String> errors = [];

    Future<void> createOne(MappedStudent student) async {
      try {
        final password = student.password.isNotEmpty
            ? student.password
            : PasswordHasher.instance.generateTemporaryPassword(); // P0-7: was defaultStudentPassword

        await _functions.httpsCallable('createStudent').call<Map<String, dynamic>>({
          'organizationId': organizationId,
          'classId': classId,
          'fullName': student.name,
          'password': password,
          'email': student.email.isNotEmpty ? student.email : null,
          'phone': student.phone.isNotEmpty ? student.phone : null,
        });

        successCount++;
      } catch (e) {
        failCount++;
        errors.add('${student.name} - $e');
      }
    }

    // Process in fixed-size windows so at most _maxConcurrentCreates
    // callable invocations are in flight at once.
    for (int i = 0; i < students.length; i += _maxConcurrentCreates) {
      final window = students.skip(i).take(_maxConcurrentCreates);
      await Future.wait(window.map(createOne));
    }

    // createStudent already updates the class's studentCount server-side
    // per call, so no separate count-and-update step is needed here.

    return ExcelImportResult(
      successCount: successCount,
      failCount: failCount,
      errors: errors,
    );
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
