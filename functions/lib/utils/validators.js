"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.isValidEmail = isValidEmail;
exports.isValidRole = isValidRole;
exports.isValidPriority = isValidPriority;
exports.isValidRecipientList = isValidRecipientList;
exports.missingField = missingField;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
function isValidEmail(email) {
    return EMAIL_RE.test(email);
}
function isValidRole(role) {
    return ['owner', 'teacher', 'student', 'parent'].includes(role);
}
function isValidPriority(priority) {
    return ['normal', 'important', 'urgent'].includes(priority);
}
function isValidRecipientList(recipients) {
    return recipients.length > 0 && recipients.length <= 50;
}
function missingField(data, required) {
    for (const field of required) {
        const value = data[field];
        if (value === undefined || value === null || value === '') {
            return field;
        }
    }
    return null;
}
//# sourceMappingURL=validators.js.map