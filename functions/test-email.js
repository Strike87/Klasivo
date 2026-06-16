/**
 * Klasivo — Email Test Script
 *
 * Run:  cd functions && node test-email.js <RESEND_API_KEY> <YOUR_EMAIL>
 * Example:
 *   node test-email.js re_xxxxxxxxxxxx your-email@gmail.com
 */

const { Resend } = require('resend');

// ─── Parse arguments ─────────────────────────────────────────
const apiKey = process.argv[2];
const testEmail = process.argv[3];

if (!apiKey || !testEmail) {
  console.log('');
  console.log('  Usage:  node test-email.js <RESEND_API_KEY> <YOUR_EMAIL>');
  console.log('');
  console.log('  Example:');
  console.log('    node test-email.js re_abc123 your-email@gmail.com');
  console.log('');
  process.exit(1);
}

// ─── Load templates ──────────────────────────────────────────
const { buildWelcomeHtml } = require('./services/emailTemplates');
const { buildContactFormHtml } = require('./services/emailTemplates');

// ─── Run tests ───────────────────────────────────────────────
async function runTests() {
  const resend = new Resend(apiKey);

  console.log('');
  console.log('═══════════════════════════════════════════════════════════');
  console.log('  Klasivo Email Test — Resend Integration');
  console.log('═══════════════════════════════════════════════════════════');
  console.log(`  Sending to: ${testEmail}`);
  console.log('');

  // ── Test 1: Welcome Email (Teacher) ─────────────────────────
  console.log('  [1/4] Sending Welcome Email (Teacher role)...');
  try {
    const { data, error } = await resend.emails.send({
      from: 'Klasivo <noreply@send.klasivo.app>',
      to: testEmail,
      subject: 'Welcome to Klasivo — Your Smart School Platform',
      html: buildWelcomeHtml('Ahmed', 'teacher'),
    });
    if (error) {
      console.log(`         FAILED: ${error.message}`);
    } else {
      console.log(`         OK — Email ID: ${data.id}`);
    }
  } catch (err) {
    console.log(`         ERROR: ${err.message}`);
  }

  // ── Test 2: Welcome Email (Student) ─────────────────────────
  console.log('  [2/4] Sending Welcome Email (Student role)...');
  try {
    const { data, error } = await resend.emails.send({
      from: 'Klasivo <noreply@send.klasivo.app>',
      to: testEmail,
      subject: 'Welcome to Klasivo — Your Smart School Platform',
      html: buildWelcomeHtml('Sara', 'student'),
    });
    if (error) {
      console.log(`         FAILED: ${error.message}`);
    } else {
      console.log(`         OK — Email ID: ${data.id}`);
    }
  } catch (err) {
    console.log(`         ERROR: ${err.message}`);
  }

  // ── Test 3: Contact Form Notification ───────────────────────
  console.log('  [3/4] Sending Contact Form Notification...');
  try {
    const { data, error } = await resend.emails.send({
      from: 'Klasivo <noreply@send.klasivo.app>',
      to: testEmail,
      subject: 'New Contact Form: Question about pricing',
      html: buildContactFormHtml({
        name: 'Mohamed',
        email: 'mohamed@example.com',
        subject: 'Question about pricing',
        message: 'Hello, I would like to know more about Klasivo pricing for my school with 200 students. Can you help?',
      }),
      replyTo: 'mohamed@example.com',
    });
    if (error) {
      console.log(`         FAILED: ${error.message}`);
    } else {
      console.log(`         OK — Email ID: ${data.id}`);
    }
  } catch (err) {
    console.log(`         ERROR: ${err.message}`);
  }

  // ── Test 4: Raw Resend Ping (minimal) ──────────────────────
  console.log('  [4/4] Sending Minimal Test Email...');
  try {
    const { data, error } = await resend.emails.send({
      from: 'Klasivo <noreply@send.klasivo.app>',
      to: testEmail,
      subject: 'Klasivo Email Test — If you see this, Resend works!',
      html: '<h1>It works!</h1><p>Your Resend integration is correctly configured.</p>',
    });
    if (error) {
      console.log(`         FAILED: ${error.message}`);
    } else {
      console.log(`         OK — Email ID: ${data.id}`);
    }
  } catch (err) {
    console.log(`         ERROR: ${err.message}`);
  }

  console.log('');
  console.log('═══════════════════════════════════════════════════════════');
  console.log('  Check your inbox: ' + testEmail);
  console.log('  (Also check spam/junk folder if not visible)');
  console.log('═══════════════════════════════════════════════════════════');
  console.log('');
}

runTests().catch((err) => {
  console.error('Fatal error:', err.message);
  process.exit(1);
});
