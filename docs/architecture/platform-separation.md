# Klasivo Platform Separation Architecture

**Status**: Approved — v1.x Implementation Roadmap  
**Date**: 2026-06-13  
**Sprint Target**: Sprint 6+ (after RBAC foundation + adoption features + academic records are complete)

> **Note (2026-06-15):** Roadmap re-prioritized. Dashboard and platform separation work is now scheduled after adoption-driving features AND the Academic Records & Gradebook phase (v2.5). Schools need gradebook/report cards before they need a web dashboard. See `DEVELOPMENT_ROADMAP.md` for current priority order. Sprint 4 is now Academic Records + SIS + Communication, Sprint 5 is School Accounts.

---

## Core Principle

**The interface must match the workflow.** Admin roles manage at scale (desktop-first). Operational roles work in the field (mobile-first).

---

## Decision 1: Flutter Web First

```
Flutter Mobile App
+
Flutter Web Dashboard
```

**v1.x**: Same models, same Riverpod providers, same RBAC layer, same Firestore integration, single team.

**v2.5+**: If dashboard performance becomes a bottleneck, migrate to Next.js at `dashboard.klasivo.app`.

### Rationale

The current architecture already has:

- 36 services
- 314+ methods
- 46 collections
- Complete RBAC domain layer (Sprint 1-2)

A Next.js dashboard today would duplicate: RBAC, Permissions, Scopes, Validation, Models. This is unnecessary before product-market fit.

---

## Decision 2: Admin Mobile Companion

Admin roles are **NOT blocked** from mobile. Instead:

| Platform | Admin Experience |
|----------|-----------------|
| **Dashboard** | Full access, bulk operations, analytics, configuration |
| **Mobile** | Read-focused, quick approvals, notifications, student lookup, attendance overview |

This matches real school workflows — campus managers and academic supervisors walk the school.

---

## Decision 3: RBAC Remains Platform-Agnostic

Permissions never know about Web, Mobile, or Dashboard. RBAC only knows:

- **Role**
- **Permission**
- **Scope**

Example: `role.assign` exists once. The dashboard simply provides the UI for it.

This is the correct separation of concerns.

---

## Decision 4: Observer Role

### Hierarchy Placement

```
owner
 └─ admin
      ├─ observer
      ├─ campus_manager
      └─ stage_manager
```

### Permissions

```
✓ analytics.view       ✓ attendance.view
✓ student.view         ✓ reports.view
✓ exam.view            ✓ assignment.view
✓ class.view           ✓ stage.view
✓ subject.view         ✓ group.view
✓ user.view            ✓ result.view
✓ lesson.view          ✓ material.view
✓ notification.view    ✓ integrity.view
✓ fees.view            ✓ payments.view
✓ inventory.view       ✓ org.view
✓ progress.view        ✓ question.view

✗ create               ✗ edit
✗ delete               ✗ assign roles
✗ publish              ✗ export
```

### Platform

- Dashboard (primary)
- Optional mobile companion (read-only views)

---

## Decision 5: Sprint Priority

Do NOT start `dashboard.klasivo.app` or `platform.klasivo.app` yet.

The RBAC foundation must exist first. Without Sprint 2: Dashboard = UI without security.

**Additionally (2026-06-15 re-prioritization):** Even after RBAC is complete, adoption-driving features (Teacher Approval, Assignment Submission, Parent Enhancement, Student Engagement) take priority over the dashboard. Schools need these features on mobile before they need a web dashboard. The dashboard is for efficiency at scale — not an adoption driver at the current stage.

---

## Updated Roadmap

### Sprint 2 (DONE)
RBAC Infrastructure — Claims, Scopes, Rules, Password Flow, Audit Logs

### Sprint 3
Scope Enforcement, Permission UI, Role Management

### Sprint 4
Academic Records & Gradebook + Student Information System + Communication Hub (v2.5 + v2.6 + v2.7)

### Sprint 5
School Accounts + School Landing Pages + Migration Center (v2.8 + v2.9)

### Sprint 6
Flutter Web Dashboard Skeleton at `dashboard.klasivo.app` + Mobile-First Offline (v3.0 + v3.1)

Pages:
- `/dashboard` — Overview
- `/users` — User management
- `/roles` — Role assignment
- `/scopes` — Scope assignment
- `/settings` — Organization settings

### Sprint 7
Admin Mobile Companion (read-focused subset for admin roles)

### Sprint 8
`platform.klasivo.app` — Super Admin Platform (separate from school dashboard)

Capabilities:
- Manage Organizations
- Subscriptions
- Feature Flags
- Support Tools
- Platform Analytics
- System Health
- Audit Review

Normal owners should never see these screens.

---

## Enterprise Structure

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

## Domain Setup

```
klasivo.app                → Marketing Website
dashboard.klasivo.app      → School Dashboard (Flutter Web)
platform.klasivo.app       → Klasivo Platform Admin
api.klasivo.app            → Functions / APIs
status.klasivo.app         → Status Page (later)
docs.klasivo.app           → Documentation (later)
```

**Today**: Priority = Sprint 1+2 Merge → Sprint 3 (RBAC + adoption features). Not subdomains.

---

## Permission Separation

### Dashboard-Optimized (available via API but UI only on dashboard)

```
organization.create
organization.delete
role.assign
scope.assign
billing.manage
feature_flags.manage
user.manage
audit.view
```

### Mobile + Web (available on both platforms)

```
attendance.mark
exam.grade
assignment.create
message.send
notification.view
```

The RBAC system itself is platform-agnostic. The constraint is purely at the UI/routing layer.
