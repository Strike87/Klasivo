/**
 * Klasivo — Input Sanitizers
 *
 * Strip dangerous or unwanted content from user-supplied text
 * before it enters email templates or Firestore.
 *
 * Pure functions. No dependencies. Easy to test.
 */
/**
 * Strip HTML tags, trim whitespace, and truncate to `maxLength`.
 *
 * This is the primary sanitiser for all free-text user input
 * (names, subjects, message bodies, etc.).
 */
export declare function sanitizeText(text: string, maxLength?: number): string;
/**
 * Normalise an email address: trim + lowercase.
 * HTML stripping is not needed (emails don't contain HTML),
 * but we still trim whitespace.
 */
export declare function sanitizeEmail(email: string): string;
/**
 * Convenience: run `sanitizeText` on every string value in an object,
 * using the provided max-length map. Keys not in the map are left untouched.
 *
 * Example:
 *   sanitizeFields({ name: '<b>Ahmed</b>', school: 'Al-Noor' }, { name: 100, school: 150 })
 *   // → { name: 'Ahmed', school: 'Al-Noor' }
 */
export declare function sanitizeFields(obj: Record<string, unknown>, maxLengths: Record<string, number>): Record<string, unknown>;
//# sourceMappingURL=sanitizer.d.ts.map