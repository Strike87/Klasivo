import * as admin from 'firebase-admin';

import type { QueueEmailParams, QueueResult } from '../types/queue';

const db = admin.firestore();

export async function queueEmail(params: QueueEmailParams): Promise<QueueResult> {
  const { type, category, to, payload, idempotencyKey } = params;

  // Check for duplicate via idempotency key
  const existing = await db
    .collection('emailQueue')
    .where('idempotencyKey', '==', idempotencyKey)
    .limit(1)
    .get();

  if (!existing.empty) {
    const existingDoc = existing.docs[0];
    return {
      queued: false,
      queueId: existingDoc?.id ?? '',
      reason: 'duplicate',
    };
  }

  const docRef = await db.collection('emailQueue').add({
    type,
    category,
    to,
    payload,
    status: 'pending',
    attempts: 0,
    maxAttempts: 5,
    idempotencyKey,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { queued: true, queueId: docRef.id };
}
