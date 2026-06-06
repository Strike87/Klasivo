import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
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
  }) async {
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: await pw.Font.fromAssetName('NotoSansArabic-Regular.ttf'),
        bold: await pw.Font.fromAssetName('NotoSansArabic-Bold.ttf'),
      ),
    );

    final passed = percentage >= 50;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text('Student Exam Report',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _infoRow('Student Name', studentName),
                _infoRow('Exam', examTitle),
                _infoRow('Class', className),
                _infoRow('Score', '$score / $totalMarks'),
                _infoRow('Percentage', '$percentage%'),
                _infoRow('Status', passed ? 'PASSED' : 'FAILED'),
                if (violationCount > 0)
                  _infoRow('Violations', '$violationCount'),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Header(level: 1, child: pw.Text('Answer Details')),
          pw.SizedBox(height: 10),
          pw.Table.fromTextArray(
            headers: ['#', 'Question', 'Your Answer', 'Correct', 'Marks'],
            data: answers.asMap().entries.map((entry) {
              final i = entry.key;
              final a = entry.value;
              return [
                '${i + 1}',
                a['questionText'] ?? '',
                a['answer'] ?? 'N/A',
                a['correctAnswer'] ?? '',
                '${a['marksAwarded'] ?? 0}/${a['marks'] ?? 0}',
              ];
            }).toList(),
          ),
        ],
      ),
    );

    // Save to temp file
    final output = await PdfService._savePdf(pdf, 'student_report_${studentName.replaceAll(' ', '_')}');
    return output;
  }

  /// Generate an exam analytics report PDF
  static Future<File> generateExamReport({
    required String examTitle,
    required String className,
    required int totalStudents,
    required int submittedStudents,
    required double averageScore,
    required int highestScore,
    required int lowestScore,
    required double passRate,
    required List<Map<String, dynamic>> gradeDistribution,
  }) async {
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: await pw.Font.fromAssetName('NotoSansArabic-Regular.ttf'),
        bold: await pw.Font.fromAssetName('NotoSansArabic-Bold.ttf'),
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text('Exam Analytics Report',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _infoRow('Exam', examTitle),
                _infoRow('Class', className),
                _infoRow('Total Students', '$totalStudents'),
                _infoRow('Submitted', '$submittedStudents'),
                _infoRow('Average Score', '${averageScore.toStringAsFixed(1)}%'),
                _infoRow('Highest Score', '$highestScore'),
                _infoRow('Lowest Score', '$lowestScore'),
                _infoRow('Pass Rate', '${passRate.toStringAsFixed(1)}%'),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Header(level: 1, child: pw.Text('Grade Distribution')),
          pw.SizedBox(height: 10),
          if (gradeDistribution.isNotEmpty)
            pw.Table.fromTextArray(
              headers: ['Grade Range', 'Count', 'Percentage'],
              data: gradeDistribution.map((g) => [
                g['range'] ?? '',
                '${g['count'] ?? 0}',
                '${g['percentage'] ?? 0}%',
              ]).toList(),
            ),
        ],
      ),
    );

    final output = await PdfService._savePdf(pdf, 'exam_report_${examTitle.replaceAll(' ', '_')}');
    return output;
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 150,
            child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }

  static Future<File> _savePdf(pw.Document pdf, String filename) async {
    final bytes = await pdf.save();
    final dir = Directory.systemTemp;
    final file = File('${dir.path}/$filename.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Print or share a PDF file
  static Future<void> printOrShare(File file) async {
    await Printing.sharePdf(bytes: await file.readAsBytes(), filename: file.path.split('/').last);
  }
}
