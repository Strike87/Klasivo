# Klasivo — Students Screen Permission-Denied: Root Cause Analysis

## The External Review is WRONG About the Collection

The external review claims:
> "Your app creates students in the **students collection**. But the All Students screen is trying to find students in: `users`"

**This is factually incorrect.** Klasivo does NOT have a separate `students` collection. Students ARE users — it's explicitly defined:

```dart
// lib/core/config/app_constants.dart:13
static const String studentsCollection = 'users'; // Students ARE users (same collection, role='student')
```

The `createStudent` Cloud Function writes to `db.collection('users')` (line 510). The `student_service.dart` queries `usersCollection`. The `all_students_screen.dart` queries `'users'`. **This is correct and by design.**

**If you changed `collectionPath: 'users'` to `collectionPath: 'students'` as the review suggests, it would break** — there IS no `students` collection in Firestore. The query would return zero results (or permission-denied because no rule exists for `match /students/`).

## The External Review is RIGHT About the Real Issue

The real problem ISN'T the collection name — it's whether `orgId` is populated when the query runs.

### The actual code in `all_students_screen.dart`:

```dart
// Line 21:
final orgId = ref.watch(currentOrganizationIdProvider);

// Lines 63-66:
filters: [
  if (orgId != null)
    QueryFilter.equalTo('organizationId', orgId),  // ← only added if orgId is NOT null
  QueryFilter.equalTo('role', 'student'),
  QueryFilter.equalTo('isActive', true),
],
```

### The Firestore rule for `users`:

```
allow read: if isAuth() && (request.auth.uid == userId || isInSameOrg());
```

### Why it fails:

For a LIST query (not a single-doc `.get()`), Firestore cannot verify `request.auth.uid == userId` — it can't prove every doc in the result set has `__name__ == auth.uid`. So that branch is unsatisfiable for list queries.

The ONLY way the list query passes is via `isInSameOrg()`, which requires the query to have `.where('organizationId', isEqualTo: orgId)`.

**If `orgId` is `null`**, the `if (orgId != null)` condition is false, the organizationId filter is skipped, and the query becomes:
```
users.where('role', '==', 'student').where('isActive', '==', true)
```

No orgId filter → `isInSameOrg()` unverifiable → **permission-denied**.

### When is `orgId` null?

Despite the Day 1 fix (which syncs `currentOrganizationIdProvider` on login), `orgId` can still be null if:

1. **App cold start before login completes** — provider initializes from Hive, but Hive hasn't been written yet
2. **After logout** — `clearAuthData()` sets both providers to `null` (line 351-352), but if the screen rebuilds before navigation away, it sees null
3. **Background isolate / FCM handler** — Hive updated but Riverpod state not (no `ref` available)

## The Fix (2 changes)

### Fix 1: Make the orgId filter MANDATORY (not conditional)

In `all_students_screen.dart`, change:

```dart
// BEFORE (broken — skips filter if orgId is null):
filters: [
  if (orgId != null)
    QueryFilter.equalTo('organizationId', orgId),
  QueryFilter.equalTo('role', 'student'),
  QueryFilter.equalTo('isActive', true),
],
```

To:

```dart
// AFTER (fixed — fails fast if orgId is missing):
filters: [
  QueryFilter.equalTo('organizationId', orgId ?? ''),  // Empty string → no match → empty list (not permission-denied)
  QueryFilter.equalTo('role', 'student'),
  QueryFilter.equalTo('isActive', true),
],
```

Or better — show an error if orgId is null:

```dart
// BEST — show error state if orgId is missing:
if (orgId == null || orgId.isEmpty) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.red),
        const SizedBox(height: 16),
        const Text('Organization context missing'),
        const SizedBox(height: 8),
        const Text('Please log out and log back in.'),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => context.go('/auth'),
          child: const Text('Go to Login'),
        ),
      ],
    ),
  );
}
// Only build the list if orgId is valid
return KlasivoPaginatedList<StudentData>(
  loader: (cursor) => paginationService.fetchPage(
    collectionPath: 'users',
    fromFirestore: StudentData.fromFirestore,
    cursor: cursor,
    pageSize: 20,
    orderBy: 'createdAt',
    descending: true,
    filters: [
      QueryFilter.equalTo('organizationId', orgId),  // ← always present
      QueryFilter.equalTo('role', 'student'),
      QueryFilter.equalTo('isActive', true),
    ],
  ),
  ...
);
```

### Fix 2: Consolidate to ONE organization provider

The external review correctly identified the dangerous pattern:

```dart
// all_students_screen.dart uses:
final orgId = ref.watch(currentOrganizationIdProvider);

// exam_form_screen.dart uses:
final organizationId = ref.read(organizationIdProvider);
```

Even though Day 1 syncs them on login, having two providers is a footgun. **Pick one and delete the other.**

**Recommended:** Keep `currentOrganizationIdProvider` (it's used by 65+ providers). Make `organizationIdProvider` an alias:

```dart
// lib/providers/auth_provider.dart
// Replace the separate declaration with an alias:
final organizationIdProvider = currentOrganizationIdProvider;
```

Or delete `organizationIdProvider` entirely and update the ~5 files that use it to use `currentOrganizationIdProvider` instead.

## What NOT to Do

**DO NOT change `collectionPath: 'users'` to `collectionPath: 'students'`.**

There is no `students` collection. The external reviewer assumed one exists based on the collection list in the audit prompt, but the actual architecture stores students in `users` with `role: 'student'`. Changing the collection path would break the screen completely.

## Summary

| What the external review said | Correct? | Why |
|---|---|---|
| "Students are in the `students` collection" | ❌ WRONG | Students are in `users` with `role: 'student'` — explicitly defined |
| "Change `collectionPath: 'users'` to `'students'`" | ❌ WRONG | Would break — no `students` collection exists |
| "The screen is getting permission-denied" | ✅ CORRECT | But the cause is missing orgId filter, not wrong collection |
| "Two organization providers is dangerous" | ✅ CORRECT | Should consolidate to one |
| "Fix the students screen first" | ✅ CORRECT | But fix it by ensuring orgId is always present, not by changing collection |

## The Actual Fix

1. **`all_students_screen.dart`**: Make orgId filter mandatory (not conditional on `if (orgId != null)`)
2. **Consolidate providers**: Make `organizationIdProvider` an alias for `currentOrganizationIdProvider`
3. **DO NOT change the collection path** — `users` is correct
