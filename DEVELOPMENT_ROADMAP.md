# Klasivo — Unified Development Roadmap

> **Current Version:** v2.0.0+7  
> **Platform:** Android (Flutter 3.x / Dart 3.x) → Multi-platform (Mobile + Web + Dashboard)  
> **Architecture:** Clean Architecture + Riverpod + Firebase + Monorepo  
> **Last Updated:** 2026-06-15  
> **Source of Truth:** This document supersedes all previous roadmap versions.
> 
> **🔴 ROADMAP VERSION 1.0 — LOCKED**  
> **Status:** Feature-complete. No new items accepted unless required by a paying school, security/compliance, or scaling. All future ideas go to `FUTURE_IDEAS.md`.  
> **Execution Priority:** Ship the next 5 deliverables. Stop planning, start building.

---

## Strategic Phase Overview

Klasivo's roadmap is organized into **12 strategic phases** that transform the platform from an exam tool into a complete School Operating System. Each phase builds on the previous, following the core principle: **Adoption Before Infrastructure**.

| Phase | Name | Versions | Focus | Status |
|-------|------|----------|-------|--------|
| **1** | Foundation | v1.0–v2.0.1 | Core exam platform, auth, grading, LMS foundations | ✅ Complete |
| **2** | School Adoption | v2.1–v2.3A | Features schools pay for daily: video, teacher approval, assignments, parent portal | 🔲 Next |
| **3** | Core Academic | v2.4 | Enhanced attendance, communication foundations | 🔲 Planned |
| **3.5** | Academic Records & Gradebook | v2.5 | Gradebook, report cards, transcripts, academic terms, GPA | 🔲 Planned |
| **3.6** | Academic Scheduling | v2.5A | Timetable builder, room scheduling, period management | 🔲 Planned |
| **4** | Student & Parent Engagement | v2.6–v2.7 | Student Information System, Communication Hub | 🔲 Planned |
| **5** | School Management | v2.8–v2.9 | School accounts, landing pages, migration center | 🔲 Planned |
| **6** | Analytics & Dashboard | v3.0 | Web dashboard, school analytics, migration | 🔲 Planned |
| **7** | Revenue & Billing | v3.1 | Subscriptions, billing, payment processing | 🔲 Planned |
| **8** | Assessment & AI Layer | v3.3–v3.5 | Assessment engine, learning outcomes, AI governance, question generator, grading assistant | 🔲 Planned |
| **9** | Enterprise Analytics | v4.0 | BigQuery, custom reports, platform analytics, performance prediction | 🔲 Planned |
| **10** | Enterprise Readiness | v4.5 | Compliance, SSO, disaster recovery, scale hardening | 🔲 Planned |
| **11** | Marketplace & Ecosystem | v5.0 | Plugin marketplace, third-party integrations, API platform | 🔲 Planned |
| **12** | Scale & Global | v5.5+ | Geographic expansion, localization, regional compliance, CDN, multi-region | 🔲 Planned |

**Why Phase 3.5 is the most critical addition:** Schools cannot fully replace existing systems without gradebooks and report cards. This single phase increases Klasivo's value more than most AI features. It bridges the gap between "exam platform with extra features" and "complete school platform."

---

## Five Pillars of Klasivo

The roadmap is organized around five strategic pillars that represent the complete value proposition of a School Operating System:

| Pillar | Purpose | Key Releases | Moat |
|--------|---------|-------------|------|
| **1 — Academic Operations** | The core reason schools buy | Attendance, Assignments, Exams, Gradebook, Report Cards, Timetable, Assessment Engine | Schools cannot leave once academic data lives here |
| **2 — School Operations** | The daily operations layer | SIS, Communication Hub, Approvals, Documents, Migration Center | Schools cannot operate without these once adopted |
| **3 — Engagement** | The retention engine | Parents, Notifications, Recordings, Progress Tracking, Mobile Growth | Parents become advocates; students stay engaged |
| **4 — Intelligence** | The differentiation layer | Analytics, AI Teaching, Learning Outcomes, Risk Detection, Benchmarking | Data insights no competitor can replicate at this scale |
| **5 — Growth** | The business engine | Billing, Marketplace, Public School Pages, Geographic Expansion, 30-Minute Launch | Network effects make Klasivo more valuable with every school |

Every feature in this roadmap maps to exactly one pillar. If a feature doesn't fit a pillar, it doesn't belong in Klasivo.

---

## Re-prioritization Summary (2026-06-15)

This roadmap has been **re-prioritized** to focus on adoption-driving features before infrastructure scale. The core insight: schools pay for features they use daily (teacher approval, assignments, parent engagement, gradebook, report cards), not for backend sophistication they never see.

**What moved UP:**
- Teacher Approval Workflow → v2.2 (was v2.3) — trust feature, directly impacts adoption
- Assignment Submission API → v2.3 (was v2.4) — highest-frequency educational workflow
- Parent Accounts Enhanced → v2.3A (was v2.4.1) — parents create engagement and retention
- Student Engagement & Reminders → v2.2A (NEW) — low effort, high value for retention
- Academic Records & Gradebook → v2.5 (NEW Phase 3.5) — schools cannot switch without this
- Student Information System → v2.6 (NEW) — central student record, SIS foundation
- Communication Hub → v2.7 (NEW) — complete communication layer

**What moved DOWN:**
- BigQuery → v4.0 (was v3.0) — not needed until 50+ schools
- Custom Report Builder → v4.0 (was v3.0) — schools initially want basic reports, not BI
- Platform Analytics → v4.0 (was v3.0) — school analytics first, platform analytics later
- Flutter Web Dashboard Skeleton → v3.0 (was Sprint 4 immediately after 3B)
- Owner Platform → v4.0 (was Sprint 7)

**What's NEW:**
- v2.2A — Student Engagement (badges, streaks, progress, leaderboards)
- Student Reminder Engine (assignment due, overdue, exam tomorrow, live class starting)
- v2.5 — Academic Records & Gradebook (gradebook, report cards, academic terms, transcripts, GPA)
- v2.6 — Student Information System (academic history, attendance history, medical, emergency contacts)
- v2.7 — Communication Hub (push, email, SMS, in-app, broadcasts, messaging)
- v2.9 — School Migration Center (Excel/CSV import for students, teachers, classes, grades)
- v3.1 — Mobile-First Offline Strategy (offline assignments, lessons, recordings, sync)
- v3.5 — AI Governance Framework (usage quotas, cost controls, prompt logging, moderation, audit trails)
- AI Question Generator (v3.5) — teacher uploads lesson → AI generates questions
- AI Assignment Grading Assistant (v3.5) — teacher uploads rubric → AI suggests score
- Competitive Positioning section — why Klasivo wins vs Google Classroom, Moodle, Canvas
- Geographic Expansion Strategy — Egypt → GCC → MENA → Africa → Global
- Disaster Recovery Objectives — RTO/RPO targets, backup verification, recovery drills
- Success KPIs Per Phase — measurable outcomes for every release

---

## How This Roadmap Works

This roadmap uses **four parallel tracks** that proceed independently but converge:

- **Strategic Phases** (Phase 1–12) — high-level business milestones, each represents a value threshold
- **Releases** (v2.1, v2.2, ...) — user-facing feature deliveries, each produces a shippable build
- **Sprints** (Sprint 1, 2, ...) — infrastructure/RBAC work that enables platform-scale features
- **Migration Phases** (M1–M8) — zero-downtime migration from MVP to production SaaS platform

A release may span multiple sprints. A sprint may contribute to multiple releases. Dependencies are explicitly mapped.

```
Strategic:  P1 ────── P2 ────── P3 ── P3.5 ── P4 ────── P5 ────── P6 ── P7 ── P8 ── P9 ── P10 ── P11 ── P12
              │         │        │      │       │         │         │      │     │     │      │      │      │
Releases:  v1.0-2.0  v2.1-2.3A v2.4   v2.5   v2.6-2.7  v2.8-2.9  v3.0  v3.1  v3.5  v4.0  v4.5   v5.0  v5.5+
                                                                                         \
Sprints:   S1+S2 ── S3 ── S3B ── S4 ── S5+S6 ── S7 ── S8 ── S9+                              \
                                                                                                  \
Migration:                                                                           M1 ── M2 ── M3 ── M4 ── M5 ── M6 ── M7 ── M8
```

**Key:** 
- v2.1 (Video Library) is **independent** — can ship before or in parallel with Sprint 3.
- v2.2–v2.3A are the **adoption sprint** — highest-impact features for first 10–20 schools.
- v2.5 (Academic Records) is the **switching threshold** — without gradebook and report cards, schools cannot fully replace existing systems.
- Sprint 4+ and infrastructure work (dashboard, BigQuery, platform analytics) comes **after** adoption-driving features.

---

## Version History

| Version | Focus | Release | Sprint | Phase | Status |
|---------|-------|---------|--------|-------|--------|
| **v1.0** | Core exam platform (auth, exams, grading) | v1.0 | — | P1 | ✅ Complete |
| **v1.1–v1.4** | Student dashboard, auto-save, timer, violations | v1.4 | — | P1 | ✅ Complete |
| **v1.5** | QR enrollment, notifications, PDF reports | v1.5 | — | P1 | ✅ Complete |
| **v1.6** | Announcements, Calendar, Academic Years, Audit Logs | v1.6 | — | P1 | ✅ Complete |
| **v1.7** | Enterprise foundations (Tokens, Components, Flags, EventBus, Permissions) | v1.7 | — | P1 | ✅ Complete |
| **v1.8** | Feature Completion (LMS, Messaging, legacy cleanup) | v1.8 | — | P1 | ✅ Complete |
| **v1.9** | Polish & Integration (component migration, tests, CI/CD) | v1.9 | — | P1 | ✅ Complete |
| **v2.0** | Dark mode, Push notifications, Video player, Content tracking | v2.0 | — | P1 | ✅ Complete |
| **v2.0.1** | Bug fixes (WidgetRef, mounted guards, adaptive icon, auth data sync) | v2.0.1 | — | P1 | ✅ Complete |
| **v2.1** | Video Library & Recorded Lessons (YouTube Integration) | v2.1 | — | P2 | 🔲 Planned |
| **v2.2** | Teacher Approval Workflow & Role-Based Routing | v2.2 | S3 | P2 | 🔲 Planned |
| **v2.2A** | Student Engagement & Reminders | v2.2A | S3 | P2 | 🔲 Planned |
| **v2.3** | Assignment Submission API | v2.3 | S3 | P2 | 🔲 Planned |
| **v2.3A** | Parent Accounts Enhanced | v2.3A | S3B | P2 | 🔲 Planned |
| **v2.4** | Enhanced Attendance & Communication Foundations | v2.4 | S3B | P3 | 🔲 Planned |
| **v2.5** | Academic Records & Gradebook | v2.5 | S4 | P3.5 | 🔲 Planned |
| **v2.5A** | Timetable Builder & Academic Scheduling | v2.5A | S4 | P3.6 | 🔲 Planned |
| **v2.6** | Student Information System (SIS) | v2.6 | S4 | P4 | 🔲 Planned |
| **v2.7** | Communication Hub | v2.7 | S4 | P4 | 🔲 Planned |
| **v2.8** | School Accounts / Multi-Tenancy (simplified) | v2.8 | S5 | P5 | 🔲 Planned |
| **v2.9** | School Landing Pages & Migration Center + 30-Minute School Launch | v2.9 | S5 | P5 | 🔲 Planned |
| **v3.0** | Web Dashboard & School Analytics | v3.0 | S5+S6 | P6 | 🔲 Planned |
| **v3.1** | Mobile-First Offline Strategy | v3.1 | S6 | P6 | 🔲 Planned |
| **v3.2** | Subscription & Billing | v3.2 | — | P7 | 🔲 Planned |
| **v3.3** | Assessment Engine | v3.3 | S9 | P8 | 🔲 Planned |
| **v3.4** | Learning Outcomes Framework | v3.4 | S9 | P8 | 🔲 Planned |
| **v3.5** | AI Features (Governance + Question Generator + Grading Assistant) | v3.5 | S9+ | P8 | 🔲 Planned |
| **v4.0** | Full Dashboard Platform + Enterprise Analytics | v4.0 | S7+S8+M1-M8 | P9 | 🔲 Planned |
| **v4.5** | Enterprise Readiness (Compliance, SSO, DR) | v4.5 | — | P10 | 🔲 Planned |
| **v5.0** | Marketplace & Ecosystem | v5.0 | — | P11 | 🔲 Planned |
| **v5.5+** | Scale & Global Expansion | v5.5+ | — | P12 | 🔲 Planned |

---

## Sprint History

| Sprint | Focus | Status | Code Location |
|--------|-------|--------|---------------|
| **Sprint 1** | LiveKit — rooms, token gen, lobby, chat, hands, attendance, recordings, scheduled classes, analytics | ✅ Coded | `klasivo/lib/features/livekit/` + `klasivo/functions/` |
| **Sprint 2** | RBAC Infrastructure — Custom Claims, Firestore Rules, Scope-level auth, Password Flow, Audit Logs | ✅ Coded | `klasivo/lib/core/rbac/` + `klasivo/functions/src/` |
| **Sprint 2A** | Scope-level LiveKit authorization (verifyScopeAuthorization, SCOPE_REQUIREMENTS, room-type-based checks, fail-closed) | ✅ Coded | `klasivo/functions/src/utils/rbac.ts` + `generateLiveKitToken.ts` |
| **Sprint 3** | Scope Enforcement, Claims Caching, Error Handling, Role Hierarchy helpers + Teacher Approval + Student Engagement + Assignment API | 🔲 Next | — |
| **Sprint 3B** | User Management UI — People Hub, Role Matrix, Scope Assignment, Permission Overrides + Parent Enhanced + Enhanced Attendance | 🟡 Partial | `klasivo/lib/features/user_management/` (screens exist, routes not wired) |
| **Sprint 4** | Academic Records & Gradebook + Student Information System + Communication Hub | 🔲 Planned | — |
| **Sprint 5** | School Accounts / Multi-Tenancy + School Landing Pages + Migration Center | 🔲 Planned | — |
| **Sprint 6** | Web Dashboard Skeleton + School Analytics + Mobile Offline | 🔲 Planned | — |
| **Sprint 7** | Full Dashboard Platform — `platform.klasivo.app`, BigQuery, Custom Reports | 🔲 Planned | — |
| **Sprint 8** | Platform Separation — subdomain routing, auth flow separation | 🔲 Planned | — |
| **Sprint 9+** | AI Features, Billing, Scale | 🔲 Planned | — |

---

## Dependency Map

```
┌─────────────────────────────────────────────────────────────────────┐
│  ✅ Sprint 1+2 code MERGED into klasivo-repo (2026-06-15)              │
│  All Sprint 3+ work depends on this merge.                          │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
          ┌────────────────────┼────────────────────┐
          │                    │                     │
          ▼                    ▼                     ▼
   ┌──────────┐      ┌──────────────┐      ┌──────────────┐
   │ v2.1     │      │ Sprint 3     │      │ v2.2         │
   │ Video    │      │ Scope        │      │ Teacher      │
   │ Library  │      │ Enforcement  │      │ Approval     │
   │ (indep.) │      │              │      │ Workflow     │
   └──────────┘      └──────┬───────┘      └──────┬───────┘
                             │                     │
                             ▼                     ▼
                     ┌──────────────┐      ┌──────────────┐
                     │ v2.2A        │      │ v2.3         │
                     │ Student      │      │ Assignment   │
                     │ Engagement   │      │ Submission   │
                     │ & Reminders  │      │ API          │
                     └──────┬───────┘      └──────┬───────┘
                             │                     │
                             └──────────┬──────────┘
                                        ▼
                                ┌──────────────┐
                                │ Sprint 3B    │
                                │ User Mgmt UI │
                                │ + v2.3A      │
                                │ Parent       │
                                │ Enhanced     │
                                │ + v2.4       │
                                │ Attendance   │
                                └──────┬───────┘
                                       │
                        ┌──────────────┼──────────────┐
                        │              │              │
                        ▼              ▼              ▼
                 ┌───────────┐  ┌───────────┐  ┌───────────────┐
                 │ Sprint 4  │  │ v2.5      │  │ v2.6 + v2.7  │
                 │ Academic  │  │ Gradebook │  │ SIS + Comm    │
                 │ Records   │  │ & Reports │  │ Hub           │
                 └─────┬─────┘  └───────────┘  └───────────────┘
                       │
                       ▼
                ┌───────────┐
                │ Sprint 5  │
                │ v2.8      │
                │ School    │
                │ Accounts  │
                │ + v2.9    │
                │ Landing + │
                │ Migration │
                └─────┬─────┘
                      │
               ┌──────┼──────┐
               │             │
               ▼             ▼
        ┌───────────┐ ┌───────────┐
        │ Sprint 6  │ │ v3.1      │
        │ v3.0      │ │ Offline   │
        │ Dashboard │ │ Strategy  │
        │ + v3.2    │ │           │
        │ Billing   │ │           │
        └─────┬─────┘ └───────────┘
              │
              ▼
       ┌───────────┐
       │ Sprint 7  │
       │ Full      │
       │ Platform  │
       │ + BigQuery│
       └─────┬─────┘
             │
             ▼
      ┌───────────┐
      │ Sprint 8  │
      │ Platform  │
      │ Separation│
      └─────┬─────┘
            │
     ┌──────┼──────┐
     │             │
     ▼             ▼
┌──────────┐ ┌──────────┐
│ M1-M8    │ │ v4.0     │
│Migration │ │ Full     │
│ Phases   │ │ Dashboard│
└──────────┘ └────┬─────┘
                  │
                  ▼
           ┌───────────┐
           │ v3.5      │
           │ AI Layer  │
           │ + Gov.    │
           └─────┬─────┘
                 │
        ┌────────┼────────┐
        │        │        │
        ▼        ▼        ▼
  ┌──────────┐ ┌──────┐ ┌──────────┐
  │ v4.5     │ │v5.0  │ │ v5.5+    │
  │ Enterprise│ │Market│ │ Scale &  │
  │ Readiness│ │place │ │ Global   │
  └──────────┘ └──────┘ └──────────┘
```

**Key Dependencies:**
- v2.5 (Gradebook) depends on v2.3 (Assignment Submission) — grades require assignments
- v2.6 (SIS) depends on v2.5 (Academic Records) — student profiles need grade history
- v2.7 (Communication Hub) depends on v2.3A (Parent Enhanced) — parent messaging requires parent accounts
- v2.9 (Migration Center) depends on v2.8 (School Accounts) — import requires school structure
- v3.5 (AI) depends on v2.5 (Gradebook) — AI grading needs rubric and grade data
- v4.0 (Enterprise Analytics) depends on v2.5 (Gradebook) + v2.8 (School Accounts) + v3.0 (Dashboard)

---

## Competitive Positioning

### Why Klasivo Wins

Klasivo occupies a unique position: it is the **only platform** that combines exam management, LMS, live classes, communication, AI teaching tools, and school administration into a single mobile-first experience designed for developing markets.

### Competitive Comparison

| Feature | Klasivo | Google Classroom | Moodle | Canvas | Schoology | ClassDojo |
|---------|---------|-----------------|--------|--------|-----------|-----------|
| **Exam System** | Advanced (3 types, auto-grade, integrity, timer) | Basic (Google Forms) | Quiz module | Basic | Basic | None |
| **Live Classes** | Built-in (LiveKit) | Google Meet integration | Plugin required | Integration | Integration | None |
| **Gradebook** | v2.5 (Full) | Basic | Full | Full | Full | Basic |
| **Report Cards** | v2.5 (Full) | None | Plugin | Full | Full | None |
| **Transcripts** | v2.5 | None | Plugin | Full | Full | None |
| **Parent Portal** | Full (mobile-first) | Email summaries | Basic | Full | Full | Primary feature |
| **Mobile-First** | Native Flutter | PWA | Poor mobile | PWA | PWA | Native |
| **Offline Mode** | v3.1 (Full) | Limited | None | Limited | None | Limited |
| **AI Teaching** | v3.5 (Questions + Grading) | None | None | None | None | None |
| **Multi-Tenant** | Full RBAC, 11 roles | Single domain | Self-hosted | Full | Full | Single school |
| **Arabic/RTL** | Planned (P12) | Partial | Plugin | Partial | None | Partial |
| **SMS Notifications** | v2.7 (Communication Hub) | None | Plugin | None | None | None |
| **School Migration** | v2.9 (Excel/CSV import) | Manual | Manual | Manual | Manual | Manual |
| **Pricing** | Freemium + Tiered | Free | Free/Self-hosted | Paid | Paid | Freemium |
| **Developing Market Focus** | Core strategy | No | No | No | No | Partial |

### Klasivo's Moat

1. **Mobile-Native in a Web-First Market** — Every competitor is web-first with mobile as an afterthought. Klasivo is mobile-native, which matters in MENA/Africa where mobile is the primary device.
2. **Exam-Grade LMS Fusion** — No competitor combines a serious exam engine with LMS features. Schools currently use 2–3 tools; Klasivo replaces all of them.
3. **Offline-First for Developing Markets** — Intermittent connectivity is the norm, not the exception, in target markets. v3.1 makes Klasivo usable without internet.
4. **School Migration Center** — The #1 adoption barrier is "our data is elsewhere." No competitor makes migration easy. Klasivo does.
5. **AI Teaching, Not Just AI Chat** — AI that generates questions and assists grading is directly useful to teachers. Competitors have generic AI copilots.
6. **All-in-One vs. Integration Hell** — Schools currently stitch together Google Classroom + Zoom + a gradebook tool + WhatsApp groups. Klasivo replaces all four.

---

## Geographic Expansion Strategy

### Phase A — Egypt (Current)

**Status:** Primary market  
**Target:** 100 schools in Year 1

- Arabic localization (full RTL support)
- Egyptian curriculum alignment
- Local payment methods (Fawry, Vodafone Cash, Instapay)
- Egyptian education regulations compliance
- Local support team (Arabic-speaking)
- Pricing: EGP-based, affordable for mid-tier private schools

**Key Metrics:**
- 100 schools by end of Year 1
- 50,000 students on platform
- 85% teacher activation rate
- NPS > 50

### Phase B — GCC (Year 2)

**Target Markets:** Saudi Arabia, UAE, Qatar, Kuwait, Bahrain, Oman

- Arabic/English bilingual (GCC schools often English-medium)
- GCC curriculum standards (Ministry of Education alignment)
- Regional payment (Mada, Apple Pay GCC, local bank transfers)
- Data residency options (UAE data centers)
- VIP support tier for premium schools
- Pricing: USD-based, premium tier for GCC market

**Key Metrics:**
- 50 GCC schools by end of Year 2
- Regional partnership with 2+ school chains
- MOE compliance certification in 2+ GCC countries

### Phase C — MENA (Year 2–3)

**Target Markets:** Jordan, Lebanon, Morocco, Tunisia, Iraq

- French localization (Morocco, Tunisia, Lebanon)
- Localized curricula per country
- Regional pricing (lower than GCC, higher than Egypt)
- Partnership with local education distributors
- Offline-first emphasis (lower connectivity)

**Key Metrics:**
- 100+ MENA schools outside GCC
- 3+ languages supported
- 200,000+ students across region

### Phase D — Africa (Year 3–4)

**Target Markets:** Nigeria, Kenya, South Africa, Ghana, Tanzania

- English + French + Swahili localization
- Mobile-money integration (M-Pesa, Flutterwave)
- Ultra-low-bandwidth mode
- Offline-first as primary, not secondary
- Partnership with NGOs and government education programs

**Key Metrics:**
- 200+ African schools
- Government pilot program in 2+ countries
- 500,000+ students across Africa

### Phase E — Global (Year 4+)

**Target Markets:** Southeast Asia, Latin America, South Asia

- Multi-language framework (plugin-based i18n)
- Regional compliance templates (GDPR, COPPA, FERPA, PDPA)
- Global CDN and multi-region deployment
- White-label options for school chains
- API platform for third-party integrations

**Localization Requirements (All Phases):**
- RTL layout support (Arabic, Hebrew, Urdu)
- Date/time/currency formatting per locale
- Regional academic calendar templates
- Country-specific grading scales (A-F, 1-10, percentage, GPA)
- Regional compliance frameworks
- Local language support content

---

# PART I — CURRENT PLATFORM (v1.0–v2.0.1)

## v2.0.1 — Bug Fixes ✅ (2026-06-15)

### Auth Data Sync
- [x] `saveTeacherAuthData`, `saveStudentAuthData`, `saveParentAuthData` now accept `WidgetRef? ref` and sync Riverpod providers after Hive writes
- [x] Welcome screen Hive fallback read if providers return null

### UI Fixes
- [x] Create Account / Sign In buttons misalignment — replaced `Wrap` with `Row` + `Flexible` across all auth screens

### Android App Icon
- [x] Fixed colored background on app icon — created adaptive icon XML + transparent foreground PNGs + white background

### Crash Fixes
- [x] Sentry crash `StateError: Cannot use 'ref' after widget disposed` — added `if (!mounted) return` / `if (mounted)` guards in all auth screen catch/finally blocks

---

## Immediate: Merge Sprint 1+2 Code into klasivo-repo ✅ COMPLETE

> **MERGED on 2026-06-15.** All Sprint 1+2 code has been merged into klasivo-repo. Sprint 3+ work is unblocked.

### What was merged from `klasivo/` to `klasivo-repo/`:

#### Flutter — LiveKit Feature (13 files) ✅
- [x] `lib/features/livekit/data/livekit_repository.dart`
- [x] `lib/features/livekit/domain/livekit_room_model.dart`
- [x] `lib/features/livekit/domain/livekit_chat_message.dart`
- [x] `lib/features/livekit/domain/livekit_raised_hand.dart`
- [x] `lib/features/livekit/domain/livekit_attendance.dart`
- [x] `lib/features/livekit/domain/recording_model.dart`
- [x] `lib/features/livekit/domain/scheduled_class_model.dart`
- [x] `lib/features/livekit/domain/session_analytics_model.dart`
- [x] `lib/features/livekit/providers/livekit_providers.dart`
- [x] `lib/features/livekit/pages/live_class_screen.dart`
- [x] `lib/features/livekit/pages/live_class_lobby_screen.dart`
- [x] `lib/features/livekit/pages/scheduled_classes_screen.dart`
- [x] `lib/features/livekit/pages/session_analytics_dashboard.dart`

#### Flutter — RBAC System (15+1 files) ✅
- [x] `lib/core/rbac/roles.dart`
- [x] `lib/core/rbac/scope_access_level.dart`
- [x] `lib/core/rbac/scope_validator.dart`
- [x] `lib/core/rbac/custom_claims.dart`
- [x] `lib/core/rbac/user_scope.dart`
- [x] `lib/core/rbac/scoped_query_builder.dart`
- [x] `lib/core/rbac/role_hierarchy.dart`
- [x] `lib/core/rbac/permission_groups.dart`
- [x] `lib/core/rbac/permission_service.dart`
- [x] `lib/core/rbac/permission_state.dart`
- [x] `lib/core/rbac/permission_overrides.dart`
- [x] `lib/core/rbac/permissions.dart`
- [x] `lib/core/rbac/rbac.dart` (barrel export)
- [x] `lib/core/rbac/rbac_health.dart`
- [x] `lib/core/rbac/password_generator.dart`
- [x] `lib/providers/rbac_provider.dart`

#### Flutter — User Management (10 files) ✅
- [x] `lib/features/user_management/data/user_management_repository.dart`
- [x] `lib/features/user_management/pages/people_hub_screen.dart`
- [x] `lib/features/user_management/pages/user_detail_screen.dart`
- [x] `lib/features/user_management/pages/role_assignment_sheet.dart`
- [x] `lib/features/user_management/pages/role_matrix_screen.dart`
- [x] `lib/features/user_management/pages/scope_assignment_screen.dart`
- [x] `lib/features/user_management/pages/permission_override_screen.dart`
- [x] `lib/features/user_management/pages/effective_permissions_screen.dart`
- [x] `lib/features/user_management/providers/user_management_providers.dart`
- [x] `lib/features/user_management/user_management.dart` (barrel export)

#### Cloud Functions — Migrate JS → TS (31 files) ✅
- [x] `functions/src/index.ts` + `functions/src/api/index.ts` + `functions/src/config/sentry.ts`
- [x] RBAC callables: `assignRole.ts`, `assignScope.ts`, `syncClaims.ts`, `changeUserPassword.ts`, `setPermissionOverrides.ts`
- [x] LiveKit callables: `generateLiveKitToken.ts`, `removeParticipant.ts`, `onLiveKitRoomEvents.ts`, `scheduledClassReminder.ts`
- [x] Auth triggers: `onUserCreated.ts`, `onUserDeleted.ts`
- [x] Email functions: `sendContactForm.ts`, `sendTeacherInvitation.ts`, `sendSchoolAnnouncement.ts`
- [x] Utils: `rbac.ts`, `sanitizer.ts`, `validators.ts`
- [x] Services: `emailService.ts`, `emailLogService.ts`, `queueService.ts`
- [x] Workers: `emailWorker.ts`
- [x] Templates: 5 email template files
- [x] Types: `email.ts`, `queue.ts`

#### Additional Files Merged ✅
- [x] `lib/core/services/claims_service.dart` — Firebase claims sync service
- [x] `lib/core/services/service_providers.dart` — Central DI provider registry (paths fixed for klasivo-repo)

#### Integration Work ✅
- [x] Wire LiveKit routes into GoRouter (`/live-classes`, `/live-classes/analytics`)
- [x] Wire User Management routes into GoRouter (`/people`, `/people/users/:userId`, `/people/roles`)
- [x] RBAC provider and imports available (`lib/providers/rbac_provider.dart`)
- [x] LiveKit SDK dependency added to `functions/package.json` (via TS migration)
- [x] Update `pubspec.yaml` with new Flutter dependencies (cloud_functions, livekit_client, firebase_app_check, firebase_analytics, sentry_flutter, freezed_annotation)
- [x] Update Firestore security rules with LiveKit + RBAC + Email Queue collections
- [x] Add feature flags for LiveKit and RBAC features (8 new flags: livekit, live_classes, scheduled_classes, session_recordings, rbac_v2, scope_management, permission_overrides, user_management)
- [x] Verify all imports resolve correctly (58 import paths verified, 0 broken)
- [ ] Add Firestore indexes for new collections (requires `firebase deploy`)
- [ ] Verify full build compiles (Flutter SDK not available in current environment)
- [ ] Run existing tests (requires Flutter SDK)

---

# PART II — FEATURE RELEASES (v2.1–v5.5+)

> **Priority order reflects adoption impact, not infrastructure dependency.** The first 7 deliverables (v2.1–v2.5) are the features schools will actually pay for. Infrastructure work (dashboard, BigQuery, platform analytics) comes later.
>
> **Revised Top 10 Priorities:**
> 1. Teacher Approval Workflow (v2.2)
> 2. Video Library — YouTube (v2.1)
> 3. Assignment Submission (v2.3)
> 4. Attendance Tracking (v2.4)
> 5. Gradebook & Report Cards (v2.5) ← **Most critical new addition**
> 6. Parent Portal (v2.3A)
> 7. Student Engagement (v2.2A)
> 8. School Accounts (v2.8)
> 9. Billing (v3.2)
> 10. AI Layer (v3.5)

---

## v2.1 — Video Library & Recorded Lessons (YouTube Integration) 🔲

> **Independent of Sprint 3.** Can ship in parallel with merge work.  
> **Why it's here:** Zero infrastructure cost, high perceived value, enables lesson replay and revision.

### Success KPIs
| KPI | Target | Measurement |
|-----|--------|-------------|
| Recording upload rate | > 2 recordings/teacher/week | Firestore query |
| Student viewing rate | > 60% of enrolled students watch | `recording_views` collection |
| Watch completion | > 40% average completion rate | Watch time analytics |
| Feature adoption | > 70% of schools use within 30 days | Feature flag activation |

### Phase 1 — Recording Library
- [ ] Firestore `class_recordings` collection with schema: `id`, `organizationId`, `classId`, `subjectId`, `teacherId`, `title`, `description`, `youtubeVideoId`, `thumbnailUrl`, `duration`, `publishedAt`, `visibility` (public/class-only/enrolled), `tags[]`, `createdAt`, `updatedAt`
- [ ] YouTube video ID extraction utility (supports full URL, short URL, embed URL, and raw ID formats)
- [ ] Class-specific recording filter (recordings scoped to student's enrolled classes)
- [ ] Recording list screen with search, filter by subject/teacher/date, and thumbnail grid view
- [ ] Route: `/lms/recordings`, `/lms/recordings/:recordingId`

### Phase 2 — Recording Management
- [ ] Teacher upload/link flow: paste YouTube URL → auto-extract video ID → fetch metadata
- [ ] Recording CRUD operations (create, edit, delete) with permission gates
- [ ] Visibility controls: Public (all students), Class-only (enrolled students), Draft (unpublished)
- [ ] Bulk import from YouTube playlist
- [ ] Recording form screen with URL validation and preview
- [ ] Route: `/teacher/recordings/create`, `/teacher/recordings/:recordingId/edit`

### Phase 3 — Analytics & Engagement
- [ ] View count tracking per recording (Firestore `recording_views` subcollection)
- [ ] Watch time analytics: aggregate watch time per student, per recording, per class
- [ ] Student engagement dashboard for teachers
- [ ] Recording popularity leaderboard
- [ ] Notify students when new recording is published (FCM + in-app)

### Future Expansion — Multi-Provider Architecture
- [ ] Abstract video provider interface: YouTube → Mux → LiveKit → Direct Upload
- [ ] Provider-agnostic recording model: `providerType` field with provider-specific metadata
- [ ] Feature flag per provider

---

## v2.2 — Teacher Approval Workflow & Role-Based Routing 🔲

> **Depends on: Sprint 3 (RBAC scope enforcement)**  
> **Why it moved UP:** Schools ask "How do we approve teachers before they enter the system?" This is a trust feature that directly impacts adoption. Without it, any teacher can join — schools won't accept that.

### Success KPIs
| KPI | Target | Measurement |
|-----|--------|-------------|
| Approval time | < 24 hours average | Approval timestamp - request timestamp |
| Teacher activation | > 80% within 48 hours of approval | First login after approval |
| Rejection rate | < 15% of requests | Approved vs. rejected counts |
| School satisfaction | > 90% feel in control | Survey (post-adoption) |

### Teacher Approval Workflow
- [ ] Admin approves/rejects teacher registration requests
- [ ] Teacher onboarding flow with invite code verification
- [ ] Approval queue dashboard for owners/admins
- [ ] Email notifications on approval status change
- [ ] Auto-assign default scope (campus/stage/class) on approval

### Role-Based Routing
- [ ] Mobile app refactored to use RBAC for route guards
- [ ] Permission gates on all screens (replace hardcoded role checks)
- [ ] Dynamic navigation based on user's effective permissions
- [ ] 403 Forbidden screen for unauthorized access attempts

---

## v2.2A — Student Engagement & Reminders 🔲

> **Can ship alongside v2.2.** Low effort, high value.  
> **Why it's NEW:** Student engagement and retention dramatically improve when students have visibility into their progress and receive timely reminders. These are table-stakes features for any LMS.

### Success KPIs
| KPI | Target | Measurement |
|-----|--------|-------------|
| Daily active students | > 60% of enrolled | DAU / total enrolled |
| Streak participation | > 40% maintain 7+ day streak | Streak collection query |
| Reminder effectiveness | > 50% act on reminders | Action after notification |
| Assignment on-time rate | > 85% with reminders ON | A/B vs. reminders OFF |

### Achievement Badges
- [ ] Badge system with categories: Academic (High Score, Perfect Attendance, Top Performer), Engagement (Streak Keeper, Active Participant, Early Bird), Milestone (First Exam, 10 Assignments, 100% Attendance)
- [ ] Badge display on student profile
- [ ] Badge notification on unlock
- [ ] Badge collection screen with locked/unlocked states
- [ ] Feature flag: `student_badges_enabled`

### Learning Streaks
- [ ] Daily login streak counter (consecutive days with activity)
- [ ] Assignment submission streak (consecutive on-time submissions)
- [ ] Streak freeze (1 per week — protects streak on a missed day)
- [ ] Streak display on student dashboard
- [ ] Streak milestone rewards (7 days, 30 days, 100 days)
- [ ] Feature flag: `student_streaks_enabled`

### Progress Visibility
- [ ] Overall progress percentage per subject (weighted: exams 40% + assignments 30% + attendance 20% + participation 10%)
- [ ] Assignment completion score (submitted on time / total assigned)
- [ ] Attendance score (days present / total school days)
- [ ] Progress cards on student dashboard
- [ ] Progress comparison with class average (anonymized)

### Leaderboards (Optional — Feature-Flagged)
- [ ] Per-class leaderboard (exam scores, assignment completion, attendance)
- [ ] Time-scoped: weekly, monthly, term
- [ ] Opt-in per school (some schools may not want competitive rankings)
- [ ] Anonymized option (show rank only, not scores)
- [ ] Feature flag: `leaderboards_enabled` → per-org, defaults OFF

### Student Reminder Engine
- [ ] **Assignment due tomorrow** — push notification at 8:00 PM local time
- [ ] **Assignment overdue** — push notification at 9:00 AM local time, daily until submitted
- [ ] **Exam tomorrow** — push notification at 8:00 PM local time day before
- [ ] **Live class starting** — push notification 5 minutes before scheduled start
- [ ] Reminder preferences per student (enable/disable per type)
- [ ] Reminder scheduling Cloud Function (runs daily at configured times per timezone)
- [ ] In-app reminder badge on relevant screen tabs
- [ ] Feature flag: `student_reminders_enabled` → defaults ON

---

## v2.3 — Assignment Submission API 🔲

> **Depends on: Sprint 3 (RBAC scope enforcement)**  
> **Why it moved UP:** Assignments are one of the highest-frequency educational workflows. Teachers create assignments daily, students submit daily. This is a core LMS function that must work flawlessly before schools will consider switching from their current tools.

### Success KPIs
| KPI | Target | Measurement |
|-----|--------|-------------|
| Weekly usage | > 75% of teachers create assignments | Firestore query |
| Submission rate | > 85% on-time submissions | Submitted / assigned |
| Grading turnaround | < 3 days average | Grade timestamp - submission timestamp |
| File upload success | > 99% success rate | Upload success/failure logs |

### Assignment Submission API
- [ ] REST API for assignment creation, submission, and grading
- [ ] File upload support (PDF, images, documents) — Firebase Storage
- [ ] Submission deadlines with late penalty rules (configurable: % deduction per day, hard deadline)
- [ ] Plagiarism detection integration placeholder (architecture ready, provider TBD)
- [ ] Rubric-based grading interface (criteria-based scoring with weight per criterion)
- [ ] Batch grading and feedback (grade multiple submissions at once)
- [ ] Student submission status tracking (not started → in progress → submitted → graded)

### Firestore Collections
- [ ] `assignments` — definition, rubric, deadlines, attachments
- [ ] `submissions` — student work, files, grade, feedback, timestamp
- [ ] `rubrics` — criteria definitions with weights and scoring levels

### Mobile Integration
- [ ] Student: assignment list with status badges, submission flow, file picker
- [ ] Teacher: assignment dashboard, grading queue, batch feedback
- [ ] Parent: view child's assignment completion status

---

## v2.3A — Parent Accounts Enhanced 🔲

> **Depends on: Sprint 3B (User Management UI for admin controls)**  
> **Why it moved UP:** Parents create engagement and retention. When parents are involved, students use the platform more consistently. Schools value parent visibility — it's a key differentiator from exam-only tools.

### Success KPIs
| KPI | Target | Measurement |
|-----|--------|-------------|
| Parent WAU | > 40% of linked parents | Weekly active parent count |
| Child linking | > 70% of students have linked parent | Parent_links collection |
| Push notification open rate | > 30% | FCM analytics |
| Weekly email open rate | > 25% | Email service analytics |

### Parent Self-Service
- [ ] Self-service parent registration (email verification)
- [ ] Link multiple children to one parent account
- [ ] Parent-teacher messaging channel
- [ ] Parent role scope isolation (view-only, no edit)

### Parent Dashboard
- [ ] Real-time child progress overview
- [ ] Push notifications for grades, attendance, announcements
- [ ] Weekly progress summary emails (auto-generated every Sunday)
- [ ] Child comparison view (if multiple children)
- [ ] Upcoming assignments and exams view

### Parent Notifications
- [ ] Grade published notification
- [ ] Attendance alert (absence detected)
- [ ] Assignment due soon (for child)
- [ ] Exam scheduled notification
- [ ] Teacher message notification
- [ ] Weekly summary email

---

## v2.4 — Enhanced Attendance & Communication Foundations 🔲

> **Why it's here:** Attendance is a core academic function that schools use daily. Enhanced attendance completes the academic core alongside assignments.

### Success KPIs
| KPI | Target | Measurement |
|-----|--------|-------------|
| Daily attendance marking | > 95% of classes mark attendance | Attendance collection coverage |
| Attendance accuracy | < 2% correction rate | Amendment frequency |
| Parent notification speed | < 5 minutes after absence marked | Notification timestamp |
| Report generation | > 50% of schools export monthly | Export action tracking |

### Communication Foundations
- [ ] File/image attachments in chat (Firebase Storage upload + Firestore message metadata)
- [ ] Message reactions (emoji picker, reaction count badges)
- [ ] Typing indicators (real-time presence via Firestore)

### Attendance (Enhanced)
- [ ] Real-time attendance during live classes (LiveKit integration)
- [ ] Manual attendance marking by teachers
- [ ] Attendance analytics per student/class/subject
- [ ] Parent notifications for student absences
- [ ] Export attendance reports (PDF/Excel)
- [ ] Attendance trends and heatmaps

---

## v2.5 — Academic Records & Gradebook 🔲 🆕

> **Depends on: v2.3 (Assignment Submission), v2.4 (Enhanced Attendance)**  
> **Strategic Phase:** Phase 3.5 — Academic Records & Gradebook  
> **Why this is the most critical addition:** Schools cannot fully replace existing systems without gradebooks and report cards. This single phase would increase Klasivo's value more than most AI features. Until gradebook and report cards exist, schools will always need a second system alongside Klasivo.

### Success KPIs
| KPI | Target | Measurement |
|-----|--------|-------------|
| Gradebook adoption | > 90% of teachers use weekly | Grade entry frequency |
| Report card generation | > 80% of schools generate per term | Report card collection |
| Parent report access | > 60% of parents view reports | Report view events |
| GPA calculation accuracy | 100% (zero errors) | Validation tests |
| Time saved vs. manual | > 50% reduction in grading time | Teacher survey |

### Gradebook
- [ ] Grade entry by assignment, exam, and category (homework, quiz, midterm, final, participation)
- [ ] Weighted category grading (e.g., homework 20%, midterm 30%, final 50%)
- [ ] Grade calculation engine (weighted average, drop lowest, extra credit)
- [ ] Grade scale configuration per school (A-F, 1-10, percentage, GPA 4.0, custom)
- [ ] Real-time GPA calculation as grades are entered
- [ ] Grade curves and adjustments (teacher can curve a grade, with audit trail)
- [ ] Bulk grade entry (spreadsheet-style grid view for teachers)
- [ ] Grade history with revision tracking (who changed what, when, why)
- [ ] Grade visibility controls (students see published grades only, teachers see all)
- [ ] Feature flag: `gradebook_enabled` → per-org, defaults OFF

### Report Cards
- [ ] Report card template builder (drag-and-drop layout: header, grades table, comments, attendance summary, signature)
- [ ] Term-based report card generation (Term 1, Term 2, Final)
- [ ] Customizable grading scale display on report card
- [ ] Teacher comments per subject (free text + predefined comment bank)
- [ ] Attendance summary section (days present, absent, late, excused)
- [ ] Behavioral comments section (optional, feature-flagged)
- [ ] Principal/admin approval workflow before publishing
- [ ] PDF generation with school branding (logo, colors, header)
- [ ] Parent digital access (view in app, download PDF)
- [ ] Print-ready format (A4/Letter optimized)
- [ ] Multi-language report cards (Arabic + English)
- [ ] Feature flag: `report_cards_enabled` → per-org, defaults OFF

### Academic Terms
- [ ] Academic year configuration (start date, end date, terms, semesters, quarters)
- [ ] Term definitions (Term 1, Term 2, Semester 1, Semester 2, Quarter 1-4)
- [ ] Term-based grade aggregation (term GPA, cumulative GPA)
- [ ] Academic calendar integration (holidays, exam periods, breaks)
- [ ] Term promotion rules (pass/fail criteria, minimum GPA)
- [ ] Historical term data preservation
- [ ] Feature flag: `academic_terms_enabled` → per-org

### Transcripts
- [ ] Official transcript generation (student's complete academic history)
- [ ] Transcript template with school branding and official seal/watermark
- [ ] Cumulative GPA calculation across all terms
- [ ] Credit tracking (credits earned per subject, total credits, credit hours)
- [ ] Transfer credit notation
- [ ] Official transcript locking (once generated, cannot be edited without audit trail)
- [ ] PDF transcript download (secured, watermarked)
- [ ] Feature flag: `transcripts_enabled` → per-org, defaults OFF

### GPA Calculations
- [ ] Weighted GPA (honors/AP courses weighted higher)
- [ ] Unweighted GPA (standard 4.0 scale)
- [ ] Custom GPA scales (5.0, 10.0, percentage-based)
- [ ] Cumulative GPA across terms and academic years
- [ ] Class rank calculation (percentile-based, optional per school)
- [ ] GPA projection (what-if: if student gets X in remaining courses)
- [ ] Feature flag: `gpa_calculations_enabled` → per-org

### Subject Performance Analytics
- [ ] Per-subject performance breakdown (assignment, exam, participation averages)
- [ ] Class average comparison per subject (anonymized)
- [ ] Subject trend analysis (improving, declining, stable)
- [ ] Weak subject identification (below threshold alert for parents/teachers)
- [ ] Subject-level attendance correlation (attendance vs. grade)

### Teacher Comments
- [ ] Free-text comments per student per subject per term
- [ ] Comment bank (predefined comments teachers can select and customize)
- [ ] Comment templates by category (positive, improvement needed, behavioral)
- [ ] Multi-language comments (Arabic + English)
- [ ] Comment visibility rules (student/parent see published comments only)
- [ ] Comment history (audit trail of changes)

### Parent Report Access
- [ ] In-app report card viewer (mobile + web)
- [ ] PDF download for offline viewing
- [ ] Email notification when report card is published
- [ ] Push notification for new grades and report cards
- [ ] Report card archive (historical reports accessible)
- [ ] Print support (share to printer from mobile)

### Firestore Collections (New)
- [ ] `gradebook_entries` — individual grade records with `studentId`, `classId`, `subjectId`, `assignmentId` (optional), `grade`, `maxGrade`, `weight`, `categoryId`, `termId`, `teacherId`, `publishedAt`
- [ ] `grade_categories` — grading categories with `name`, `weight`, `classId`, `subjectId`, `dropLowest`
- [ ] `report_cards` — generated report cards with `studentId`, `termId`, `templateId`, `grades[]`, `comments[]`, `attendance`, `gpa`, `status` (draft/published/archived), `pdfUrl`
- [ ] `report_card_templates` — customizable templates with `layout`, `sections[]`, `schoolBranding`
- [ ] `academic_terms` — term definitions with `organizationId`, `academicYearId`, `name`, `startDate`, `endDate`, `type` (term/semester/quarter)
- [ ] `academic_years` — academic year definitions with `organizationId`, `name`, `startDate`, `endDate`, `terms[]`, `status`
- [ ] `transcripts` — official transcript records with `studentId`, `academicYears[]`, `cumulativeGPA`, `credits`, `pdfUrl`, `isLocked`, `lockedAt`
- [ ] `grade_scales` — school-specific grading scales with `organizationId`, `name`, `ranges[]` (min, max, letter, gpaPoints)
- [ ] `teacher_comments` — teacher comments per student per subject per term

---

## v2.5A — Timetable Builder & Academic Scheduling 🔲 🆕

> **Depends on: v2.5 (Academic Records — terms and academic year structure)**  
> **Strategic Phase:** Phase 3.6 — Academic Scheduling  
> **Why it's here:** Every school runs on schedules. Assignments, attendance, live classes, exams, rooms, teachers, and parents all depend on a timetable. This is one of the most requested school features globally. Without it, schools must maintain separate scheduling tools alongside Klasivo.

### Success KPIs
| KPI | Target | Measurement |
|-----|--------|-------------|
| Timetable creation time | < 15 minutes for full school schedule | Time tracking |
| Conflict detection | 100% of teacher/room conflicts caught | Conflict validation |
| Schedule adherence | > 90% of classes follow timetable | Attendance vs. schedule match |
| Teacher satisfaction | > 85% find scheduling easy | Teacher survey |

### Timetable Builder
- [ ] Period definition (configure school day: periods, breaks, lunch)
- [ ] Subject-teacher-room assignment matrix
- [ ] Drag-and-drop schedule builder (visual grid: days × periods)
- [ ] Auto-generate timetable from constraints (greedy algorithm, future: AI optimization)
- [ ] Multi-week rotation support (Week A / Week B schedules)
- [ ] Per-class and per-teacher timetable views
- [ ] Student timetable view (aggregated from all enrolled classes)

### Constraints Engine
- [ ] Teacher availability constraints (teacher cannot be in two places at once)
- [ ] Room capacity constraints (room must fit class size)
- [ ] Subject distribution constraints (e.g., Math 5 times/week, Art 1 time/week)
- [ ] Consecutive period rules (e.g., no double PE, lab periods must be consecutive)
- [ ] Break requirements (minimum 1 break per 4 periods)
- [ ] Priority-based constraint satisfaction (hard constraints vs. soft preferences)

### Room & Resource Management
- [ ] Room inventory (name, capacity, type: classroom, lab, gym, library)
- [ ] Room booking conflicts detection
- [ ] Resource allocation per period (projectors, labs, sports equipment)
- [ ] Room utilization analytics (% of time each room is used)

### Schedule Publishing
- [ ] Publish timetable to teachers, students, and parents
- [ ] Push notification on schedule changes
- [ ] Schedule change audit trail (who changed what, when)
- [ ] Print-ready timetable (PDF per class/teacher/student)
- [ ] Feature flag: `timetable_enabled` → per-org, defaults OFF

### Future: AI Schedule Optimization
- [ ] AI-generated optimal timetable from constraints
- [ ] "What-if" scheduling (simulate teacher absence → suggest redistribution)
- [ ] Balanced workload optimization (spread difficult subjects across the week)

### Firestore Collections (New)
- [ ] `timetables` — schedule definitions with `organizationId`, `termId`, `version`, `status` (draft/published/archived)
- [ ] `timetable_entries` — individual period assignments with `timetableId`, `dayOfWeek`, `periodIndex`, `classId`, `subjectId`, `teacherId`, `roomId`
- [ ] `period_definitions` — school day structure with `organizationId`, `name`, `startTime`, `endTime`, `isBreak`
- [ ] `rooms` — room inventory with `organizationId`, `name`, `capacity`, `type`, `resources[]`
- [ ] `scheduling_constraints` — constraint rules with `organizationId`, `type`, `priority` (hard/soft), `parameters`

---

## v2.6 — Student Information System (SIS) 🔲 🆕

> **Depends on: v2.5 (Academic Records)**  
> **Strategic Phase:** Phase 4 — Student & Parent Engagement  
> **Why it's NEW:** Klasivo is becoming a School Operating System. A comprehensive student profile becomes the central student record — the single source of truth for every piece of information about a student. Without it, schools must maintain separate SIS systems alongside Klasivo.

### Success KPIs
| KPI | Target | Measurement |
|-----|--------|-------------|
| Profile completeness | > 90% of students have full profiles | Required fields check |
| Emergency contact coverage | 100% of students have emergency contacts | Field presence check |
| Medical info completeness | > 70% of students have medical notes | Field presence check |
| Admin lookup time | < 10 seconds to find any student data | UX measurement |

### Student Profile
- [ ] Comprehensive student profile page (single view of all student data)
- [ ] Profile sections: Academic, Attendance, Medical, Emergency, Documents, Parent Links
- [ ] Quick-action menu (message parent, view schedule, generate report)
- [ ] Student timeline view (chronological event stream: enrollments, grade changes, attendance events, comments)
- [ ] Profile search by name, ID, class, or parent
- [ ] Feature flag: `sis_enabled` → per-org, defaults OFF

### Academic History
- [ ] Complete academic record across all terms and years
- [ ] Term-by-term grade summary with GPA trend
- [ ] Subject performance history (grade in each subject each term)
- [ ] Exam history with scores and percentile rankings
- [ ] Assignment submission history with on-time rate
- [ ] Academic achievements and honors (Dean's List, Honor Roll, etc.)
- [ ] Academic standing status (Good, Warning, Probation)

### Attendance History
- [ ] Complete attendance record with daily breakdown
- [ ] Attendance pattern analysis (which days, which periods, trends)
- [ ] Absence reason tracking (excused, unexcused, medical, etc.)
- [ ] Attendance summary per term (present %, absent days, late days)
- [ ] Comparison with class average (anonymized)
- [ ] Early warning alerts for chronic absence (> 5 days consecutive, > 10% absence rate)

### Parent Relationships
- [ ] Parent-student link management (link, unlink, primary parent designation)
- [ ] Guardian types (father, mother, legal guardian, emergency contact)
- [ ] Sibling detection and cross-linking (students with same parent)
- [ ] Parent communication log (messages sent/received regarding this student)
- [ ] Parent-teacher meeting notes

### Medical Notes
- [ ] Medical conditions (allergies, chronic conditions, disabilities)
- [ ] Medication requirements (name, dosage, frequency, prescribing doctor)
- [ ] Dietary restrictions
- [ ] Physical activity limitations
- [ ] Vision and hearing screening results
- [ ] Medical emergency procedures (school-specific)
- [ ] Permission fields: `medical_info_viewable_by` (nurse, admin, teacher — not student)
- [ ] Feature flag: `medical_info_enabled` → per-org, defaults OFF

### Emergency Contacts
- [ ] Multiple emergency contacts per student (minimum 1, maximum 5)
- [ ] Contact priority ordering (primary, secondary, etc.)
- [ ] Contact fields: name, relationship, phone (primary/alternate), email, address
- [ ] Emergency contact card (quick-access view for admin/teacher, always visible)
- [ ] Verification status (confirmed, unconfirmed, outdated)
- [ ] Annual re-confirmation workflow (prompt parents to update annually)

### Documents
- [ ] Document upload and storage (birth certificate, ID, transcripts from other schools, medical records, permission slips)
- [ ] Document categorization (identity, academic, medical, permission, other)
- [ ] Document access control (admin-only, teacher-view, parent-view)
- [ ] Document expiration tracking (IDs, medical certificates)
- [ ] e-Signature support for permission slips (parent signs digitally)
- [ ] Feature flag: `student_documents_enabled` → per-org

### Firestore Collections (New)
- [ ] `student_profiles` — extended student data with `medicalNotes[]`, `emergencyContacts[]`, `documents[]`, `guardians[]`
- [ ] `student_medical` — medical records with `conditions[]`, `medications[]`, `restrictions[]`, `emergencyProcedure`
- [ ] `student_emergency_contacts` — emergency contact entries with `studentId`, `priority`, `name`, `relationship`, `phones[]`, `email`, `verifiedAt`
- [ ] `student_documents` — uploaded documents with `studentId`, `category`, `fileUrl`, `fileName`, `fileSize`, `uploadedBy`, `expiresAt`, `accessLevel`
- [ ] `student_timeline` — chronological event stream with `studentId`, `eventType`, `eventData`, `timestamp`

---

## v2.7 — Communication Hub 🔲 🆕

> **Depends on: v2.3A (Parent Enhanced for parent messaging)**  
> **Strategic Phase:** Phase 4 — Student & Parent Engagement  
> **Why it's NEW:** Klasivo has notifications but not a complete communication layer. Schools currently rely on WhatsApp groups alongside Klasivo for announcements, alerts, and messaging. The Communication Hub replaces WhatsApp as the school's primary communication channel.

### Success KPIs
| KPI | Target | Measurement |
|-----|--------|-------------|
| Broadcast reach | > 90% delivery rate | Delivery receipts |
| Read rate | > 70% within 24 hours | Read receipts |
| SMS opt-in | > 30% of parents | SMS preference tracking |
| Teacher-parent messaging | > 50% of teachers use monthly | Message count analytics |

### Communication Channels

| Channel | Status | Priority | Use Case |
|---------|--------|----------|----------|
| Push (FCM) | ✅ Live | Primary | Real-time alerts, reminders |
| In-App | ✅ Live | Primary | Notification center, messages |
| Email (Resend) | ✅ Live | Secondary | Weekly summaries, reports, formal communications |
| SMS (Twilio/Vonage) | 🔲 New | Tertiary | Urgent alerts, parents without smartphones |
| WhatsApp Business API | 🔲 Future | Optional | Market-specific (high WhatsApp usage regions) |

### Broadcast Announcements
- [ ] Admin creates announcement → select audience (all school, specific campus, stage, class, or custom group)
- [ ] Multi-channel delivery: push + in-app + email (SMS for urgent)
- [ ] Rich content: text, images, attachments, links
- [ ] Scheduled broadcasts (set date/time for future delivery)
- [ ] Delivery and read receipt tracking per recipient
- [ ] Announcement archive with search and filter
- [ ] Pinned announcements (shown at top of feed)
- [ ] Urgent flag (bypasses notification preferences, triggers SMS)
- [ ] Feature flag: `broadcast_announcements_enabled` → per-org

### School Alerts
- [ ] Emergency alerts (school closure, security incident, weather)
- [ ] Attendance alerts (absence notification to parent — existing, enhanced)
- [ ] Grade alerts (new grade published — existing, enhanced)
- [ ] Event alerts (parent-teacher meeting, school trip, deadline)
- [ ] Alert priority levels: Info, Important, Urgent, Emergency
- [ ] Alert escalation: Emergency alerts → SMS + push + email + in-app
- [ ] Alert audit trail (who sent, when, who received, who read)
- [ ] Feature flag: `school_alerts_enabled` → per-org

### Teacher-Parent Messaging
- [ ] Direct messaging between teacher and parent (scoped to their shared student)
- [ ] Message threading per student (all teacher-parent communication about a student in one thread)
- [ ] File sharing in messages (documents, images)
- [ ] Message templates (common responses: "Your child did well today", "Missing homework")
- [ ] Auto-translate option (Arabic ↔ English for bilingual communities)
- [ ] Message moderation controls (admin can view flagged messages)
- [ ] Quiet hours (no notifications 9 PM – 7 AM, configurable per school)
- [ ] Feature flag: `teacher_parent_messaging_enabled` → per-org

### Scheduled Campaigns
- [ ] Campaign builder: compose message → select audience → choose channels → schedule delivery
- [ ] Recurring campaigns (weekly newsletter, monthly attendance summary)
- [ ] Campaign analytics (sent, delivered, opened, clicked)
- [ ] A/B testing for engagement optimization
- [ ] Campaign templates (welcome message, term start, exam period, holiday greeting)
- [ ] Feature flag: `scheduled_campaigns_enabled` → per-org

### Firestore Collections (New)
- [ ] `announcements` — broadcast announcements with `authorId`, `audienceType`, `audienceIds[]`, `channels[]`, `content`, `priority`, `scheduledAt`, `sentAt`, `stats` (delivered, read)
- [ ] `announcement_receipts` — delivery/read tracking with `announcementId`, `userId`, `channel`, `deliveredAt`, `readAt`
- [ ] `messages` — direct messages with `senderId`, `recipientId`, `studentId` (context), `content`, `attachments[]`, `readAt`
- [ ] `message_threads` — conversation threads with `participants[]`, `studentId`, `lastMessageAt`, `unreadCount`
- [ ] `campaigns` — scheduled campaigns with `organizationId`, `name`, `content`, `audience`, `channels[]`, `schedule`, `stats`
- [ ] `communication_preferences` — per-user channel preferences with `userId`, `channels` {push, email, sms}, `quietHours`

---

## v2.8 — School Accounts / Multi-Tenancy (Simplified) 🔲

> **Depends on: Sprint 5**  
> **Why it's simplified:** BigQuery, Custom Report Builder, and Platform Analytics moved to v4.0. At current scale (1–20 schools), Firestore analytics and basic reports are sufficient.

### Success KPIs
| KPI | Target | Measurement |
|-----|--------|-------------|
| School onboarding time | < 30 minutes | Time from signup to first class |
| Data isolation incidents | Zero | Cross-org data leak detection |
| Multi-campus adoption | > 30% of schools use multi-campus | Campus count per school |
| Feature flag coverage | 100% of new features flag-gated | Flag audit |

### School Accounts / Multi-Tenancy
- [ ] School registration and onboarding wizard
- [ ] Organization settings (branding, logo, academic calendar)
- [ ] Campus/stage/class hierarchy management
- [ ] Role-based access per campus/stage
- [ ] Cross-campus analytics for district-level admins
- [ ] Data isolation between organizations (Firestore security)
- [ ] Organization-specific feature flag overrides
- [ ] Bulk import/export for school data

### School Analytics (Basic — No BigQuery)
- [ ] Attendance report (daily, weekly, monthly by class/student)
- [ ] Grades report (exam results by class/subject/student)
- [ ] Assignment report (completion rates by class/subject)
- [ ] Simple charts and exportable data (PDF/CSV)
- [ ] Custom date range filters
- [ ] These reports run against Firestore — sufficient at current scale

### What's NOT in v2.8 (Moved to v4.0)
- ~~BigQuery integration~~ → v4.0 (not needed until 50+ schools)
- ~~Custom report builder (drag-and-drop BI)~~ → v4.0 (schools initially want standard reports, not BI)
- ~~Student performance prediction (ML)~~ → v4.0 (requires BigQuery first)
- ~~Platform Analytics~~ → v4.0 (school analytics first, platform analytics later)

---

## v2.9 — School Landing Pages, Migration Center & 30-Minute School Launch 🔲

> **Depends on: Sprint 5**  
> **Why combined:** Landing pages drive adoption; migration center removes the biggest adoption barrier; 30-minute launch ties them together. These form the "acquisition toolkit."

### Success KPIs
| KPI | Target | Measurement |
|-----|--------|-------------|
| Landing page visits | > 500/month across all schools | Page view analytics |
| Parent signups from landing | > 10% conversion | Signup source tracking |
| Migration completion rate | > 90% of imports succeed | Import job success rate |
| Time to first class | **< 30 minutes from signup** | Onboarding funnel timing |

### 30-Minute School Launch 🆕

> **The single highest-ROI business feature.** A school should be able to go from "no account" to "operational school" in 30 minutes. This directly increases conversions by removing friction.

- [ ] Guided School Setup Wizard (step-by-step: name → logo → campus structure → academic calendar → invite teachers → import students → done)
- [ ] Pre-configured academic year templates (Egyptian, GCC, international)
- [ ] Quick-start role assignment (invite first 3 teachers by email/WhatsApp)
- [ ] Bulk student import as part of onboarding flow (not a separate screen)
- [ ] Timetable template import (upload existing schedule or use default)
- [ ] Auto-configure feature flags based on school size (small school → simpler defaults)
- [ ] Onboarding progress tracker (visual checklist: 7 steps to operational)
- [ ] Feature flag: `quick_launch_enabled` → defaults ON
- [ ] KPI: Time-to-first-class < 30 minutes (measured from account creation to first class viewable)

### Public School Profile
- [ ] School profile page at `klasivo.app/school/{slug}` or `school.klasivo.app/{slug}`
- [ ] School name, logo, description, and contact information
- [ ] Announcement feed (public posts from admin)
- [ ] Admission links (link to external enrollment form or Klasivo enrollment flow)
- [ ] School photo gallery
- [ ] Social media links

### Admin Controls
- [ ] School profile editor (admin/owner only)
- [ ] Custom slug selection (e.g., `klasivo.app/school/al-noor-academy`)
- [ ] Toggle public visibility (draft → published)
- [ ] Announcement publisher (select which announcements are public)
- [ ] SEO metadata editor (title, description, Open Graph image)

### Technical
- [ ] Server-side rendering or static generation for SEO (Flutter Web or separate Next.js landing)
- [ ] Firestore `school_profiles` collection with slug index
- [ ] Feature flag: `school_landing_pages_enabled` → per-org

### School Migration Center 🆕

> **Why this is critical:** One of the biggest barriers to adoption is "We already have our data elsewhere." The Migration Center dramatically improves conversion by making it trivial to import existing data.

#### Import Wizard
- [ ] Step-by-step import wizard: Select data type → Upload file → Map columns → Preview → Confirm → Import
- [ ] Data type selection: Students, Teachers, Classes, Subjects, Attendance, Grades, Assignments
- [ ] Multi-entity import (upload multiple sheets/files in one session)

#### Supported Formats
- [ ] Excel (.xlsx, .xls) — primary format, most schools use Excel
- [ ] CSV (.csv) — universal fallback
- [ ] Google Sheets (via link) — future expansion

#### Import Templates
- [ ] Downloadable import templates per data type (pre-formatted Excel with correct columns)
- [ ] Template with example data (1-2 sample rows pre-filled)
- [ ] Template in Arabic + English
- [ ] Required vs. optional column indicators in template

#### Data Validation
- [ ] Column mapping interface (auto-detect columns, manual override)
- [ ] Pre-import validation: required fields, data types, duplicate detection
- [ ] Dry-run preview (show what will be imported, highlight errors)
- [ ] Error report generation (row-by-row error listing with suggested fixes)
- [ ] Duplicate resolution: skip, overwrite, or merge (configurable per import)

#### Import Processing
- [ ] Background import processing (Cloud Function + Firestore batch writes)
- [ ] Progress tracking with percentage and estimated time
- [ ] Import history log (what was imported, when, by whom, how many records)
- [ ] Rollback capability (undo last import within 24 hours)
- [ ] Feature flag: `school_migration_center_enabled` → per-org

#### Importable Data Types
| Data Type | Required Fields | Optional Fields |
|-----------|----------------|-----------------|
| Students | name, class | email, phone, parentName, parentPhone, dateOfBirth, gender |
| Teachers | name, email | phone, subject, classAssignment |
| Classes | name, stage | teacherName, subject |
| Subjects | name, code | stage, class, teacher |
| Attendance | studentName, date, status | class, subject, notes |
| Grades | studentName, subject, grade | class, examName, date, maxGrade |

### Firestore Collections (New)
- [ ] `import_jobs` — migration job tracking with `organizationId`, `userId`, `dataType`, `status` (pending/validating/importing/completed/failed), `recordsTotal`, `recordsImported`, `recordsFailed`, `errors[]`, `startedAt`, `completedAt`
- [ ] `import_templates` — template definitions with `name`, `dataType`, `columns[]`, `requiredColumns[]`

---

## v3.0 — Web Dashboard & School Analytics 🔲

> **Depends on: Sprint 6**  
> **Why it moved DOWN:** Schools don't need a web dashboard before they have teacher approval, assignments, gradebook, and parent accounts working on mobile. The dashboard is for efficiency at scale — it's not an adoption driver at the current stage.

### Success KPIs
| KPI | Target | Measurement |
|-----|--------|-------------|
| Dashboard DAU | > 50% of admins use daily | Dashboard login analytics |
| Report generation | > 70% of schools generate weekly | Report action tracking |
| Data table load time | < 2 seconds for 1000 rows | Performance monitoring |
| Mobile-to-web crossover | > 40% of mobile users also use web | Cross-platform tracking |

### Flutter Web Dashboard Skeleton
- [ ] `/dashboard` — Overview (org stats, active classes, recent activity)
- [ ] `/users` — User management (People Hub, web-optimized layout)
- [ ] `/roles` — Role assignment and role matrix
- [ ] `/scopes` — Scope assignment and visualization
- [ ] `/settings` — Organization settings (branding, calendar, features)
- [ ] Sidebar navigation (collapsible)
- [ ] Data tables with sorting, filtering, pagination
- [ ] Bulk action toolbar (multi-select, batch operations)
- [ ] Breadcrumb navigation

### School Analytics Dashboard
- [ ] Teacher dashboard: class performance, assignment completion rates
- [ ] Student dashboard: personal progress, strengths/weaknesses
- [ ] Admin dashboard: organization-wide KPIs
- [ ] Live class participation metrics
- [ ] Custom date range filters
- [ ] Exportable charts and reports

---

## v3.1 — Mobile-First Offline Strategy 🔲 🆕

> **Strategic Phase:** Phase 6 — Analytics & Dashboard  
> **Why it's NEW:** For Egypt, MENA, and developing markets, intermittent connectivity is the norm, not the exception. Students and teachers in areas with poor internet cannot use a purely online platform. Offline mode makes Klasivo usable everywhere and becomes a major competitive advantage — no competitor in this market offers true offline LMS functionality.

### Success KPIs
| KPI | Target | Measurement |
|-----|--------|-------------|
| Offline usage rate | > 30% of sessions are offline | Session connectivity tracking |
| Sync success rate | > 99% of offline actions sync successfully | Sync queue completion |
| Data loss incidents | Zero | Sync conflict resolution tracking |
| Offline feature satisfaction | > 80% positive rating | User survey |

### Offline Data Access

Students can read the following without internet:
- [ ] Assignment descriptions and instructions
- [ ] Lesson content and materials (text, images)
- [ ] Recording metadata (title, description, duration — not video itself)
- [ ] Exam metadata (upcoming exam schedule)
- [ ] Grade history (cached from last sync)
- [ ] Class schedule
- [ ] Announcements (cached from last sync)

### Offline Actions (Queue for Sync)

Students can perform the following offline:
- [ ] Read assignments and materials
- [ ] Prepare submission drafts (text + local file selection)
- [ ] Write message drafts (to teachers/parents)
- [ ] Take notes on lessons
- [ ] Review cached grades and attendance

Actions are queued and synced when connectivity is restored.

### Technical Architecture
- [ ] Local SQLite/Hive database for offline data storage
- [ ] Sync queue with conflict resolution (last-write-wins with manual resolution option)
- [ ] Incremental sync (only changed records since last sync, not full download)
- [ ] Background sync when connectivity detected
- [ ] Network-aware providers (Riverpod providers that return cached data when offline)
- [ ] Connectivity indicator in app shell (green/yellow/red)
- [ ] Sync status screen (pending actions, last sync time, data usage)
- [ ] Feature flag: `offline_mode_enabled` → per-org, defaults ON for mobile

### Data Sizing Estimates
| Data Type | Per Record | 1 Class (30 students) | 1 School (500 students) |
|-----------|-----------|----------------------|------------------------|
| Assignments | ~2 KB | ~60 KB (30 assignments) | ~1 MB |
| Submissions | ~1 KB | ~900 KB (30 × 30) | ~15 MB |
| Grades | ~0.5 KB | ~15 KB | ~250 KB |
| Attendance | ~0.3 KB | ~9 KB | ~150 KB |
| Announcements | ~1 KB | ~20 KB | ~20 KB |
| **Total Cache** | — | **~1 MB** | **~17 MB** |

### Sync Conflict Resolution
- [ ] Conflict types: same record edited on two devices, assignment submitted offline after deadline
- [ ] Default: last-write-wins with server timestamp authority
- [ ] Critical conflicts (grade changes, submission status): manual resolution UI
- [ ] Conflict log for admin review
- [ ] Feature flag: `sync_conflict_resolution` → automatic vs. manual

---

## v3.2 — Subscription & Billing 🔲

> **Depends on: v2.8 (School Accounts)**  
> **Why it's here:** Revenue enables everything else. Billing is the bridge between product value and sustainable business.

### Success KPIs
| KPI | Target | Measurement |
|-----|--------|-------------|
| Free-to-paid conversion | > 15% within 90 days | Plan change tracking |
| MRR growth | > 20% month-over-month | Revenue analytics |
| Churn rate | < 5% monthly | Subscription cancellation tracking |
| Payment success rate | > 98% | Stripe payment analytics |

### Subscription Plans
- [ ] Free tier definition (limits: students, storage, features)
- [ ] Pro plan with expanded limits
- [ ] Enterprise plan with custom pricing
- [ ] Plan comparison page

### Billing Infrastructure
- [ ] Stripe integration for payment processing
- [ ] Subscription management (upgrade/downgrade/cancel)
- [ ] Invoice generation and history
- [ ] Trial period with automatic conversion
- [ ] Proration on plan changes

### Billing-aware Features
- [ ] Feature gating based on subscription tier
- [ ] Usage metering (student count, storage, API calls)
- [ ] Soft limits with upgrade prompts
- [ ] Admin billing dashboard
- [ ] Payment method management
- [ ] Revenue analytics for platform admin

---

## v3.3 — Assessment Engine 🔲 🆕

> **Strategic Phase:** Phase 8 — Assessment & AI Layer  
> **Why it's here:** The assessment engine transforms Klasivo's exam system from "basic quiz tool" to "professional assessment platform." This is a major differentiator — most LMS competitors have limited question types and no exam blueprinting. Schools that build rich assessments in Klasivo become deeply locked in.

### Success KPIs
| KPI | Target | Measurement |
|-----|--------|-------------|
| Question type usage | > 5 types used per school | Question type distribution |
| Exam creation time | < 30 minutes for 20-question exam | Time tracking |
| Randomization adoption | > 40% of exams use randomization | Feature usage analytics |
| Question bank growth | > 100 questions/teacher/month | Question count tracking |

### Question Types
- [ ] **MCQ** — Multiple choice (single answer, multiple answer, with images)
- [ ] **True/False** — Binary choice with optional explanation
- [ ] **Essay** — Free-text response (manual or AI-assisted grading)
- [ ] **Matching** — Pair items from two columns
- [ ] **Fill in the Blanks** — Cloze deletion with one or more blanks
- [ ] **Numeric** — Math answers with tolerance (e.g., answer = 3.14 ± 0.01)
- [ ] **Drag & Drop** — Ordering, categorization, labeling (image-based)
- [ ] **Short Answer** — Free-text with keyword matching or AI evaluation
- [ ] **Code Submission** — Code with syntax highlighting and test cases (CS courses)

### Randomization & Anti-Cheating
- [ ] Question randomization (shuffle question order per student)
- [ ] Choice randomization (shuffle MCQ options per student)
- [ ] Question pool sampling (randomly select N questions from pool of M)
- [ ] Parallel form generation (create equivalent exam versions with same difficulty)
- [ ] Tab-switch detection (browser/app focus change tracking)
- [ ] Time-per-question analytics (flag impossibly fast answers)
- [ ] IP/device restriction (one exam session per device)

### Question Pools & Blueprints
- [ ] Question pool per subject/topic/difficulty level
- [ ] Exam blueprint builder (define: 5 easy MCQ + 3 medium essay + 2 hard numeric)
- [ ] Difficulty balancing (automatic difficulty distribution from blueprint)
- [ ] Bloom's taxonomy tagging per question (Remember → Understand → Apply → Analyze → Evaluate → Create)
- [ ] Question reuse tracking (which exams used which questions, performance per question)
- [ ] Question lifecycle (draft → reviewed → published → deprecated)

### Assessment Analytics
- [ ] Item analysis per question (difficulty index, discrimination index, distractor analysis)
- [ ] Reliability scoring per exam (Cronbach's alpha)
- [ ] Question performance heatmap (easy vs. hard questions visualized)
- [ ] Exam statistics dashboard (mean, median, standard deviation, distribution curve)
- [ ] Feature flag: `assessment_engine_enabled` → per-org, defaults OFF

### Firestore Collections (New)
- [ ] `question_pools` — question pool definitions with `organizationId`, `subjectId`, `topicId`, `difficultyDistribution`
- [ ] `exam_blueprints` — exam structure templates with `sections[]`, `questionTypes[]`, `difficultyTargets[]`, `totalQuestions`, `totalMarks`
- [ ] `question_analytics` — per-question performance data with `questionId`, `examId`, `difficultyIndex`, `discriminationIndex`, `distractorAnalysis`

---

## v3.4 — Learning Outcomes Framework 🔲 🆕

> **Strategic Phase:** Phase 8 — Assessment & AI Layer  
> **Depends on: v2.5 (Gradebook), v3.3 (Assessment Engine)**  
> **Why it's here:** Enterprise schools increasingly ask "How do we know students achieved outcomes?" This framework connects lessons, assignments, exams, and grades to measurable learning outcomes. It's the bridge between traditional grading and competency-based education, and it's especially attractive for international schools.

### Success KPIs
| KPI | Target | Measurement |
|-----|--------|-------------|
| Outcome coverage | > 80% of subjects have defined outcomes | Outcome count per subject |
| Outcome-linked assessments | > 60% of questions linked to outcomes | Question-outcome mapping |
| Teacher adoption | > 50% of teachers use outcome tracking | Feature usage analytics |
| Parent outcome visibility | > 30% of parents view outcome reports | Report view tracking |

### Learning Outcomes Definition
- [ ] Outcome hierarchy: Subject → Unit → Topic → Outcome
- [ ] Outcome statements (measurable, verb-driven: "Student can solve quadratic equations")
- [ ] Bloom's taxonomy level per outcome
- [ ] Curriculum mapping (outcomes mapped to national/international standards)
- [ ] Outcome import/export (Excel template for bulk definition)
- [ ] Feature flag: `learning_outcomes_enabled` → per-org, defaults OFF

### Outcome-Content Linking
- [ ] Link lessons to outcomes (this lesson teaches Outcome #4)
- [ ] Link assignments to outcomes (this assignment assesses Outcome #4)
- [ ] Link exam questions to outcomes (this question tests Outcome #4)
- [ ] Link rubric criteria to outcomes (this criterion measures Outcome #4)
- [ ] Automatic coverage analysis (which outcomes are taught? assessed? both?)

### Outcome Mastery Tracking
- [ ] Per-student outcome mastery score (0–100% per outcome)
- [ ] Mastery thresholds (Not Started < 25% < Developing < 50% < Proficient < 75% < Mastered)
- [ ] Mastery calculation from linked assessments (weighted average of all assessments linked to outcome)
- [ ] Outcome progress visualization (heat map: student × outcome)
- [ ] Class mastery overview (average mastery per outcome per class)

### Curriculum Map
- [ ] Visual curriculum map (outcomes × content matrix)
- [ ] Gap analysis (outcomes with no linked content or assessments — "orphan outcomes")
- [ ] Coverage report (what percentage of outcomes are taught and assessed)
- [ ] Standards alignment report (mapped to national/international standards)

### Outcome Reports
- [ ] Student outcome report (mastery per outcome, trend over time)
- [ ] Class outcome report (class average mastery, weakest outcomes)
- [ ] Parent outcome summary (plain-language: "Your child has mastered 7/10 Algebra outcomes")
- [ ] Teacher outcome dashboard (which outcomes need more instructional time)

### Future: Competency-Based Education
- [ ] Competency definitions (skills that span multiple outcomes)
- [ ] Competency progress maps (visual pathway showing prerequisite relationships)
- [ ] Personalized learning recommendations (based on weak outcomes, suggest resources)
- [ ] Portfolio evidence (student uploads work demonstrating outcome mastery)

### Firestore Collections (New)
- [ ] `learning_outcomes` — outcome definitions with `organizationId`, `subjectId`, `unitId`, `statement`, `bloomLevel`, `standardsAlignment`
- [ ] `outcome_links` — links between outcomes and content with `outcomeId`, `resourceType` (lesson/assignment/exam_question/rubric_criterion), `resourceId`
- [ ] `outcome_mastery` — per-student mastery records with `studentId`, `outcomeId`, `masteryScore`, `masteryLevel`, `evidenceCount`, `lastAssessedAt`
- [ ] `curriculum_maps` — curriculum map definitions with `organizationId`, `subjectId`, `standardsFramework`, `outcomes[]`

---

## v3.5 — AI Layer (Governance + Features) 🔲

> **Strategic Phase:** Phase 8 — AI Layer  
> **Why these are here:** AI features are powerful differentiators but require a stable base platform first. They depend on having a rich dataset of lessons, questions, rubrics, and grading patterns. They're strategically valuable but not blocking for adoption.

### Success KPIs
| KPI | Target | Measurement |
|-----|--------|-------------|
| AI question acceptance rate | > 60% of generated questions used | Accept vs. reject tracking |
| Grading time reduction | > 40% faster with AI assist | Time tracking (with/without) |
| Teacher satisfaction | > 80% find AI helpful | Teacher survey |
| Cost per AI interaction | < $0.05 | Usage + billing tracking |

### AI Governance Framework 🆕

> **Why this is critical:** Before AI rollout, schools need assurance that AI usage is controlled, auditable, and safe. This is especially important for schools — parents and regulators demand transparency about AI in education.

#### Usage Quotas
- [ ] Per-school AI usage quotas (questions generated per day/week, grading assists per day)
- [ ] Per-teacher sub-quotas (configurable by admin)
- [ ] Quota dashboard for admins (current usage, remaining, projected cost)
- [ ] Hard stop when quota exceeded (not soft — no surprise bills)
- [ ] Quota reset schedule (daily at midnight local, weekly on Sunday, monthly on 1st)
- [ ] Feature flag: `ai_quotas_enabled` → per-org, defaults ON

#### Cost Controls
- [ ] Per-interaction cost tracking (input tokens, output tokens, model, cost)
- [ ] Monthly cost budget per organization (admin sets max budget)
- [ ] Alert at 50%, 75%, 90% of budget
- [ ] Auto-disable AI features at 100% budget (with admin override option)
- [ ] Cost reporting per teacher, per feature, per model
- [ ] Model selection per feature (GPT-4o for questions, GPT-4o-mini for grading — cost optimization)

#### Prompt Logging & Audit
- [ ] Every AI prompt logged with: userId, role, feature, inputHash, model, timestamp, organizationId
- [ ] Every AI response logged with: promptId, outputHash, tokenCount, cost, timestamp
- [ ] Prompt content NOT stored by default (privacy) — only hashes + metadata
- [ ] Optional: full prompt content logging (admin opt-in, with parent notification)
- [ ] Audit trail: who used AI, when, which feature, how much it cost
- [ ] 90-day retention for AI logs, 1-year for audit summaries

#### Content Moderation
- [ ] Input moderation (block inappropriate content in prompts)
- [ ] Output moderation (filter AI-generated content for safety)
- [ ] Content safety scoring per AI response (confidence + safety score)
- [ ] Flagged content review queue (admin reviews flagged AI outputs)
- [ ] Blocklist for specific topics per school (e.g., religious sensitivity, political content)
- [ ] Feature flag: `ai_content_moderation_enabled` → per-org, defaults ON

#### Human Approval Workflows
- [ ] AI-generated questions require teacher review before publishing (always)
- [ ] AI-suggested grades require teacher confirmation before recording (always)
- [ ] Bulk AI operations (generate 50 questions) require admin approval
- [ ] No autonomous AI actions — every AI output is a suggestion, not a decision
- [ ] Approval flow logging (who approved, when, any modifications made)

#### AI Transparency
- [ ] AI-generated content labeled as "AI-Assisted" in the UI
- [ ] Parent notification: "This question was generated with AI assistance and reviewed by [Teacher Name]"
- [ ] School-level AI usage report (monthly summary for admin/parents)
- [ ] Student-facing: no direct AI interaction — AI is teacher-facing only
- [ ] Feature flag: `ai_transparency_labels_enabled` → per-org, defaults ON

### AI Question Generator
- [ ] Teacher uploads lesson content (text, PDF, or video transcript)
- [ ] AI generates question set (MCQ, True/False, Short Answer) based on content
- [ ] Teacher reviews and edits generated questions
- [ ] Teacher publishes exam from edited questions
- [ ] Subject-specific question generation (math, science, language, etc.)
- [ ] Difficulty level control (easy, medium, hard)
- [ ] Bloom's taxonomy alignment
- [ ] Feature flag: `ai_question_generator_enabled` → per-org, defaults OFF

```
Teacher uploads lesson
       ↓
AI generates questions (5-20 per topic)
       ↓
Teacher edits (accept, modify, reject, add)
       ↓
Publish exam
```

### AI Assignment Grading Assistant
- [ ] Teacher uploads grading rubric
- [ ] AI analyzes student submission against rubric criteria
- [ ] AI suggests score per criterion with justification
- [ ] Teacher reviews and approves/modifies each suggestion
- [ ] Final grade is always teacher's decision
- [ ] Supports: essay-type answers, short answers, code submissions
- [ ] Learns from teacher's corrections over time
- [ ] Feature flag: `ai_grading_assistant_enabled` → per-org, defaults OFF

```
Teacher uploads rubric
       ↓
AI suggests score per criterion
       ↓
Teacher approves/modifies
       ↓
Grade published
```

**Important:** This is AI-assisted grading, NOT automatic grading. The teacher always has final say. The AI saves time on initial assessment, but the human remains accountable for the grade.

### Firestore Collections (New)
- [ ] `ai_usage_logs` — AI interaction logs with `userId`, `organizationId`, `feature` (question_gen/grading_assist), `model`, `inputTokens`, `outputTokens`, `cost`, `timestamp`, `safetyScore`
- [ ] `ai_quotas` — usage quotas with `organizationId`, `feature`, `dailyLimit`, `weeklyLimit`, `monthlyLimit`, `currentUsage`
- [ ] `ai_cost_budgets` — cost budgets with `organizationId`, `monthlyBudget`, `currentSpend`, `alertThresholds[]`
- [ ] `ai_moderation_flags` — flagged content with `logId`, `reason`, `severity`, `reviewedBy`, `reviewedAt`, `action`

---

## v4.0 — Full Dashboard Platform + Enterprise Analytics 🔲

> **Depends on: Sprint 7+8 + M1-M8 Migration**  
> **Why BigQuery/Custom Reports/Platform Analytics are here:** These are enterprise-scale features. At 50+ schools, Firestore analytics become expensive and slow. At 1–20 schools, they're premature infrastructure.

### Success KPIs
| KPI | Target | Measurement |
|-----|--------|-------------|
| Dashboard load time | < 3 seconds for any page | Performance monitoring |
| Report generation | < 10 seconds for any report | Timing analytics |
| BigQuery query cost | < $100/month at 50 schools | BigQuery billing |
| Platform uptime | > 99.9% | Uptime monitoring |

### Dashboard Platform — Owner Dashboard
- [ ] Domain: `dashboard.klasivo.app/owner`
- [ ] KPIs: Total Schools, Teachers, Students, Parents, Active Classes, Live Sessions, Monthly Growth, Revenue, Storage
- [ ] School management: Create, Suspend, Activate schools
- [ ] Teacher Approval: Workflow (Pending → Approved → Rejected)
- [ ] User Management: Search, Disable, Reactivate
- [ ] LiveKit Management: Rooms, Participants, Duration, Quality
- [ ] Audit Logs: Immutable, append-only, cross-org

### BigQuery Integration
- [ ] BigQuery export pipeline from Firestore
- [ ] Historical analytics queries
- [ ] Data warehouse for cross-school analysis
- [ ] Cost-effective at scale (50+ schools)

### Custom Report Builder
- [ ] Drag-and-drop field selection
- [ ] Scheduled report generation (daily/weekly/monthly)
- [ ] Report sharing (PDF export, email)
- [ ] Saved report templates
- [ ] Schools that need this: district-level admins, accreditation bodies

### Platform Analytics
- [ ] DAU, WAU, MAU
- [ ] Retention cohorts
- [ ] Engagement scoring
- [ ] Churn analysis
- [ ] Revenue analytics (MRR, ARR, LTV)
- [ ] Platform health (function metrics, error rates, latency)

### Platform Separation
- [ ] `platform.klasivo.app` — Super Admin / Owner Platform
- [ ] `dashboard.klasivo.app` — School Dashboard
- [ ] `api.klasivo.app` — Functions / APIs
- [ ] Subdomain routing and auth flow separation

### Student Performance Prediction (ML)
- [ ] ML model integration for at-risk student identification
- [ ] Early warning system based on attendance, grades, engagement patterns
- [ ] Requires BigQuery data pipeline first

---

## v4.5 — Enterprise Readiness 🔲 🆕

> **Strategic Phase:** Phase 10 — Enterprise Readiness  
> **Why it's here:** Enterprise features (compliance certifications, SSO, disaster recovery) are required for large school chains and government contracts. They come after the platform is proven at scale with 50+ schools.

### Success KPIs
| KPI | Target | Measurement |
|-----|--------|-------------|
| RTO achievement | < 4 hours in DR tests | Recovery test results |
| RPO achievement | < 15 minutes data loss in DR tests | Recovery test results |
| SSO adoption | > 20% of enterprise schools use SSO | SSO enrollment |
| Compliance pass rate | 100% on annual audit | Audit results |

### Compliance Framework
- [ ] GDPR compliance (EU schools, data processing agreements)
- [ ] COPPA compliance (children's data, parental consent)
- [ ] FERPA compliance (US student records privacy)
- [ ] Egyptian data protection law compliance
- [ ] GCC data residency requirements
- [ ] Privacy policy generator (per-jurisdiction)
- [ ] Data processing agreement templates
- [ ] Data export for portability (GDPR right to data portability)
- [ ] Right to deletion workflow (GDPR right to be forgotten)
- [ ] Cookie consent management (web dashboard)

### SSO & Identity
- [ ] Google Workspace SSO
- [ ] Microsoft 365 / Azure AD SSO
- [ ] SAML 2.0 support (enterprise standard)
- [ ] LDAP integration (on-premise schools)
- [ ] Multi-factor authentication enforcement per school
- [ ] Session management (concurrent session limits, idle timeout)
- [ ] Feature flag: `sso_enabled` → per-org

### Disaster Recovery 🆕

> **Why this is critical:** Enterprises demand formal disaster recovery objectives. Without documented RTO/RPO targets and tested recovery procedures, schools cannot trust Klasivo with their critical data.

#### Recovery Objectives
| Metric | Target | Justification |
|--------|--------|---------------|
| **RPO** (Recovery Point Objective) | 15 minutes | Maximum acceptable data loss — Firestore real-time sync + point-in-time recovery |
| **RTO** (Recovery Time Objective) | 4 hours | Maximum acceptable downtime — school operations can tolerate 4-hour outage |
| **RTO (Critical)** | 1 hour | For exam periods — scheduled exams must not be disrupted |

#### Backup Strategy
- [ ] Firestore automated backups (daily full + continuous incremental)
- [ ] Firebase Storage backups (daily sync to cold storage bucket)
- [ ] Cloud Functions code versioning (Git-based, always recoverable)
- [ ] Configuration backups (feature flags, security rules, indexes)
- [ ] Cross-region backup replication (primary: europe-west1, backup: europe-west3)

#### Backup Verification
- [ ] Automated backup integrity checks (daily: verify backup exists and is readable)
- [ ] Backup size monitoring (alert if backup size deviates > 10% from expected)
- [ ] Sample restore testing (weekly: restore 1 random collection to staging)
- [ ] Full backup metadata catalog (what was backed up, when, where, size)

#### Recovery Testing
- [ ] Monthly recovery drill: restore staging environment from backup
- [ ] Quarterly full DR test: simulate complete failure, restore to fresh environment
- [ ] Annual DR audit: third-party verification of RTO/RPO compliance
- [ ] DR test report template (what was tested, time to recover, data loss, lessons learned)
- [ ] Feature flag: `disaster_recovery_enabled` → always ON in production

#### Recovery Procedures
- [ ] Documented runbook for each failure scenario:
  - Firestore region outage → failover to backup region
  - Firebase Storage outage → redirect to backup bucket
  - Cloud Functions failure → redeploy from Git
  - Complete platform outage → full restore from backup
- [ ] Escalation matrix (who to call, when, in what order)
- [ ] Communication template (customer notification during outage)
- [ ] Post-incident review process (blameless, documented, action items)

### Scale Hardening
- [ ] Multi-region Firestore deployment
- [ ] CDN for static assets and recordings (Cloudflare)
- [ ] Auto-scaling Cloud Functions configuration review
- [ ] Database connection pooling and query optimization
- [ ] Rate limiting review (per-user, per-school, per-IP)
- [ ] Performance monitoring dashboards (Sentry + Cloud Monitoring)

---

## v5.0 — Marketplace & Ecosystem 🔲 🆕

> **Strategic Phase:** Phase 11 — Marketplace & Ecosystem  
> **Why it's here:** Once Klasivo is a complete school platform, the marketplace creates network effects and platform lock-in. Third-party developers build on Klasivo's API, making the platform more valuable for every school.

### API Platform
- [ ] Public REST API with OAuth 2.0 authentication
- [ ] Webhook system for real-time event notifications
- [ ] API rate limiting per application
- [ ] API documentation (OpenAPI/Swagger)
- [ ] Developer portal with sandbox environment
- [ ] SDK for common languages (JavaScript, Python, Dart)

### Plugin Marketplace
- [ ] Plugin registration and review process
- [ ] Plugin categories: Grading, Content, Communication, Analytics, Integration
- [ ] Plugin installation per school (admin control)
- [ ] Plugin permission model (what data each plugin can access)
- [ ] Plugin revenue sharing (Klasivo takes 20% platform fee)

### Third-Party Integrations
- [ ] Google Workspace integration (Calendar, Drive, Classroom sync)
- [ ] Microsoft 365 integration (Teams, OneDrive, Outlook)
- [ ] Zoom integration (alternative to LiveKit for schools that prefer Zoom)
- [ ] LTI compliance (Learning Tools Interoperability — connect to any LTI-compliant tool)
- [ ] Accounting software integration (QuickBooks, Xero)
- [ ] Government reporting APIs (Ministry of Education data submission)

---

## v5.5+ — Scale & Global Expansion 🔲 🆕

> **Strategic Phase:** Phase 12 — Scale & Global  
> **Why it's here:** Global expansion requires infrastructure investment, localization at scale, and regional compliance. This phase only begins after the platform is proven across 100+ schools in the home market.

### Success KPIs
| KPI | Target | Measurement |
|-----|--------|-------------|
| Schools on platform | 1,000+ | School count |
| Countries served | 10+ | Geographic distribution |
| Multi-language support | 5+ languages | Language coverage |
| Platform uptime | 99.95% | Uptime monitoring |
| Support response time | < 1 hour (critical), < 4 hours (standard) | Ticket tracking |

### Infrastructure Scaling
- [ ] Multi-region deployment (US, EU, Asia)
- [ ] Global CDN with regional edge caching
- [ ] Database sharding strategy for > 1,000 schools
- [ ] Event-driven architecture migration (Pub/Sub for cross-service communication)
- [ ] Kubernetes deployment for Cloud Functions replacement at scale
- [ ] Regional data residency (data stays in region per local laws)

### White-Label Platform
- [ ] Custom branding per school chain (logo, colors, app name)
- [ ] Custom domain support (school.klasivo.app → portal.schoolname.edu)
- [ ] Custom feature selection per chain
- [ ] Dedicated support team per chain (100+ schools)

---

# PART III — SPRINTS (Infrastructure & RBAC)

## Sprint 3 — Scope Enforcement, Claims Caching, Error Handling 🔲

> **Depends on: Sprint 1+2 merge**

### Scope Enforcement
- [ ] Scope-level Firestore rules — enforce `classId`/`stageId`/`campusId` boundaries in security rules
- [ ] Claims caching strategy — avoid stale claims after role/scope changes
- [ ] `hasMinimumRole()` helper — ordinal comparison using ROLE_HIERARCHY
- [ ] `canPerformAction()` helper — unified capability check (role + permission + scope)
- [ ] Unit tests for scope validator with edge cases

### Error Handling
- [ ] Client-side RBAC error mapping — Firebase permission denied → user-friendly messages
- [ ] Claims sync retry logic — exponential backoff with user notification
- [ ] Scope mismatch diagnostics — help admins understand access denials

### Phase 2B — Role Hierarchy Helpers
- [ ] `ROLE_HIERARCHY` ordinal map
- [ ] `hasMinimumRole(callerRole, minimumRole)` — ordinal comparison
- [ ] `canPerformAction(callerRole, action)` — ROLE_HIERARCHY + capability constants
- [ ] Replace all inline role-array inclusion checks with these helpers

---

## Sprint 3B — User Management UI + Enhanced Attendance 🔲

> **Depends on: Sprint 3 · Release target: v2.3A + v2.4**

### People Hub
- [ ] Unified people list with role badges, search, and filters
- [ ] Route: `/people`

### User Detail
- [ ] User profile with effective permissions view
- [ ] Route: `/people/:userId`

### Role Assignment
- [ ] Bottom sheet for role assignment with role matrix visualization
- [ ] Permission preview before confirming role change
- [ ] Calls `assignRole` callable

### Scope Assignment
- [ ] Screen for assigning campus/stage/class/subject scope
- [ ] Scope visualization (tree view)
- [ ] Calls `assignScope` callable

### Permission Overrides
- [ ] Allow/deny individual permissions beyond role defaults
- [ ] Calls `setPermissionOverrides` callable

### Role Matrix
- [ ] Visual matrix of roles × permissions
- [ ] Read-only view of the RBAC system

---

## Sprint 4 — Academic Records & Gradebook + SIS + Communication 🔲 🆕

> **Depends on: Sprint 3B · Release target: v2.5 + v2.6 + v2.7**

### Academic Records (v2.5)
- [ ] Gradebook engine (weighted categories, grade calculation, GPA)
- [ ] Report card template builder and PDF generation
- [ ] Academic term and year management
- [ ] Transcript generation and locking
- [ ] Teacher comments system

### Student Information System (v2.6)
- [ ] Comprehensive student profile pages
- [ ] Academic and attendance history views
- [ ] Medical notes and emergency contacts
- [ ] Document upload and management
- [ ] Student timeline

### Communication Hub (v2.7)
- [ ] Broadcast announcement system
- [ ] SMS integration (Twilio/Vonage)
- [ ] Teacher-parent messaging
- [ ] Scheduled campaigns

---

## Sprint 5 — School Accounts + Landing Pages + Migration Center 🔲

> **Depends on: Sprint 4 · Release target: v2.8 + v2.9**

### School Registration & Onboarding
- [ ] School registration wizard (step-by-step: name → logo → campus structure → academic calendar)
- [ ] Organization settings CRUD
- [ ] Campus/stage/class hierarchy management
- [ ] Data isolation between organizations (Firestore security rules)

### School Landing Pages
- [ ] `school_profiles` Firestore collection with slug indexing
- [ ] Public profile rendering (SEO-optimized)
- [ ] Admin profile editor
- [ ] Feature flag: `school_landing_pages_enabled`

### School Migration Center
- [ ] Import wizard (step-by-step, multi-entity)
- [ ] Excel/CSV parsing and validation
- [ ] Dry-run preview and error reporting
- [ ] Background import processing with progress tracking
- [ ] Rollback capability

---

## Sprint 6 — Web Dashboard Skeleton + School Analytics + Offline 🔲

> **Depends on: Sprint 5 · Release target: v3.0 + v3.1**

### Architecture Decision
Flutter Web first (same models, providers, RBAC, Firestore). If performance becomes a bottleneck at v4.0+, migrate dashboard to Next.js at `dashboard.klasivo.app`.

### Monorepo Structure
```
apps/
 ├─ mobile_app          ← Existing Flutter mobile app
 ├─ web_dashboard       ← New Flutter Web dashboard
 └─ public_site         ← Marketing website (future)

packages/
 ├─ auth                ← Shared authentication (Firebase Auth, Email OTP, Google, Apple, SSO)
 ├─ permissions         ← Shared RBAC (roles, scopes, permission checks)
 ├─ analytics           ← Shared analytics tracking and aggregation
 ├─ notifications       ← Shared push/email/in-app notifications
 ├─ api_client          ← Shared Firebase Functions callable wrappers
 ├─ design_system       ← Shared KlasivoButton, KlasivoCard, tokens, themes
 ├─ audit_logs          ← Shared audit event recording and querying
 └─ common_models       ← Shared Firestore models, DTOs, converters
```

### Dashboard Pages
- [ ] `/dashboard` — Overview (org stats, active classes, recent activity)
- [ ] `/users` — User management (People Hub, web-optimized layout)
- [ ] `/roles` — Role assignment and role matrix
- [ ] `/scopes` — Scope assignment and visualization
- [ ] `/settings` — Organization settings (branding, calendar, features)

### Responsive Layout
- [ ] Sidebar navigation (collapsible)
- [ ] Data tables with sorting, filtering, pagination
- [ ] Bulk action toolbar (multi-select, batch operations)
- [ ] Breadcrumb navigation

### Offline Mode (v3.1)
- [ ] Local SQLite/Hive database for offline data
- [ ] Sync queue with conflict resolution
- [ ] Network-aware Riverpod providers
- [ ] Connectivity indicator and sync status

---

## Sprint 7 — Full Dashboard Platform 🔲

> **Depends on: Sprint 6 · Domain: `platform.klasivo.app`**

Capabilities (separate from school dashboard — normal owners never see these):
- [ ] Manage Organizations (create, suspend, delete)
- [ ] Subscriptions management (plan assignment, billing overrides)
- [ ] Feature Flags (platform-wide and per-org)
- [ ] Support Tools (impersonate user, view org data, debug scope issues)
- [ ] Platform Analytics (signups, churn, MRR, active users)
- [ ] System Health (function metrics, error rates, latency)
- [ ] Audit Review (cross-org audit log, compliance reporting)
- [ ] BigQuery integration for historical analytics
- [ ] Custom Report Builder (drag-and-drop fields)

---

## Sprint 8 — Platform Separation 🔲

> **Depends on: Sprint 7**

### Subdomain Routing
```
klasivo.app           → Marketing Website
dashboard.klasivo.app → School Dashboard (Flutter Web)
platform.klasivo.app  → Klasivo Platform Admin
api.klasivo.app       → Functions / APIs
```

### Auth Flow Separation
- [ ] School dashboard auth (owner, admin, campus_manager, stage_manager, academic_supervisor)
- [ ] Platform auth (super_admin only)
- [ ] Mobile app auth (teacher, assistant_teacher, student, parent)
- [ ] Shared token format, separate routing based on role

### Enterprise Structure
```
Klasivo Platform
│
├── platform.klasivo.app
│     └─ super_admin
│
├── dashboard.klasivo.app
│     ├─ owner
│     ├─ admin
│     ├─ campus_manager
│     ├─ stage_manager
│     └─ academic_supervisor
│
└── Mobile App (Android/iOS)
      ├─ teacher
      ├─ assistant_teacher
      ├─ student
      └─ parent
```

---

# PART IV — DASHBOARD PLATFORM (v4.0)

## Platform Domains

```
klasivo.app                → Marketing Website (public, no management functionality)
dashboard.klasivo.app      → Platform administration, school management, analytics, operations
api.klasivo.app            → Secure backend APIs, Cloud Functions, admin operations
status.klasivo.app         → Status Page (future)
docs.klasivo.app           → Documentation (future)
```

---

## Authentication

**Primary:** Firebase Auth

| Method | Status | Notes |
|--------|--------|-------|
| Email/Password | ✅ Live | Current default |
| Email OTP | 🔲 Planned | Passwordless sign-in |
| Google Sign-In | ✅ Live | Current |
| Apple Sign-In | 🔲 Planned | Required for iOS App Store |
| SSO | 🔲 Planned | Google Workspace, Microsoft 365 (v4.5) |

---

## Authorization — RBAC

### Roles

```
owner              → Platform owner (multi-school access)
school_admin       → School-level administrator
teacher            → Classroom operations
parent             → Child monitoring (view-only)
student            → Learning and participation
```

Expanded role hierarchy (from Sprint 2):
```
super_admin         → Platform-wide (klasivo team only)
owner               → Multi-school owner
 └─ admin            → School administrator
      ├─ observer           → Read-only school access
      ├─ campus_manager     → Campus-level operations
      ├─ stage_manager      → Stage/grade-level operations
      └─ academic_supervisor → Academic oversight
teacher             → Classroom operations
 └─ assistant_teacher   → Limited classroom access
parent              → Child monitoring
student             → Learning and participation
```

### Permission Domains

```
users.read          users.write
schools.read        schools.write
classes.read        classes.write
assignments.read    assignments.write
attendance.read     attendance.write
analytics.read
billing.read        billing.write
exams.read          exams.write
grades.read         grades.write
live_rooms.read     live_rooms.write
notifications.read  notifications.write
reports.read        reports.write
settings.read       settings.write
audit.read
sis.read            sis.write
communication.read  communication.write
migration.read      migration.write
ai.read             ai.write
```

### Authorization Chain (Fail-Closed)

All access must pass through every layer:

```
Authentication → Role Validation → Scope Validation → Resource Validation
```

If any layer fails or is missing data: **DENY**. Never allow by default.

---

## Owner Dashboard

> **Domain: `dashboard.klasivo.app/owner`**  
> **Sprint: Sprint 7 (v4.0)**

Purpose: Platform administration across all schools.

### Overview
- [ ] KPIs: Total Schools, Total Teachers, Total Students, Total Parents, Active Classes, Live Sessions, Monthly Growth, Revenue, Storage Usage
- [ ] Charts: User Growth, School Growth, Session Usage, Daily Activity

### Schools
- [ ] Create school, Suspend school, Activate school
- [ ] View statistics, Assign admins, Set quotas

### Teacher Approval
- [ ] Workflow: Pending → Approved → Rejected
- [ ] Review profile, Verify credentials, Approval notes, Audit trail

### User Management
- [ ] Manage: Owners, Admins, Teachers, Parents, Students
- [ ] Search, Disable, Reactivate, Reset access

### LiveKit Management
- [ ] View: Rooms, Participants, Duration, Quality
- [ ] Controls: Close room, Remove participant, View logs

### Platform Analytics
- [ ] DAU, WAU, MAU, Retention, Engagement, Attendance, Assignment Completion

### Audit Logs
- [ ] Track every action with: userId, role, action, resource, resourceId, ip, timestamp, metadata
- [ ] Immutable — append-only, no deletion

### Billing
- [ ] Plans, Subscriptions, Invoices, Payments (future-ready)

### Navigation
```
Dashboard → Schools → Users → Teacher Approval → Live Classes → Analytics → Audit Logs → Billing → Settings
```

---

## School Dashboard

> **Domain: `dashboard.klasivo.app/school`**  
> **Sprint: Sprint 6 (v3.0 skeleton) → Sprint 7 (v4.0 full)**

Purpose: School operations.

### School Overview
- [ ] KPIs: Teachers, Students, Attendance Rate, Assignments, Active Classes

### Teacher Management
- [ ] Add teacher, Remove teacher, Assign subjects, Assign classes

### Student Management
- [ ] Enrollment, Transfer, Status changes, SIS profile view

### Parent Management
- [ ] Link parent, Invite parent, Remove access

### Class Management
- [ ] Create class, Assign teacher, Schedule lessons

### Attendance
- [ ] Daily attendance tracking
- [ ] Reports: Student, Class, School

### Gradebook & Academic Records 🆕
- [ ] Grade entry, GPA calculation, report cards
- [ ] Academic term management
- [ ] Transcript generation

### Communication 🆕
- [ ] Announcements, alerts, messaging
- [ ] Campaign management

### Exams
- [ ] Exam creation, Grades, Results

### Assignments
- [ ] Create, Review, Grade

### Reports
- [ ] PDF, Excel generation

### Migration 🆕
- [ ] Import data from external systems
- [ ] Import history and status

### Navigation
```
Overview → Teachers → Students → Parents → Classes → Attendance → Gradebook → Communication → Assignments → Exams → Reports → Migration → Settings
```

---

## Teacher Dashboard

> **Domain: `dashboard.klasivo.app/teacher`**  
> **Sprint: Sprint 6 (v3.0 web) · Mobile: already live**

### Modules
- [ ] My Classes — view assigned classes
- [ ] Assignments — create and grade
- [ ] Gradebook — enter and manage grades 🆕
- [ ] Exams — create and mark
- [ ] Attendance — take attendance
- [ ] Live Classes — create LiveKit rooms
- [ ] Student Performance — track progress
- [ ] AI Tools — question generator, grading assistant 🆕

### Navigation
```
Overview → Classes → Gradebook → Assignments → Attendance → Exams → Live Classes → AI Tools → Students
```

---

## Parent Dashboard

> **Domain: `dashboard.klasivo.app/parent`**  
> **Sprint: Sprint 6 (v3.0 web) · Mobile: already live**

### Modules
- [ ] Children — view linked students
- [ ] Attendance — track attendance
- [ ] Grades — view results and report cards 🆕
- [ ] Report Cards — view and download PDFs 🆕
- [ ] Assignments — monitor completion
- [ ] Messages — communicate with teachers 🆕
- [ ] Notifications — receive alerts

### Navigation
```
Overview → Children → Attendance → Grades → Report Cards → Assignments → Messages → Notifications
```

---

## Student Dashboard

> **Domain: `dashboard.klasivo.app/student`**  
> **Sprint: Sprint 6 (v3.0 web) · Mobile: already live**

### Modules
- [ ] My Classes
- [ ] Assignments
- [ ] Grades & GPA 🆕
- [ ] Exams
- [ ] Attendance
- [ ] Live Classes
- [ ] Resources
- [ ] Progress & Badges 🆕

### Navigation
```
Overview → Classes → Assignments → Grades → Attendance → Exams → Live Classes → Resources → Progress
```

---

## Dashboard UI Design System

Inspired by: Linear, Notion, Stripe Dashboard

Requirements:
- [ ] Responsive layout (desktop-first, mobile-friendly)
- [ ] Dark mode + Light mode (use existing design tokens)
- [ ] Accessibility (WCAG 2.1 AA)
- [ ] Sidebar navigation (collapsible)
- [ ] Data tables with sort/filter/pagination
- [ ] Bulk action toolbar
- [ ] Global search (schools, classes, students, teachers, parents)

---

# PART V — FIRESTORE DESIGN

## Collections

```
users               ← Authenticated users (all roles)
schools             ← Organization/school entities
school_members      ← Membership links (user ↔ school + role)
school_profiles     ← Public school profile data (v2.9)
classes             ← Class/group entities
enrollments         ← Student ↔ class enrollment
parents             ← Parent entities
parent_links        ← Parent ↔ student links
students            ← Student profile data
teachers            ← Teacher profile data
attendance          ← Daily attendance records
assignments         ← Assignment definitions
submissions         ← Student assignment submissions
rubrics             ← Grading rubrics (v2.3)
grades              ← Grade records
exams               ← Exam definitions
exam_submissions    ← Student exam submissions
live_rooms          ← LiveKit room metadata (existing: livekit_rooms)
notifications       ← In-app notifications
analytics_events    ← Raw analytics events
audit_logs          ← Immutable audit trail (existing)
subscriptions       ← Billing subscriptions
class_recordings    ← Video library (v2.1)
scheduled_classes   ← Scheduled live classes (existing)
session_analytics   ← LiveKit session analytics (existing)
feature_flags       ← Feature flag definitions (existing)
permission_overrides ← Per-user permission overrides (existing)
badges              ← Achievement badge definitions (v2.2A)
student_badges      ← Student badge unlocks (v2.2A)
streaks             ← Student streak data (v2.2A)
reminders           ← Reminder configurations (v2.2A)
gradebook_entries   ← Gradebook grade records (v2.5) 🆕
grade_categories    ← Grading categories with weights (v2.5) 🆕
report_cards        ← Generated report cards (v2.5) 🆕
report_card_templates ← Customizable report templates (v2.5) 🆕
academic_terms      ← Term definitions (v2.5) 🆕
academic_years      ← Academic year definitions (v2.5) 🆕
transcripts         ← Official transcript records (v2.5) 🆕
grade_scales        ← School-specific grading scales (v2.5) 🆕
teacher_comments    ← Teacher comments per student/subject/term (v2.5) 🆕
student_profiles    ← Extended student data with medical/emergency (v2.6) 🆕
student_medical     ← Medical records (v2.6) 🆕
student_emergency_contacts ← Emergency contact entries (v2.6) 🆕
student_documents   ← Uploaded documents (v2.6) 🆕
student_timeline    ← Chronological event stream (v2.6) 🆕
announcements       ← Broadcast announcements (v2.7) 🆕
announcement_receipts ← Delivery/read tracking (v2.7) 🆕
messages            ← Direct messages (v2.7) 🆕
message_threads     ← Conversation threads (v2.7) 🆕
campaigns           ← Scheduled campaigns (v2.7) 🆕
communication_preferences ← Per-user channel preferences (v2.7) 🆕
import_jobs         ← Migration job tracking (v2.9) 🆕
import_templates    ← Template definitions (v2.9) 🆕
timetables          ← Schedule definitions (v2.5A) 🆕
timetable_entries   ← Period assignments (v2.5A) 🆕
period_definitions  ← School day structure (v2.5A) 🆕
rooms               ← Room inventory (v2.5A) 🆕
scheduling_constraints ← Constraint rules (v2.5A) 🆕
question_pools      ← Question pool definitions (v3.3) 🆕
exam_blueprints     ← Exam structure templates (v3.3) 🆕
question_analytics  ← Per-question performance data (v3.3) 🆕
learning_outcomes   ← Outcome definitions (v3.4) 🆕
outcome_links       ← Outcome-content links (v3.4) 🆕
outcome_mastery     ← Per-student mastery (v3.4) 🆕
curriculum_maps     ← Curriculum map definitions (v3.4) 🆕
ai_usage_logs       ← AI interaction logs (v3.5) 🆕
ai_quotas           ← AI usage quotas (v3.5) 🆕
ai_cost_budgets     ← AI cost budgets (v3.5) 🆕
ai_moderation_flags ← Flagged AI content (v3.5) 🆕
```

### Schema Requirements
- [ ] All collections include: `createdAt`, `updatedAt`, `organizationId`
- [ ] Soft delete pattern: `isArchived` + `archivedAt` on all entities
- [ ] Scope fields on scope-bound collections: `campusId`, `stageId`, `classId`
- [ ] Owner validation on all writes (resource must belong to caller's org)
- [ ] Immutable audit logs (no update/delete — append only)

### Indexes
- [ ] Composite indexes for all filtered+sorted queries
- [ ] Scope-based indexes: `organizationId` + `classId` + `createdAt`
- [ ] Slug index on `school_profiles` for landing page routing
- [ ] Full-text search indexes (Algolia or Firestore native) for global search
- [ ] Gradebook indexes: `organizationId` + `classId` + `subjectId` + `termId` 🆕
- [ ] Student timeline index: `studentId` + `timestamp` 🆕
- [ ] Announcement audience index: `organizationId` + `audienceType` + `sentAt` 🆕

### Security Rules
- [ ] Role-based rules with field-level security
- [ ] Scope validation in rules (caller's classIds must include resource.classId)
- [ ] Organization boundary enforcement (caller.orgId == resource.orgId)
- [ ] Fail-closed: missing fields → DENY
- [ ] Medical/emergency data: restricted access (admin + designated staff only) 🆕
- [ ] Grade history: immutable after publication (no delete, edit requires audit trail) 🆕
- [ ] AI logs: read-only for all roles except super_admin 🆕

---

# PART VI — CROSS-CUTTING SYSTEMS

## Analytics System

### Event Tracking (`analytics_events` collection)
- [ ] Login events
- [ ] Attendance marking
- [ ] Assignment submission
- [ ] Live session join/leave
- [ ] Exam completion
- [ ] Recording view
- [ ] Badge unlock
- [ ] Page view (dashboard)
- [ ] Grade entry (v2.5) 🆕
- [ ] Report card generation (v2.5) 🆕
- [ ] Announcement delivery/read (v2.7) 🆕
- [ ] AI feature usage (v3.5) 🆕

### Aggregation
- [ ] Daily/weekly/monthly aggregation Cloud Functions
- [ ] Pre-computed dashboards in `analytics_daily`, `analytics_monthly` collections
- [ ] BigQuery export for historical analysis (v4.0+ only)

### School Analytics (v2.8)
- [ ] Attendance reports
- [ ] Grades reports
- [ ] Assignment completion rates
- [ ] Basic charts and data export

### Platform Analytics (v4.0)
- [ ] DAU, WAU, MAU
- [ ] Retention cohorts
- [ ] Engagement scoring
- [ ] Attendance trends
- [ ] Assignment completion rates

---

## Notification System

### Channels
| Channel | Status | Notes |
|---------|--------|-------|
| Push (FCM) | ✅ Live | Android + iOS |
| In-App | ✅ Live | Notification center |
| Email (Resend) | ✅ Live | Weekly summaries, reports |
| SMS (Twilio/Vonage) | 🔲 v2.7 | Urgent alerts, parents without smartphones 🆕 |
| WhatsApp Business API | 🔲 Future | Market-specific (high WhatsApp usage regions) |

### Events → Notifications
| Event | Recipients | Channel |
|-------|-----------|---------|
| Assignment Due Tomorrow | Student | Push + In-App |
| Assignment Overdue | Student | Push + In-App (daily) |
| Exam Tomorrow | Student | Push + In-App |
| Live Class Starting (5 min) | Student | Push |
| Attendance Alert (Absence) | Parent | Push + Email + SMS 🆕 |
| Grade Published | Student, Parent | Push + In-App |
| Report Card Published | Parent, Student | Push + Email + SMS 🆕 |
| Teacher Approved | Teacher | Email |
| New Recording | Student | Push + In-App |
| Badge Unlocked | Student | Push + In-App |
| Streak Milestone | Student | Push + In-App |
| Weekly Progress Summary | Parent | Email (Sunday) |
| Broadcast Announcement | School-wide | Push + In-App + Email 🆕 |
| Emergency Alert | School-wide | Push + SMS + Email + In-App 🆕 |
| Teacher-Parent Message | Parent/Teacher | Push + In-App 🆕 |
| AI Usage Alert (Quota) | Admin | In-App + Email 🆕 |
| AI Budget Warning | Admin | In-App + Email 🆕 |

---

## Search System 🔲

Global dashboard search across:
- [ ] Schools
- [ ] Classes
- [ ] Students
- [ ] Teachers
- [ ] Parents
- [ ] Assignments
- [ ] Exams
- [ ] Gradebook entries 🆕
- [ ] Report cards 🆕
- [ ] Announcements 🆕

Implementation options:
- [ ] Algolia (recommended for production-scale full-text search)
- [ ] Firestore native search (limited but zero-infrastructure)
- [ ] Meilisearch (self-hosted alternative)

---

## Audit Logging

### Schema
```typescript
{
  userId: string,
  role: string,
  action: string,           // e.g., 'user.disable', 'school.create', 'role.assign', 'grade.edit', 'ai.use'
  resource: string,         // e.g., 'user', 'school', 'class', 'gradebook_entry', 'ai_usage'
  resourceId: string,
  organizationId: string,
  ip: string,
  userAgent: string,
  timestamp: Timestamp,
  metadata: Map<string, any>,  // action-specific details
}
```

### Requirements
- [ ] Immutable — append-only, no update or delete
- [ ] Indexed by: `organizationId`, `userId`, `action`, `timestamp`
- [ ] Retention policy: 90 days hot, 1 year cold (BigQuery)
- [ ] Export to CSV for compliance reporting
- [ ] AI usage audit trail (v3.5+): prompt metadata, model, cost, safety score 🆕
- [ ] Grade change audit trail (v2.5+): who changed, old value, new value, reason 🆕

---

# PART VII — MIGRATION PLAN (M1–M8)

> **Goal:** Migrate from MVP to production SaaS platform with zero downtime and full backward compatibility.  
> **Principle:** Feature flags gate every migration step. Rollback is always possible.  
> **Timing:** Migration phases are tied to v4.0 platform readiness. They begin AFTER adoption-driving features (v2.1–v2.9) are shipped and schools are using the platform.

### M1 — Preserve & Stabilize
- [ ] Audit all existing Firestore collections for schema consistency
- [ ] Add missing `organizationId` fields to legacy documents
- [ ] Backfill `createdAt`/`updatedAt` on documents missing timestamps
- [ ] Verify all existing users have correct custom claims (`role`, `organizationId`, `scopeAccessLevel`)
- [ ] Feature flag: `migration_m1_complete` → enables M2

### M2 — Introduce RBAC
- [ ] Deploy RBAC callables (assignRole, assignScope, syncClaims, setPermissionOverrides)
- [ ] Deploy scope-aware Firestore rules (fail-closed, but with legacy bypass flag)
- [ ] Feature flag: `rbac_enforcement` → defaults OFF, per-org rollout
- [ ] Feature flag: `migration_m2_complete` → enables M3
- [ ] Backward compatible: existing code continues to work with RBAC OFF

### M3 — Introduce Dashboard
- [ ] Deploy Flutter Web dashboard skeleton at `dashboard.klasivo.app`
- [ ] Dashboard uses same Firestore, same models, same RBAC
- [ ] Feature flag: `dashboard_enabled` → per-org, defaults OFF
- [ ] Feature flag: `migration_m3_complete` → enables M4

### M4 — Migrate Attendance + Gradebook 🆕
- [ ] Dashboard attendance page reads/writes same `attendance` collection as mobile
- [ ] Dashboard gradebook page reads/writes same `gradebook_entries` collection
- [ ] Mobile attendance and gradebook screens continue to work unchanged
- [ ] Feature flag: `dashboard_attendance` → per-org
- [ ] Feature flag: `dashboard_gradebook` → per-org 🆕
- [ ] Feature flag: `migration_m4_complete` → enables M5

### M5 — Migrate Assignments + Communication 🆕
- [ ] Dashboard assignment page reads/writes same `assignments` + `submissions` collections
- [ ] Dashboard communication page reads/writes same `announcements` + `messages` collections
- [ ] Mobile assignment and messaging screens continue to work unchanged
- [ ] Feature flag: `dashboard_assignments` → per-org
- [ ] Feature flag: `dashboard_communication` → per-org 🆕
- [ ] Feature flag: `migration_m5_complete` → enables M6

### M6 — Migrate Analytics + SIS 🆕
- [ ] Dashboard analytics page reads pre-computed aggregation collections
- [ ] Dashboard SIS page reads/writes same `student_profiles` and related collections
- [ ] Aggregation Cloud Functions run alongside existing analytics
- [ ] Feature flag: `dashboard_analytics` → per-org
- [ ] Feature flag: `dashboard_sis` → per-org 🆕
- [ ] Feature flag: `migration_m6_complete` → enables M7

### M7 — Enable School Management + Migration Center 🆕
- [ ] School dashboard pages (teachers, students, parents, classes)
- [ ] Owner dashboard pages (schools, teacher approval, platform analytics)
- [ ] Migration Center accessible from dashboard
- [ ] Feature flag: `school_management` → per-org
- [ ] Feature flag: `migration_center` → per-org 🆕
- [ ] Feature flag: `migration_m7_complete` → enables M8

### M8 — Enable Billing + AI 🆕
- [ ] Stripe integration, subscription management, invoice generation
- [ ] AI features enabled per-org (with governance framework)
- [ ] Feature flag: `billing_enabled` → per-org
- [ ] Feature flag: `ai_features_enabled` → per-org 🆕
- [ ] Feature flag: `migration_m8_complete` → platform fully migrated

---

# PART VIII — SECURITY REQUIREMENTS

### Mandatory Security Layers

```
┌──────────────────────────────────────────────────────────────────┐
│  1. Authentication  — Firebase Auth (email, Google, Apple, OTP)  │
│  2. Role Validation — Custom claims checked server-side          │
│  3. Scope Validation — Caller scope must include resource scope  │
│  4. Resource Validation — Resource must belong to caller's org   │
│  5. Audit Logging   — Every mutation recorded immutably          │
└──────────────────────────────────────────────────────────────────┘
```

### Additional Security Requirements
- [ ] Rate limiting on all callable functions (per-user, per-IP)
- [ ] Cloudflare protection on `dashboard.klasivo.app` and `api.klasivo.app`
- [ ] Secure API gateway with request validation
- [ ] Signed Firebase Storage URLs (no public access)
- [ ] Server-side authorization on ALL operations (never trust client)
- [ ] Firestore rules: role + scope + ownership validation
- [ ] App Check enforcement on all callable functions
- [ ] CORS configuration for `dashboard.klasivo.app` origin only
- [ ] Medical/emergency data field-level security (admin + nurse only) 🆕
- [ ] Grade data: immutable after publication (edit requires audit trail) 🆕
- [ ] AI content moderation on all AI inputs and outputs 🆕
- [ ] Student documents: access-controlled per document category 🆕

### Fail-Closed Principle
- Missing role → DENY
- Missing scope → DENY
- Missing organizationId → DENY
- Unknown scopeAccessLevel → DENY
- Empty scope arrays → DENY (not "all access")
- Unknown room type → DENY
- Missing AI governance quota → DENY 🆕
- AI content moderation failure → DENY 🆕
- Unpublished grade → student/parent DENY 🆕

### Disaster Recovery 🆕

#### Recovery Objectives
| Metric | Target | Justification |
|--------|--------|---------------|
| **RPO** | 15 minutes | Firestore real-time sync + point-in-time recovery |
| **RTO** | 4 hours | School operations can tolerate 4-hour outage |
| **RTO (Critical)** | 1 hour | During exam periods |

#### Backup Strategy
- [ ] Firestore automated backups (daily full + continuous incremental)
- [ ] Firebase Storage backups (daily sync to cold storage bucket)
- [ ] Cloud Functions code versioning (Git-based, always recoverable)
- [ ] Configuration backups (feature flags, security rules, indexes)
- [ ] Cross-region backup replication (primary: europe-west1, backup: europe-west3)

#### Backup Verification
- [ ] Automated backup integrity checks (daily)
- [ ] Backup size monitoring (alert if > 10% deviation)
- [ ] Sample restore testing (weekly: restore 1 random collection to staging)

#### Recovery Testing
- [ ] Monthly recovery drill: restore staging from backup
- [ ] Quarterly full DR test: simulate complete failure, restore to fresh environment
- [ ] Annual DR audit: third-party RTO/RPO verification
- [ ] DR test report template (what was tested, recovery time, data loss, lessons learned)

---

# PART IX — INFRASTRUCTURE

## Cloud Functions ✅ (2026-06-14)

### v1→v2 Migration
- [x] 5 RBAC callables migrated v1→v2
- [x] Auth triggers remain v1 (no v2 after-event auth API)
- [x] All other functions already v2

### Cost Optimization
- [x] `maxInstances` caps on all v2 functions
- [x] `minInstances: 1` only on latency-critical (api, generateLiveKitToken)
- [x] `concurrency: 80–100` on all callables
- [x] Explicit `memory` + `timeoutSeconds` on all functions

### Post-Deploy Verification Required
- [ ] Run `firebase deploy --only functions` to deploy v2 callables
- [ ] Run `firebase functions:list` to confirm all RBAC functions are Gen 2
- [ ] If old v1 versions remain, delete explicitly
- [ ] Confirm no duplicate Gen1 + Gen2 versions

### Function Config Summary
| Function | Gen | min | max | Conc. | Memory |
|----------|-----|-----|-----|-------|--------|
| api | v2 | 1 | 100 | 80 | 512MiB |
| generateLiveKitToken | v2 | 1 | 50 | 100 | 256MiB |
| removeParticipant | v2 | 0 | 20 | 80 | 256MiB |
| assignRole | v2 | 0 | 10 | 80 | 256MiB |
| assignScope | v2 | 0 | 10 | 80 | 256MiB |
| syncClaims | v2 | 0 | 20 | 80 | 256MiB |
| changeUserPassword | v2 | 0 | 10 | 80 | 256MiB |
| setPermissionOverrides | v2 | 0 | 10 | 80 | 256MiB |
| sendContactForm | v2 | 0 | 10 | 80 | 256MiB |
| sendTeacherInvitation | v2 | 0 | 10 | 80 | 256MiB |
| sendSchoolAnnouncement | v2 | 0 | 10 | 80 | 256MiB |
| emailWorker | v2 | 0 | — | — | 256MiB |
| onLiveKitRoomCreated | v2 | 0 | — | — | 256MiB |
| onLiveKitRoomUpdated | v2 | 0 | — | — | 256MiB |
| scheduledClassReminder | v2 | 0 | 1 | — | 256MiB |
| onUserCreated | v1 | — | — | — | 256MB |
| onUserDeleted | v1 | — | — | — | 256MB |

### New Functions Required 🆕
| Function | Gen | Purpose | Release |
|----------|-----|---------|---------|
| gradebookCalculateGPA | v2 | Calculate GPA for student/term | v2.5 |
| reportCardGeneratePDF | v2 | Generate report card PDF | v2.5 |
| transcriptGeneratePDF | v2 | Generate official transcript PDF | v2.5 |
| announcementBroadcast | v2 | Send announcement across channels | v2.7 |
| smsSend | v2 | Send SMS via Twilio/Vonage | v2.7 |
| campaignProcess | v2 | Process scheduled campaigns | v2.7 |
| importProcessFile | v2 | Parse and validate import file | v2.9 |
| importExecute | v2 | Execute import with batch writes | v2.9 |
| aiGenerateQuestions | v2 | AI question generation | v3.5 |
| aiGradeAssist | v2 | AI grading assistance | v3.5 |
| aiModerateContent | v2 | AI content moderation | v3.5 |
| aiTrackUsage | v2 | AI usage tracking and quota management | v3.5 |

---

# PART X — OBSERVER ROLE SPECIFICATION

### Hierarchy Placement
```
owner
 └─ admin
      ├─ observer
      ├─ campus_manager
      └─ stage_manager
```

### Permissions (Read-Only)
```
✓ analytics.view       ✓ attendance.view       ✓ student.view
✓ reports.view         ✓ exam.view             ✓ assignment.view
✓ class.view           ✓ stage.view            ✓ subject.view
✓ group.view           ✓ user.view             ✓ result.view
✓ lesson.view          ✓ material.view         ✓ notification.view
✓ integrity.view       ✓ fees.view             ✓ payments.view
✓ inventory.view       ✓ org.view              ✓ progress.view
✓ question.view        ✓ gradebook.view        ✓ report_card.view 🆕
✓ sis.view             ✓ communication.view    ✓ transcript.view 🆕

✗ create               ✗ edit                  ✗ delete
✗ assign roles         ✗ publish               ✗ export
✗ grade.edit           ✗ ai.use 🆕
```

### Platform
- Dashboard (primary)
- Optional mobile companion (read-only views)

---

# PART XI — PERMISSION SEPARATION BY PLATFORM

### Dashboard-Only (available via API but UI only on dashboard)
```
organization.create    organization.delete
role.assign            scope.assign
billing.manage         feature_flags.manage
user.manage            audit.view
report_card.publish    transcript.generate 🆕
ai.governance.manage   import.execute 🆕
```

### Mobile + Web (available on both platforms)
```
attendance.mark        exam.grade
assignment.create      message.send
notification.view      gradebook.entry 🆕
communication.send     parent.message 🆕
```

### Mobile-Only (not available on dashboard)
```
offline.sync           camera.upload 🆕
push.register
```

RBAC is platform-agnostic. The constraint is purely at the UI/routing layer.

---

# PART XII — COMPLETED RELEASES (ARCHIVE)

### v1.0–v1.5 — Core Platform ✅
- [x] Firebase Auth (email/password + Google Sign-In), Multi-role, Hive-persisted sessions
- [x] Teacher: Dashboard, Stage→Class→Group, Exams (3 types), Question Bank, Auto-grading, Results, Attendance, Gradebook, Assignments, Excel import, QR enrollment
- [x] Student: Dashboard, Exam taking (auto-save, timer, integrity), Results review
- [x] Parent: Dashboard, child overview, results/attendance/assignments/progress/announcements
- [x] Notifications: FCM, Local, Notification center
- [x] Reports: PDF generation, exam statistics, analytics dashboard

### v1.6 — Feature Expansion ✅
- [x] Announcements, Calendar, Academic Years, Audit Logs

### v1.7 — Enterprise Foundations ✅
- [x] Design Tokens (7 files), Component Library (8 files), Feature Flags (27 flags), Event Bus (25+ events), Permission Service (80+ permissions)

### v1.8 — Feature Completion ✅
- [x] LMS screens, Messaging UI, legacy cleanup

### v1.9 — Polish & Integration ✅
- [x] Component migration, Unit/Integration tests, CI/CD, Performance optimization

### v2.0 — Dark Mode, Push Notifications, Video Player, Content Tracking ✅
- [x] Theme provider, Dark/Light/System, FCM push notifications, YouTube player, Video progress tracking, Content completion tracking

---

# PART XIII — AI GOVERNANCE FRAMEWORK 🆕

> **Release Target:** v3.5 (AI Layer)  
> **Principle:** AI in education must be transparent, controlled, auditable, and always human-supervised. Every AI action is a suggestion, never a decision.

## Governance Pillars

```
┌─────────────────────────────────────────────────────────────┐
│                    AI GOVERNANCE FRAMEWORK                    │
├─────────────┬─────────────┬──────────────┬─────────────────┤
│  QUOTAS &   │  CONTENT    │  AUDIT &     │  TRANSPARENCY   │
│  COST CTRL  │  MODERATION │  ACCOUNTING  │  & LABELING     │
├─────────────┼─────────────┼──────────────┼─────────────────┤
│ Per-school  │ Input       │ Prompt       │ AI-Assisted     │
│ quotas      │ moderation  │ logging      │ labels in UI    │
│             │             │              │                 │
│ Per-teacher │ Output      │ Cost         │ Parent          │
│ sub-quotas  │ moderation  │ tracking     │ notification    │
│             │             │              │                 │
│ Monthly     │ Safety      │ 90-day       │ Monthly         │
│ budgets     │ scoring     │ retention    │ usage report    │
│             │             │              │                 │
│ Budget      │ Blocklist   │ Annual       │ Student never   │
│ auto-disable│ per school  │ audit        │ talks to AI     │
│             │             │              │                 │
│ Cost        │ Flagged     │ Human        │ Teacher always   │
│ reporting   │ review      │ approval     │ has final say   │
└─────────────┴─────────────┴──────────────┴─────────────────┘
```

## Feature Flags for AI

| Flag | Default | Purpose |
|------|---------|---------|
| `ai_features_enabled` | OFF | Master switch for all AI features |
| `ai_question_generator_enabled` | OFF | Question generation feature |
| `ai_grading_assistant_enabled` | OFF | Grading assistant feature |
| `ai_quotas_enabled` | ON | Usage quota enforcement |
| `ai_content_moderation_enabled` | ON | Input/output moderation |
| `ai_transparency_labels_enabled` | ON | "AI-Assisted" labels in UI |
| `ai_full_prompt_logging` | OFF | Full prompt content logging (privacy-sensitive) |

## AI Safety Rules

1. **No autonomous AI actions** — every AI output is a suggestion requiring human approval
2. **No direct student-AI interaction** — AI is teacher-facing only
3. **No AI-generated grades without teacher confirmation** — grading is always human-verified
4. **No AI without content moderation** — all inputs and outputs pass through safety checks
5. **No AI without audit trail** — every interaction is logged with metadata
6. **No AI without quotas** — usage is bounded per school and per teacher
7. **No hidden AI** — all AI-generated content is labeled as "AI-Assisted"
8. **No cost surprises** — budgets auto-disable AI when exceeded

---

## Current Codebase Stats

| Metric | Count |
|--------|-------|
| Services | 56 |
| Providers | 54 |
| Screens | 71 |
| Routes | 65+ |
| Custom Widgets | 14 |
| Feature Flags | 27 (+7 AI + 5 new) 🆕 |
| Permissions | 80+ (+4 new domains) 🆕 |
| Event Types | 25+ |
| User Roles | 11 (with expanded hierarchy) |
| Firestore Indexes | 126 (+12 new) 🆕 |
| Cloud Functions | 17 (+15 new) 🆕 |
| Firestore Collections | 30 (+30 new) 🆕 |
| RBAC Files (pending merge) | 15 |
| LiveKit Files (pending merge) | 13 |
| User Mgmt Files (pending merge) | 10 |
| Cloud Functions TS (pending merge) | 25+ |

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                        Presentation Layer                         │
│  Mobile App  ·  Web Dashboard  ·  Owner Platform  ·  Public Site│
│  Screens (71+)  ·  Widgets (18)  ·  Shells (3+)                 │
├──────────────────────────────────────────────────────────────────┤
│                     Shared Packages (Monorepo)                    │
│  auth  ·  permissions  ·  analytics  ·  notifications            │
│  api_client  ·  design_system  ·  audit_logs  ·  common_models  │
│  gradebook  ·  sis  ·  communication  ·  ai_governance 🆕        │
├──────────────────────────────────────────────────────────────────┤
│                        State Management                           │
│  Providers (54+)  ·  Riverpod  ·  StreamProviders               │
│  Offline Sync Queue (v3.1) 🆕                                    │
├──────────────────────────────────────────────────────────────────┤
│                        Business Logic                             │
│  Services (56+)  ·  Event Bus  ·  Feature Flags                  │
│  RBAC (15 files) ·  Permission Service  ·  Audit                 │
│  Grading Engine  ·  GPA Calculator  ·  Report Card Builder 🆕    │
│  LiveKit Repository  ·  Scope Validator  ·  AI Governance 🆕     │
├──────────────────────────────────────────────────────────────────┤
│                        Data Layer                                 │
│  Firebase Auth  ·  Firestore  ·  FCM  ·  Hive  ·  PDF           │
│  Firebase Functions (37+ TS)  ·  LiveKit Server  ·  Storage      │
│  Stripe (v3.2+)  ·  BigQuery (v4.0+)  ·  Algolia (v4.0+)        │
│  Twilio/Vonage SMS (v2.7+) 🆕  ·  OpenAI/Gemini (v3.5+) 🆕      │
│  Local SQLite/Hive (v3.1+ offline) 🆕                            │
└──────────────────────────────────────────────────────────────────┘
```

---

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
10. **RBAC is Platform-Agnostic** — Permissions know role/permission/scope, not Web/Mobile/Dashboard
11. **Fail-Closed Authorization** — Missing metadata = DENY. Unknown scope = DENY. Empty arrays = DENY.
12. **Server-Side Role Determination** — Never trust client-sent role values; derive from auth claims
13. **Shared Models, No Duplication** — Monorepo packages ensure single source of truth for all apps
14. **Migration is Feature-Flagged** — Every migration step can be rolled back per-org without downtime
15. **Immutable Audit Trail** — Every mutation logged, append-only, no deletion
16. **Adoption Before Infrastructure** — Features schools pay for ship before features that scale the backend
17. **Academic Core First** — Gradebook, report cards, and transcripts are not "nice-to-have" — they are prerequisites for schools to replace existing systems 🆕
18. **AI is Always Suggestion, Never Decision** — Every AI output requires human approval before taking effect 🆕
19. **Offline is a Feature, Not an Afterthought** — Mobile-first means offline-first for developing markets 🆕
20. **School Migration Removes Barriers** — Making it easy to import data removes the #1 adoption blocker 🆕
21. **Timetable is Foundational** — Schedules underpin attendance, live classes, rooms, and parent communication 🆕
22. **Outcomes Over Grades** — Learning outcomes connect content to measurable mastery, not just scores 🆕
23. **30 Minutes to Value** — A school should go from signup to operational in 30 minutes 🆕
24. **Build Outcomes, Not Features** — Every feature must produce a measurable outcome (see Product Metrics Framework) 🆕

---

## Adoption Priority Reference

The following table summarizes the re-prioritization rationale for quick reference:

| Feature | Old Position | New Position | Why |
|---------|-------------|-------------|-----|
| Teacher Approval | v2.3 | v2.2 | Trust feature — schools ask for this before adoption |
| Assignment Submission | v2.4 | v2.3 | Highest-frequency daily workflow |
| Parent Enhanced | v2.4.1 | v2.3A | Parents drive engagement and retention |
| Student Engagement | — | v2.2A | Low effort, high retention value |
| Student Reminders | — | v2.2A | Low effort, high perceived value |
| Academic Records & Gradebook | — | v2.5 🆕 | Schools cannot switch without gradebook and report cards |
| Timetable Builder | — | v2.5A 🆕 | Every school runs on schedules — most requested feature globally |
| Student Information System | — | v2.6 🆕 | Central student record — SIS foundation |
| Communication Hub | — | v2.7 🆕 | Replace WhatsApp as school communication channel |
| 30-Minute School Launch | — | v2.9 🆕 | Highest-ROI business feature — reduces conversion friction |
| School Migration Center | — | v2.9 🆕 | #1 adoption barrier — "our data is elsewhere" |
| Mobile-First Offline | — | v3.1 🆕 | Competitive advantage in developing markets |
| Assessment Engine | — | v3.3 🆕 | Transforms basic exams into professional assessment platform |
| Learning Outcomes Framework | — | v3.4 🆕 | Bridge between grading and competency-based education |
| Chat Attachments | v2.2 | v2.4 | Quality-of-life, not adoption driver |
| Offline Caching | v2.2 | v3.1 | Elevated from basic to full offline strategy |
| School Landing Pages | — | v2.9 | Network effects, parent discovery |
| BigQuery | v2.5 | v4.0 | Not needed until 50+ schools |
| Custom Report Builder | v2.5 | v4.0 | Schools want basic reports first |
| Platform Analytics | v2.5 | v4.0 | School analytics first |
| Web Dashboard | Sprint 4 | v3.0 (S6) | Not needed before mobile features work |
| AI Question Generator | — | v3.5 | Differentiator, needs stable base + governance |
| AI Grading Assistant | — | v3.5 | Differentiator, needs stable base + governance |
| AI Governance | — | v3.5 🆕 | Required before any AI rollout in schools |
| Competitive Positioning | — | New section 🆕 | Investors need to understand the moat |
| Geographic Expansion | — | New section 🆕 | Strategic growth roadmap |
| Disaster Recovery | — | Part VIII 🆕 | Enterprise requirement for RTO/RPO |
| Success KPIs | — | Each release 🆕 | Measurable outcomes for every phase |

---

# PART XIV — PRODUCT METRICS FRAMEWORK 🆕

> **Purpose:** Transform the roadmap from "build features" into "build outcomes." Every phase must produce measurable results. These metrics are the scoreboard that determines whether the roadmap is working.

## Acquisition Metrics

| Metric | Definition | Target | Measurement |
|--------|-----------|--------|-------------|
| Schools Signed Up | New school registrations per month | 10/month by Month 6 | Firestore `schools` count |
| Schools Activated | Schools with > 1 teacher AND > 10 students AND > 1 class | > 70% of signups | Activation funnel |
| Activation Time | Time from signup to first class session | < 30 minutes | Onboarding funnel |
| Signup Source | Where schools come from (referral, landing page, organic, paid) | Track all | UTM parameters |
| Conversion Rate | Trial → Paid school ratio | > 15% within 90 days | Subscription events |

## Engagement Metrics

| Metric | Definition | Target | Measurement |
|--------|-----------|--------|-------------|
| DAU | Daily Active Users (any role) | > 60% of enrolled | Daily login events |
| WAU | Weekly Active Users | > 75% of enrolled | Weekly login events |
| MAU | Monthly Active Users | > 85% of enrolled | Monthly login events |
| Teacher DAU | Teachers who create or grade content daily | > 70% | Teacher action events |
| Student DAU | Students who view content or submit work daily | > 50% | Student action events |
| Parent WAU | Parents who view child progress weekly | > 40% | Parent login events |
| Feature Adoption | % of schools using each feature within 30 days | > 50% per feature | Feature flag activation |

## Retention Metrics

| Metric | Definition | Target | Measurement |
|--------|-----------|--------|-------------|
| 30-Day Retention | Users active Day 30 after signup | > 70% | Cohort analysis |
| 90-Day Retention | Users active Day 90 after signup | > 50% | Cohort analysis |
| School Churn Rate | Schools that cancel per month | < 5% | Subscription cancellation events |
| Teacher Churn | Teachers who stop using within 30 days | < 10% | Teacher inactivity tracking |
| NPS | Net Promoter Score (quarterly survey) | > 50 | Survey responses |

## Revenue Metrics

| Metric | Definition | Target | Measurement |
|--------|-----------|--------|-------------|
| MRR | Monthly Recurring Revenue | Track growth rate | Stripe billing data |
| ARR | Annual Recurring Revenue | Track growth rate | MRR × 12 |
| ARPU | Average Revenue Per User (per student) | Track monthly | MRR / total students |
| Free → Paid Rate | Conversion from free to paid tier | > 15% within 90 days | Plan change events |
| LTV | Customer Lifetime Value | Track per cohort | ARPU × average lifespan |
| CAC | Customer Acquisition Cost | Track monthly | Marketing spend / new schools |

## Education-Specific Metrics

| Metric | Definition | Target | Measurement |
|--------|-----------|--------|-------------|
| Assignment Completion Rate | % of assignments submitted on time | > 85% | Submission timestamps |
| Attendance Rate | % of students present daily | > 90% | Attendance records |
| Grade Entry Rate | % of teachers entering grades weekly | > 80% | Gradebook entry frequency |
| Report Card Generation | % of schools generating report cards per term | > 70% | Report card creation events |
| Parent Engagement | % of parents viewing child progress weekly | > 40% | Parent dashboard views |
| Exam Integrity Score | % of exams without integrity violations | > 95% | Integrity event tracking |
| Outcome Coverage | % of subjects with defined learning outcomes | > 60% | Outcome count per subject |
| Timetable Adherence | % of classes following published timetable | > 90% | Schedule vs. actual comparison |

## Metric Review Cadence

| Frequency | Metrics Reviewed | Audience |
|-----------|-----------------|----------|
| Daily | DAU, critical errors, support tickets | Engineering |
| Weekly | WAU, feature adoption, teacher DAU, student DAU | Product + Engineering |
| Monthly | MAU, MRR, churn, activation, NPS | Leadership + Product + Engineering |
| Quarterly | Retention cohorts, LTV, CAC, NPS, strategic review | Leadership + Investors |
| Per Release | Release-specific KPIs (see each version section) | Product + Engineering |

---

# PART XV — EXECUTION PRIORITY 🆕

> **🔴 ROADMAP IS LOCKED.** No new features. The only acceptable additions are requirements from paying schools, security/compliance, or scaling needs. Everything else goes to `FUTURE_IDEAS.md`.
>
> **The biggest risk now is Planning > Shipping.**

## Next 5 Deliverables (Execute Now)

These five features, when shipped, transform Klasivo from an exam platform into a complete school platform:

| # | Feature | Version | Sprint | Why It Matters |
|---|---------|---------|--------|---------------|
| 1 | Teacher Approval Workflow | v2.2 | S3 | Trust feature — schools ask for this first |
| 2 | Video Library (YouTube) | v2.1 | Independent | Zero cost, high perceived value |
| 3 | Assignment Submission API | v2.3 | S3 | Highest-frequency daily workflow |
| 4 | Attendance Tracking (Enhanced) | v2.4 | S3B | Core academic daily operation |
| 5 | Gradebook + Report Cards | v2.5 | S4 | **Switching threshold** — schools cannot leave existing systems without this |

## The Rule

For every new roadmap idea, ask:

> **"Would a school pay me sooner because of this?"**

If the answer is **no**, it goes to `FUTURE_IDEAS.md`, not this roadmap.

## After the Next 5

| # | Feature | Version | Why It Matters |
|---|---------|---------|---------------|
| 6 | Timetable Builder | v2.5A | Every school runs on schedules |
| 7 | Parent Portal | v2.3A | Parents drive retention |
| 8 | Student Information System | v2.6 | Deep integration, high retention |
| 9 | Communication Hub | v2.7 | Replace WhatsApp |
| 10 | School Accounts | v2.8 | Multi-tenancy foundation |

## Future Ideas (NOT in Roadmap)

These are recorded for future consideration but are **not** part of the locked roadmap:

- Digital Academic Identity (permanent student record across schools)
- School Knowledge Graph (relationship-aware analytics)
- Competency-Based Education (full CBE tracking)
- Teacher Performance & Development (quality tracking, PD modules)
- School Accreditation Toolkit (evidence collection, audit reports)
- Finance & School Operations (tuition, invoices, scholarships)
- Alumni Network (directory, mentorship, donations)
- Student Career Pathway System (skills → career recommendations)
- School Benchmarking (anonymized cross-school comparison)
- Ecosystem Developer Platform (APIs, SDKs, third-party tools)
- Mobile Growth Layer (referrals, deep links, share achievements)
- Integration Hub (Google Workspace, Microsoft 365, Zoom, Moodle imports)

These will be re-evaluated when Klasivo reaches 50+ schools and the core platform is proven.
