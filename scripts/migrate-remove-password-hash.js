// ============================================================================
// Klasivo — Remove passwordHash field from user docs (FUTURE MIGRATION)
// ============================================================================
// RUN THIS ONLY AFTER:
//   1. All client-side hashPassword() copies are removed (5 Dart files).
//   2. All callers updated to send plaintext to server callables.
//   3. Server-side verifyPassword() has backward-compat for legacy
//      scrypt(SHA-256(plaintext)) hashes (or all users have reset passwords).
//   4. Firestore backup taken (this is IRREVERSIBLE).
//
// What this does:
//   - Iterates all docs in 'users' collection that have a 'passwordHash' field.
//   - Deletes the field (FieldValue.delete()).
//   - Batches in groups of 400.
//
// Usage:
//   cd functions
//   npm install firebase-admin
//   # Place service-account.json in functions/ (download from Firebase Console)
//   # Then EITHER:
//   #   $env:NODE_PATH = "$PWD\node_modules"   (PowerShell)
//   #   export NODE_PATH="$PWD/node_modules"   (bash)
//   #   node ../scripts/migrate-remove-password-hash.js
//   # OR just run from functions/ — the script auto-discovers both
//   # functions/node_modules and functions/service-account.json.
// ============================================================================

const path = require('path');
const fs = require('fs');

// Resolve service-account.json relative to the functions/ directory
// (regardless of where node is invoked from).
const functionsDir = path.resolve(__dirname, '..', 'functions');
const saPath = path.join(functionsDir, 'service-account.json');

// serviceAccount is loaded lazily below (after the ADC-vs-file decision).
let serviceAccount = null;
if (fs.existsSync(saPath)) {
  try {
    serviceAccount = JSON.parse(fs.readFileSync(saPath, 'utf-8'));
  } catch (e) {
    console.error(`WARNING: service-account.json is not valid JSON: ${e.message}`);
    console.error('Will fall back to Application Default Credentials (ADC).');
    console.error('Run: gcloud auth application-default login');
  }
}

// Load firebase-admin from functions/node_modules if NODE_PATH wasn't set.
let admin;
try {
  admin = require('firebase-admin');
} catch (e) {
  const adminPath = path.join(functionsDir, 'node_modules', 'firebase-admin');
  if (fs.existsSync(adminPath)) {
    admin = require(adminPath);
  } else {
    console.error('ERROR: firebase-admin not found.');
    console.error('Either:');
    console.error('  1. cd functions && npm install firebase-admin');
    console.error('  2. $env:NODE_PATH = "$PWD\\node_modules"   (PowerShell)');
    console.error('     export NODE_PATH="$PWD/node_modules"   (bash)');
    process.exit(1);
  }
}

// ─── Authentication strategy ───────────────────────────────────────────────
// Try (in order):
//   1. Application Default Credentials (ADC) — most reliable on dev machines.
//      Set up once via:  gcloud auth application-default login
//   2. service-account.json in functions/ — fallback for CI / ephemeral runners.
//
// ADC is preferred because PowerShell sometimes mangles the private_key field
// in downloaded JSON files (escaped newlines get double-escaped), causing
// `UNAUTHENTICATED` errors even though the file parses as valid JSON.
// ───────────────────────────────────────────────────────────────────────────

let adminApp;
let projectIdForLog = '(unset)';

// Prefer ADC if GOOGLE_APPLICATION_CREDENTIALS is set, OR if the JSON file
// is missing/corrupted (serviceAccount will be null in that case).
const useAdc = !!process.env.GOOGLE_APPLICATION_CREDENTIALS || !serviceAccount;

if (useAdc) {
  // Use ADC — admin.initializeApp() auto-discovers the credentials.
  // Requires `gcloud auth application-default login` to have been run.
  console.log('Auth: Application Default Credentials (ADC)');
  if (!process.env.GOOGLE_APPLICATION_CREDENTIALS && !fs.existsSync(path.join(process.env.USERPROFILE || process.env.HOME || '', '.config', 'gcloud', 'application_default_credentials.json'))) {
    console.error('ERROR: ADC not found. Run this once to set it up:');
    console.error('  gcloud auth application-default login');
    process.exit(1);
  }
  adminApp = admin.initializeApp({
    projectId: serviceAccount?.project_id,
  });
  projectIdForLog = serviceAccount?.project_id || '(from ADC)';
} else {
  // Verify the service-account.json looks intact before trusting it.
  projectIdForLog = serviceAccount.project_id || '(unknown)';

  // Common PowerShell-corruption check: private_key should contain real
  // newlines, not literal "\n" sequences or escaped "\\n".
  if (serviceAccount.private_key) {
    const pemHeader = '-----BEGIN ' + 'PRIVATE KEY-----';
    const looksMangled = !serviceAccount.private_key.includes(pemHeader)
      || serviceAccount.private_key.includes('\\n');
    if (looksMangled) {
      console.error('ERROR: service-account.json private_key looks corrupted.');
      console.error('Common cause: PowerShell escaped the newlines when saving.');
      console.error('');
      console.error('Fix: switch to ADC instead — run:');
      console.error('  gcloud auth application-default login');
      console.error('then re-run this script. ADC reads from your gcloud user');
      console.error('profile and avoids the JSON-corruption problem entirely.');
      process.exit(1);
    }
  }

  console.log(`Auth: service-account.json (project: ${serviceAccount.project_id})`);
  adminApp = admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: serviceAccount.project_id,
  });
}

const db = adminApp.firestore();

// Dry-run mode: `node migrate-remove-password-hash.js --dry-run`
// Lists what would be deleted without actually deleting.
const DRY_RUN = process.argv.includes('--dry-run');

async function migrate() {
  console.log(`Mode: ${DRY_RUN ? 'DRY RUN (no writes)' : 'LIVE (will delete field)'}`);
  console.log(`Project: ${projectIdForLog}`);
  console.log('Fetching all user docs with passwordHash field...');

  const snapshot = await db.collection('users')
    .where('passwordHash', '!=', null)
    .get();

  console.log(`Found ${snapshot.size} docs to migrate.`);
  if (snapshot.size === 0) {
    console.log('No docs need migration.');
    return;
  }

  if (DRY_RUN) {
    console.log('\nDocs that would be updated (first 20 shown):');
    const preview = snapshot.docs.slice(0, 20);
    for (const doc of preview) {
      const data = doc.data();
      const hashPreview = typeof data.passwordHash === 'string'
        ? `${data.passwordHash.slice(0, 12)}... (${data.passwordHash.length} chars)`
        : JSON.stringify(data.passwordHash).slice(0, 30);
      console.log(`  ${doc.id}  role=${data.role ?? 'unknown'}  org=${data.organizationId ?? 'none'}  hash=${hashPreview}`);
    }
    if (snapshot.size > 20) {
      console.log(`  ... and ${snapshot.size - 20} more.`);
    }
    console.log(`\nDry run complete. Re-run without --dry-run to actually delete the field.`);
    return;
  }

  // LIVE mode — confirm before destroying data.
  console.log('\nWARNING: This will DELETE the passwordHash field from');
  console.log(`${snapshot.size} user documents. This is IRREVERSIBLE.`);
  console.log('Make sure you have a Firestore backup.');
  console.log('\nProceeding in 5 seconds... (Ctrl+C to abort)');
  await new Promise((resolve) => setTimeout(resolve, 5000));

  let batch = db.batch();
  let count = 0;
  let total = 0;

  for (const doc of snapshot.docs) {
    batch.update(doc.ref, {
      passwordHash: admin.firestore.FieldValue.delete(),
    });
    count++;
    total++;

    if (count % 400 === 0) {
      await batch.commit();
      console.log(`Migrated ${total}/${snapshot.size}...`);
      batch = db.batch();
    }
  }

  if (count % 400 !== 0) {
    await batch.commit();
  }

  console.log(`\nMigration complete. ${total} docs updated.`);
  console.log('\nNOTE: Users who relied on passwordHash for authentication');
  console.log('must now use Firebase Auth password reset flow.');
}

migrate()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Migration failed:', err);
    process.exit(1);
  });
