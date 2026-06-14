"use strict";
/**
 * Klasivo — Input Sanitizers
 *
 * Strip dangerous or unwanted content from user-supplied text
 * before it enters email templates or Firestore.
 *
 * Pure functions. No dependencies. Easy to test.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.sanitizeText = sanitizeText;
exports.sanitizeEmail = sanitizeEmail;
exports.sanitizeFields = sanitizeFields;
// ─── Text ─────────────────────────────────────────────────────
/**
 * Strip HTML tags, trim whitespace, and truncate to `maxLength`.
 *
 * This is the primary sanitiser for all free-text user input
 * (names, subjects, message bodies, etc.).
 */
function sanitizeText(text, maxLength = 1000) {
    return text
        .replace(/<[^>]*>/g, '') // strip HTML tags
        .trim()
        .slice(0, maxLength);
}
// ─── Email ────────────────────────────────────────────────────
/**
 * Normalise an email address: trim + lowercase.
 * HTML stripping is not needed (emails don't contain HTML),
 * but we still trim whitespace.
 */
function sanitizeEmail(email) {
    return email.trim().toLowerCase();
}
// ─── Batch ────────────────────────────────────────────────────
/**
 * Convenience: run `sanitizeText` on every string value in an object,
 * using the provided max-length map. Keys not in the map are left untouched.
 *
 * Example:
 *   sanitizeFields({ name: '<b>Ahmed</b>', school: 'Al-Noor' }, { name: 100, school: 150 })
 *   // → { name: 'Ahmed', school: 'Al-Noor' }
 */
function sanitizeFields(obj, maxLengths) {
    const result = { ...obj };
    for (const [key, max] of Object.entries(maxLengths)) {
        if (typeof result[key] === 'string') {
            result[key] = sanitizeText(result[key], max);
        }
    }
    return result;
}
//# sourceMappingURL=sanitizer.js.map