export type QueueStatus =
  | 'pending'
  | 'processing'
  | 'sent'
  | 'retrying'
  | 'failed'
  | 'cancelled';

export interface EmailQueueDocument {
  type: string;
  category: string;
  to: string | string[];
  payload: Record<string, unknown>;
  status: QueueStatus;
  attempts: number;
  maxAttempts: number;
  idempotencyKey: string;
  lastError?: string;
  resendId?: string;
  createdAt: unknown;
  scheduledAt?: unknown;
  processedAt?: unknown;
  sentAt?: unknown;
}

export interface QueueEmailParams {
  type: string;
  category: string;
  to: string | string[];
  payload: Record<string, unknown>;
  idempotencyKey: string;
}

export interface QueueResult {
  queued: boolean;
  queueId: string;
  reason?: string;
}
