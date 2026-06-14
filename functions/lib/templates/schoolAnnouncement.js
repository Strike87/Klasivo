"use strict";
/**
 * Klasivo — School Announcement Template
 *
 * Sent when a school owner or admin broadcasts an announcement
 * to one or more recipients (teachers, parents, students).
 *
 * Supports three priority levels: urgent, important, normal.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.buildAnnouncement = buildAnnouncement;
const emailLayout_1 = require("./emailLayout");
// ─── Priority styling ─────────────────────────────────────────
const PRIORITY_CONFIG = {
    urgent: {
        bg: '#fef2f2',
        border: '#fecaca',
        badge: '#dc2626',
        label: 'URGENT',
    },
    important: {
        bg: '#fffbeb',
        border: '#fde68a',
        badge: '#d97706',
        label: 'IMPORTANT',
    },
    normal: {
        bg: '#eff6ff',
        border: '#bfdbfe',
        badge: '#2563eb',
        label: 'ANNOUNCEMENT',
    },
};
/**
 * Build the HTML for a school announcement email.
 *
 * @returns Complete HTML string ready for Resend
 */
function buildAnnouncement(payload) {
    const { schoolName, title, message, senderName, senderRole, priority } = payload;
    const p = PRIORITY_CONFIG[priority] ?? PRIORITY_CONFIG.normal;
    const priorityBadge = `
    <table role="presentation" cellspacing="0" cellpadding="0" style="margin-bottom:16px;">
      <tr>
        <td style="background-color:${p.badge};border-radius:4px;padding:4px 12px;font-size:12px;font-weight:700;color:${emailLayout_1.BRAND.white};letter-spacing:0.5px;">
          ${p.label}
        </td>
      </tr>
    </table>`;
    const bodyContent = `
    <h2 style="margin:0 0 4px;font-size:20px;color:${emailLayout_1.BRAND.heading};">${title}</h2>
    <p style="margin:0 0 16px;font-size:14px;color:${emailLayout_1.BRAND.secondary};">
      From <strong>${schoolName}</strong> &mdash; ${senderName} (${senderRole})
    </p>

    ${priority !== 'normal' ? priorityBadge : ''}

    <div style="padding:20px;background-color:${p.bg};border-radius:6px;border:1px solid ${p.border};">
      <p style="margin:0;font-size:15px;color:#1f2937;line-height:1.8;white-space:pre-wrap;">${message}</p>
    </div>

    ${(0, emailLayout_1.ctaButton)('https://klasivo.app/announcements', 'View in Klasivo')}

    <p style="margin:12px 0 0;font-size:13px;color:${emailLayout_1.BRAND.muted};line-height:1.5;">
      You received this announcement because you are a member of ${schoolName} on Klasivo.
      To manage your notification preferences, visit your account settings.
    </p>`;
    return (0, emailLayout_1.wrapInLayout)({ title: `${title} — ${schoolName}`, bodyContent });
}
//# sourceMappingURL=schoolAnnouncement.js.map