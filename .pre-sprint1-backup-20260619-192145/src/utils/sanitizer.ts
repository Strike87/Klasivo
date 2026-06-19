export function sanitizeText(input: string, maxLength: number): string {
  return input.slice(0, maxLength).trim();
}

export function sanitizeEmail(input: string): string {
  return input.trim().toLowerCase();
}

export function sanitizeFields(
  fields: Record<string, string>,
  maxLens: Record<string, number>
): Record<string, string> {
  const result: Record<string, string> = {};
  for (const [key, value] of Object.entries(fields)) {
    result[key] = sanitizeText(value, maxLens[key] ?? 100);
  }
  return result;
}
