"use strict";
/**
 * Klasivo — Email Layout
 *
 * The single source of truth for all email branding:
 *   - Logo / Header
 *   - Footer
 *   - Klasivo colours
 *   - CTA buttons
 *
 * Every template inherits from this file.
 * Change branding once here → all emails update.
 *
 * Design principles:
 *   — Inline CSS only (most email clients strip <style> blocks)
 *   — 600 px max-width for mobile compatibility
 *   — Brand colours: primary #4F46E5 (indigo), accent #10B981 (emerald)
 *   — System font stack for fast rendering & CJK / Arabic support
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.SENDER = exports.BRAND = exports.EMAIL_TEMPLATE_VERSION = void 0;
exports.wrapInLayout = wrapInLayout;
exports.ctaButton = ctaButton;
exports.noteBox = noteBox;
exports.fallbackUrl = fallbackUrl;
exports.detailRow = detailRow;
// ─── Brand constants ──────────────────────────────────────────
/** Bump this when you change any email template significantly.
 *  Included in every email footer so you can trace which template version
 *  generated a given email — years later.
 */
exports.EMAIL_TEMPLATE_VERSION = '1.0.0';
exports.BRAND = {
    /** Indigo-600 — primary brand colour */
    primary: '#4F46E5',
    /** Emerald-500 — accent / success colour */
    accent: '#10B981',
    /** Neutral-50 — light background */
    surfaceLight: '#f9fafb',
    /** Neutral-100 — card background */
    surfaceCard: '#f3f4f6',
    /** Neutral-200 — borders */
    border: '#e5e7eb',
    /** Gray-900 — headings */
    heading: '#111827',
    /** Gray-700 — body text */
    body: '#374151',
    /** Gray-500 — secondary text */
    secondary: '#6b7280',
    /** Gray-400 — muted / hints */
    muted: '#9ca3af',
    /** White */
    white: '#ffffff',
};
/** Sender addresses used across the app. */
exports.SENDER = {
    /** Default noreply — welcome emails, announcements, verification */
    noreply: 'Klasivo <noreply@klasivo.app>',
    /** Support — contact form submissions, user support */
    support: 'Klasivo <support@klasivo.app>',
};
/** Font stack that renders well on all platforms including Arabic/CJK. */
const FONT_STACK = "-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,'Helvetica Neue',Arial,'Noto Sans','Noto Sans Arabic',sans-serif";
/**
 * Wrap email body content in the standard Klasivo layout.
 *
 * Usage:
 *   return wrapInLayout({ title: 'Welcome!', bodyContent: '<h2>Hello</h2>' });
 */
function wrapInLayout({ title, bodyContent, footerOverride }) {
    const footerText = footerOverride ??
        `Klasivo &mdash; Smart School Management Platform<br />
                <a href="https://klasivo.app" style="color:${exports.BRAND.primary};text-decoration:none;">klasivo.app</a>`;
    return `<!DOCTYPE html>
<html lang="en" dir="ltr">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>${title}</title>
</head>
<body style="margin:0;padding:0;background-color:${exports.BRAND.surfaceCard};font-family:${FONT_STACK};">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color:${exports.BRAND.surfaceCard};padding:24px 0;">
    <tr>
      <td align="center">
        <table role="presentation" width="600" cellspacing="0" cellpadding="0" style="max-width:600px;width:100%;">

          <!-- Header -->
          <tr>
            <td style="background-color:${exports.BRAND.primary};padding:24px 32px;border-radius:8px 8px 0 0;text-align:center;">
              <h1 style="margin:0;color:${exports.BRAND.white};font-size:22px;font-weight:700;letter-spacing:0.5px;">
                Klasivo
              </h1>
            </td>
          </tr>

          <!-- Body -->
          <tr>
            <td style="background-color:${exports.BRAND.white};padding:32px;border-left:1px solid ${exports.BRAND.border};border-right:1px solid ${exports.BRAND.border};">
              ${bodyContent}
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background-color:${exports.BRAND.surfaceLight};padding:20px 32px;border-radius:0 0 8px 8px;border:1px solid ${exports.BRAND.border};text-align:center;">
              <p style="margin:0;font-size:13px;color:${exports.BRAND.secondary};line-height:1.5;">
                ${footerText}
              </p>
              <p style="margin:8px 0 0;font-size:12px;color:${exports.BRAND.muted};">
                You received this email because you have an account on Klasivo.
                If you did not create this account, please contact
                <a href="mailto:support@klasivo.app" style="color:${exports.BRAND.secondary};">support@klasivo.app</a>.
              </p>
              <p style="margin:4px 0 0;font-size:11px;color:${exports.BRAND.muted};opacity:0.6;">
                Template v${exports.EMAIL_TEMPLATE_VERSION}
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
// ─── CTA button ───────────────────────────────────────────────
/**
 * Render a branded indigo CTA button.
 *
 * Uses a table-based layout for maximum email client compatibility.
 */
function ctaButton(url, label) {
    return `
  <table role="presentation" cellspacing="0" cellpadding="0" style="margin:24px auto;">
    <tr>
      <td style="background-color:${exports.BRAND.primary};border-radius:6px;">
        <a href="${url}" style="display:inline-block;padding:12px 28px;color:${exports.BRAND.white};font-size:15px;font-weight:600;text-decoration:none;">
          ${label}
        </a>
      </td>
    </tr>
  </table>`;
}
// ─── Reusable fragments ───────────────────────────────────────
/**
 * A styled info/note box (amber warning style).
 * Used for invitation expiry notes, disclaimers, etc.
 */
function noteBox(text) {
    return `
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="margin:16px 0;padding:14px 16px;background-color:#fef3c7;border-radius:6px;border:1px solid #fde68a;">
      <tr>
        <td style="font-size:13px;color:#92400e;line-height:1.5;">
          ${text}
        </td>
      </tr>
    </table>`;
}
/**
 * A fallback URL line shown below CTA buttons for email clients
 * that don't render the button correctly.
 */
function fallbackUrl(url) {
    return `
    <p style="margin:12px 0 0;font-size:14px;color:${exports.BRAND.muted};line-height:1.5;">
      If the button above doesn't work, copy and paste this URL into your browser:<br />
      <a href="${url}" style="color:${exports.BRAND.primary};word-break:break-all;">${url}</a>
    </p>`;
}
/**
 * A simple key-value row for the detail tables used in
 * contact form and invitation templates.
 */
function detailRow(label, value, opts = {}) {
    const bg = opts.stripe ? `background-color:${exports.BRAND.surfaceLight};` : '';
    const valueExtra = opts.valueStyle ?? '';
    return `
      <tr>
        <td style="padding:8px 12px;${bg}border-bottom:1px solid ${exports.BRAND.border};font-size:14px;color:${exports.BRAND.secondary};width:120px;">
          ${label}
        </td>
        <td style="padding:8px 12px;${bg}border-bottom:1px solid ${exports.BRAND.border};font-size:14px;color:${exports.BRAND.heading};${valueExtra}">
          ${value}
        </td>
      </tr>`;
}
//# sourceMappingURL=emailLayout.js.map