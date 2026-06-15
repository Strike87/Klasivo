"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.sanitizeText = sanitizeText;
exports.sanitizeEmail = sanitizeEmail;
exports.sanitizeFields = sanitizeFields;
function sanitizeText(input, maxLength) {
    return input.slice(0, maxLength).trim();
}
function sanitizeEmail(input) {
    return input.trim().toLowerCase();
}
function sanitizeFields(fields, maxLens) {
    const result = {};
    for (const [key, value] of Object.entries(fields)) {
        result[key] = sanitizeText(value, maxLens[key] ?? 100);
    }
    return result;
}
//# sourceMappingURL=sanitizer.js.map