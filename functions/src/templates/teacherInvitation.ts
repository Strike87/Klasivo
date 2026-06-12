import { emailWrapper } from './emailLayout';

interface InvitationParams {
  teacherName: string;
  schoolName: string;
  inviterName: string;
  inviteCode: string;
  orgId: string;
}

export function buildTeacherInvitationHtml(params: InvitationParams): string {
  const { teacherName, schoolName, inviterName, inviteCode } = params;
  const content = `
    <h2 style="margin:0 0 8px;color:#1E293B;font-size:22px;">You're Invited, ${teacherName}!</h2>
    <p style="color:#64748B;font-size:16px;margin:0 0 24px;">Join ${schoolName} on Klasivo</p>
    <p style="font-size:16px;line-height:1.6;"><strong>${inviterName}</strong> has invited you to join <strong>${schoolName}</strong> as a teacher on Klasivo.</p>
    <div class="note">
      <div class="detail">
        <div class="detail-label">Your Invite Code</div>
        <div class="detail-value" style="font-size:24px;font-weight:700;color:#1A3A8A;letter-spacing:0.1em;">${inviteCode}</div>
      </div>
    </div>
    <div style="margin:24px 0;">
      <a href="https://klasivo.app/invite?code=${inviteCode}" class="cta-button">Accept Invitation</a>
    </div>
    <p style="font-size:14px;color:#64748B;">This invitation code is unique to you. If you weren't expecting this, you can safely ignore this email.</p>
  `;
  return emailWrapper(content, `You're invited to join ${schoolName} on Klasivo`);
}
