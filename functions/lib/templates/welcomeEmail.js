"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.buildWelcomeHtml = buildWelcomeHtml;
const emailLayout_1 = require("./emailLayout");
function buildWelcomeHtml(name, role) {
    const roleLabel = role.charAt(0).toUpperCase() + role.slice(1);
    const content = `
    <h2 style="margin:0 0 8px;color:#1E293B;font-size:22px;">Welcome to Klasivo, ${name}!</h2>
    <p style="color:#64748B;font-size:16px;margin:0 0 24px;">Your smart school management platform</p>
    <p style="font-size:16px;line-height:1.6;">You've joined Klasivo as a <strong>${roleLabel}</strong>. We're excited to help you transform your school experience.</p>
    <div style="margin:24px 0;">
      <a href="https://klasivo.app" class="cta-button">Get Started</a>
    </div>
    <div class="note">
      <p style="margin:0;font-size:14px;">If you didn't create this account, please contact us at <a href="mailto:support@klasivo.app" style="color:#2563EB;">support@klasivo.app</a></p>
    </div>
  `;
    return (0, emailLayout_1.emailWrapper)(content, `Welcome to Klasivo, ${name}!`);
}
//# sourceMappingURL=welcomeEmail.js.map