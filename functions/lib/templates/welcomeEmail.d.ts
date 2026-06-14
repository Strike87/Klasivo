/**
 * Klasivo — Welcome Email Template
 *
 * Sent automatically when a new Firebase Auth user is created
 * (via onUserCreated auth trigger) or manually via the
 * sendWelcomeEmail callable function.
 *
 * Personalised by role: teacher / student / parent.
 */
import type { UserRole } from '../utils/validators';
/**
 * Build the HTML for the welcome email.
 *
 * @param name  — User's display name
 * @param role  — 'teacher' | 'student' | 'parent' (defaults to 'teacher')
 * @returns Complete HTML string ready for Resend
 */
export declare function buildWelcomeEmail(name: string, role?: UserRole): string;
//# sourceMappingURL=welcomeEmail.d.ts.map