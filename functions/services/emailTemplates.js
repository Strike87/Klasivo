/**
 * Klasivo Email Templates
 *
 * All HTML email templates live here so they are easy to find, update,
 * and eventually migrate to a visual editor (e.g. React Email / MJML).
 *
 * Design principles:
 *   — Inline CSS only (most email clients strip <style> blocks)
 *   — 600 px max-width for mobile compatibility
 *   — Brand colours: primary #4F46E5 (indigo), accent #10B981 (emerald)
 *   — System font stack for fast rendering & CJK support
 */

// ─── Shared layout wrapper ───────────────────────────────────
function wrapInLayout({ title, bodyContent }) {
  return `
<!DOCTYPE html>
<html lang="en" dir="ltr">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>${title}</title>
</head>
<body style="margin:0;padding:0;background-color:#f3f4f6;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,'Helvetica Neue',Arial,'Noto Sans','Noto Sans Arabic',sans-serif;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color:#f3f4f6;padding:24px 0;">
    <tr>
      <td align="center">
        <table role="presentation" width="600" cellspacing="0" cellpadding="0" style="max-width:600px;width:100%;">

          <!-- Header -->
          <tr>
            <td style="background-color:#4F46E5;padding:24px 32px;border-radius:8px 8px 0 0;text-align:center;">
              <h1 style="margin:0;color:#ffffff;font-size:22px;font-weight:700;letter-spacing:0.5px;">
                Klasivo
              </h1>
            </td>
          </tr>

          <!-- Body -->
          <tr>
            <td style="background-color:#ffffff;padding:32px;border-left:1px solid #e5e7eb;border-right:1px solid #e5e7eb;">
              ${bodyContent}
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background-color:#f9fafb;padding:20px 32px;border-radius:0 0 8px 8px;border:1px solid #e5e7eb;text-align:center;">
              <p style="margin:0;font-size:13px;color:#6b7280;line-height:1.5;">
                Klasivo &mdash; Smart School Management Platform<br />
                <a href="https://klasivo.app" style="color:#4F46E5;text-decoration:none;">klasivo.app</a>
              </p>
              <p style="margin:8px 0 0;font-size:12px;color:#9ca3af;">
                You received this email because you have an account on Klasivo.
                If you did not create this account, please contact
                <a href="mailto:support@klasivo.app" style="color:#6b7280;">support@klasivo.app</a>.
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

// ─── CTA button ──────────────────────────────────────────────
function ctaButton(url, label) {
  return `
  <table role="presentation" cellspacing="0" cellpadding="0" style="margin:24px auto;">
    <tr>
      <td style="background-color:#4F46E5;border-radius:6px;">
        <a href="${url}" style="display:inline-block;padding:12px 28px;color:#ffffff;font-size:15px;font-weight:600;text-decoration:none;">
          ${label}
        </a>
      </td>
    </tr>
  </table>`;
}

// ─── Welcome Email ───────────────────────────────────────────
function buildWelcomeHtml(name, role = 'teacher') {
  const roleLabel = { teacher: 'Teacher', student: 'Student', parent: 'Parent' }[role] || 'User';

  const ctaUrl = role === 'student'
    ? 'https://klasivo.app/student/dashboard'
    : 'https://klasivo.app/dashboard';

  const ctaLabel = role === 'student'
    ? 'Go to My Dashboard'
    : 'Go to Dashboard';

  const roleContent = role === 'teacher'
    ? `
    <p style="margin:0 0 12px;font-size:15px;color:#374151;line-height:1.6;">
      As a <strong>Teacher</strong> on Klasivo you can:
    </p>
    <ul style="margin:0 0 16px;padding-left:20px;font-size:15px;color:#374151;line-height:1.8;">
      <li>Create and manage exams with smart question banks</li>
      <li>Track student performance with real-time analytics</li>
      <li>Communicate with students and parents seamlessly</li>
      <li>Manage attendance, assignments, and grades in one place</li>
    </ul>`
    : role === 'student'
    ? `
    <p style="margin:0 0 12px;font-size:15px;color:#374151;line-height:1.6;">
      As a <strong>Student</strong> on Klasivo you can:
    </p>
    <ul style="margin:0 0 16px;padding-left:20px;font-size:15px;color:#374151;line-height:1.8;">
      <li>Take exams online with a secure, user-friendly interface</li>
      <li>View your grades and performance analytics</li>
      <li>Receive instant feedback on your submissions</li>
      <li>Access study materials and assignments anytime</li>
    </ul>`
    : `
    <p style="margin:0 0 12px;font-size:15px;color:#374151;line-height:1.6;">
      As a <strong>Parent</strong> on Klasivo you can:
    </p>
    <ul style="margin:0 0 16px;padding-left:20px;font-size:15px;color:#374151;line-height:1.8;">
      <li>Monitor your child's academic progress in real time</li>
      <li>Communicate directly with teachers</li>
      <li>Receive notifications about grades and attendance</li>
      <li>Stay informed about upcoming exams and assignments</li>
    </ul>`;

  const bodyContent = `
    <h2 style="margin:0 0 8px;font-size:20px;color:#111827;">Welcome to Klasivo, ${name}!</h2>
    <p style="margin:0 0 16px;font-size:15px;color:#6b7280;">Your ${roleLabel} account is ready.</p>

    ${roleContent}

    <p style="margin:0 0 8px;font-size:15px;color:#374151;line-height:1.6;">
      We're excited to have you on board. Here's how to get started:
    </p>
    <ol style="margin:0 0 16px;padding-left:20px;font-size:15px;color:#374151;line-height:1.8;">
      <li>Complete your profile with your details</li>
      <li>Join or create your organization</li>
      <li>Explore the dashboard and start using Klasivo</li>
    </ol>

    ${ctaButton(ctaUrl, ctaLabel)}

    <p style="margin:16px 0 0;font-size:14px;color:#9ca3af;line-height:1.5;">
      If the button above doesn't work, copy and paste this URL into your browser:<br />
      <a href="${ctaUrl}" style="color:#4F46E5;word-break:break-all;">${ctaUrl}</a>
    </p>`;

  return wrapInLayout({ title: `Welcome to Klasivo, ${name}!`, bodyContent });
}

// ─── Contact Form Notification ───────────────────────────────
function buildContactFormHtml({ name, email, subject, message }) {
  const bodyContent = `
    <h2 style="margin:0 0 8px;font-size:20px;color:#111827;">New Contact Form Submission</h2>
    <p style="margin:0 0 20px;font-size:15px;color:#6b7280;">Someone reached out via the Klasivo website.</p>

    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="margin-bottom:20px;">
      <tr>
        <td style="padding:8px 12px;background-color:#f9fafb;border-bottom:1px solid #e5e7eb;font-size:14px;color:#6b7280;width:100px;">
          Name
        </td>
        <td style="padding:8px 12px;background-color:#f9fafb;border-bottom:1px solid #e5e7eb;font-size:14px;color:#111827;">
          ${name}
        </td>
      </tr>
      <tr>
        <td style="padding:8px 12px;border-bottom:1px solid #e5e7eb;font-size:14px;color:#6b7280;">
          Email
        </td>
        <td style="padding:8px 12px;border-bottom:1px solid #e5e7eb;font-size:14px;color:#111827;">
          <a href="mailto:${email}" style="color:#4F46E5;text-decoration:none;">${email}</a>
        </td>
      </tr>
      <tr>
        <td style="padding:8px 12px;background-color:#f9fafb;border-bottom:1px solid #e5e7eb;font-size:14px;color:#6b7280;">
          Subject
        </td>
        <td style="padding:8px 12px;background-color:#f9fafb;border-bottom:1px solid #e5e7eb;font-size:14px;color:#111827;">
          ${subject}
        </td>
      </tr>
    </table>

    <h3 style="margin:0 0 8px;font-size:16px;color:#374151;">Message</h3>
    <div style="padding:16px;background-color:#f9fafb;border-radius:6px;border:1px solid #e5e7eb;">
      <p style="margin:0;font-size:14px;color:#374151;line-height:1.7;white-space:pre-wrap;">${message}</p>
    </div>

    ${ctaButton(`mailto:${email}`, 'Reply to ' + name)}`;

  return wrapInLayout({ title: `Contact: ${subject}`, bodyContent });
}

// ─── Teacher Invitation ───────────────────────────────────────
function buildTeacherInvitationHtml({ teacherName, schoolName, inviterName, inviteCode, orgId }) {
  const acceptUrl = `https://klasivo.app/invite?code=${inviteCode}&org=${orgId}`;

  const bodyContent = `
    <h2 style="margin:0 0 8px;font-size:20px;color:#111827;">You're Invited to Join ${schoolName}</h2>
    <p style="margin:0 0 16px;font-size:15px;color:#6b7280;">${inviterName} wants you on their team.</p>

    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="margin-bottom:20px;">
      <tr>
        <td style="padding:8px 12px;background-color:#f9fafb;border-bottom:1px solid #e5e7eb;font-size:14px;color:#6b7280;width:120px;">
          School
        </td>
        <td style="padding:8px 12px;background-color:#f9fafb;border-bottom:1px solid #e5e7eb;font-size:14px;color:#111827;">
          ${schoolName}
        </td>
      </tr>
      <tr>
        <td style="padding:8px 12px;border-bottom:1px solid #e5e7eb;font-size:14px;color:#6b7280;">
          Invited by
        </td>
        <td style="padding:8px 12px;border-bottom:1px solid #e5e7eb;font-size:14px;color:#111827;">
          ${inviterName}
        </td>
      </tr>
      <tr>
        <td style="padding:8px 12px;background-color:#f9fafb;border-bottom:1px solid #e5e7eb;font-size:14px;color:#6b7280;">
          Invite Code
        </td>
        <td style="padding:8px 12px;background-color:#f9fafb;border-bottom:1px solid #e5e7eb;font-size:16px;color:#4F46E5;font-weight:600;letter-spacing:1px;">
          ${inviteCode}
        </td>
      </tr>
    </table>

    <p style="margin:0 0 16px;font-size:15px;color:#374151;line-height:1.6;">
      Hi ${teacherName}, you've been invited to join <strong>${schoolName}</strong> on Klasivo
      as a teacher. Once you accept, you'll be able to:
    </p>
    <ul style="margin:0 0 16px;padding-left:20px;font-size:15px;color:#374151;line-height:1.8;">
      <li>Create and manage exams for your classes</li>
      <li>Track student performance and analytics</li>
      <li>Communicate with students and parents</li>
      <li>Manage attendance, assignments, and grades</li>
    </ul>

    ${ctaButton(acceptUrl, 'Accept Invitation')}

    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="margin:16px 0;padding:14px 16px;background-color:#fef3c7;border-radius:6px;border:1px solid #fde68a;">
      <tr>
        <td style="font-size:13px;color:#92400e;line-height:1.5;">
          <strong>Note:</strong> This invitation code expires in 7 days. If you don't already have a
          Klasivo account, you'll be prompted to create one after clicking the button above.
        </td>
      </tr>
    </table>

    <p style="margin:12px 0 0;font-size:14px;color:#9ca3af;line-height:1.5;">
      If the button doesn't work, copy this URL:<br />
      <a href="${acceptUrl}" style="color:#4F46E5;word-break:break-all;">${acceptUrl}</a>
    </p>`;

  return wrapInLayout({ title: `Invitation to join ${schoolName}`, bodyContent });
}

// ─── School Announcement ─────────────────────────────────────
function buildSchoolAnnouncementHtml({ schoolName, title, message, senderName, senderRole, priority }) {
  const priorityConfig = {
    urgent: { bg: '#fef2f2', border: '#fecaca', badge: '#dc2626', label: 'URGENT' },
    important: { bg: '#fffbeb', border: '#fde68a', badge: '#d97706', label: 'IMPORTANT' },
    normal: { bg: '#eff6ff', border: '#bfdbfe', badge: '#2563eb', label: 'ANNOUNCEMENT' },
  };
  const p = priorityConfig[priority] || priorityConfig.normal;

  const priorityBadge = `
    <table role="presentation" cellspacing="0" cellpadding="0" style="margin-bottom:16px;">
      <tr>
        <td style="background-color:${p.badge};border-radius:4px;padding:4px 12px;font-size:12px;font-weight:700;color:#ffffff;letter-spacing:0.5px;">
          ${p.label}
        </td>
      </tr>
    </table>`;

  const bodyContent = `
    <h2 style="margin:0 0 4px;font-size:20px;color:#111827;">${title}</h2>
    <p style="margin:0 0 16px;font-size:14px;color:#6b7280;">
      From <strong>${schoolName}</strong> &mdash; ${senderName} (${senderRole})
    </p>

    ${priority !== 'normal' ? priorityBadge : ''}

    <div style="padding:20px;background-color:${p.bg};border-radius:6px;border:1px solid ${p.border};">
      <p style="margin:0;font-size:15px;color:#1f2937;line-height:1.8;white-space:pre-wrap;">${message}</p>
    </div>

    ${ctaButton('https://klasivo.app/announcements', 'View in Klasivo')}

    <p style="margin:12px 0 0;font-size:13px;color:#9ca3af;line-height:1.5;">
      You received this announcement because you are a member of ${schoolName} on Klasivo.
      To manage your notification preferences, visit your account settings.
    </p>`;

  return wrapInLayout({ title: `${title} — ${schoolName}`, bodyContent });
}

// ─── Exports ─────────────────────────────────────────────────
module.exports = {
  buildWelcomeHtml,
  buildContactFormHtml,
  buildTeacherInvitationHtml,
  buildSchoolAnnouncementHtml,
  wrapInLayout, // re-export for custom templates
};
