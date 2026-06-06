// ============================================================
// PHASE C - FILE MODIFICATIONS
// ============================================================
// Apply these changes to your existing files.
// Each section shows the file path and what to add/modify.
// ============================================================

// ============================================================
// 1. pubspec.yaml - ADD these dependencies
// ============================================================
/*
Add under dependencies: section:

  # Phase C - Excel Import
  excel: ^4.0.0
  file_picker: ^8.0.0
  path_provider: ^2.1.0

  # Phase C - QR Enrollment
  qr_flutter: ^4.1.0
  mobile_scanner: ^5.1.1

  # Phase C - PDF Reports (Phase D will use these)
  pdf: ^3.10.0
  printing: ^5.12.0

  # Phase C - Analytics Charts (Phase D will use these)
  fl_chart: ^0.68.0

  # Phase C - Crypto (for hashing - may already exist from Phase A)
  crypto: ^3.0.3

  # Phase C - Sharing QR codes / PDFs
  share_plus: ^9.0.0
*/

// Also add assets section if not present:
/*
flutter:
  assets:
    - assets/icon/
*/

// ============================================================
// 2. main.dart - ADD these routes to your GoRouter
// ============================================================
/*
Find the GoRouter route list and ADD these new routes:

import 'package:smart_exam_pro/features/excel_import/pages/excel_import_screen.dart';
import 'package:smart_exam_pro/features/question_bank/pages/question_bank_screen.dart';
import 'package:smart_exam_pro/features/qr/pages/qr_generate_screen.dart';
import 'package:smart_exam_pro/features/qr/pages/qr_scan_screen.dart';
import 'package:smart_exam_pro/features/exam_instances/pages/exam_instances_screen.dart';
import 'package:smart_exam_pro/providers/question_bank_provider.dart';
import 'package:smart_exam_pro/providers/excel_import_provider.dart';
import 'package:smart_exam_pro/providers/exam_instance_provider.dart';

Then add these routes inside the teacher ShellRoute or alongside existing teacher routes:

GoRoute(
  path: '/teacher/question-bank',
  builder: (context, state) => ProviderScope(
    overrides: [
      teacherIdForBankProvider.overrideWithValue(
        Hive.box('auth_box').get('userId') as String?,
      ),
    ],
    child: const QuestionBankScreen(),
  ),
),
GoRoute(
  path: '/teacher/excel-import',
  builder: (context, state) => const ExcelImportScreen(),
),
GoRoute(
  path: '/teacher/classes/:classId/qr',
  builder: (context, state) {
    final classId = state.pathParameters['classId']!;
    final extra = state.extra as Map<String, dynamic>? ?? {};
    return QRGenerateScreen(
      classId: classId,
      className: extra['className'] as String? ?? '',
      grade: extra['grade'] as String?,
    );
  },
),
GoRoute(
  path: '/teacher/exams/:examId/instances',
  builder: (context, state) {
    final examId = state.pathParameters['examId']!;
    return ExamInstancesScreen(examId: examId);
  },
),
GoRoute(
  path: '/student/qr-scan',
  builder: (context, state) => const QRScanScreen(),
),
*/

// ============================================================
// 3. exam_service.dart - ADD these methods
// ============================================================
/*
Add these methods to the ExamService class. These handle:
- Creating exam instances when a student starts a randomized exam
- Updating the exam model with isRandomized field
*/

// ADD to createExam method: add these fields to the document set:
//   'isRandomized': isRandomized ?? false,
//   'allowRetake': allowRetake ?? false,
//   'publishedAt': null,

// ADD these new methods:

/*
  /// Create an exam instance for a student (for randomized exams)
  /// Returns the exam instance document ID
  Future<String> createExamInstance({
    required String examId,
    required String studentId,
    required String classId,
    required String teacherId,
  }) async {
    // Check if instance already exists
    final existing = await _firestore
        .collection('exam_instances')
        .where('examId', isEqualTo: examId)
        .where('studentId', isEqualTo: studentId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }

    // Get exam to check if randomized
    final examDoc = await _firestore.collection('exams').doc(examId).get();
    if (!examDoc.exists) throw Exception('Exam not found');

    final isRandomized = examDoc.data()?['isRandomized'] as bool? ?? false;

    // Fetch all questions
    final questionsSnapshot = await _firestore
        .collection('questions')
        .where('examId', isEqualTo: examId)
        .orderBy('order')
        .get();

    final List<String> questionIds = questionsSnapshot.docs.map((doc) => doc.id).toList();

    // Shuffle if randomized
    List<String> orderedQuestions;
    if (isRandomized && questionIds.length > 1) {
      orderedQuestions = List<String>.from(questionIds);
      final random = Random();
      for (int i = orderedQuestions.length - 1; i > 0; i--) {
        final j = random.nextInt(i + 1);
        final temp = orderedQuestions[i];
        orderedQuestions[i] = orderedQuestions[j];
        orderedQuestions[j] = temp;
      }
    } else {
      orderedQuestions = questionIds;
    }

    // Create instance
    final docRef = _firestore.collection('exam_instances').doc();
    await docRef.set({
      'id': docRef.id,
      'institutionId': 'default',
      'examId': examId,
      'studentId': studentId,
      'classId': classId,
      'teacherId': teacherId,
      'randomizedQuestions': orderedQuestions,
      'isRandomized': isRandomized,
      'startedAt': FieldValue.serverTimestamp(),
      'completedAt': null,
      'submissionId': null,
    });

    return docRef.id;
  }

  /// Get exam instance for a student
  Future<Map<String, dynamic>?> getExamInstance({
    required String examId,
    required String studentId,
  }) async {
    final snapshot = await _firestore
        .collection('exam_instances')
        .where('examId', isEqualTo: examId)
        .where('studentId', isEqualTo: studentId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first.data();
  }

  /// Get questions in the randomized order for a specific exam instance
  Future<List<Map<String, dynamic>>> getInstanceQuestions(String instanceId) async {
    final instanceDoc = await _firestore.collection('exam_instances').doc(instanceId).get();
    if (!instanceDoc.exists) return [];

    final instanceData = instanceDoc.data()!;
    final List<dynamic> questionOrder = instanceData['randomizedQuestions'] ?? [];

    if (questionOrder.isEmpty) {
      // Fallback: return questions in original order
      final questions = await _firestore
          .collection('questions')
          .where('examId', isEqualTo: instanceData['examId'])
          .orderBy('order')
          .get();
      return questions.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    }

    // Fetch each question in the randomized order
    final List<Map<String, dynamic>> orderedQuestions = [];
    for (final questionId in questionOrder) {
      final doc = await _firestore.collection('questions').doc(questionId as String).get();
      if (doc.exists) {
        orderedQuestions.add(doc.data()!);
      }
    }

    return orderedQuestions;
  }

  /// Update exam stats (precomputed analytics)
  Future<void> updateExamStats(String examId) async {
    final submissions = await _firestore
        .collection('submissions')
        .where('examId', isEqualTo: examId)
        .where('status', isEqualTo: 'submitted')
        .get();

    if (submissions.docs.isEmpty) {
      await _firestore.collection('exam_stats').doc(examId).set({
        'examId': examId,
        'totalStudents': 0,
        'submittedStudents': 0,
        'averageScore': 0.0,
        'highestScore': 0.0,
        'lowestScore': 0.0,
        'passRate': 0.0,
      }, SetOptions(merge: true));
      return;
    }

    final scores = submissions.docs.map((doc) {
      return (doc.data()['percentage'] as num?)?.toDouble() ?? 0.0;
    }).toList();

    final average = scores.reduce((a, b) => a + b) / scores.length;
    final highest = scores.reduce((a, b) => a > b ? a : b);
    final lowest = scores.reduce((a, b) => a < b ? a : b);

    // Get exam for passing score
    final examDoc = await _firestore.collection('exams').doc(examId).get();
    final passingScore = (examDoc.data()?['passingScore'] as num?)?.toDouble() ?? 50.0;
    final passCount = scores.where((s) => s >= passingScore).length;

    // Get total students in class
    final classId = examDoc.data()?['classId'] as String?;
    int totalStudents = 0;
    if (classId != null) {
      final classDoc = await _firestore.collection('classes').doc(classId).get();
      totalStudents = (classDoc.data()?['studentCount'] as int?) ?? 0;
    }

    await _firestore.collection('exam_stats').doc(examId).set({
      'examId': examId,
      'totalStudents': totalStudents,
      'submittedStudents': scores.length,
      'averageScore': double.parse(average.toStringAsFixed(1)),
      'highestScore': highest,
      'lowestScore': lowest,
      'passRate': totalStudents > 0 ? double.parse((passCount / totalStudents * 100).toStringAsFixed(1)) : 0.0,
    }, SetOptions(merge: true));
  }
*/

// Need to add this import at the top of exam_service.dart:
// import 'dart:math';

// ============================================================
// 4. exam_form_screen.dart - ADD randomization toggle
// ============================================================
/*
In the exam creation/editing form, add a toggle for randomization.
Find the form fields section and add:

  bool _isRandomized = false;
  bool _allowRetake = false;

  // In the form widgets, add:
  SwitchListTile(
    title: const Text('Randomize Questions'),
    subtitle: const Text('Each student sees questions in a different order'),
    value: _isRandomized,
    onChanged: (v) => setState(() => _isRandomized = v),
    secondary: Icon(Icons.shuffle, color: _isRandomized ? theme.colorScheme.primary : null),
  ),
  SwitchListTile(
    title: const Text('Allow Retake'),
    subtitle: const Text('Students can retake the exam'),
    value: _allowRetake,
    onChanged: (v) => setState(() => _allowRetake = v),
    secondary: Icon(Icons.replay, color: _allowRetake ? theme.colorScheme.primary : null),
  ),

  // In the createExam/updateExam call, add:
  //   isRandomized: _isRandomized,
  //   allowRetake: _allowRetake,
*/

// ============================================================
// 5. exam_taking_screen.dart - MODIFY to use exam instances
// ============================================================
/*
The exam taking screen needs to be modified to support randomized questions.
The key change is: instead of directly fetching questions by examId,
it should:

1. When starting an exam, create/get an exam instance
2. Use the instance's randomized question order
3. Show questions in that order

Find the section where questions are loaded (likely in initState or a provider)
and modify it:

  String? _instanceId;

  @override
  void initState() {
    super.initState();
    _initializeExam();
  }

  Future<void> _initializeExam() async {
    // Get/create exam instance
    final examService = ref.read(examServiceProvider);
    final studentId = ref.read(userIdProvider) ?? '';

    _instanceId = await examService.createExamInstance(
      examId: widget.examId,
      studentId: studentId,
      classId: ref.read(studentClassIdProvider) ?? '',
      teacherId: ref.read(studentTeacherIdProvider) ?? '',
    );

    // Fetch questions in randomized order
    if (_instanceId != null) {
      final questions = await examService.getInstanceQuestions(_instanceId!);
      // Update your question list state with these questions
      setState(() {
        _questions = questions;
        _isLoading = false;
      });
    }
  }

Also, when submitting the exam, mark the instance as completed:
  await examService.completeInstance(instanceId: _instanceId!, submissionId: submissionId);
*/

// ============================================================
// 6. teacher_dashboard.dart - ADD navigation links for new features
// ============================================================
/*
In the teacher dashboard, add quick action buttons and navigation items
for the new Phase C features. Find the "Quick Actions" section and add:

  // Add these QuickActionCards or ListTile items:
  
  _buildQuickAction(
    context,
    icon: Icons.quiz,
    title: 'Question Bank',
    subtitle: 'Manage reusable questions',
    color: Colors.purple,
    onTap: () => context.push('/teacher/question-bank'),
  ),
  _buildQuickAction(
    context,
    icon: Icons.upload_file,
    title: 'Import Excel',
    subtitle: 'Import students or questions',
    color: Colors.teal,
    onTap: () => context.push('/teacher/excel-import'),
  ),

Also add a "More Features" section or integrate into existing menus:

  // In the drawer or overflow menu:
  ListTile(
    leading: const Icon(Icons.quiz),
    title: const Text('Question Bank'),
    onTap: () => context.push('/teacher/question-bank'),
  ),
  ListTile(
    leading: const Icon(Icons.upload_file),
    title: const Text('Import from Excel'),
    onTap: () => context.push('/teacher/excel-import'),
  ),
*/

// ============================================================
// 7. class_list_screen.dart - ADD QR code button
// ============================================================
/*
On each class card/list item, add a QR code button that navigates
to the QR generate screen:

  IconButton(
    icon: const Icon(Icons.qr_code),
    tooltip: 'Generate QR Code',
    onPressed: () {
      context.push('/teacher/classes/${classDoc.id}/qr', extra: {
        'className': className,
        'grade': grade,
      });
    },
  ),
*/

// ============================================================
// 8. student_login_screen.dart - ADD QR scan button
// ============================================================
/*
Add a QR scan button on the student login screen that navigates
to the QR scanner:

  // Below the login form:
  Row(
    children: [
      const Expanded(child: Divider()),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text('OR', style: TextStyle(color: Colors.grey[600])),
      ),
      const Expanded(child: Divider()),
    ],
  ),
  const SizedBox(height: 16),
  OutlinedButton.icon(
    onPressed: () => context.push('/student/qr-scan'),
    icon: const Icon(Icons.qr_code_scanner),
    label: const Text('Scan QR Code to Enroll'),
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 16),
    ),
  ),
*/

// ============================================================
// 9. question_builder_screen.dart - ADD "Import from Bank" button
// ============================================================
/*
Add a button in the question builder screen to import questions
from the question bank:

  FilledButton.tonalIcon(
    onPressed: () => _showImportFromBankDialog(context),
    icon: const Icon(Icons.library_books),
    label: const Text('Import from Bank'),
  ),

And the dialog method:

  Future<void> _showImportFromBankDialog(BuildContext context) async {
    // Navigate to question bank in selection mode
    // or show a dialog with bank questions
    final selected = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (ctx) => const QuestionBankScreen(),
      ),
    );

    if (selected != null && selected.isNotEmpty) {
      // Import selected questions to exam
      final bankService = ref.read(questionBankServiceProvider);
      await bankService.importMultipleToExam(
        bankQuestionIds: selected,
        examId: widget.examId,
      );
    }
  }
*/

// ============================================================
// 10. exam_detail_screen.dart - ADD instance viewer link
// ============================================================
/*
Add a button or list tile to view exam instances:

  ListTile(
    leading: const Icon(Icons.shuffle),
    title: const Text('View Exam Instances'),
    subtitle: Text('See per-student question orders'),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => context.push('/teacher/exams/${widget.examId}/instances'),
  ),
*/

// ============================================================
// 11. exam_provider.dart - ADD isRandomized and allowRetake to ExamData
// ============================================================
/*
Update the ExamData model to include:

  final bool isRandomized;
  final bool allowRetake;
  final DateTime? publishedAt;

  // In the ExamData class constructor, add:
    this.isRandomized = false,
    this.allowRetake = false,
    this.publishedAt,

  // In fromFirestore factory, add:
    isRandomized: data['isRandomized'] as bool? ?? false,
    allowRetake: data['allowRetake'] as bool? ?? false,
    publishedAt: (data['publishedAt'] as Timestamp?)?.toDate(),

  // In toMap method, add:
    'isRandomized': isRandomized,
    'allowRetake': allowRetake,
    'publishedAt': publishedAt != null ? Timestamp.fromDate(publishedAt!) : null,
*/
