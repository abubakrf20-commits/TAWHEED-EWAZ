#!/usr/bin/env node
/**
 * ارسال اعلان پوش — پنجرهٔ محلی **تماماً رایگان** (بدون Cloud Functions / Blaze).
 *
 * اجرا:
 *   node tools/fcm_server.mjs
 *
 * مرورگر به‌طور خودکار باز می‌شود (http://localhost:8787). اگر نشد خودتان
 * آدرس را باز کنید. «عنوان» و «متن» را می‌نویسید و «ارسال به همه». تاریخچهٔ
 * ارسال‌ها هم در همان صفحه و در فایل .fcm_history.json (ایگنور) ذخیره می‌شود.
 */
import { createSign, randomBytes } from 'node:crypto';
import { createServer } from 'node:http';
import {
  appendFileSync,
  existsSync,
  readFileSync,
  writeFileSync,
} from 'node:fs';
import { request } from 'node:https';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));

const PORT = Number(process.env.FCM_PORT || 8787);
const PROJECT_ID = process.env.FIREBASE_PROJECT_ID || 'tawheed-1f347';
const TOPIC = 'all';
const KEY_PATH =
  process.env.GOOGLE_APPLICATION_CREDENTIALS ||
  join(__dirname, 'firebase-adminsdk.json');
const HISTORY_FILE = join(__dirname, '.fcm_history.json');
const URL_HINT = `http://localhost:${PORT}`;

// A random secret minted per run. The page it serves carries the token, so a
// visitor has it, but a *different* web page cannot: without this, any site
// the developer visits could POST to /send and push a notification to every
// user of the app.
const TOKEN = randomBytes(24).toString('base64url');

// Requests the browser may make. A cross-origin request to 127.0.0.1 has an
// Origin we do not recognise and is refused outright.
function isOwnOrigin(req) {
  const origin = req.headers.origin;
  if (!origin) return true; // curl / PowerShell, no browser involved
  try {
    const { hostname, port } = new URL(origin);
    return (
      (hostname === '127.0.0.1' || hostname === 'localhost') &&
      (port === String(PORT) || port === '')
    );
  } catch {
    return false;
  }
}

function hasToken(req, url) {
  return (
    req.headers['x-fcm-token'] === TOKEN ||
    url.searchParams.get('token') === TOKEN
  );
}

if (!existsSync(KEY_PATH)) {
  console.error(
    `کلید یافت نشد: ${KEY_PATH}\n` +
      'از کنسول Firebase → Settings → Service accounts → Generate new private key دریافت و\n' +
      'با نام firebase-adminsdk.json در tools/ بگذارید.',
  );
  process.exit(1);
}
const ACCOUNT = JSON.parse(readFileSync(KEY_PATH, 'utf8'));

// ─────────────────────────── FCM ───────────────────────────
function base64url(s) {
  return Buffer.from(s).toString('base64url');
}

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

async function getAccessToken() {
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = base64url(
    JSON.stringify({
      iss: ACCOUNT.client_email,
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
  const assertion = `${unsigned}.${signer.sign(ACCOUNT.private_key, 'base64url')}`;

  const res = await postJson('https://oauth2.googleapis.com/token', {
    grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
    assertion,
  });
  if (res.status !== 200) {
    throw new Error(`توکن ناموفق (${res.status})`);
  }
  return JSON.parse(res.body).access_token;
}

async function sendPush(token, title, body) {
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
    let detail = res.body;
    try {
      detail = JSON.parse(res.body)?.error?.message ?? res.body;
    } catch {}
    throw new Error(detail);
  }
  return true;
}

// ─────────────────────────── پیشنهادهای کاربران (Firestore REST) ─────────────
function getJson(url, token) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const req = request(
      {
        hostname: u.hostname,
        path: u.pathname + u.search,
        method: 'GET',
        headers: { Authorization: `Bearer ${token}` },
      },
      (res) => {
        let data = '';
        res.on('data', (c) => (data += c));
        res.on('end', () =>
          resolve({ status: res.statusCode, body: data }),
        );
      },
    );
    req.on('error', reject);
    req.end();
  });
}

async function listSuggestions(token, limit = 50) {
  const url =
    `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}` +
    `/databases/(default)/documents/suggestions?` +
    'orderBy=createdAt%20desc&pageSize=' +
    Math.min(100, limit);
  const res = await getJson(url, token);
  if (res.status !== 200) {
    throw new Error(
      `دریافت پیشنهادها ناموفق بود (${res.status}): ${res.body}`,
    );
  }
  const root = JSON.parse(res.body);
  const docs = root.documents ?? [];
  return docs.map((doc) => {
    const f = doc.fields ?? {};
    const text = f.text?.stringValue ?? '';
    const category = f.category?.stringValue ?? '';
    const deviceTag = f.deviceTag?.stringValue ?? '';
    const createdAt = f.createdAt?.timestampValue
      ? new Date(f.createdAt.timestampValue).toISOString()
      : '';
    return {
      id: (doc.name ?? '').split('/').pop(),
      text,
      category,
      deviceTag,
      createdAt,
    };
  });
}

// ─────────────────────────── تاریخچهٔ محلی ───────────────────────────
function loadHistory() {
  try {
    return JSON.parse(readFileSync(HISTORY_FILE, 'utf8'));
  } catch {
    return [];
  }
}

function pushHistory(entry) {
  const list = loadHistory();
  list.unshift({ ts: Date.now(), ...entry });
  writeFileSync(HISTORY_FILE, JSON.stringify(list.slice(0, 30), null, 2), 'utf8');
}

// ─────────────────────────── صفحهٔ وب ───────────────────────────
const PAGE = `<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>ارسال اعلان پوش — توحید</title>
<style>
  :root { color-scheme: light; }
  * { box-sizing: border-box; font-family: "Segoe UI", Tahoma, sans-serif; }
  body { margin:0; background:#f2f4f8; color:#1a1a2e; display:flex; justify-content:center; padding:32px 16px; }
  .card { width:100%; max-width:520px; background:#fff; border-radius:16px; padding:24px;
          box-shadow:0 4px 20px rgba(0,0,0,.08); }
  h1 { font-size:20px; margin:0 0 4px; }
  .sub { color:#5a6472; font-size:13px; margin:0 0 20px; }
  label { display:block; font-size:13px; font-weight:600; margin:14px 0 6px; }
  input, textarea { width:100%; padding:10px 12px; border:1px solid #c9d1de; border-radius:10px;
                    font-size:14px; outline:none; }
  input:focus, textarea:focus { border-color:#1565c0; }
  textarea { resize:vertical; min-height:96px; }
  button { width:100%; margin-top:20px; padding:12px; background:#1565c0; color:#fff; border:0;
           border-radius:10px; font-size:15px; font-weight:700; cursor:pointer; }
  button:disabled { opacity:.6; cursor:not-allowed; }
  #status { margin-top:14px; font-size:13px; border-radius:10px; padding:10px 12px; display:none; }
  #status.ok { display:block; background:#e6f4ea; color:#1e7d34; }
  #status.err { display:block; background:#fdecea; color:#b3261e; white-space:pre-wrap; }
  .hist { margin-top:24px; border-top:1px solid #e4e9f0; padding-top:16px; }
  .hist h2 { font-size:14px; margin:0 0 10px; color:#3a4258; }
  .items { display:flex; flex-direction:column; gap:8px; }
  .item { border:1px solid #e4e9f0; border-radius:10px; padding:10px 12px; font-size:13px; }
  .item .t { font-weight:600; }
  .item .b { color:#5a6472; margin-top:4px; }
  .cat { display:inline-block; background:#eef2fa; color:#1565c0; border-radius:999px;
         padding:1px 10px; font-size:11px; }
  .item .meta { display:flex; justify-content:space-between; margin-top:6px; font-size:11px; color:#8a93a1; }
  .dot { display:inline-block; width:8px; height:8px; border-radius:50%; margin-inline-start:4px; vertical-align:middle; }
  .dot.ok { background:#1e7d34; } .dot.err { background:#b3261e; }
  .hint { margin-top:18px; font-size:11px; color:#8a93a1; }
  .empty { color:#8a93a1; font-size:13px; }
</style>
</head>
<body>
<div class="card">
  <h1>ارسال اعلان پوش</h1>
  <p class="sub">به همهٔ کاربرانِ نصب‌شدهٔ توحید (موضوع all) — رایگان و بدون سرور.</p>
  <label for="t">عنوان</label>
  <input id="t" maxlength="80" placeholder="مثلاً نسخه ۱٫۸ آمد">
  <label for="b">متن</label>
  <textarea id="b" maxlength="300" placeholder="متن اعلان…"></textarea>
  <button id="go">ارسال به همه</button>
  <div id="status"></div>
  <div class="hist">
    <h2>تاریخچهٔ اخیر</h2>
    <div class="items" id="hist"><div class="empty">در حال بارگذاری…</div></div>
  </div>
  <div class="hist">
    <h2>پیشنهادهای کاربران</h2>
    <div class="items" id="sug"><div class="empty">در حال بارگذاری…</div></div>
  </div>
  <p class="hint">این ابزار فقط روی همین سیستم اجرا می‌شود و اعلان را با صدای «یادآورها» می‌فرستد.</p>
</div>
<script>
const go = document.getElementById('go');
const status = document.getElementById('status');
const hist = document.getElementById('hist');
const sug = document.getElementById('sug');
const TOKEN = '__TOKEN__';
const api = (path, opts) => fetch(path, Object.assign({
  headers: { 'X-FCM-Token': TOKEN },
}, opts));
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
}[c]));
const CAT_FA = { suggestion: 'پیشنهاد', complaint: 'انتقاد', bug: 'گزارش مشکل', other: 'سایر' };
function fmtTime(iso) {
  const d = new Date(iso);
  return d.toLocaleDateString('fa-IR') + ' · ' + d.toLocaleTimeString('fa-IR', { hour: '2-digit', minute: '2-digit' });
}
async function reloadSuggestions() {
  try {
    const r = await api('/suggestions');
    const j = await r.json();
    if (!j.ok) { sug.innerHTML = '<div class="empty">خطا: ' + esc(j.error || 'نامشخص') + '</div>'; return; }
    if (!j.items.length) { sug.innerHTML = '<div class="empty">هنوز پیشنهادی ارسال نشده است.</div>'; return; }
    sug.innerHTML = j.items.map(it => {
      const cat = it.category ? '<span class="cat">' + esc(CAT_FA[it.category] || it.category) + '</span>' : '';
      return '<div class="item"><div class="b">' + esc(it.text) + '</div>' +
        '<div class="meta"><span>' + cat + ' ' + esc(it.deviceTag || '') + '</span>' +
        '<span>' + fmtTime(it.createdAt) + '</span></div></div>';
    }).join('');
  } catch (e) {
    sug.innerHTML = '<div class="empty">خطا در دریافت پیشنهادها</div>';
  }
}
async function reloadHistory() {
  try {
    const r = await api('/history');
    const j = await r.json();
    if (!j.items || j.items.length === 0) {
      hist.innerHTML = '<div class="empty">هنوز اعلانی ارسال نشده است.</div>';
      return;
    }
    hist.innerHTML = j.items.map(it => {
      const time = new Date(it.ts).toLocaleTimeString('fa-IR', { hour: '2-digit', minute: '2-digit' });
      const date = new Date(it.ts).toLocaleDateString('fa-IR');
      const ok = it.ok === true;
      // These come back from the server as free text: an FCM error can echo
      // remote content, so they are escaped like the suggestions list is.
      const err = it.error ? '<div class="meta"><span>خطا: ' + esc(it.error) + '</span></div>' : '';
      return '<div class="item"><div class="t"><span class="dot ' + (ok?'ok':'err') + '"></span>' +
        esc(it.title || '(بدون عنوان)') + '</div>' +
        (it.body ? '<div class="b">' + esc(it.body) + '</div>' : '') +
        '<div class="meta"><span>' + (ok ? 'ارسال شد' : 'ناموفق') + '</span><span>' + date + ' · ' + time + '</span></div>' + err + '</div>';
    }).join('');
  } catch (e) {
    hist.innerHTML = '<div class="empty">خطا در دریافت تاریخچه</div>';
  }
}
go.addEventListener('click', async () => {
  const title = document.getElementById('t').value.trim();
  const body = document.getElementById('b').value.trim();
  if (!title && !body) { show('err', 'عنوان یا متن را بنویسید.'); return; }
  go.disabled = true; go.textContent = 'در حال ارسال…'; show(null);
  try {
    const r = await api('/send', { method:'POST', headers:{'Content-Type':'application/json','X-FCM-Token':TOKEN},
      body: JSON.stringify({ title, body }) });
    const j = await r.json();
    if (j.ok) { show('ok', '✓ اعلان به همهٔ کاربران ارسال شد.'); document.getElementById('t').value=''; document.getElementById('b').value=''; }
    else { show('err', 'خطا: ' + (j.error || 'نامشخص')); }
    await reloadHistory();
  } catch (e) { show('err', 'خطا در ارتباط: ' + e.message); }
  finally { go.disabled = false; go.textContent = 'ارسال به همه'; }
});
function show(kind, text) {
  if (!kind) { status.style.display = 'none'; return; }
  status.className = kind; status.textContent = text;
}
reloadHistory();
reloadSuggestions();
setInterval(reloadHistory, 15000);
setInterval(reloadSuggestions, 15000);
</script>
</body>
</html>`;

// ─────────────────────────── سرور ───────────────────────────
function openBrowser(url) {
  const win = process.platform === 'win32';
  const cmd = win ? 'cmd' : process.platform === 'darwin' ? 'open' : 'xdg-open';
  const args = win ? ['/c', 'start', '', url] : [url];
  try {
    spawn(cmd, args, { detached: true, stdio: 'ignore' }).unref();
  } catch {}
}

const server = createServer(async (req, res) => {
  const url = new URL(req.url, URL_HINT);

  const json = (code, obj) => {
    res.writeHead(code, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify(obj));
  };

  if (req.method === 'GET' && url.pathname === '/') {
    // The page itself must load before it can present the token.
    res.writeHead(200, {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'no-store',
    });
    res.end(PAGE.replace('__TOKEN__', TOKEN));
    return;
  }

  if (url.pathname === '/history' || url.pathname === '/suggestions' ||
      url.pathname === '/send') {
    if (!isOwnOrigin(req)) {
      json(403, { ok: false, error: 'cross-origin request refused' });
      return;
    }
    if (!hasToken(req, url)) {
      json(403, { ok: false, error: 'missing or wrong token' });
      return;
    }
  }

  if (req.method === 'GET' && url.pathname === '/history') {
    json(200, { items: loadHistory() });
    return;
  }

  if (req.method === 'GET' && url.pathname === '/suggestions') {
    try {
      const token = await getAccessToken();
      const items = await listSuggestions(token, 100);
      json(200, { ok: true, items });
    } catch (e) {
      json(500, { ok: false, error: e.message });
    }
    return;
  }

  if (req.method === 'POST' && url.pathname === '/send') {
    let raw = '';
    let tooBig = false;
    for await (const chunk of req) {
      raw += chunk;
      if (raw.length > 64 * 1024) {
        tooBig = true;
        break;
      }
    }
    if (tooBig) {
      json(413, { ok: false, error: 'request body too large' });
      return;
    }
    let title = '';
    let body = '';
    try {
      ({ title, body } = JSON.parse(raw || '{}'));
    } catch {
      json(400, { ok: false, error: 'JSON نامعتبر' });
      return;
    }
    title = (title || '').toString().trim();
    body = (body || '').toString().trim();
    if (!title && !body) {
      json(400, { ok: false, error: 'عنوان یا متن خالی است' });
      return;
    }
    try {
      const token = await getAccessToken();
      await sendPush(token, title, body);
      pushHistory({ title, body, ok: true });
      console.log(`✓ sent: ${title}`);
      json(200, { ok: true });
    } catch (e) {
      pushHistory({ title, body, ok: false, error: e.message });
      console.error('× error:', e.message);
      json(500, { ok: false, error: e.message });
    }
    return;
  }

  res.writeHead(404);
  res.end('Not found');
});

server.on('error', (e) => {
  if (e.code === 'EADDRINUSE') {
    console.log(`سرویس از قبل در حال اجراست — باز کردن ${URL_HINT}`);
    openBrowser(URL_HINT);
    process.exit(0);
  }
  throw e;
});

server.listen(PORT, '127.0.0.1', () => {
  console.log('✓ ابزار ارسال اعلان توحید آماده است. مرورگر به‌زودی باز می‌شود:');
  console.log(`   آدرس: http://localhost:${PORT}`);
  if (process.platform === 'win32') {
    console.log('   اگر باز نشد، فقط این آدرس را در مرورگر بزنید.');
  }
  openBrowser(URL_HINT);
});