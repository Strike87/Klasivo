import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class PdfService {
  static pw.Font? _arabicFont;
  static pw.Font? _arabicBoldFont;
  static bool _fontsLoaded = false;

  /// Load Arabic fonts from assets for PDF generation
  static Future<void> loadFonts() async {
    if (_fontsLoaded) return;
    try {
      final regularBytes = await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
      _arabicFont = pw.Font.ttf(regularBytes);
      
      final boldBytes = await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf');
      _arabicBoldFont = pw.Font.ttf(boldBytes);
      
      _fontsLoaded = true;
    } catch (e) {
      // Fallback: use default fonts if Arabic fonts aren't available
      _fontsLoaded = true;
    }
  }

  /// Get the appropriate font (Arabic-supporting if loaded, default otherwise)
  static pw.Font get baseFont => _arabicFont ?? pw.Font.helvetica();
  static pw.Font get boldFont => _arabicBoldFont ?? pw.Font.helveticaBold();

  /// Generate a student exam report PDF
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
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue700,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Smart Exam Pro',
                    style: pw.TextStyle(fontSize: 12, color: PdfColors.white, fontWeight: pw.FontWeight.normal)),
                pw.SizedBox(height: 4),
                pw.Text('Student Exam Report',
                    style: pw.TextStyle(fontSize: 22, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // ── Student Info ──
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Student Information', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 8),
                _infoRow('Student Name', studentName),
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
          ),
          pw.SizedBox(height: 20),

          // ── Score Visual ──
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: passed ? PdfColors.green50 : PdfColors.red50,
              borderRadius: pw.BorderRadius.circular(12),
              border: pw.Border.all(color: passed ? PdfColors.green200 : PdfColors.red200),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text('$percentage%',
                    style: pw.TextStyle(fontSize: 48, fontWeight: pw.FontWeight.bold, color: passed ? PdfColors.green700 : PdfColors.red700)),
                pw.SizedBox(width: 20),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(passed ? 'PASSED' : 'FAILED',
                        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: passed ? PdfColors.green700 : PdfColors.red700)),
                    pw.Text('$score out of $totalMarks marks',
                        style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // ── Answer Details Table ──
          pw.Text('Answer Details', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
          pw.SizedBox(height: 10),
          if (answers.isNotEmpty)
            pw.Table.fromTextArray(
              headers: ['#', 'Question', 'Your Answer', 'Correct', 'Marks'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
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
                  (a['questionText'] ?? '').toString().length > 40
                      ? '${(a['questionText'] ?? '').toString().substring(0, 40)}...'
                      : (a['questionText'] ?? '').toString(),
                  (a['answer'] ?? 'N/A').toString(),
                  (a['correctAnswer'] ?? '').toString(),
                  '${a['marksAwarded'] ?? 0}/${a['marks'] ?? 0}',
                ];
              }).toList(),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            ),
        ],
      ),
    );

    return _savePdf(pdf, 'student_report_${studentName.replaceAll(' ', '_')}');
  }

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
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue700,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Smart Exam Pro',
                    style: pw.TextStyle(fontSize: 12, color: PdfColors.white)),
                pw.SizedBox(height: 4),
                pw.Text('Exam Analytics Report',
                    style: pw.TextStyle(fontSize: 22, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // ── Exam Info ──
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Exam Summary', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 8),
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
          ),
          pw.SizedBox(height: 20),

          // ── Grade Distribution ──
          pw.Text('Grade Distribution', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
          pw.SizedBox(height: 10),
          if (gradeDistribution.isNotEmpty)
            pw.Table.fromTextArray(
              headers: ['Grade Range', 'Count', 'Percentage'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
              data: gradeDistribution.map((g) => [
                g['range'] ?? '',
                '${g['count'] ?? 0}',
                '${g['percentage'] ?? 0}%',
              ]).toList(),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            ),
          pw.SizedBox(height: 20),

          // ── Student Results Table ──
          if (studentResults.isNotEmpty) ...[
            pw.Text('Student Results', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['#', 'Student', 'Code', 'Score', 'Percentage', 'Status'],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
              cellStyle: const pw.TextStyle(fontSize: 8),
              data: studentResults.asMap().entries.map((entry) {
                final i = entry.key;
                final s = entry.value;
                return [
                  '${i + 1}',
                  s['name'] ?? '',
                  s['code'] ?? '',
                  '${s['score'] ?? 0}/${s['totalMarks'] ?? 0}',
                  '${s['percentage'] ?? 0}%',
                  s['status'] ?? '',
                ];
              }).toList(),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            ),
          ],
        ],
      ),
    );

    return _savePdf(pdf, 'exam_report_${examTitle.replaceAll(' ', '_')}');
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
          ),
          pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: 11))),
        ],
      ),
    );
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
      subject: 'Smart Exam Pro Report',
    );
  }

  /// Print a PDF file
  static Future<void> printPdf(File file) async {
    await Printing.layoutPdf(
      onLayout: (_) => file.readAsBytesSync(),
    );
  }
}
