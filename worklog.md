---
Task ID: 1
Agent: Main Agent
Task: Implement Smart Exam Pro v1.5 - Full feature upgrade

Work Log:
- Read and analyzed the entire existing codebase (38 Dart files, ~8,150+ lines)
- Updated pubspec.yaml to v1.5.0+2 with 8 new packages (crypto, excel, file_picker, qr_flutter, mobile_scanner, pdf, printing, fl_chart)
- Updated app_constants.dart with 16 collection names, violation types, notification types, difficulty levels, default password constant
- Updated firestore.rules with 9 new collection rules (stages, grades, groups, question_bank, exam_instances, exam_stats, violations, notifications)
- Created firestore.indexes.json with 17 composite indexes
- Updated auth_service.dart with SHA-256 password hashing and migration support
- Updated student_service.dart with passwordHash, stageId, gradeId, groupId, institutionId
- Updated class_service.dart with gradeId, stageId, institutionId
- Updated exam_service.dart with isRandomized, allowRetake, institutionId, exam_instances, exam_stats
- Updated question_service.dart with imageUrl, difficulty, bankQuestionId
- Created 8 new services: stage, grade, group, question_bank, violation, excel_import, pdf, qr
- Updated 4 existing providers: exam (isRandomized, allowRetake, publishedAt), student (stageId, gradeId, groupId), class (gradeId, stageId), question (imageUrl, difficulty)
- Created 6 new providers: stage, grade, group, question_bank, notification, violation
- Created 9 new UI screens: StageList, GradeList, GroupList, QuestionBank, NotificationCenter, ExcelImport, QrGenerate, QrScan, TeacherAnalyticsDashboard
- Updated main.dart with all new routes (stages, question-bank, notifications, analytics, import, qr, scan-qr)
- Updated teacher_dashboard.dart with new quick actions and notification badge
- Updated student_dashboard.dart with QR scan button and notification badge
- Pushed all changes to GitHub (56 files changed, 4,502 insertions, 701 deletions)

Stage Summary:
- v1.5 code is complete and pushed to GitHub
- User needs to: git pull, flutter pub get, flutter run
- Firebase setup still needed: deploy indexes, configure Google Sign-In SHA-1
- Total new Dart files: 23 (8 services, 6 providers, 9 screens)
- Total modified Dart files: 14
