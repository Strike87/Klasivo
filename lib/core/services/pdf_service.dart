import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;

class PdfService {
  static pw.Font? _arabicFont;
  static pw.Font? _arabicBoldFont;
  static bool _fontsLoaded = false;
  static bool _fontLoadAttempted = false;

  // Google Fonts CDN URLs for NotoSansArabic
  static const String _arabicFontUrl =
      'https://github.com/googlefonts/noto-fonts/raw/main/hinted/ttf/NotoSansArabic/NotoSansArabic-Regular.ttf';
  static const String _arabicBoldFontUrl =
      'https://github.com/googlefonts/noto-fonts/raw/main/hinted/ttf/NotoSansArabic/NotoSansArabic-Bold.ttf';

  /// Load Arabic fonts for PDF generation.
  /// Strategy: try assets first → then download from CDN → fallback to Helvetica
  static Future<void> loadFonts() async {
    if (_fontsLoaded) return;

    // Strategy 1: Try loading from bundled assets
    try {
      final regularBytes =
          await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
      final boldBytes =
          await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf');
      _arabicFont = pw.Font.ttf(regularBytes);
      _arabicBoldFont = pw.Font.ttf(boldBytes);
      _fontsLoaded = true;
      _fontLoadAttempted = true;
      return;
    } catch (_) {
      // Assets not available, try CDN
    }

    // Strategy 2: Try loading from cached/downloaded files
    if (!_fontLoadAttempted) {
      _fontLoadAttempted = true;
      try {
        final dir = await getApplicationDocumentsDirectory();
        final regularFile = File('${dir.path}/NotoSansArabic-Regular.ttf');
        final boldFile = File('${dir.path}/NotoSansArabic-Bold.ttf');

        // Download if not cached
        if (!await regularFile.exists()) {
          final response = await http.get(Uri.parse(_arabicFontUrl));
          if (response.statusCode == 200) {
            await regularFile.writeAsBytes(response.bodyBytes);
          }
        }
        if (!await boldFile.exists()) {
          final response = await http.get(Uri.parse(_arabicBoldFontUrl));
          if (response.statusCode == 200) {
            await boldFile.writeAsBytes(response.bodyBytes);
          }
        }

        if (await regularFile.exists()) {
          final bytes = await regularFile.readAsBytes();
          _arabicFont = pw.Font.ttf(ByteData.sublistView(Uint8List.fromList(bytes)));
        }
        if (await boldFile.exists()) {
          final bytes = await boldFile.readAsBytes();
          _arabicBoldFont = pw.Font.ttf(ByteData.sublistView(Uint8List.fromList(bytes)));
        }
      } catch (_) {
        // CDN download failed, use fallback
      }
    }

    _fontsLoaded = true;
  }

  /// Get the appropriate font (Arabic-supporting if loaded, default otherwise)
  static pw.Font get baseFont => _arabicFont ?? pw.Font.helvetica();
  static pw.Font get boldFont => _arabicBoldFont ?? pw.Font.helveticaBold();

  /// Whether Arabic fonts were successfully loaded
  static bool get hasArabicSupport => _arabicFont != null;

  // ══════════════════════════════════════════════════════════════════════════
  // 1. STUDENT EXAM REPORT PDF
  // ══════════════════════════════════════════════════════════════════════════

  /// Generate a detailed student exam report PDF
  static Future<File> generateStudentReport({
    required String studentName,
    required String examTitle,
    required int score,
    required int totalMarks,
    required int percentage,
    required String className,
    required List<Map<String, dynamic>> answers,
    int violationCount = 0,
    int timeSpentMinutes = 0,
    String? studentCode,
    String? institutionName,
  }) async {
    await loadFonts();

    final passed = percentage >= 50;
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          // ── Header ──
          _buildReportHeader(
            title: 'Student Exam Report',
            subtitle: institutionName ?? 'Klasivo',
          ),
          pw.SizedBox(height: 20),

          // ── Student Info ──
          _buildSectionBox(
            title: 'Student Information',
            children: [
              _infoRow('Student Name', studentName),
              if (studentCode != null) _infoRow('Student Code', studentCode),
              _infoRow('Exam', examTitle),
              _infoRow('Class', className),
              _infoRow('Score', '$score / $totalMarks'),
              _infoRow('Percentage', '$percentage%'),
              _infoRow('Status', passed ? 'PASSED' : 'FAILED'),
              if (timeSpentMinutes > 0)
                _infoRow('Time Spent', '$timeSpentMinutes min'),
              if (violationCount > 0)
                _infoRow('Violations', '$violationCount'),
            ],
          ),
          pw.SizedBox(height: 20),

          // ── Score Visual ──
          _buildScoreBadge(
            percentage: percentage,
            score: score,
            totalMarks: totalMarks,
            passed: passed,
          ),
          pw.SizedBox(height: 24),

          // ── Answer Details Table ──
          _buildSectionTitle('Answer Details'),
          pw.SizedBox(height: 10),
          if (answers.isNotEmpty)
            pw.Table.fromTextArray(
              headers: ['#', 'Question', 'Your Answer', 'Correct', 'Marks'],
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
              headerAlignment: pw.Alignment.center,
              data: answers.asMap().entries.map((entry) {
                final i = entry.key;
                final a = entry.value;
                final isCorrect = a['isCorrect'] as bool? ?? false;
                return [
                  '${i + 1}',
                  _truncate((a['questionText'] ?? '').toString(), 40),
                  _truncate((a['answer'] ?? 'N/A').toString(), 20),
                  _truncate((a['correctAnswer'] ?? '').toString(), 20),
                  '${a['marksAwarded'] ?? 0}/${a['marks'] ?? 0}',
                ];
              }).toList(),
              border:
                  pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            ),
        ],
      ),
    );

    return _savePdf(pdf, 'student_report_${studentName.replaceAll(' ', '_')}');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 2. EXAM ANALYTICS REPORT PDF (Teacher View)
  // ══════════════════════════════════════════════════════════════════════════

  /// Generate an exam analytics report PDF (teacher view)
  static Future<File> generateExamReport({
    required String examTitle,
    required String className,
    required int totalStudents,
    required int submittedStudents,
    required double averageScore,
    required int highestScore,
    required int lowestScore,
    required double passRate,
    required int totalMarks,
    required int passingScore,
    required List<Map<String, dynamic>> gradeDistribution,
    required List<Map<String, dynamic>> studentResults,
    String? institutionName,
    List<Map<String, dynamic>>? questionAnalysis,
  }) async {
    await loadFonts();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          // ── Header ──
          _buildReportHeader(
            title: 'Exam Analytics Report',
            subtitle: institutionName ?? 'Klasivo',
          ),
          pw.SizedBox(height: 20),

          // ── Exam Info ──
          _buildSectionBox(
            title: 'Exam Summary',
            children: [
              _infoRow('Exam', examTitle),
              _infoRow('Class', className),
              _infoRow('Total Marks', '$totalMarks'),
              _infoRow('Passing Score', '$passingScore%'),
              pw.Divider(color: PdfColors.grey200),
              _infoRow('Total Students', '$totalStudents'),
              _infoRow('Submitted', '$submittedStudents'),
              _infoRow('Absent', '${totalStudents - submittedStudents}'),
              pw.Divider(color: PdfColors.grey200),
              _infoRow('Average Score', '${averageScore.toStringAsFixed(1)}%'),
              _infoRow('Highest Score', '$highestScore'),
              _infoRow('Lowest Score', '$lowestScore'),
              _infoRow('Pass Rate', '${passRate.toStringAsFixed(1)}%'),
            ],
          ),
          pw.SizedBox(height: 20),

          // ── Grade Distribution ──
          _buildSectionTitle('Grade Distribution'),
          pw.SizedBox(height: 10),
          if (gradeDistribution.isNotEmpty)
            pw.Table.fromTextArray(
              headers: ['Grade Range', 'Count', 'Percentage'],
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
              data: gradeDistribution
                  .map((g) => [
                        g['range'] ?? '',
                        '${g['count'] ?? 0}',
                        '${g['percentage'] ?? 0}%',
                      ])
                  .toList(),
              border:
                  pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            ),
          pw.SizedBox(height: 20),

          // ── Question Analysis ──
          if (questionAnalysis != null && questionAnalysis.isNotEmpty) ...[
            _buildSectionTitle('Question Analysis'),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['#', 'Question', 'Type', 'Difficulty', 'Correct %'],
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
              cellStyle: const pw.TextStyle(fontSize: 8),
              data: questionAnalysis.asMap().entries.map((entry) {
                final q = entry.value;
                return [
                  '${entry.key + 1}',
                  _truncate((q['questionText'] ?? '').toString(), 35),
                  (q['questionType'] ?? '').toString(),
                  (q['difficulty'] ?? '').toString(),
                  '${q['correctPercentage'] ?? 0}%',
                ];
              }).toList(),
              border:
                  pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            ),
            pw.SizedBox(height: 20),
          ],

          // ── Student Results Table ──
          if (studentResults.isNotEmpty) ...[
            _buildSectionTitle('Student Results'),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['#', 'Student', 'Code', 'Score', '%', 'Status'],
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
              cellStyle: const pw.TextStyle(fontSize: 8),
              data: studentResults.asMap().entries.map((entry) {
                final s = entry.value;
                return [
                  '${entry.key + 1}',
                  s['name'] ?? '',
                  s['code'] ?? '',
                  '${s['score'] ?? 0}/${s['totalMarks'] ?? 0}',
                  '${s['percentage'] ?? 0}%',
                  s['status'] ?? '',
                ];
              }).toList(),
              border:
                  pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            ),
          ],
        ],
      ),
    );

    return _savePdf(pdf, 'exam_report_${examTitle.replaceAll(' ', '_')}');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 3. CLASS COMPARISON REPORT PDF
  // ══════════════════════════════════════════════════════════════════════════

  /// Generate a class comparison report comparing multiple exams
  static Future<File> generateClassReport({
    required String className,
    required List<Map<String, dynamic>> examResults,
    required Map<String, dynamic> overallStats,
    String? institutionName,
  }) async {
    await loadFonts();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          _buildReportHeader(
            title: 'Class Performance Report',
            subtitle: institutionName ?? 'Klasivo',
          ),
          pw.SizedBox(height: 20),

          // ── Class Overview ──
          _buildSectionBox(
            title: 'Class Overview - $className',
            children: [
              _infoRow('Total Exams', '${overallStats['totalExams'] ?? 0}'),
              _infoRow('Total Students',
                  '${overallStats['totalStudents'] ?? 0}'),
              _infoRow('Average Pass Rate',
                  '${(overallStats['avgPassRate'] as num?)?.toStringAsFixed(1) ?? '0'}%'),
              _infoRow('Average Score',
                  '${(overallStats['avgScore'] as num?)?.toStringAsFixed(1) ?? '0'}%'),
            ],
          ),
          pw.SizedBox(height: 20),

          // ── Exam-by-Exam Breakdown ──
          _buildSectionTitle('Exam Performance Breakdown'),
          pw.SizedBox(height: 10),
          if (examResults.isNotEmpty)
            pw.Table.fromTextArray(
              headers: [
                'Exam',
                'Submitted',
                'Avg %',
                'High',
                'Low',
                'Pass Rate'
              ],
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
              cellStyle: const pw.TextStyle(fontSize: 8),
              data: examResults
                  .map((e) => [
                        e['examTitle'] ?? '',
                        '${e['submittedStudents'] ?? 0}/${e['totalStudents'] ?? 0}',
                        '${(e['averageScore'] as num?)?.toStringAsFixed(1) ?? '0'}',
                        '${e['highestScore'] ?? 0}',
                        '${e['lowestScore'] ?? 0}',
                        '${(e['passRate'] as num?)?.toStringAsFixed(1) ?? '0'}%',
                      ])
                  .toList(),
              border:
                  pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            ),
        ],
      ),
    );

    return _savePdf(pdf, 'class_report_${className.replaceAll(' ', '_')}');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // 4. STUDENT REPORT CARD PDF
  // ══════════════════════════════════════════════════════════════════════════

  /// Generate a student report card across all exams
  static Future<File> generateStudentReportCard({
    required String studentName,
    required String studentCode,
    required String className,
    required List<Map<String, dynamic>> examResults,
    required Map<String, dynamic> overallStats,
    String? institutionName,
  }) async {
    await loadFonts();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          _buildReportHeader(
            title: 'Student Report Card',
            subtitle: institutionName ?? 'Klasivo',
          ),
          pw.SizedBox(height: 20),

          // ── Student Info ──
          _buildSectionBox(
            title: 'Student Information',
            children: [
              _infoRow('Name', studentName),
              _infoRow('Code', studentCode),
              _infoRow('Class', className),
              _infoRow('Total Exams Taken',
                  '${overallStats['totalExams'] ?? 0}'),
              _infoRow(
                  'Overall Average',
                  '${(overallStats['averageScore'] as num?)?.toStringAsFixed(1) ?? '0'}%'),
              _infoRow(
                  'Overall Pass Rate',
                  '${(overallStats['passRate'] as num?)?.toStringAsFixed(1) ?? '0'}%'),
            ],
          ),
          pw.SizedBox(height: 20),

          // ── Exam Results ──
          _buildSectionTitle('Exam Results'),
          pw.SizedBox(height: 10),
          if (examResults.isNotEmpty)
            pw.Table.fromTextArray(
              headers: ['Exam', 'Score', 'Percentage', 'Status', 'Time'],
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
              cellStyle: const pw.TextStyle(fontSize: 8),
              data: examResults
                  .map((e) => [
                        e['examTitle'] ?? '',
                        '${e['score'] ?? 0}/${e['totalMarks'] ?? 0}',
                        '${e['percentage'] ?? 0}%',
                        e['passed'] == true ? 'Passed' : 'Failed',
                        '${e['timeSpent'] ?? 0} min',
                      ])
                  .toList(),
              border:
                  pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            ),
        ],
      ),
    );

    return _savePdf(
        pdf, 'report_card_${studentName.replaceAll(' ', '_')}');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPER BUILDERS
  // ══════════════════════════════════════════════════════════════════════════

  static pw.Widget _buildReportHeader({
    required String title,
    required String subtitle,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue700,
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(subtitle,
                  style: pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.normal)),
              pw.SizedBox(height: 4),
              pw.Text(title,
                  style: pw.TextStyle(
                      fontSize: 22,
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.Text(
            _formatDate(DateTime.now()),
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSectionBox({
    required String title,
    required List<pw.Widget> children,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title,
              style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue700)),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Text(title,
        style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue700));
  }

  static pw.Widget _buildScoreBadge({
    required int percentage,
    required int score,
    required int totalMarks,
    required bool passed,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: passed ? PdfColors.green50 : PdfColors.red50,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(
            color: passed ? PdfColors.green200 : PdfColors.red200),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text('$percentage%',
              style: pw.TextStyle(
                  fontSize: 48,
                  fontWeight: pw.FontWeight.bold,
                  color: passed ? PdfColors.green700 : PdfColors.red700)),
          pw.SizedBox(width: 20),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(passed ? 'PASSED' : 'FAILED',
                  style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: passed ? PdfColors.green700 : PdfColors.red700)),
              pw.Text('$score out of $totalMarks marks',
                  style: const pw.TextStyle(
                      fontSize: 12, color: PdfColors.grey600)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(label,
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 11)),
          ),
          pw.Expanded(
              child:
                  pw.Text(value, style: const pw.TextStyle(fontSize: 11))),
        ],
      ),
    );
  }

  static String _truncate(String text, int maxLen) {
    if (text.length <= maxLen) return text;
    return '${text.substring(0, maxLen)}...';
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static Future<File> _savePdf(pw.Document pdf, String filename) async {
    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Share a PDF file using the platform share sheet
  static Future<void> sharePdf(File file) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Klasivo Report',
    );
  }

  /// Print a PDF file
  static Future<void> printPdf(File file) async {
    await Printing.layoutPdf(
      onLayout: (_) => file.readAsBytesSync(),
    );
  }
}
