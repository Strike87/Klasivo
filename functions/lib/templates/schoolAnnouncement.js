"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.buildSchoolAnnouncementHtml = buildSchoolAnnouncementHtml;
const emailLayout_1 = require("./emailLayout");
function buildSchoolAnnouncementHtml(params) {
    const { schoolName, title, message, senderName, senderRole, priority } = params;
    const priorityColors = {
        urgent: emailLayout_1.BRAND_COLORS.danger,
        important: emailLayout_1.BRAND_COLORS.warning,
        normal: emailLayout_1.BRAND_COLORS.secondary,
    };
    const priorityLabels = {
        urgent: 'URGENT',
        important: 'IMPORTANT',
        normal: '',
    };
    const color = priorityColors[priority] ?? emailLayout_1.BRAND_COLORS.secondary;
    const label = priorityLabels[priority] ?? '';
    const priorityBanner = label
        ? `<div style="background:${color};color:#FFFFFF;padding:12px 16px;border-radius:8px;margin:0 0 16px;font-weight:700;font-size:14px;text-align:center;">${label}</div>`
        : '';
    const content = `
    <h2 style="margin:0 0 8px;color:#1E293B;font-size:22px;">${title}</h2>
    <p style="color:#64748B;font-size:14px;margin:0 0 16px;">From ${schoolName}</p>
    ${priorityBanner}
    <div style="font-size:16px;line-height:1.7;color:#1E293B;">${message.replace(/\n/g, '<br>')}</div>
    <div style="margin-top:24px;padding-top:16px;border-top:1px solid #E2E8F0;">
      <p style="margin:0;font-size:14px;color:#64748B;">Sent by <strong>${senderName}</strong> (${senderRole})</p>
    </div>
  `;
    return (0, emailLayout_1.emailWrapper)(content, `${label ? label + ': ' : ''}${title} — ${schoolName}`);
}
//# sourceMappingURL=schoolAnnouncement.js.map