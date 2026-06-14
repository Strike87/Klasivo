import * as admin from 'firebase-admin';

const db = admin.firestore();

interface EmailLogEntry {
  resendId: string;
  type: string;
  to: string | string[];
  from: string;
  subject: string;
  replyTo?: string;
  queueId?: string;
}

export async function logEmail(entry: EmailLogEntry): Promise<void> {
  try {
    await db.collection('emailLogs').add({
      ...entry,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error(`Failed to write email log: ${msg}`);
  }
}
