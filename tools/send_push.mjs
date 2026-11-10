#!/usr/bin/env node
/**
 * ارسال اعلان پوش به همهٔ کاربران — بدون نیاز به Cloud Functions / پلن Blaze.
 *
 *   node tools/send_push.mjs "عنوان اعلان" "متن اعلان"
 *
 * آماده‌سازی (فقط یک‌بار):
 *   ۱. کنسول Firebase → Project settings → Service accounts →
 *      «Generate new private key» → فایل JSON را با نام firebase-adminsdk.json
 *      در همین پوشه (tools/) بگذارید. (این فایل راز است و در git ایگنور شده.)
 *
 * بعدها اگر به Cloud Function ارتقا دادید، این اسکریپت فقط برای موارد فوری
 * کاربرد دارد؛ قرارداد پیام همان است (موضوع all).
 */
import { createSign } from 'node:crypto';
import { readFileSync, existsSync } from 'node:fs';
import { request } from 'node:https';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));

const PROJECT_ID = process.env.FIREBASE_PROJECT_ID || 'tawheed-1f347';
const KEY_PATH =
  process.env.GOOGLE_APPLICATION_CREDENTIALS ||
  join(__dirname, 'firebase-adminsdk.json');
const TOPIC = 'all';

if (!existsSync(KEY_PATH)) {
  console.error(
    `فایل کلید یافت نشد: ${KEY_PATH}\n` +
      'از کنسول Firebase → Settings → Service accounts → Generate new private key دریافت کنید\n' +
      'و در tools/firebase-adminsdk.json بگذارید.',
  );
  process.exit(1);
}

if (process.argv.length < 4 || !process.argv[2]?.trim()) {
  console.error('\u0646\u062D\u0648\u0647\u0654 \u0627\u0633\u062A\u0641\u0627\u062F\u0647:   node tools/send_push.mjs "\u0639\u0646\u0648\u0627\u0646" "\u0645\u062A\u0646"');
  process.exit(1);
}

const title = process.argv[2].trim();
const body = process.argv[3]?.trim() ?? '';

function postJson(url, payload, token) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const req = request(
      {
        hostname: u.hostname,
        path: u.pathname,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
      },
      (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () => resolve({ status: res.statusCode, body: data }));
      },
    );
    req.on('error', reject);
    req.end(JSON.stringify(payload));
  });
}

function base64url(s) {
  return Buffer.from(s).toString('base64url');
}

async function getAccessToken(account) {
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = base64url(
    JSON.stringify({
      iss: account.client_email,
      scope:
        'https://www.googleapis.com/auth/cloud-platform https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    }),
  );
  const unsigned = `${header}.${claims}`;
  const signer = createSign('RSA-SHA256');
  signer.update(unsigned);
  const signature = signer.sign(account.private_key, 'base64url');
  const assertion = `${unsigned}.${signature}`;

  const res = await postJson(
    'https://oauth2.googleapis.com/token',
    {
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    },
  );
  if (res.status !== 200) {
    throw new Error(`دریافت توکن ناموفق بود (${res.status}): ${res.body}`);
  }
  return JSON.parse(res.body).access_token;
}

async function sendPush(token) {
  const res = await postJson(
    `https://fcm.googleapis.com/v1/projects/${PROJECT_ID}/messages:send`,
    {
      message: {
        topic: TOPIC,
        notification: { title, body },
        android: {
          notification: {
            channel_id: 'custom_reminders_v2',
            sound: 'ios17',
            color: '#C48A27',
            icon: 'ic_notification',
          },
        },
      },
    },
    token,
  );
  if (res.status !== 200) {
    const detail = (() => {
      try {
        return JSON.parse(res.body)?.error?.message ?? res.body;
      } catch {
        return res.body;
      }
    })();
    throw new Error(`ارسال اعلان ناموفق بود (${res.status}): ${detail}`);
  }
  return res.body;
}

try {
  const account = JSON.parse(readFileSync(KEY_PATH, 'utf8'));
  const token = await getAccessToken(account);
  await sendPush(token);
  console.log('✓ اعلان به همهٔ کاربران ارسال شد:');
  console.log(`   عنوان: ${title}`);
  console.log(`   متن:   ${body || '(بدون متن)'}`);
  console.log(`   موضوع: ${TOPIC}`);
} catch (e) {
  console.error('خطا:', e.message);
  process.exit(1);
}