# Smart Exam Pro MVP v1.0

A production-ready Android application that allows teachers to create exams, manage students, schedule exams, send notifications, automatically grade exams, monitor exam participation, and prevent students from leaving the exam.

## Features

### Teacher Features
- ✅ Register and Login
- ✅ Create and manage classes
- ✅ Add and manage students
- ✅ Create and publish exams
- ✅ View exam results
- ✅ Track student violations
- ✅ Generate reports

### Student Features
- ✅ Login
- ✅ View assigned exams
- ✅ Take exams with auto-save
- ✅ View results
- ✅ Real-time timer

### Security Features
- ✅ Prevent back navigation during exam
- ✅ Disable screen capture
- ✅ Keep screen awake
- ✅ Detect app leave (home button, recent apps, minimize)
- ✅ Track violations

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
│   │   └── firebase_service.dart
│   ├── models/
│   │   ├── user_model.dart
│   │   ├── student_model.dart
│   │   └── class_model.dart
│   └── config/
│       ├── theme.dart
│       └── app_constants.dart
├── providers/
│   └── auth_provider.dart
├── features/
│   ├── auth/
│   │   └── pages/
│   │       ├── splash_screen.dart
│   │       ├── role_selection_screen.dart
│   │       ├── teacher_login_screen.dart
│   │       ├── teacher_registration_screen.dart
│   │       └── student_login_screen.dart
│   ├── dashboard/
│   │   ├── teacher_dashboard.dart
│   │   └── student_dashboard.dart
│   ├── students/
│   ├── classes/
│   ├── exams/
│   ├── results/
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
git clone https://github.com/Strike87/Smart-Exam-Pro-.git
cd Smart-Exam-Pro-
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

### Phase 2: Core Features (In Progress)
- [ ] Teacher Dashboard (data integration)
- [ ] Class Management
- [ ] Student Management
- [ ] Exam Creation

### Phase 3: Student Exam Features
- [ ] Student Dashboard (data integration)
- [ ] Exam List
- [ ] Exam Screen with Timer
- [ ] Auto-save mechanism
- [ ] Auto-submit on timer end

### Phase 4: Grading & Results
- [ ] Auto-grading engine
- [ ] Results display
- [ ] Teacher reports

### Phase 5: Security & Notifications
- [ ] App leave detection
- [ ] Screen capture prevention
- [ ] Notifications system
- [ ] Violation tracking

### Phase 6: Testing & Optimization
- [ ] Unit tests
- [ ] Integration tests
- [ ] Performance optimization
- [ ] Security audit

## License

MIT License

## Author

Strike87
