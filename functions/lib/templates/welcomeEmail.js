"use strict";
/**
 * Klasivo — Welcome Email Template
 *
 * Sent automatically when a new Firebase Auth user is created
 * (via onUserCreated auth trigger) or manually via the
 * sendWelcomeEmail callable function.
 *
 * Personalised by role: teacher / student / parent.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.buildWelcomeEmail = buildWelcomeEmail;
const emailLayout_1 = require("./emailLayout");
// ─── Role-specific content ────────────────────────────────────
const ROLE_LABELS = {
    teacher: 'Teacher',
    student: 'Student',
    parent: 'Parent',
};
const ROLE_BENEFITS = {
    teacher: `
    <p style="margin:0 0 12px;font-size:15px;color:${emailLayout_1.BRAND.body};line-height:1.6;">
      As a <strong>Teacher</strong> on Klasivo you can:
    </p>
    <ul style="margin:0 0 16px;padding-left:20px;font-size:15px;color:${emailLayout_1.BRAND.body};line-height:1.8;">
      <li>Create and manage exams with smart question banks</li>
      <li>Track student performance with real-time analytics</li>
      <li>Communicate with students and parents seamlessly</li>
      <li>Manage attendance, assignments, and grades in one place</li>
    </ul>`,
    student: `
    <p style="margin:0 0 12px;font-size:15px;color:${emailLayout_1.BRAND.body};line-height:1.6;">
      As a <strong>Student</strong> on Klasivo you can:
    </p>
    <ul style="margin:0 0 16px;padding-left:20px;font-size:15px;color:${emailLayout_1.BRAND.body};line-height:1.8;">
      <li>Take exams online with a secure, user-friendly interface</li>
      <li>View your grades and performance analytics</li>
      <li>Receive instant feedback on your submissions</li>
      <li>Access study materials and assignments anytime</li>
    </ul>`,
    parent: `
    <p style="margin:0 0 12px;font-size:15px;color:${emailLayout_1.BRAND.body};line-height:1.6;">
      As a <strong>Parent</strong> on Klasivo you can:
    </p>
    <ul style="margin:0 0 16px;padding-left:20px;font-size:15px;color:${emailLayout_1.BRAND.body};line-height:1.8;">
      <li>Monitor your child's academic progress in real time</li>
      <li>Communicate directly with teachers</li>
      <li>Receive notifications about grades and attendance</li>
      <li>Stay informed about upcoming exams and assignments</li>
    </ul>`,
};
// ─── Public API ───────────────────────────────────────────────
/**
 * Build the HTML for the welcome email.
 *
 * @param name  — User's display name
 * @param role  — 'teacher' | 'student' | 'parent' (defaults to 'teacher')
 * @returns Complete HTML string ready for Resend
 */
function buildWelcomeEmail(name, role = 'teacher') {
    const roleLabel = ROLE_LABELS[role];
    const ctaUrl = role === 'student'
        ? 'https://klasivo.app/student/dashboard'
        : 'https://klasivo.app/dashboard';
    const ctaLabel = role === 'student' ? 'Go to My Dashboard' : 'Go to Dashboard';
    const bodyContent = `
    <h2 style="margin:0 0 8px;font-size:20px;color:${emailLayout_1.BRAND.heading};">Welcome to Klasivo, ${name}!</h2>
    <p style="margin:0 0 16px;font-size:15px;color:${emailLayout_1.BRAND.secondary};">Your ${roleLabel} account is ready.</p>

    ${ROLE_BENEFITS[role]}

    <p style="margin:0 0 8px;font-size:15px;color:${emailLayout_1.BRAND.body};line-height:1.6;">
      We're excited to have you on board. Here's how to get started:
    </p>
    <ol style="margin:0 0 16px;padding-left:20px;font-size:15px;color:${emailLayout_1.BRAND.body};line-height:1.8;">
      <li>Complete your profile with your details</li>
      <li>Join or create your organization</li>
      <li>Explore the dashboard and start using Klasivo</li>
    </ol>

    ${(0, emailLayout_1.ctaButton)(ctaUrl, ctaLabel)}
    ${(0, emailLayout_1.fallbackUrl)(ctaUrl)}`;
    return (0, emailLayout_1.wrapInLayout)({ title: `Welcome to Klasivo, ${name}!`, bodyContent });
}
//# sourceMappingURL=welcomeEmail.js.map