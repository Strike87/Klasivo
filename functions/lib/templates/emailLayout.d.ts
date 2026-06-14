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
/** Bump this when you change any email template significantly.
 *  Included in every email footer so you can trace which template version
 *  generated a given email — years later.
 */
export declare const EMAIL_TEMPLATE_VERSION = "1.0.0";
export declare const BRAND: {
    /** Indigo-600 — primary brand colour */
    readonly primary: "#4F46E5";
    /** Emerald-500 — accent / success colour */
    readonly accent: "#10B981";
    /** Neutral-50 — light background */
    readonly surfaceLight: "#f9fafb";
    /** Neutral-100 — card background */
    readonly surfaceCard: "#f3f4f6";
    /** Neutral-200 — borders */
    readonly border: "#e5e7eb";
    /** Gray-900 — headings */
    readonly heading: "#111827";
    /** Gray-700 — body text */
    readonly body: "#374151";
    /** Gray-500 — secondary text */
    readonly secondary: "#6b7280";
    /** Gray-400 — muted / hints */
    readonly muted: "#9ca3af";
    /** White */
    readonly white: "#ffffff";
};
/** Sender addresses used across the app. */
export declare const SENDER: {
    /** Default noreply — welcome emails, announcements, verification */
    readonly noreply: "Klasivo <noreply@klasivo.app>";
    /** Support — contact form submissions, user support */
    readonly support: "Klasivo <support@klasivo.app>";
};
interface LayoutParams {
    /** <title> tag content (not visible in most email clients) */
    title: string;
    /** The inner HTML that goes between header and footer */
    bodyContent: string;
    /** Override the default footer text (optional) */
    footerOverride?: string;
}
/**
 * Wrap email body content in the standard Klasivo layout.
 *
 * Usage:
 *   return wrapInLayout({ title: 'Welcome!', bodyContent: '<h2>Hello</h2>' });
 */
export declare function wrapInLayout({ title, bodyContent, footerOverride }: LayoutParams): string;
/**
 * Render a branded indigo CTA button.
 *
 * Uses a table-based layout for maximum email client compatibility.
 */
export declare function ctaButton(url: string, label: string): string;
/**
 * A styled info/note box (amber warning style).
 * Used for invitation expiry notes, disclaimers, etc.
 */
export declare function noteBox(text: string): string;
/**
 * A fallback URL line shown below CTA buttons for email clients
 * that don't render the button correctly.
 */
export declare function fallbackUrl(url: string): string;
/**
 * A simple key-value row for the detail tables used in
 * contact form and invitation templates.
 */
export declare function detailRow(label: string, value: string, opts?: {
    stripe?: boolean;
    valueStyle?: string;
}): string;
export {};
//# sourceMappingURL=emailLayout.d.ts.map