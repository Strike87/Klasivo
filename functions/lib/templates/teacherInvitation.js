"use strict";
/**
 * Klasivo — Teacher Invitation Template
 *
 * Sent when a school owner invites a teacher to join
 * their organisation on Klasivo.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.buildTeacherInvitation = buildTeacherInvitation;
const emailLayout_1 = require("./emailLayout");
/**
 * Build the HTML for a teacher invitation email.
 *
 * @returns Complete HTML string ready for Resend
 */
function buildTeacherInvitation(payload) {
    const { teacherName, schoolName, inviterName, inviteCode, orgId } = payload;
    const acceptUrl = `https://klasivo.app/invite?code=${inviteCode}&org=${orgId}`;
    const bodyContent = `
    <h2 style="margin:0 0 8px;font-size:20px;color:${emailLayout_1.BRAND.heading};">You're Invited to Join ${schoolName}</h2>
    <p style="margin:0 0 16px;font-size:15px;color:${emailLayout_1.BRAND.secondary};">${inviterName} wants you on their team.</p>

    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="margin-bottom:20px;">
      ${(0, emailLayout_1.detailRow)('School', schoolName, { stripe: true })}
      ${(0, emailLayout_1.detailRow)('Invited by', inviterName)}
      ${(0, emailLayout_1.detailRow)('Invite Code', inviteCode, {
        stripe: true,
        valueStyle: `font-size:16px;color:${emailLayout_1.BRAND.primary};font-weight:600;letter-spacing:1px;`,
    })}
    </table>

    <p style="margin:0 0 16px;font-size:15px;color:${emailLayout_1.BRAND.body};line-height:1.6;">
      Hi ${teacherName}, you've been invited to join <strong>${schoolName}</strong> on Klasivo
      as a teacher. Once you accept, you'll be able to:
    </p>
    <ul style="margin:0 0 16px;padding-left:20px;font-size:15px;color:${emailLayout_1.BRAND.body};line-height:1.8;">
      <li>Create and manage exams for your classes</li>
      <li>Track student performance and analytics</li>
      <li>Communicate with students and parents</li>
      <li>Manage attendance, assignments, and grades</li>
    </ul>

    ${(0, emailLayout_1.ctaButton)(acceptUrl, 'Accept Invitation')}
    ${(0, emailLayout_1.noteBox)('<strong>Note:</strong> This invitation code expires in 7 days. If you don\'t already have a Klasivo account, you\'ll be prompted to create one after clicking the button above.')}
    ${(0, emailLayout_1.fallbackUrl)(acceptUrl)}`;
    return (0, emailLayout_1.wrapInLayout)({ title: `Invitation to join ${schoolName}`, bodyContent });
}
//# sourceMappingURL=teacherInvitation.js.map