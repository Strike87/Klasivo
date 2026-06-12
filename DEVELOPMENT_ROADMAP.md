# Klasivo — Development Roadmap

> **Current Version:** v2.0.0+7  
> **Platform:** Android (Flutter 3.x / Dart 3.x)  
> **Architecture:** Clean Architecture + Riverpod + Firebase  
> **Last Updated:** 2026-06-12

---

## Version History

| Version | Focus | Status |
|---------|-------|--------|
| **v1.0** | Core exam platform (auth, exams, grading) | ✅ Complete |
| **v1.1–v1.4** | Student dashboard, auto-save, timer, violations | ✅ Complete |
| **v1.5** | QR enrollment, notifications, PDF reports | ✅ Complete |
| **v1.6** | Announcements, Calendar, Academic Years, Audit Logs | ✅ Complete |
| **v1.7** | Enterprise foundations (Design Tokens, Component Library, Feature Flags, Event Bus, Permission Service) | ✅ Complete |
| **v1.8** | Feature Completion (LMS screens, Messaging UI, legacy cleanup) | ✅ Complete |
| **v1.9** | Polish & Integration (component migration, tests, CI/CD) | ✅ Complete |
| **v2.0** | Dark mode, Push notifications, Video player, Content tracking | ✅ Complete |
| **v2.1** | Chat attachments, Offline caching, Multi-tenant | 🔲 Planned |
| **v2.2** | RTL, iOS, Web, SSO, Analytics warehouse | 🔲 Planned |

---

## v1.8 — Feature Completion ✅

### LMS Screens
- [x] Lesson Detail Screen — video player placeholder, type-specific cards (YouTube/Zoom/Drive/Recorded), metadata, related materials
- [x] Material Viewer Screen — file type hero banner, metadata, open/share/download actions
- [x] Fixed TODO navigations in SubjectContentScreen

### Messaging/Chat
- [x] Conversation List Screen — WhatsApp-style conversation list with search, FAB for new conversations
- [x] Chat Screen — full chat UI with message bubbles, read receipts, auto-scroll, message deletion
- [x] Routes wired: `/inbox/messages`, `/inbox/messages/:conversationId`

### Legacy Cleanup
- [x] Removed orphaned GradeService, GradeProvider, GradeListScreen (replaced by Stage → Class → Group)

### Routes Added
| Route | Screen |
|-------|--------|
| `/lms/lessons/:lessonId` | LessonDetailScreen |
| `/lms/materials/:materialId` | MaterialViewerScreen |
| `/inbox/messages` | ConversationListScreen |
| `/inbox/messages/:conversationId` | ChatScreen |

---

## v1.7 — Enterprise Foundations ✅

### Design Tokens System (7 files)
- [x] `app_colors.dart` — Full palette with semantic helpers
- [x] `app_spacing.dart` — 4px base grid with semantic aliases
- [x] `app_radius.dart` — Radius scale with semantic aliases
- [x] `app_typography.dart` — Complete type scale with Arabic variants
- [x] `app_elevation.dart` — Shadow system with "border-first" philosophy
- [x] `app_animation.dart` — Duration scale, curves, stagger patterns
- [x] `tokens.dart` — Barrel export

### Enterprise Component Library (8 files)
- [x] `klasivo_button.dart` — 5 variants, 3 sizes, loading state
- [x] `klasivo_card.dart` — 4 variants with accent support
- [x] `klasivo_text_field.dart` — Validation states
- [x] `klasivo_badge.dart` — 5 variants, factory methods
- [x] `klasivo_avatar.dart` — 4 sizes, role color coding
- [x] `klasivo_modal.dart` — confirm/showForm/showContent
- [x] `klasivo_toast.dart` — success/error/warning/info
- [x] `klasivo_permission_gate.dart` — Permission/Role/Feature gates

### Feature Flag Service
- [x] 27 feature flags covering v1.6–v2.0
- [x] Percentage rollout, user targeting, Firestore persistence
- [x] Real-time streaming via Riverpod providers
- [x] Feature Flags admin screen at `/settings/feature-flags`

### Event Bus
- [x] Singleton broadcast event bus with typed streams
- [x] 25+ event models across 8 domains (Auth, Exam, Academic, Attendance, Assignment, LMS, Parent, Integrity, Organization)

### Permission Service
- [x] 8 roles: owner, admin, teacher, student, parent, campus_manager, observer, super_admin
- [x] 80+ granular permissions
- [x] Firestore overrides (allow/deny), resource-level ownership, wildcard support
- [x] Riverpod providers with bulk checks and convenience providers

---

## v1.6 — Feature Expansion ✅

### Announcements
- [x] AnnouncementListScreen, AnnouncementFormScreen, AnnouncementDetailScreen
- [x] Routes: `/inbox/announcements`, `/inbox/announcements/create`, `/inbox/announcements/:id`

### Calendar
- [x] CalendarScreen, CalendarEventFormScreen
- [x] Route: `/teacher/calendar`

### Academic Years
- [x] AcademicYearListScreen, AcademicYearFormScreen
- [x] Route: `/teacher/academic-years`

### Audit Logs
- [x] AuditLogScreen with filtering
- [x] Route: `/teacher/audit-log`

---

## v1.0–v1.5 — Core Platform ✅

### Authentication
- [x] Firebase Auth (email/password + Google Sign-In)
- [x] Multi-role: Owner, Teacher, Student, Parent
- [x] Splash → Role Selection → Login/Register flow
- [x] Hive-persisted session management

### Teacher Features
- [x] Dashboard with analytics cards
- [x] Stage → Class → Group hierarchy with Smart Setup Wizard
- [x] Exam creation with 3 question types (MCQ, True/False, Short Answer)
- [x] Question Bank
- [x] Exam publishing and scheduling
- [x] Auto-grading engine
- [x] Results with export and visualization
- [x] Attendance tracking
- [x] Gradebook
- [x] Assignment management
- [x] Excel import for students
- [x] QR enrollment and generation

### Student Features
- [x] Dashboard with upcoming/active/completed exams
- [x] Exam taking with auto-save, countdown timer
- [x] Exam integrity (app leave detection, violation tracking, screen security)
- [x] Results review

### Parent Features
- [x] Dashboard with child overview
- [x] Results, attendance, assignments, progress, announcements views

### Notifications
- [x] Firebase Cloud Messaging integration
- [x] Local notifications
- [x] Notification center with read/unread

### Reports
- [x] PDF report generation
- [x] Exam statistics with charts
- [x] Analytics dashboard

---

## Current Codebase Stats

| Metric | Count |
|--------|-------|
| Services | 56 |
| Providers | 54 |
| Screens | 71 |
| Routes | 65+ |
| Custom Widgets | 14 |
| Feature Flags | 27 |
| Permissions | 80+ |
| Event Types | 25+ |
| User Roles | 8 |
| Firestore Indexes | 126 |
| Paginated Screens | 5 |
| CI/CD Workflows | 3 |
| Performance Traces | 30+ |

---

## v1.9 — Polish & Integration ✅

### Component Migration ✅
- [x] Migrate existing screens from raw `ElevatedButton` → `KlasivoButton`
- [x] Migrate raw `Card` → `KlasivoCard` variants
- [x] Migrate raw `TextField` → `KlasivoTextField` (added `borderless` + `autofocus` for AppBar search)
- [x] Migrate raw `SnackBar` → `KlasivoToast`
- [x] Migrate raw `showDialog` → `KlasivoModal`

### Testing
- [x] Unit tests for grading engine (1030 lines — submission_service_test.dart)
- [x] Unit tests for permission service (900+ lines — permission_service_test.dart)
- [x] Unit tests for feature flag service (700+ lines — feature_flag_service_test.dart)
- [x] Integration tests for auth flow (auth_flow_test.dart — 30+ tests)
- [x] Integration tests for exam creation flow (exam_creation_flow_test.dart — 25+ tests)

### CI/CD ✅
- [x] GitHub Actions for PR checks (test.yml, build.yml, pr-checks.yml)
- [x] Automated test execution — 3-workflow matrix (analyze, unit, integration)
- [x] APK build pipeline — debug APK, release APK, AAB with GitHub Release

### Performance ✅
- [x] Optimize Firestore queries (composite indexes) — 43 new indexes, 126 total
- [x] Add pagination to large lists — 5 major screens converted to KlasivoPaginatedList
- [x] Profile app performance — PerformanceTraceService, N+1 fixes, FirebaseService tracing

---

## v2.0 — Dark Mode, Push Notifications, Video Player, Content Tracking ✅

### Dark Mode ✅
- [x] Theme provider with light/dark/system toggle
- [x] Persist theme choice to Hive
- [x] Update all design tokens for dark palette
- [x] Settings screen theme selector UI

### Push Notifications for Messages ✅
- [x] FCM token management per user
- [x] Cloud Function for message push notifications
- [x] Notification routing (tap → open conversation)
- [x] Notification preferences per conversation

### Video Player + Progress Tracking ✅
- [x] YouTube player integration (youtube_player_flutter)
- [x] Video progress tracking service
- [x] Progress indicator on lesson cards
- [x] Resume playback where student left off

### Content Completion Tracking ✅
- [x] ContentProgress service enhanced (video progress, resume, completion rate)
- [x] Mark lesson/material as completed (auto on video >90%)
- [x] Progress percentage per subject (weighted: lessons 60% + materials 40%)
- [x] Completion badges and streaks (KlasivoCompletionBadge + KlasivoStreakBadge)

---

## v2.1 — Chat Attachments, Offline Caching, Multi-Tenant 🔲

### Communication
- [ ] File/image attachments in chat
- [ ] Message reactions

### Offline
- [ ] Offline content caching (lesson downloads)

### Platform
- [ ] Multi-tenant campus model

---

## v2.2 — RTL, iOS, Web, SSO, Analytics 🔲

### Platform
- [ ] RTL layout support (Arabic fonts loaded)
- [ ] iOS support
- [ ] Web support
- [ ] SSO integration

### Analytics
- [ ] Analytics warehouse (BigQuery integration)
- [ ] Custom report builder
- [ ] Student performance prediction

### LMS
- [ ] Lesson plan templates

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────┐
│                     Presentation Layer                    │
│  Screens (71)  ·  Widgets (18)  ·  Shells (3)           │
├──────────────────────────────────────────────────────────┤
│                     State Management                      │
│  Providers (38)  ·  Riverpod  ·  StreamProviders        │
├──────────────────────────────────────────────────────────┤
│                     Business Logic                        │
│  Services (48)  ·  Event Bus  ·  Feature Flags           │
│  Permission Service  ·  Audit  ·  Grading Engine         │
├──────────────────────────────────────────────────────────┤
│                     Data Layer                            │
│  Firebase Auth  ·  Firestore  ·  FCM  ·  Hive  ·  PDF   │
└──────────────────────────────────────────────────────────┘
```

## Key Implementation Principles


1. **Use Design Tokens** — All colors, spacing, typography from `lib/core/tokens/`
2. **Use Enterprise Components** — KlasivoButton, KlasivoCard, KlasivoBadge, etc.
3. **Use Feature Flags** — Gate new features behind flags
4. **Use Permission Gates** — `KlasivoPermissionGate`, `KlasivoRoleGate`
5. **Use Event Bus** — Decouple feature modules via typed events
6. **Follow Clean Architecture** — Services → Providers → Screens
7. **Soft Delete** — All entities use `isArchived` + `archivedAt` pattern
8. **Riverpod Functional Style** — Functional providers, not Notifiers (except where needed)
9. **Firestore Security** — Role-based rules with field-level security
