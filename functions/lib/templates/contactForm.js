"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.buildContactFormHtml = buildContactFormHtml;
const emailLayout_1 = require("./emailLayout");
function buildContactFormHtml(params) {
    const { name, email, subject, message } = params;
    const content = `
    <h2 style="margin:0 0 8px;color:#1E293B;font-size:22px;">New Contact Form Submission</h2>
    <p style="color:#64748B;font-size:16px;margin:0 0 24px;">${subject}</p>
    <div class="note">
      <div class="detail">
        <div class="detail-label">From</div>
        <div class="detail-value">${name} (${email})</div>
      </div>
      <div class="detail" style="margin-top:12px;">
        <div class="detail-label">Subject</div>
        <div class="detail-value">${subject}</div>
      </div>
    </div>
    <div style="font-size:16px;line-height:1.7;color:#1E293B;margin-top:16px;">${message.replace(/\n/g, '<br>')}</div>
    <div style="margin-top:24px;padding-top:16px;border-top:1px solid #E2E8F0;">
      <a href="mailto:${email}" class="cta-button">Reply to ${name}</a>
    </div>
  `;
    return (0, emailLayout_1.emailWrapper)(content, `Contact Form: ${subject}`);
}
//# sourceMappingURL=contactForm.js.map