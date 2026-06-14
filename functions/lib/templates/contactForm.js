"use strict";
/**
 * Klasivo — Contact Form Notification Template
 *
 * Sent to the Klasivo support team when a visitor submits
 * the public contact form on the website.
 *
 * Recipient: support@klasivo.app
 * Reply-To:  the submitter's email
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.buildContactNotification = buildContactNotification;
const emailLayout_1 = require("./emailLayout");
/**
 * Build the HTML for a contact-form notification email.
 *
 * @returns Complete HTML string ready for Resend
 */
function buildContactNotification(payload) {
    const { name, email, subject, message } = payload;
    const bodyContent = `
    <h2 style="margin:0 0 8px;font-size:20px;color:${emailLayout_1.BRAND.heading};">New Contact Form Submission</h2>
    <p style="margin:0 0 20px;font-size:15px;color:${emailLayout_1.BRAND.secondary};">Someone reached out via the Klasivo website.</p>

    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="margin-bottom:20px;">
      ${(0, emailLayout_1.detailRow)('Name', name, { stripe: true })}
      ${(0, emailLayout_1.detailRow)('Email', `<a href="mailto:${email}" style="color:${emailLayout_1.BRAND.primary};text-decoration:none;">${email}</a>`)}
      ${(0, emailLayout_1.detailRow)('Subject', subject, { stripe: true })}
    </table>

    <h3 style="margin:0 0 8px;font-size:16px;color:${emailLayout_1.BRAND.body};">Message</h3>
    <div style="padding:16px;background-color:${emailLayout_1.BRAND.surfaceLight};border-radius:6px;border:1px solid ${emailLayout_1.BRAND.border};">
      <p style="margin:0;font-size:14px;color:${emailLayout_1.BRAND.body};line-height:1.7;white-space:pre-wrap;">${message}</p>
    </div>

    ${(0, emailLayout_1.ctaButton)(`mailto:${email}`, `Reply to ${name}`)}`;
    return (0, emailLayout_1.wrapInLayout)({
        title: `Contact: ${subject}`,
        bodyContent,
        footerOverride: `Klasivo Support &mdash; Smart School Management Platform<br />
                <a href="https://klasivo.app" style="color:${emailLayout_1.BRAND.primary};text-decoration:none;">klasivo.app</a>`,
    });
}
//# sourceMappingURL=contactForm.js.map