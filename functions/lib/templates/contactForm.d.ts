/**
 * Klasivo — Contact Form Notification Template
 *
 * Sent to the Klasivo support team when a visitor submits
 * the public contact form on the website.
 *
 * Recipient: support@klasivo.app
 * Reply-To:  the submitter's email
 */
export interface ContactFormPayload {
    name: string;
    email: string;
    subject: string;
    message: string;
}
/**
 * Build the HTML for a contact-form notification email.
 *
 * @returns Complete HTML string ready for Resend
 */
export declare function buildContactNotification(payload: ContactFormPayload): string;
//# sourceMappingURL=contactForm.d.ts.map