const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function isValidEmail(email: string): boolean {
  return EMAIL_RE.test(email);
}

export function isValidRole(role: string): boolean {
  return ['owner', 'teacher', 'student', 'parent'].includes(role);
}

export function isValidPriority(priority: string): boolean {
  return ['normal', 'important', 'urgent'].includes(priority);
}

export function isValidRecipientList(recipients: string[]): boolean {
  return recipients.length > 0 && recipients.length <= 50;
}

export function missingField(
  data: Record<string, unknown>,
  required: string[]
): string | null {
  for (const field of required) {
    const value = data[field];
    if (value === undefined || value === null || value === '') {
      return field;
    }
  }
  return null;
}
