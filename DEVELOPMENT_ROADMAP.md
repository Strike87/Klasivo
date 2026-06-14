# Klasivo — Development Roadmap

> **Current Version:** v2.0.0+7  
> **Platform:** Android (Flutter 3.x / Dart 3.x) → Multi-platform (Mobile + Web + Dashboard)  
> **Architecture:** Clean Architecture + Riverpod + Firebase + Monorepo  
> **Last Updated:** 2026-06-15

> **Canonical roadmap:** `klasivo-repo/DEVELOPMENT_ROADMAP.md` — this file is a summary. Full details, dependency maps, migration plans, sprint breakdowns, competitive positioning, geographic expansion, AI governance, product metrics framework, and execution priority live there.

> **🔴 ROADMAP VERSION 1.0 — LOCKED**  
> **Status:** Feature-complete. No new items accepted unless required by a paying school, security/compliance, or scaling.  
> **Execution Priority:** Ship the next 5 deliverables. Stop planning, start building.

---

## Five Pillars of Klasivo

| Pillar | Purpose | Key Releases |
|--------|---------|-------------|
| **1 — Academic Operations** | The core reason schools buy | Attendance, Assignments, Exams, Gradebook, Report Cards, Timetable, Assessment Engine |
| **2 — School Operations** | The daily operations layer | SIS, Communication Hub, Approvals, Documents, Migration Center |
| **3 — Engagement** | The retention engine | Parents, Notifications, Recordings, Progress Tracking |
| **4 — Intelligence** | The differentiation layer | Analytics, AI Teaching, Learning Outcomes, Risk Detection |
| **5 — Growth** | The business engine | Billing, Marketplace, Public School Pages, 30-Minute Launch |

---

## Strategic Phase Overview

| Phase | Name | Versions | Status |
|-------|------|----------|--------|
| **1** | Foundation | v1.0–v2.0.1 | ✅ Complete |
| **2** | School Adoption | v2.1–v2.3A | 🔲 Next |
| **3** | Core Academic | v2.4 | 🔲 Planned |
| **3.5** | Academic Records & Gradebook | v2.5 | 🔲 Planned |
| **3.6** | Academic Scheduling | v2.5A | 🔲 Planned |
| **4** | Student & Parent Engagement | v2.6–v2.7 | 🔲 Planned |
| **5** | School Management | v2.8–v2.9 | 🔲 Planned |
| **6** | Analytics & Dashboard | v3.0–v3.1 | 🔲 Planned |
| **7** | Revenue & Billing | v3.2 | 🔲 Planned |
| **8** | Assessment & AI Layer | v3.3–v3.5 | 🔲 Planned |
| **9** | Enterprise Analytics | v4.0 | 🔲 Planned |
| **10** | Enterprise Readiness | v4.5 | 🔲 Planned |
| **11** | Marketplace & Ecosystem | v5.0 | 🔲 Planned |
| **12** | Scale & Global | v5.5+ | 🔲 Planned |

---

## Version History

| Version | Focus | Phase | Status |
|---------|-------|-------|--------|
| **v1.0–v2.0.1** | Core exam platform, auth, grading, LMS, enterprise foundations | P1 | ✅ Complete |
| **v2.1** | Video Library & Recorded Lessons (YouTube) | P2 | 🔲 Planned |
| **v2.2** | Teacher Approval Workflow & Role-Based Routing | P2 | 🔲 Planned |
| **v2.2A** | Student Engagement & Reminders | P2 | 🔲 Planned |
| **v2.3** | Assignment Submission API | P2 | 🔲 Planned |
| **v2.3A** | Parent Accounts Enhanced | P2 | 🔲 Planned |
| **v2.4** | Enhanced Attendance & Communication Foundations | P3 | 🔲 Planned |
| **v2.5** | Academic Records & Gradebook | P3.5 | 🔲 Planned |
| **v2.5A** | Timetable Builder & Academic Scheduling (NEW) | P3.6 | 🔲 Planned |
| **v2.6** | Student Information System (SIS) | P4 | 🔲 Planned |
| **v2.7** | Communication Hub | P4 | 🔲 Planned |
| **v2.8** | School Accounts / Multi-Tenancy (simplified) | P5 | 🔲 Planned |
| **v2.9** | School Landing Pages, Migration Center & 30-Minute Launch | P5 | 🔲 Planned |
| **v3.0** | Web Dashboard & School Analytics | P6 | 🔲 Planned |
| **v3.1** | Mobile-First Offline Strategy | P6 | 🔲 Planned |
| **v3.2** | Subscription & Billing | P7 | 🔲 Planned |
| **v3.3** | Assessment Engine (NEW) | P8 | 🔲 Planned |
| **v3.4** | Learning Outcomes Framework (NEW) | P8 | 🔲 Planned |
| **v3.5** | AI Layer — Governance + Question Generator + Grading Assistant | P8 | 🔲 Planned |
| **v4.0** | Full Dashboard Platform + Enterprise Analytics | P9 | 🔲 Planned |
| **v4.5** | Enterprise Readiness — Compliance, SSO, Disaster Recovery | P10 | 🔲 Planned |
| **v5.0** | Marketplace & Ecosystem | P11 | 🔲 Planned |
| **v5.5+** | Scale & Global Expansion | P12 | 🔲 Planned |

---

## Next 5 Deliverables (Execute Now)

| # | Feature | Version | Why It Matters |
|---|---------|---------|---------------|
| 1 | Teacher Approval Workflow | v2.2 | Trust feature — schools ask for this first |
| 2 | Video Library (YouTube) | v2.1 | Zero cost, high perceived value |
| 3 | Assignment Submission API | v2.3 | Highest-frequency daily workflow |
| 4 | Attendance Tracking (Enhanced) | v2.4 | Core academic daily operation |
| 5 | **Gradebook + Report Cards** | v2.5 | **Switching threshold** — schools cannot leave without this |

---

## Key Feature Summaries

### v2.5 — Academic Records & Gradebook
Gradebook, Report Cards, Academic Terms, Transcripts, GPA, Teacher Comments, Parent Report Access

### v2.5A — Timetable Builder (NEW)
Period definition, drag-and-drop schedule builder, constraints engine, room management, auto-generation

### v2.6 — Student Information System
Student profiles, academic/attendance history, medical notes, emergency contacts, documents, timeline

### v2.7 — Communication Hub
Broadcast announcements (push+email+SMS+in-app), school alerts, teacher-parent messaging, campaigns

### v2.9 — 30-Minute School Launch (NEW)
Guided setup wizard, pre-configured templates, quick-start role assignment, bulk import during onboarding

### v3.3 — Assessment Engine (NEW)
9 question types (MCQ, essay, matching, fill-in-blanks, numeric, drag-drop, code), randomization, question pools, exam blueprints, item analysis

### v3.4 — Learning Outcomes Framework (NEW)
Outcome hierarchy, outcome-content linking, mastery tracking, curriculum maps, outcome reports

### v3.5 — AI Layer
AI Governance (quotas, cost controls, moderation, transparency), AI Question Generator, AI Grading Assistant

---

## Product Metrics Framework

| Category | Key Metrics |
|----------|-------------|
| **Acquisition** | Schools signed up, activation rate (< 30 min), conversion rate (> 15%) |
| **Engagement** | DAU > 60%, Teacher DAU > 70%, Parent WAU > 40% |
| **Retention** | 30-day > 70%, 90-day > 50%, school churn < 5% |
| **Revenue** | MRR, ARPU, LTV, free→paid > 15% |
| **Education** | Assignment completion > 85%, Attendance > 90%, Report card gen > 70% |

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
│                        Business Logic                             │
│  Services (56+)  ·  Event Bus  ·  Feature Flags (39+)            │
│  RBAC  ·  GPA Calculator  ·  Assessment Engine  ·  AI Governance │
│  Timetable Scheduler  ·  Outcome Tracker  ·  Sync Queue          │
├──────────────────────────────────────────────────────────────────┤
│                        Data Layer                                 │
│  Firebase Auth  ·  Firestore (60+ collections)  ·  FCM  ·  Hive  │
│  Functions (32+)  ·  LiveKit  ·  Storage  ·  Stripe              │
│  BigQuery (v4.0+)  ·  Twilio SMS  ·  OpenAI/Gemini (v3.5+)      │
│  Local SQLite (v3.1+ offline)                                     │
└──────────────────────────────────────────────────────────────────┘
```

## The Rule

For every new roadmap idea, ask:

> **"Would a school pay me sooner because of this?"**

If **no**, it goes to `FUTURE_IDEAS.md`, not this roadmap.

## Future Ideas (NOT in Roadmap)

Digital Academic Identity · School Knowledge Graph · Competency-Based Education · Teacher Performance & Development · School Accreditation Toolkit · Finance & School Operations · Alumni Network · Student Career Pathway System · School Benchmarking · Ecosystem Developer Platform · Mobile Growth Layer · Integration Hub

These will be re-evaluated when Klasivo reaches 50+ schools.
