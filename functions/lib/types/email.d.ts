export type EmailCategory = 'welcome' | 'teacher_invitation' | 'school_announcement' | 'contact';
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
export declare const SENDER: {
    readonly noreply: "Klasivo <noreply@klasivo.app>";
    readonly support: "Klasivo Support <support@klasivo.app>";
};
