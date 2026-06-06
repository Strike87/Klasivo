# Klasivo v1.5

A production-ready Android exam management application that empowers teachers to create and manage exams, import question banks from Excel, generate randomized exam instances, monitor student integrity with enhanced lockdown mode, and produce detailed PDF analytics reports — all powered by Flutter and Firebase.

## Features

### Teacher Features
- Register and Login (Firebase Auth)
- Create and manage classes with full educational hierarchy (Institution → Stage → Grade → Class → Group)
- Add students manually or import from Excel with auto-detect column mapping
- Create and publish exams with question bank support
- Exam randomization (Fisher-Yates shuffle) — each student gets a unique instance
- QR-based student enrollment
- View exam results with live statistics
- Track student violations with severity levels
- Generate PDF reports (Exam Analytics, Student Report Cards, Class Comparison)
- Enhanced analytics dashboard with performance trends and question difficulty analysis
- Exam integrity dashboard with violation summaries and suspicious behavior detection

### Student Features
- Login with class code
- View assigned exams
- Take exams with auto-save and auto-submit
- View results with detailed breakdown
- Real-time timer with screen wake lock

### Security Features
- Prevent back navigation during exam
- Disable screen capture (FLAG_SECURE via native platform channel)
- Keep screen awake during exams
- Detect app leave (home button, recent apps, minimize)
- Track violations with severity levels (low, medium, high, critical)
- Enhanced lockdown mode with clipboard monitoring
- Violation review workflow for teachers
- New violation types: clipboard activity, back navigation, idle timeout

## Technology Stack

- **Frontend**: Flutter (Dart)
- **State Management**: Riverpod
- **Navigation**: GoRouter with auth guards
- **Local Storage**: Hive
- **Backend**: Firebase
  - Firebase Authentication
  - Cloud Firestore
  - Firebase Cloud Messaging
  - Firebase Storage

## Project Structure

```
lib/
├── core/
│   ├── services/
│   │   ├── auth_service.dart
│   │   ├── firebase_service.dart
│   │   ├── exam_security_service.dart
│   │   ├── violation_service.dart
│   │   ├── exam_instance_service.dart
│   │   ├── excel_import_service.dart
│   │   ├── question_bank_service.dart
│   │   ├── qr_enrollment_service.dart
│   │   ├── qr_service.dart
│   │   ├── exam_stats_service.dart
│   │   ├── pdf_service.dart
│   │   ├── submission_service.dart
│   │   └── notification_service.dart
│   ├── models/
│   │   ├── user_model.dart
│   │   ├── student_model.dart
│   │   └── class_model.dart
│   └── config/
│       ├── theme.dart
│       └── app_constants.dart
├── providers/
│   ├── auth_provider.dart
│   ├── exam_provider.dart
│   ├── exam_instance_provider.dart
│   ├── excel_import_provider.dart
│   ├── question_bank_provider.dart
│   ├── violation_provider.dart
│   ├── exam_stats_provider.dart
│   └── notification_provider.dart
├── features/
│   ├── auth/pages/
│   ├── dashboard/
│   ├── classes/
│   ├── students/
│   ├── exams/
│   ├── student_exams/
│   ├── teacher_results/
│   ├── student_results/
│   ├── analytics/
│   ├── integrity/
│   ├── reports/
│   └── notifications/
├── widgets/
├── firebase_options.dart
└── main.dart
```

## Navigation Flow

```
Splash Screen
    │
    ├── Logged In (Teacher) → /teacher (Teacher Dashboard)
    ├── Logged In (Student) → /student (Student Dashboard)
    └── Not Logged In → /auth (Role Selection)
                            │
                            ├── Teacher → /auth/teacher-login
                            │               ├── /auth/teacher-register
                            │               └── /teacher (after login)
                            │
                            └── Student → /auth/student-login
                                            └── /student (after login)
```

## Getting Started

### Prerequisites
- Flutter SDK >= 3.0.0
- Dart >= 3.0.0
- Android SDK (for Android development)
- Firebase project (configure with `flutterfire configure`)

### Installation

1. Clone the repository
```bash
git clone https://github.com/Strike87/Klasivo.git
cd Klasivo
```

2. Install dependencies
```bash
flutter pub get
```

3. Configure Firebase
```bash
# Install FlutterFire CLI if not already installed
dart pub global activate flutterfire_cli

# Configure Firebase for your project
flutterfire configure
```

4. Generate code (for Freezed models)
```bash
flutter pub run build_runner build
```

5. Run the app
```bash
flutter run
```

## Development Phases

### Phase 1: Project Setup & Authentication ✅
- [x] Flutter project initialization
- [x] Firebase setup
- [x] Authentication module (Teacher & Student)
- [x] Splash screen with animation
- [x] Role selection screen
- [x] GoRouter with auth guards
- [x] Teacher login & registration
- [x] Student login
- [x] Local auth state persistence (Hive)

### Phase 2: Core Features ✅
- [x] Teacher Dashboard with data integration
- [x] Class Management
- [x] Student Management
- [x] Exam Creation

### Phase 3: Student Exam Features ✅
- [x] Student Dashboard with data integration
- [x] Exam List
- [x] Exam Screen with Timer
- [x] Auto-save mechanism
- [x] Auto-submit on timer end

### Phase 4: Grading & Results ✅
- [x] Auto-grading engine
- [x] Results display
- [x] Teacher reports

### Phase 5: Security & Notifications ✅
- [x] App leave detection
- [x] Screen capture prevention
- [x] Notifications system
- [x] Violation tracking

### Phase A: Security Hardening ✅
- [x] SHA-1 fingerprint for Firebase
- [x] Firestore security rules deployed
- [x] Screenshot protection via native platform channel

### Phase C: Advanced Features ✅
- [x] Excel import with 4-step wizard
- [x] Question bank with reuse tracking
- [x] Exam randomization (Fisher-Yates shuffle)
- [x] QR code enrollment

### Phase D: Reports & Analytics ✅
- [x] PDF report generation (Arabic font support)
- [x] Precomputed exam statistics
- [x] Enhanced analytics dashboard with charts
- [x] Live exam stats banner

### Phase E: Integrity & Lockdown ✅
- [x] Enhanced violation logging with severity levels
- [x] Violation review workflow
- [x] Enhanced lockdown mode (clipboard monitoring)
- [x] Exam integrity dashboard
- [x] New violation types (clipboard, back nav, idle timeout)

## License

MIT License

## Author

Strike87
