interface ContactFormParams {
    name: string;
    email: string;
    subject: string;
    message: string;
}
export declare function buildContactFormHtml(params: ContactFormParams): string;
export {};
