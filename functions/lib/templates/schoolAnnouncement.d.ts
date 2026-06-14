/**
 * Klasivo — School Announcement Template
 *
 * Sent when a school owner or admin broadcasts an announcement
 * to one or more recipients (teachers, parents, students).
 *
 * Supports three priority levels: urgent, important, normal.
 */
import type { AnnouncementPriority } from '../utils/validators';
export interface AnnouncementPayload {
    schoolName: string;
    title: string;
    message: string;
    senderName: string;
    senderRole: string;
    priority: AnnouncementPriority;
}
/**
 * Build the HTML for a school announcement email.
 *
 * @returns Complete HTML string ready for Resend
 */
export declare function buildAnnouncement(payload: AnnouncementPayload): string;
//# sourceMappingURL=schoolAnnouncement.d.ts.map