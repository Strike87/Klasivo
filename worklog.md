---
Task ID: A
Agent: Main Agent
Task: Phase A - Security (Password Hashing, Firestore Rules, institutionId)

Work Log:
- Explored full project structure, read all service files, provider files, and key screens
- Phase A.1: SHA-256 Password Hashing
  - Upgraded hashPassword() in AuthService to use per-user salt (salt$hash format)
  - Added verifyPassword() static method that handles salted, unsalted, and plaintext formats
  - Added isSaltedHash() helper for format detection
  - Removed plaintext 'password' field from all Firestore writes (student_service, excel_import_service)
  - Centralized hashPassword: removed duplicate implementations from student_service and excel_import_service
  - All services now call AuthService.hashPassword() instead of local copies
  - loginStudent now auto-migrates: unsalted hash → salted hash, plaintext → salted hash on successful login

- Phase A.2: Firestore Security Rules Audit
  - Replaced blanket isAuth() read access with teacher-ownership checks (isOwner)
  - Teachers can only CRUD their own data (students, classes, stages, grades, groups, exams, question_bank)
  - Exam stats are now teacher-only read (students shouldn't see aggregated stats)
  - Violations are teacher-only read (students can still create them)
  - Notifications use isUserOwner check (userId-based)
  - Users collection: only self-read/update
  - Added helper functions: isOwner(), isUserOwner(), getUserInstitutionId()

- Phase A.3: Add institutionId to all collections
  - Added institutionId to: questions collection (question_service.dart - 3 add methods)
  - Added institutionId to: submissions collection (submission_service.dart - startSubmission, exam_service.dart - createExamInstance)
  - Added institutionId to: answers collection (submission_service.dart - saveAnswer, bulkSaveAnswers)
  - Added institutionId to: exam_instances collection (exam_service.dart - createExamInstance)
  - Added institutionId to: exam_stats collection (exam_service.dart - updateExamStats)
  - Added institutionId to: question_bank import (question_bank_service.dart - importQuestionToExam inherits from bank)
  - Updated all data model classes: QuestionData, SubmissionData, NotificationData (added institutionId field, fromFirestore, toMap)

Stage Summary:
- Phase A complete: All three subtasks implemented
- Password security: salted SHA-256, no plaintext storage, backward-compatible migration
- Firestore rules: teacher-ownership-based access control, no more blanket isAuth() reads
- institutionId: now present in ALL collections (15 total), defaulting to 'default'
- Flutter SDK not available on server for compile check, but code has been manually reviewed for correctness
