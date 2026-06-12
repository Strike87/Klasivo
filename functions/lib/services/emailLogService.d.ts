interface EmailLogEntry {
    resendId: string;
    type: string;
    to: string | string[];
    from: string;
    subject: string;
    replyTo?: string;
    queueId?: string;
}
export declare function logEmail(entry: EmailLogEntry): Promise<void>;
export {};
