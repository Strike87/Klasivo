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
//   node ../scripts/migrate-remove-password-hash.js
// ============================================================================

const admin = require('firebase-admin');
const serviceAccount = require('./service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: serviceAccount.project_id,
});

const db = admin.firestore();

async function migrate() {
  console.log('Fetching all user docs with passwordHash field...');
  const snapshot = await db.collection('users')
    .where('passwordHash', '!=', null)
    .get();

  console.log(`Found ${snapshot.size} docs to migrate.`);
  if (snapshot.size === 0) {
    console.log('No docs need migration.');
    return;
  }

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
