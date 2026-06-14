# Klasivo — Development Roadmap

> **Current Version:** v2.0.0+7  
> **Platform:** Android (Flutter 3.x / Dart 3.x)  
> **Architecture:** Clean Architecture + Riverpod + Firebase  
> **Last Updated:** 2026-06-15

> **Canonical roadmap:** `klasivo-repo/DEVELOPMENT_ROADMAP.md` — this file is a summary. Full details, dependency maps, migration plans, and sprint breakdowns live there.

---

## Re-prioritization (2026-06-15)

Roadmap re-prioritized to focus on **adoption-driving features before infrastructure scale**. Schools pay for features they use daily (teacher approval, assignments, parent engagement), not backend sophistication.

**Moved UP:** Teacher Approval (v2.3→v2.2), Assignment Submission (v2.4→v2.3), Parent Enhanced (v2.4.1→v2.3A)  
**Moved DOWN:** BigQuery (v2.5→v3.0), Custom Reports (v2.5→v3.0), Platform Analytics (v2.5→v3.0), Web Dashboard (Sprint 4→v2.7)  
**NEW:** Student Engagement & Reminders (v2.2A), School Landing Pages (v2.6), AI Features (v3.5)

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
| **v2.1** | Video Library & Recorded Lessons (YouTube) | 🔲 Planned |
| **v2.2** | Teacher Approval Workflow & Role-Based Routing | 🔲 Planned |
| **v2.2A** | Student Engagement & Reminders (NEW) | 🔲 Planned |
| **v2.3** | Assignment Submission API | 🔲 Planned |
| **v2.3A** | Parent Accounts Enhanced | 🔲 Planned |
| **v2.4** | Chat Attachments, Offline Caching, Enhanced Attendance | 🔲 Planned |
| **v2.5** | School Accounts / Multi-Tenancy (simplified — no BigQuery) | 🔲 Planned |
| **v2.6** | School Landing Pages (NEW) | 🔲 Planned |
| **v2.7** | Web Dashboard & School Analytics | 🔲 Planned |
| **v2.8** | Subscription & Billing | 🔲 Planned |
| **v3.0** | Full Dashboard Platform + BigQuery + Custom Reports + Platform Analytics | 🔲 Planned |
| **v3.5** | AI Features (Question Generator, Grading Assistant) (NEW) | 🔲 Planned |

---

## v1.0–v2.0.1 — Completed ✅

All versions through v2.0.1 are complete. See `klasivo-repo/DEVELOPMENT_ROADMAP.md` for full details.

---

## v2.1 — Video Library & Recorded Lessons (YouTube) 🔲

> Independent of Sprint 3. Can ship in parallel.

### Phase 1 — Recording Library
- [ ] Firestore `class_recordings` collection
- [ ] YouTube video ID extraction utility
- [ ] Class-specific recording filter
- [ ] Recording list screen with search and thumbnails

### Phase 2 — Recording Management
- [ ] Teacher upload/link flow
- [ ] Recording CRUD with permission gates
- [ ] Visibility controls (Public, Class-only, Draft)
- [ ] Bulk import from YouTube playlist

### Phase 3 — Analytics
- [ ] View count tracking
- [ ] Watch time analytics
- [ ] Notify students on new recording

---

## v2.2 — Teacher Approval Workflow & Role-Based Routing 🔲

> Depends on: Sprint 3 (RBAC scope enforcement)

### Teacher Approval Workflow
- [ ] Admin approves/rejects teacher registration requests
- [ ] Teacher onboarding flow with invite code verification
- [ ] Approval queue dashboard for owners/admins
- [ ] Email notifications on approval status change
- [ ] Auto-assign default scope on approval

### Role-Based Routing
- [ ] RBAC route guards on all screens
- [ ] Dynamic navigation based on effective permissions
- [ ] 403 Forbidden screen for unauthorized access

---

## v2.2A — Student Engagement & Reminders 🔲 (NEW)

> Can ship alongside v2.2. Low effort, high value.

### Achievement Badges
- [ ] Badge system (Academic, Engagement, Milestone categories)
- [ ] Badge display on student profile
- [ ] Badge notification on unlock

### Learning Streaks
- [ ] Daily login streak counter
- [ ] Assignment submission streak
- [ ] Streak freeze (1 per week)

### Progress Visibility
- [ ] Overall progress % per subject
- [ ] Assignment completion score
- [ ] Attendance score

### Leaderboards (Optional, feature-flagged)
- [ ] Per-class leaderboard (weekly, monthly, term)
- [ ] Opt-in per school

### Student Reminder Engine
- [ ] Assignment due tomorrow (push at 8 PM)
- [ ] Assignment overdue (push daily at 9 AM)
- [ ] Exam tomorrow (push at 8 PM)
- [ ] Live class starting (push 5 min before)
- [ ] Reminder preferences per student

---

## v2.3 — Assignment Submission API 🔲

> Depends on: Sprint 3

- [ ] REST API for assignment creation, submission, and grading
- [ ] File upload support (PDF, images, documents)
- [ ] Submission deadlines with late penalty rules
- [ ] Rubric-based grading interface
- [ ] Batch grading and feedback
- [ ] Student submission status tracking

---

## v2.3A — Parent Accounts Enhanced 🔲

- [ ] Self-service parent registration (email verification)
- [ ] Link multiple children to one parent account
- [ ] Parent dashboard with real-time child progress
- [ ] Push notifications for grades, attendance, announcements
- [ ] Parent-teacher messaging channel
- [ ] Weekly progress summary emails
- [ ] Parent role scope isolation (view-only, no edit)

---

## v2.4 — Chat Attachments, Offline Caching, Enhanced Attendance 🔲

### Communication
- [ ] File/image attachments in chat
- [ ] Message reactions
- [ ] Typing indicators

### Offline
- [ ] Offline content caching (lesson downloads)
- [ ] Background sync queue

### Attendance (Enhanced)
- [ ] Real-time attendance during live classes
- [ ] Manual attendance marking
- [ ] Attendance analytics per student/class/subject
- [ ] Parent notifications for student absences
- [ ] Export attendance reports (PDF/Excel)
- [ ] Attendance trends and heatmaps

---

## v2.5 — School Accounts / Multi-Tenancy (Simplified) 🔲

- [ ] School registration and onboarding wizard
- [ ] Organization settings (branding, logo, academic calendar)
- [ ] Campus/stage/class hierarchy management
- [ ] Role-based access per campus/stage
- [ ] Data isolation between organizations
- [ ] Organization-specific feature flag overrides
- [ ] Bulk import/export for school data
- [ ] Basic school analytics (attendance, grades, assignments reports — Firestore, no BigQuery)

**NOT in v2.5 (moved to v3.0):** ~~BigQuery~~, ~~Custom Report Builder~~, ~~Platform Analytics~~

---

## v2.6 — School Landing Pages 🔲 (NEW)

- [ ] Public school profile at `klasivo.app/school/{slug}`
- [ ] School name, logo, description, contact information
- [ ] Public announcement feed
- [ ] Admission links
- [ ] Admin profile editor
- [ ] SEO metadata and slug management
- [ ] Feature flag: `school_landing_pages_enabled`

---

## v2.7 — Web Dashboard & School Analytics 🔲

- [ ] Flutter Web dashboard skeleton at `dashboard.klasivo.app`
- [ ] `/dashboard` — Overview
- [ ] `/users` — User management
- [ ] `/roles` — Role assignment
- [ ] `/scopes` — Scope assignment
- [ ] `/settings` — Organization settings
- [ ] School analytics dashboard (teacher, student, admin views)
- [ ] Bulk import (CSV/Excel)

---

## v2.8 — Subscription & Billing 🔲

- [ ] Subscription plans (Free, Pro, Enterprise)
- [ ] Stripe integration
- [ ] Subscription management
- [ ] Invoice generation and history
- [ ] Feature gating based on tier
- [ ] Usage metering

---

## v3.0 — Full Dashboard Platform + Enterprise Analytics 🔲

- [ ] Owner Dashboard (`dashboard.klasivo.app/owner`)
- [ ] BigQuery integration for historical analytics
- [ ] Custom Report Builder (drag-and-drop)
- [ ] Platform Analytics (DAU, WAU, MAU, retention)
- [ ] Platform Separation (`platform.klasivo.app`, `dashboard.klasivo.app`, `api.klasivo.app`)
- [ ] Student Performance Prediction (ML)
- [ ] Migration Phases M1–M8

---

## v3.5 — AI Features 🔲 (NEW)

### AI Question Generator
- [ ] Teacher uploads lesson → AI generates questions → Teacher edits → Publish exam
- [ ] Subject-specific, difficulty control, Bloom's taxonomy alignment

### AI Assignment Grading Assistant
- [ ] Teacher uploads rubric → AI suggests score → Teacher approves
- [ ] AI-assisted, NOT automatic — teacher always has final say

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
| Cloud Functions | 17 |

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
10. **Adoption Before Infrastructure** — Features schools pay for ship before backend scale features
