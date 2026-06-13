# Klasivo Secrets Inventory

> **This file tracks every secret used by Klasivo.**
> Store a copy in your password manager (1Password / Bitwarden) as a Secure Note.

**Last Updated:** 2026-06-13
**Maintained By:** Strike87

---

## Production Secrets

| # | Service | Secret Name | Where Stored | Who Has Access | Recovery Method | Rotation Policy |
|---|---------|-------------|--------------|----------------|-----------------|-----------------|
| 1 | Firebase | `FIREBASE_ADMIN_PRIVATE_KEY` | Firebase Secret Manager (auto-provisioned in Cloud Functions) | Cloud Functions runtime | Firebase Console → Project Settings → Service Accounts | On compromise |
| 2 | Firebase | `FIREBASE_ADMIN_CLIENT_EMAIL` | Firebase Secret Manager (auto-provisioned in Cloud Functions) | Cloud Functions runtime | Firebase Console → Project Settings → Service Accounts | On compromise |
| 3 | Firebase | `FIREBASE_API_KEY` | `firebase_options.dart` (committed) | All developers | Firebase Console → Project Settings → General → Web App | On compromise |
| 4 | Firebase | `FIREBASE_PROJECT_ID` | `.firebaserc`, `firebase_options.dart` (committed) | All developers | Firebase Console | N/A (not secret) |
| 5 | LiveKit | `LIVEKIT_URL` | `functions/.env.example` (reference), Firebase Secret Manager | Cloud Functions runtime | LiveKit Dashboard → Settings | N/A (not secret) |
| 6 | LiveKit | `LIVEKIT_API_KEY` | Firebase Secret Manager | Cloud Functions runtime | LiveKit Dashboard → Settings | On compromise |
| 7 | LiveKit | `LIVEKIT_API_SECRET` | Firebase Secret Manager | Cloud Functions runtime | LiveKit Dashboard → Settings | On compromise |
| 8 | LiveKit | `LIVEKIT_HOST` | Firebase Secret Manager | Cloud Functions runtime | LiveKit Dashboard → Settings | On compromise |
| 9 | Resend | `RESEND_API_KEY` | Firebase Secret Manager | Cloud Functions runtime | Resend Dashboard → API Keys | On compromise |
| 10 | Turnstile | `TURNSTILE_SITE_KEY` | Flutter client code (public) | All developers | Cloudflare Dashboard → Turnstile | N/A (public) |
| 11 | Turnstile | `TURNSTILE_SECRET_KEY` | Firebase Secret Manager | Cloud Functions runtime | Cloudflare Dashboard → Turnstile | On compromise |

---

## CI/CD Secrets (GitHub Actions)

| # | Secret Name | Purpose | Where Stored | Recovery Method |
|---|-------------|---------|--------------|-----------------|
| 1 | `FIREBASE_TOKEN` | Deploy Cloud Functions / Firestore rules | GitHub → Repo Settings → Secrets | `firebase login:ci` |
| 2 | `FIREBASE_PROJECT_ID` | Target project for deploys | GitHub → Repo Settings → Secrets | Firebase Console |

---

## Future Secrets (Not Yet Implemented)

| # | Service | Secret Name | Purpose | Storage (When Added) | Recovery Method |
|---|---------|-------------|---------|---------------------|-----------------|
| 1 | Sentry | `SENTRY_DSN` | Error reporting endpoint | Flutter client code (public) | Sentry → Project Settings → Client Keys |
| 2 | Sentry | `SENTRY_AUTH_TOKEN` | Source map uploads + release management | GitHub Secrets | Sentry → Account Settings → Auth Tokens |
| 3 | Stripe | `STRIPE_SECRET_KEY` | Payment processing | Firebase Secret Manager | Stripe Dashboard → Developers → API Keys |
| 4 | Stripe | `STRIPE_WEBHOOK_SECRET` | Webhook signature verification | Firebase Secret Manager | Stripe Dashboard → Developers → Webhooks |
| 5 | Stripe | `STRIPE_PUBLISHABLE_KEY` | Client-side payment UI | Flutter client code (public) | Stripe Dashboard → Developers → API Keys |

---

## Client-Side Config (Public, Not Secrets)

These are embedded in the Flutter app or website. They are restricted by platform rules (SHA-1, package name), not by secrecy.

| # | Key | Value | File | Notes |
|---|-----|-------|------|-------|
| 1 | Firebase API Key | `AIzaSyDfdIVXkqtfzA93CtJTrFsYEoSIc8CYTaw` | `firebase_options.dart` | Restricted by package name + SHA-1 |
| 2 | Firebase Project ID | `klasivo-prod` | `.firebaserc` | Not secret |
| 3 | Firebase Storage Bucket | `klasivo-prod.firebasestorage.app` | `firebase_options.dart` | Not secret |
| 4 | Firebase App ID | `1:952580193002:android:f21194c3de1b0064ac3593` | `firebase_options.dart` | Not secret |
| 5 | Firebase Messaging Sender ID | `952580193002` | `firebase_options.dart` | Not secret |
| 6 | GA Measurement ID | *(not yet configured)* | `web/index.html` (future) | Public |
| 7 | Turnstile Site Key | `1x00000000000000000000AA` | Flutter login screen | Public (Cloudflare test key) |

---

## Secret Storage Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    WHERE SECRETS LIVE                    │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Firebase Secret Manager (Cloud Functions)              │
│  ├── RESEND_API_KEY                                    │
│  ├── TURNSTILE_SECRET_KEY                              │
│  ├── LIVEKIT_API_KEY                                   │
│  ├── LIVEKIT_API_SECRET                                │
│  └── LIVEKIT_HOST                                      │
│                                                         │
│  Firebase Auto-Provisioned (Admin SDK)                  │
│  ├── FIREBASE_ADMIN_PRIVATE_KEY                        │
│  └── FIREBASE_ADMIN_CLIENT_EMAIL                       │
│                                                         │
│  GitHub Actions Secrets (CI/CD)                         │
│  ├── FIREBASE_TOKEN                                    │
│  └── FIREBASE_PROJECT_ID                               │
│                                                         │
│  Client Code (Public, restricted by platform rules)     │
│  ├── FIREBASE_API_KEY                                  │
│  ├── FIREBASE_PROJECT_ID                               │
│  ├── FIREBASE_STORAGE_BUCKET                           │
│  ├── TURNSTILE_SITE_KEY                                │
│  └── SENTRY_DSN (future)                               │
│                                                         │
│  Local Development (.env.local — NEVER committed)       │
│  └── (same as Firebase Secret Manager keys)            │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## How to Set / Rotate a Firebase Secret

### Set a new secret
```bash
firebase functions:secrets:set SECRET_NAME
# Paste the value when prompted
# Deploy functions to apply
firebase deploy --only functions
```

### Rotate an existing secret
```bash
# 1. Set the new version
firebase functions:secrets:set SECRET_NAME
# Paste the new value

# 2. Deploy to apply
firebase deploy --only functions

# 3. Destroy old version (after confirming new one works)
firebase functions:secrets:destroy SECRET_NAME --version VERSION_NUMBER
```

### List all secrets
```bash
firebase functions:secrets:list
```

---

## Emergency Response — If a Secret Is Compromised

1. **Identify the secret** — Which service? Which key?
2. **Rotate immediately** — Generate a new key from the service's dashboard
3. **Update storage** — Set the new value in Firebase Secret Manager or GitHub Secrets
4. **Deploy** — `firebase deploy --only functions` to pick up the new secret
5. **Destroy old version** — Remove the compromised version from Secret Manager
6. **Document** — Update this file with the rotation date
7. **Audit** — Check logs for unauthorized access between exposure and rotation

---

## Rotation Log

| Date | Secret | Action | Reason | Performed By |
|------|--------|--------|--------|--------------|
| 2026-06-13 | `.env` | Removed from git tracking | Was committed before .gitignore | Automated |
| 2026-06-13 | `google-services.json` | Removed from git tracking | Contains OAuth client IDs | Automated |
| 2026-06-13 | Turnstile `verifyTurnstile()` | Fixed fail-open → fail-closed | Was silently bypassing in production | Automated |
| | | | | |

---

## Checklist — New Secret Onboarding

When adding a new third-party service to Klasivo:

- [ ] Identify if the key is **public** (client-side) or **private** (server-only)
- [ ] Public keys → embed in Flutter code, document in "Client-Side Config" above
- [ ] Private keys → `firebase functions:secrets:set KEY_NAME`
- [ ] Declare the secret in `runWith({ secrets: [...] })` in the Cloud Function
- [ ] Access via `process.env.KEY_NAME` — never log, print, or persist it
- [ ] Add to this inventory under the correct section
- [ ] Add recovery method (dashboard URL where key can be regenerated)
- [ ] Add to `.env.example` as a reference (placeholder value only)
