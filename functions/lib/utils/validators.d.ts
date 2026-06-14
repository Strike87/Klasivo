/**
 * Klasivo — Input Validators
 *
 * Pure validation functions used across all callable Cloud Functions.
 * No side effects. No dependencies. Easy to test.
 */
/**
 * Basic email format validation.
 * Checks for: non-empty local part, @ symbol, domain with at least one dot.
 */
export declare function isValidEmail(email: string): boolean;
declare const VALID_ROLES: readonly ["teacher", "student", "parent"];
export type UserRole = (typeof VALID_ROLES)[number];
/** Check if a string is a valid Klasivo user role. */
export declare function isValidRole(value: string): value is UserRole;
/** Return the valid roles array for error messages. */
export declare function getValidRoles(): readonly string[];
declare const VALID_PRIORITIES: readonly ["urgent", "important", "normal"];
export type AnnouncementPriority = (typeof VALID_PRIORITIES)[number];
/** Check if a string is a valid announcement priority. */
export declare function isValidPriority(value: string): value is AnnouncementPriority;
/**
 * Check that an array of emails is within size bounds and every entry is valid.
 */
export declare function isValidRecipientList(recipients: string[], min?: number, max?: number): {
    valid: boolean;
    reason?: string;
};
/**
 * Ensure none of the required fields are missing or undefined.
 * Returns the first missing field name, or null if all present.
 */
export declare function missingField(obj: Record<string, unknown>, fields: string[]): string | null;
export {};
//# sourceMappingURL=validators.d.ts.map