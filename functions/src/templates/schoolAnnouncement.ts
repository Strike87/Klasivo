import { emailWrapper, BRAND_COLORS } from './emailLayout';

interface AnnouncementParams {
  schoolName: string;
  title: string;
  message: string;
  senderName: string;
  senderRole: string;
  priority: string;
}

export function buildSchoolAnnouncementHtml(params: AnnouncementParams): string {
  const { schoolName, title, message, senderName, senderRole, priority } = params;

  const priorityColors: Record<string, string> = {
    urgent: BRAND_COLORS.danger,
    important: BRAND_COLORS.warning,
    normal: BRAND_COLORS.secondary,
  };
  const priorityLabels: Record<string, string> = {
    urgent: 'URGENT',
    important: 'IMPORTANT',
    normal: '',
  };

  const color = priorityColors[priority] ?? BRAND_COLORS.secondary;
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
  return emailWrapper(content, `${label ? label + ': ' : ''}${title} — ${schoolName}`);
}
