export type EmailCategory =
  | 'welcome'
  | 'teacher_invitation'
  | 'school_announcement'
  | 'contact';

export interface SendEmailParams {
  to: string | string[];
  subject: string;
  html: string;
  category: EmailCategory;
  queueId?: string;
  from?: string;
  replyTo?: string;
}

export interface EmailResult {
  success: boolean;
  id?: string;
  error?: string;
}

export const SENDER = {
  noreply: 'Klasivo <noreply@klasivo.app>',
  support: 'Klasivo Support <support@klasivo.app>',
} as const;
