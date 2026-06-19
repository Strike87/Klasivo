export const BRAND_COLORS = {
  primary: '#1A3A8A',
  secondary: '#2563EB',
  accent: '#3B82F6',
  background: '#F8FAFC',
  text: '#1E293B',
  muted: '#64748B',
  success: '#10B981',
  warning: '#F59E0B',
  danger: '#EF4444',
} as const;

export function emailWrapper(content: string, preview: string): string {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Klasivo</title>
  <style>
    body { margin: 0; padding: 0; font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: ${BRAND_COLORS.background}; color: ${BRAND_COLORS.text}; }
    .container { max-width: 600px; margin: 0 auto; background: #FFFFFF; border-radius: 12px; overflow: hidden; }
    .header { background: ${BRAND_COLORS.primary}; padding: 32px 24px; text-align: center; }
    .header h1 { color: #FFFFFF; margin: 0; font-size: 24px; font-weight: 700; }
    .body { padding: 32px 24px; }
    .footer { padding: 24px; text-align: center; color: ${BRAND_COLORS.muted}; font-size: 13px; border-top: 1px solid #E2E8F0; }
    .cta-button { display: inline-block; background: ${BRAND_COLORS.secondary}; color: #FFFFFF; text-decoration: none; padding: 14px 28px; border-radius: 8px; font-weight: 600; font-size: 16px; }
    .note { background: #EFF6FF; border-left: 4px solid ${BRAND_COLORS.secondary}; padding: 16px; margin: 16px 0; border-radius: 0 8px 8px 0; }
    .detail { margin: 8px 0; }
    .detail-label { font-weight: 600; color: ${BRAND_COLORS.muted}; font-size: 13px; text-transform: uppercase; letter-spacing: 0.05em; }
    .detail-value { color: ${BRAND_COLORS.text}; font-size: 16px; margin-top: 4px; }
  </style>
</head>
<body style="margin:0;padding:0;background:${BRAND_COLORS.background};">
  <!--[if mso]><table width="100%" cellpadding="0" cellspacing="0"><tr><td><![endif]-->
  <div style="max-width:600px;margin:0 auto;padding:20px 0;">
    <div class="container">
      <div class="header">
        <h1>Klasivo</h1>
      </div>
      <div class="body">
        ${content}
      </div>
      <div class="footer">
        <p>Klasivo — Smart School Management Platform</p>
        <p>noreply@klasivo.app</p>
      </div>
    </div>
  </div>
  <!--[if mso]></td></tr></table><![endif]-->
</body>
</html>`;
}
