"use strict";
/**
 * Klasivo — Input Validators
 *
 * Pure validation functions used across all callable Cloud Functions.
 * No side effects. No dependencies. Easy to test.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.isValidEmail = isValidEmail;
exports.isValidRole = isValidRole;
exports.getValidRoles = getValidRoles;
exports.isValidPriority = isValidPriority;
exports.isValidRecipientList = isValidRecipientList;
exports.missingField = missingField;
// ─── Email ────────────────────────────────────────────────────
/**
 * Basic email format validation.
 * Checks for: non-empty local part, @ symbol, domain with at least one dot.
 */
function isValidEmail(email) {
    const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return re.test(email);
}
// ─── Role ─────────────────────────────────────────────────────
const VALID_ROLES = ['teacher', 'student', 'parent'];
/** Check if a string is a valid Klasivo user role. */
function isValidRole(value) {
    return VALID_ROLES.includes(value);
}
/** Return the valid roles array for error messages. */
function getValidRoles() {
    return VALID_ROLES;
}
// ─── Priority ─────────────────────────────────────────────────
const VALID_PRIORITIES = ['urgent', 'important', 'normal'];
/** Check if a string is a valid announcement priority. */
function isValidPriority(value) {
    return VALID_PRIORITIES.includes(value);
}
// ─── Array ────────────────────────────────────────────────────
/**
 * Check that an array of emails is within size bounds and every entry is valid.
 */
function isValidRecipientList(recipients, min = 1, max = 50) {
    if (recipients.length < min) {
        return { valid: false, reason: `At least ${min} recipient required.` };
    }
    if (recipients.length > max) {
        return { valid: false, reason: `Maximum ${max} recipients allowed.` };
    }
    for (const email of recipients) {
        if (!isValidEmail(email)) {
            return { valid: false, reason: `Invalid email address: ${email}` };
        }
    }
    return { valid: true };
}
// ─── Required fields ──────────────────────────────────────────
/**
 * Ensure none of the required fields are missing or undefined.
 * Returns the first missing field name, or null if all present.
 */
function missingField(obj, fields) {
    for (const field of fields) {
        if (obj[field] === undefined || obj[field] === null || obj[field] === '') {
            return field;
        }
    }
    return null;
}
//# sourceMappingURL=validators.js.map