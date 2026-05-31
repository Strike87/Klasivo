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
│   ├── models/
│   └── config/
├── providers/
├── features/
│   ├── auth/
│   ├── dashboard/
│   ├── students/
│   ├── classes/
│   ├── exams/
│   ├── results/
│   └── notifications/
├── widgets/
└── main.dart
```

## Getting Started

### Prerequisites
- Flutter SDK >= 3.0.0
- Dart >= 3.0.0
- Android SDK (for Android development)

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

3. Generate code
```bash
flutter pub run build_runner build
```

4. Run the app
```bash
flutter run
```

## Development Phases

### Phase 1: Project Setup & Authentication
- [ ] Flutter project initialization
- [ ] Firebase setup
- [ ] Authentication module (Teacher & Student)
- [ ] Splash screen

### Phase 2: Core Features
- [ ] Teacher Dashboard
- [ ] Class Management
- [ ] Student Management
- [ ] Exam Creation

### Phase 3: Student Exam Features
- [ ] Student Dashboard
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
