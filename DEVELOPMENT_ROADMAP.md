# Klasivo — Development Roadmap

> **Current Version:** v2.0.0+7  
> **Platform:** Android (Flutter 3.x / Dart 3.x) → Multi-platform (Mobile + Web + Dashboard)  
> **Architecture:** Clean Architecture + Riverpod + Firebase + Monorepo  
> **Last Updated:** 2026-06-15

> **Canonical roadmap:** `klasivo-repo/DEVELOPMENT_ROADMAP.md` — this file is a summary. Full details, dependency maps, migration plans, sprint breakdowns, competitive positioning, geographic expansion, AI governance, and disaster recovery live there.

---

## Strategic Phase Overview

| Phase | Name | Versions | Status |
|-------|------|----------|--------|
| **1** | Foundation | v1.0–v2.0.1 | ✅ Complete |
| **2** | School Adoption | v2.1–v2.3A | 🔲 Next |
| **3** | Core Academic | v2.4 | 🔲 Planned |
| **3.5** | Academic Records & Gradebook | v2.5 | 🔲 Planned |
| **4** | Student & Parent Engagement | v2.6–v2.7 | 🔲 Planned |
| **5** | School Management | v2.8–v2.9 | 🔲 Planned |
| **6** | Analytics & Dashboard | v3.0–v3.1 | 🔲 Planned |
| **7** | Revenue & Billing | v3.2 | 🔲 Planned |
| **8** | AI Layer | v3.5 | 🔲 Planned |
| **9** | Enterprise Analytics | v4.0 | 🔲 Planned |
| **10** | Enterprise Readiness | v4.5 | 🔲 Planned |
| **11** | Marketplace & Ecosystem | v5.0 | 🔲 Planned |
| **12** | Scale & Global | v5.5+ | 🔲 Planned |

---

## Re-prioritization (2026-06-15)

Roadmap re-prioritized to focus on **adoption-driving features before infrastructure scale**. Schools pay for features they use daily (teacher approval, assignments, parent engagement, gradebook, report cards), not backend sophistication.

**Moved UP:** Teacher Approval (v2.3→v2.2), Assignment Submission (v2.4→v2.3), Parent Enhanced (v2.4.1→v2.3A)  
**Moved DOWN:** BigQuery (v2.5→v4.0), Custom Reports (v2.5→v4.0), Platform Analytics (v2.5→v4.0), Web Dashboard (Sprint 4→v3.0)  
**NEW:** Student Engagement & Reminders (v2.2A), Academic Records & Gradebook (v2.5), Student Information System (v2.6), Communication Hub (v2.7), School Migration Center (v2.9), Mobile-First Offline (v3.1), AI Governance (v3.5), AI Features (v3.5)

---

## Version History

| Version | Focus | Phase | Status |
|---------|-------|-------|--------|
| **v1.0** | Core exam platform (auth, exams, grading) | P1 | ✅ Complete |
| **v1.1–v1.4** | Student dashboard, auto-save, timer, violations | P1 | ✅ Complete |
| **v1.5** | QR enrollment, notifications, PDF reports | P1 | ✅ Complete |
| **v1.6** | Announcements, Calendar, Academic Years, Audit Logs | P1 | ✅ Complete |
| **v1.7** | Enterprise foundations (Design Tokens, Component Library, Feature Flags, Event Bus, Permission Service) | P1 | ✅ Complete |
| **v1.8** | Feature Completion (LMS screens, Messaging UI, legacy cleanup) | P1 | ✅ Complete |
| **v1.9** | Polish & Integration (component migration, tests, CI/CD) | P1 | ✅ Complete |
| **v2.0** | Dark mode, Push notifications, Video player, Content tracking | P1 | ✅ Complete |
| **v2.1** | Video Library & Recorded Lessons (YouTube) | P2 | 🔲 Planned |
| **v2.2** | Teacher Approval Workflow & Role-Based Routing | P2 | 🔲 Planned |
| **v2.2A** | Student Engagement & Reminders | P2 | 🔲 Planned |
| **v2.3** | Assignment Submission API | P2 | 🔲 Planned |
| **v2.3A** | Parent Accounts Enhanced | P2 | 🔲 Planned |
| **v2.4** | Enhanced Attendance & Communication Foundations | P3 | 🔲 Planned |
| **v2.5** | Academic Records & Gradebook (NEW) | P3.5 | 🔲 Planned |
| **v2.6** | Student Information System (NEW) | P4 | 🔲 Planned |
| **v2.7** | Communication Hub (NEW) | P4 | 🔲 Planned |
| **v2.8** | School Accounts / Multi-Tenancy (simplified) | P5 | 🔲 Planned |
| **v2.9** | School Landing Pages & Migration Center (NEW) | P5 | 🔲 Planned |
| **v3.0** | Web Dashboard & School Analytics | P6 | 🔲 Planned |
| **v3.1** | Mobile-First Offline Strategy (NEW) | P6 | 🔲 Planned |
| **v3.2** | Subscription & Billing | P7 | 🔲 Planned |
| **v3.5** | AI Layer — Governance + Question Generator + Grading Assistant (NEW) | P8 | 🔲 Planned |
| **v4.0** | Full Dashboard Platform + Enterprise Analytics | P9 | 🔲 Planned |
| **v4.5** | Enterprise Readiness — Compliance, SSO, Disaster Recovery (NEW) | P10 | 🔲 Planned |
| **v5.0** | Marketplace & Ecosystem (NEW) | P11 | 🔲 Planned |
| **v5.5+** | Scale & Global Expansion (NEW) | P12 | 🔲 Planned |

---

## v1.0–v2.0.1 — Completed ✅

All versions through v2.0.1 are complete. See `klasivo-repo/DEVELOPMENT_ROADMAP.md` for full details.

---

## v2.1 — Video Library & Recorded Lessons (YouTube) 🔲

> Independent of Sprint 3. Can ship in parallel.

- [ ] Firestore `class_recordings` collection
- [ ] YouTube video ID extraction utility
- [ ] Teacher upload/link flow with visibility controls
- [ ] Recording list screen with search and thumbnails
- [ ] View count tracking and watch time analytics

---

## v2.2 — Teacher Approval Workflow & Role-Based Routing 🔲

> Depends on: Sprint 3

- [ ] Admin approves/rejects teacher registration requests
- [ ] Teacher onboarding with invite code verification
- [ ] Approval queue dashboard for owners/admins
- [ ] RBAC route guards on all screens
- [ ] Dynamic navigation based on effective permissions

---

## v2.2A — Student Engagement & Reminders 🔲

> Can ship alongside v2.2. Low effort, high value.

- [ ] Achievement badges (Academic, Engagement, Milestone)
- [ ] Learning streaks (login, submission, streak freeze)
- [ ] Progress visibility per subject
- [ ] Leaderboards (optional, feature-flagged)
- [ ] Student reminder engine (assignment due, overdue, exam, live class)

---

## v2.3 — Assignment Submission API 🔲

> Depends on: Sprint 3

- [ ] REST API for assignment creation, submission, and grading
- [ ] File upload support (PDF, images, documents)
- [ ] Rubric-based grading interface
- [ ] Batch grading and feedback
- [ ] Student submission status tracking

---

## v2.3A — Parent Accounts Enhanced 🔲

- [ ] Self-service parent registration
- [ ] Link multiple children to one parent account
- [ ] Parent dashboard with real-time child progress
- [ ] Push notifications for grades, attendance, announcements
- [ ] Weekly progress summary emails

---

## v2.4 — Enhanced Attendance & Communication Foundations 🔲

- [ ] Real-time attendance during live classes
- [ ] Manual attendance marking by teachers
- [ ] Attendance analytics per student/class/subject
- [ ] Parent absence notifications
- [ ] Chat file/image attachments and message reactions

---

## v2.5 — Academic Records & Gradebook 🔲 🆕

> **Most critical addition.** Schools cannot fully replace existing systems without gradebooks and report cards.

- [ ] Gradebook (weighted categories, grade calculation engine, GPA)
- [ ] Report Cards (template builder, PDF generation, school branding)
- [ ] Academic Terms (year configuration, term-based aggregation)
- [ ] Transcripts (official transcript generation, cumulative GPA, credit tracking)
- [ ] GPA Calculations (weighted/unweighted, custom scales, class rank)
- [ ] Subject Performance Analytics (trends, comparisons, weak subject alerts)
- [ ] Teacher Comments (per student/subject/term, comment bank)
- [ ] Parent Report Access (in-app viewer, PDF download, email notification)

---

## v2.6 — Student Information System (SIS) 🔲 🆕

- [ ] Comprehensive student profile (academic, attendance, medical, emergency, documents)
- [ ] Academic history (term-by-term grades, GPA trends, achievements)
- [ ] Attendance history (patterns, absence reasons, early warning)
- [ ] Parent relationships (guardian types, sibling detection)
- [ ] Medical notes (conditions, medications, dietary restrictions)
- [ ] Emergency contacts (multiple, prioritized, verified)
- [ ] Document management (upload, categorize, access control, e-signatures)

---

## v2.7 — Communication Hub 🔲 🆕

> Replaces WhatsApp as the school's primary communication channel.

- [ ] Broadcast announcements (multi-channel: push + in-app + email + SMS)
- [ ] School alerts (emergency, attendance, grade, event — priority levels)
- [ ] Teacher-parent messaging (scoped to shared student, auto-translate)
- [ ] Scheduled campaigns (recurring newsletters, campaign analytics)
- [ ] SMS integration (Twilio/Vonage) for urgent alerts and non-smartphone parents

---

## v2.8 — School Accounts / Multi-Tenancy (Simplified) 🔲

- [ ] School registration and onboarding wizard
- [ ] Organization settings (branding, logo, academic calendar)
- [ ] Campus/stage/class hierarchy management
- [ ] Data isolation between organizations
- [ ] Basic school analytics (Firestore, no BigQuery)

**NOT in v2.8 (moved to v4.0):** ~~BigQuery~~, ~~Custom Report Builder~~, ~~Platform Analytics~~

---

## v2.9 — School Landing Pages & Migration Center 🔲 🆕

- [ ] Public school profile at `klasivo.app/school/{slug}`
- [ ] Admin profile editor with SEO metadata
- [ ] School Migration Center: import students, teachers, classes, subjects, attendance, grades
- [ ] Import formats: Excel (.xlsx), CSV
- [ ] Import wizard with validation, dry-run preview, and rollback

---

## v3.0 — Web Dashboard & School Analytics 🔲

- [ ] Flutter Web dashboard skeleton at `dashboard.klasivo.app`
- [ ] `/dashboard` — Overview
- [ ] `/users` — User management
- [ ] `/roles`, `/scopes`, `/settings`
- [ ] School analytics dashboard (teacher, student, admin views)

---

## v3.1 — Mobile-First Offline Strategy 🔲 🆕

> Competitive advantage for developing markets — no competitor offers true offline LMS.

- [ ] Offline data access (assignments, lessons, recording metadata, grades)
- [ ] Offline actions queued for sync (submission drafts, message drafts)
- [ ] Local SQLite/Hive database for offline storage
- [ ] Sync queue with conflict resolution
- [ ] Network-aware Riverpod providers

---

## v3.2 — Subscription & Billing 🔲

- [ ] Subscription plans (Free, Pro, Enterprise)
- [ ] Stripe integration
- [ ] Feature gating based on tier
- [ ] Usage metering and admin billing dashboard

---

## v3.5 — AI Layer (Governance + Features) 🔲 🆕

### AI Governance Framework
- [ ] Usage quotas (per-school, per-teacher, daily/weekly/monthly)
- [ ] Cost controls (monthly budget, auto-disable at limit)
- [ ] Prompt logging & audit (hashes + metadata, opt-in full content)
- [ ] Content moderation (input/output safety scoring, blocklists)
- [ ] Human approval workflows (AI output = suggestion, never decision)
- [ ] Transparency labels ("AI-Assisted" in UI, parent notification)

### AI Features
- [ ] AI Question Generator: lesson → questions → teacher edits → publish exam
- [ ] AI Grading Assistant: rubric → AI suggests score → teacher confirms
- [ ] Always teacher-facing, never student-facing

---

## v4.0 — Full Dashboard Platform + Enterprise Analytics 🔲

- [ ] Owner Dashboard (`dashboard.klasivo.app/owner`)
- [ ] BigQuery integration for historical analytics
- [ ] Custom Report Builder (drag-and-drop)
- [ ] Platform Analytics (DAU, WAU, MAU, retention)
- [ ] Platform Separation (`platform.klasivo.app`, `dashboard.klasivo.app`, `api.klasivo.app`)
- [ ] Student Performance Prediction (ML)
- [ ] Migration Phases M1–M8

---

## v4.5 — Enterprise Readiness 🔲 🆕

- [ ] Compliance framework (GDPR, COPPA, FERPA, Egyptian data protection)
- [ ] SSO (Google Workspace, Microsoft 365, SAML 2.0)
- [ ] Disaster Recovery (RPO: 15 min, RTO: 4 hours, backup verification, quarterly drills)

---

## v5.0 — Marketplace & Ecosystem 🔲 🆕

- [ ] Public REST API with OAuth 2.0
- [ ] Plugin marketplace (grading, content, communication, analytics)
- [ ] Third-party integrations (Google Workspace, Microsoft 365, Zoom, LTI)

---

## v5.5+ — Scale & Global Expansion 🔲 🆕

- [ ] Multi-region deployment (US, EU, Asia)
- [ ] Geographic expansion: Egypt → GCC → MENA → Africa → Global
- [ ] Localization framework (RTL, Arabic, French, multi-language)
- [ ] Regional compliance templates
- [ ] White-label platform for school chains

---

## Current Codebase Stats

| Metric | Count |
|--------|-------|
| Services | 56 |
| Providers | 54 |
| Screens | 71 |
| Routes | 65+ |
| Custom Widgets | 14 |
| Feature Flags | 27 (+7 AI) |
| Permissions | 80+ (+4 domains) |
| Event Types | 25+ |
| User Roles | 11 |
| Firestore Indexes | 126 (+6 new) |
| Cloud Functions | 17 (+12 new) |
| Firestore Collections | 30 (+20 new) |

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                        Presentation Layer                         │
│  Mobile App  ·  Web Dashboard  ·  Owner Platform  ·  Public Site│
├──────────────────────────────────────────────────────────────────┤
│                     Shared Packages (Monorepo)                    │
│  auth  ·  permissions  ·  analytics  ·  notifications            │
│  api_client  ·  design_system  ·  audit_logs  ·  common_models  │
│  gradebook  ·  sis  ·  communication  ·  ai_governance           │
├──────────────────────────────────────────────────────────────────┤
│                        State Management                           │
│  Providers (54+)  ·  Riverpod  ·  Offline Sync Queue             │
├──────────────────────────────────────────────────────────────────┤
│                        Business Logic                             │
│  Services (56+)  ·  Event Bus  ·  Feature Flags                  │
│  RBAC  ·  Permission Service  ·  GPA Calculator  ·  AI Governance│
├──────────────────────────────────────────────────────────────────┤
│                        Data Layer                                 │
│  Firebase Auth  ·  Firestore  ·  FCM  ·  Hive  ·  PDF           │
│  Functions (37+)  ·  LiveKit  ·  Storage  ·  Stripe              │
│  BigQuery (v4.0+)  ·  Algolia (v4.0+)  ·  Twilio SMS (v2.7+)   │
│  OpenAI/Gemini (v3.5+)  ·  Local SQLite (v3.1+ offline)         │
└──────────────────────────────────────────────────────────────────┘
```

## Key Implementation Principles

1. **Use Design Tokens** — All colors, spacing, typography from `lib/core/tokens/`
2. **Use Enterprise Components** — KlasivoButton, KlasivoCard, KlasivoBadge, etc.
3. **Use Feature Flags** — Gate new features AND migration steps behind flags
4. **Use Permission Gates** — `KlasivoPermissionGate`, `KlasivoRoleGate`
5. **Use Event Bus** — Decouple feature modules via typed events
6. **Follow Clean Architecture** — Services → Providers → Screens
7. **Soft Delete** — All entities use `isArchived` + `archivedAt` pattern
8. **Riverpod Functional Style** — Functional providers, not Notifiers (except where needed)
9. **Firestore Security** — Role-based rules with field-level security
10. **Adoption Before Infrastructure** — Features schools pay for ship before backend scale features
11. **Academic Core First** — Gradebook, report cards, and transcripts are prerequisites for school switching
12. **AI is Always Suggestion, Never Decision** — Every AI output requires human approval
13. **Offline is a Feature, Not an Afterthought** — Mobile-first means offline-first for developing markets
14. **School Migration Removes Barriers** — Making import easy removes the #1 adoption blocker
