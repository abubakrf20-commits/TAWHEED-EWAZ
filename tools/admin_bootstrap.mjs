#!/usr/bin/env node
/**
 * Bootstraps Firebase Auth admins and writes their UIDs to `config/app.adminUids`,
 * which is the only place the app reads admin rights from.
 *
 * There are NO default credentials. An earlier version of this script shipped
 * `admin@tawhid.app` / `TawhidAdmin!2026` as fallbacks, so anyone who could
 * read the repository had admin access to the production project.
 *
 * Admin paths (at least one is required):
 *   1. Google sign-in account - no password involved:
 *        $env:ADMIN_GOOGLE_EMAIL="you@gmail.com"; node tools/admin_bootstrap.mjs
 *   2. Email + password account:
 *        $env:ADMIN_EMAIL="you@yourdomain.com"
 *        $env:ADMIN_PASS="<unique passphrase, 16+ chars>"
 *        node tools/admin_bootstrap.mjs
 *
 * Optional:
 *   GOOGLE_APPLICATION_CREDENTIALS  service account key (default:
 *                                  tools/firebase-adminsdk.json, git-ignored)
 *   ADMIN_EMAIL_VERIFIED=1         mark a newly created email account verified
 *                                  (off by default; the script does not lie
 *                                  about mailbox ownership)
 *
 * Safety rules enforced here:
 *   - a weak, reused or previously-shipped password aborts the run
 *   - the password is never printed and never written to disk
 *   - an existing account is never re-created or have its password changed
 *   - the write is an arrayUnion: running this for one account never drops the
 *     other admins (use --revoke <email-or-uid> to take rights away on purpose)
 *
 * `node tools/admin_bootstrap.mjs --self-test` runs the credential policy
 * checks without contacting Firebase.
 */
import { initializeApp, cert } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { randomBytes } from 'node:crypto';
import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));

export const MIN_PASSWORD_LENGTH = 16;

/** Passwords that were ever shipped as defaults in this repository. */
const FORBIDDEN_PASSWORDS = new Set([
  'tawhidadmin!2026',
  'tawhidadmin2026',
  'admin@tawhid.app',
  'password',
  '12345678',
  'qwerty12345678',
]);

function fail(message) {
  console.error(`\nERROR: ${message}\n`);
  process.exit(1);
}

function readEnv(name) {
  const raw = process.env[name];
  if (raw == null) return null;
  const trimmed = raw.trim();
  return trimmed.length === 0 ? null : trimmed;
}

/**
 * Rejects anything that is not a unique, high-entropy passphrase.
 * Returns a list of problems; empty means acceptable.
 */
export function passwordProblems(password, email) {
  const problems = [];
  if (typeof password !== 'string' || password.length === 0) {
    return ['ADMIN_PASS is empty'];
  }
  if (password.length < MIN_PASSWORD_LENGTH) {
    problems.push(
      `shorter than ${MIN_PASSWORD_LENGTH} characters (${password.length})`,
    );
  }
  const lowered = password.toLowerCase();
  if (FORBIDDEN_PASSWORDS.has(lowered)) {
    problems.push('this value was previously shipped as a default in this repo');
  }
  if (/^(.)\1+$/.test(password)) {
    problems.push('a single repeated character');
  }
  if (/(0123456789|abcdefghij|qwertyuiop|password|admin|tawhid)/.test(lowered) &&
      lowered.replace(/(0123456789|abcdefghij|qwertyuiop|password|admin|tawhid)/g, '')
          .length < 4) {
    problems.push('mostly a keyboard pattern or a well-known word');
  }
  const classes = [/[a-z]/, /[A-Z]/, /[0-9]/, /[^A-Za-z0-9]/].filter((re) =>
      re.test(password),
  ).length;
  if (classes < 3) {
    problems.push('needs at least 3 of: lowercase, uppercase, digit, symbol');
  }
  if (email) {
    const localPart = String(email).split('@')[0].toLowerCase();
    if (localPart.length >= 6 && lowered.includes(localPart)) {
      problems.push('contains the email account name');
    }
    if (lowered === String(email).toLowerCase()) {
      problems.push('is the email address itself');
    }
  }
  return problems;
}

function selfTest() {
  const cases = [
    ['short', 'Ab1!', 'me@x.com', true],
    ['previously shipped default', 'TawhidAdmin!2026', 'me@x.com', true],
    ['single repeated char', 'a'.repeat(20), 'me@x.com', true],
    ['keyboard walk', 'qwertyuiop12345678', 'me@x.com', true],
    ['only two classes', 'alllowercaseletters', 'me@x.com', true],
    ['contains the local part', 'Abubakr.f20!secure-2026', 'abubakr.f20@gmail.com', true],
    ['strong passphrase', 'g7#Nq2!vLz9@Wp4$Ke', 'me@x.com', false],
    ['strong passphrase w/ symbols', 'River-Cedar!Lantern-97', 'me@x.com', false],
  ];
  let failures = 0;
  for (const [name, password, email, shouldFail] of cases) {
    const problems = passwordProblems(password, email);
    const ok = shouldFail ? problems.length > 0 : problems.length === 0;
    console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}`);
    if (!ok) {
      failures++;
      console.log(`      problems: ${JSON.stringify(problems)}`);
    }
  }
  if (failures > 0) {
    console.error(`\n${failures} self-test case(s) failed.`);
    process.exit(1);
  }
  console.log('\nAll credential policy self-tests passed.');
}

if (process.argv.includes('--self-test')) {
  selfTest();
  process.exit(0);
}

const revokeIndex = process.argv.indexOf('--revoke');
if (revokeIndex > -1) {
  const target = process.argv[revokeIndex + 1];
  if (!target || target.startsWith('--')) {
    fail('usage: node tools/admin_bootstrap.mjs --revoke <email-or-uid>');
  }
  await runRevoke(target);
  process.exit(0);
}

/**
 * Takes admin rights away from exactly one account. Only the `adminUids` list is
 * edited; the Auth account itself keeps existing (disable or delete it in the
 * Firebase console if it must stop existing at all).
 */
async function runRevoke(target) {
  const keyPath =
    readEnv('GOOGLE_APPLICATION_CREDENTIALS') ||
    join(__dirname, 'firebase-adminsdk.json');
  if (!existsSync(keyPath)) fail(`service account key not found: ${keyPath}`);

  initializeApp({ credential: cert(JSON.parse(readFileSync(keyPath, 'utf8'))) });
  const auth = getAuth();
  const db = getFirestore();

  let uid = target;
  if (target.includes('@')) {
    try {
      uid = (await auth.getUserByEmail(target)).uid;
    } catch {
      fail(`no Firebase Auth user with email ${target}`);
    }
  } else {
    try {
      await auth.getUser(target);
    } catch {
      fail(`no Firebase Auth user with uid ${target}`);
    }
  }

  const docRef = db.doc('config/app');
  const before = ((await docRef.get()).data()?.adminUids ?? []).map(String);
  if (!before.includes(uid)) {
    console.log(`uid ${uid} is not in adminUids; nothing changed.`);
    return;
  }
  await docRef.set(
    {
      adminUids: FieldValue.arrayRemove(uid),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  const after = ((await docRef.get()).data()?.adminUids ?? []).map(String);
  console.log(`- revoked admin  ${target}  uid=${uid}`);
  console.log('\nconfig/app.adminUids now contains:');
  for (const rest of after) console.log(`  - ${rest}`);
  if (after.length === 0) {
    console.log(
      '\nWARNING: no admin is left. Nobody can moderate suggestions or publish\n' +
        '  announcements until an account is added again.',
    );
  }
}

const googleEmail = readEnv('ADMIN_GOOGLE_EMAIL');
const adminEmail = readEnv('ADMIN_EMAIL');
const adminPass = readEnv('ADMIN_PASS');

if (!googleEmail && !adminEmail) {
  fail(
    'No admin account given.\n' +
      '  Set ADMIN_GOOGLE_EMAIL (recommended, no password), or\n' +
      '  set both ADMIN_EMAIL and ADMIN_PASS.',
  );
}
if (adminEmail && !adminPass) {
  fail(
    'ADMIN_EMAIL was given without ADMIN_PASS. Either provide a strong\n' +
      '  passphrase, or unset ADMIN_EMAIL and use ADMIN_GOOGLE_EMAIL instead.',
  );
}
if (adminPass) {
  const problems = passwordProblems(adminPass, adminEmail);
  if (problems.length > 0) {
    fail(
      `ADMIN_PASS is not acceptable:\n  - ${problems.join('\n  - ')}\n\n` +
        'Generate one instead of inventing it, e.g.:\n' +
        "  node -e \"console.log(require('crypto').randomBytes(24).toString('base64url'))\"",
    );
  }
}
if (adminEmail && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(adminEmail)) {
  fail(`ADMIN_EMAIL is not a valid address: ${adminEmail}`);
}

const KEY_PATH =
  readEnv('GOOGLE_APPLICATION_CREDENTIALS') ||
  join(__dirname, 'firebase-adminsdk.json');

if (!existsSync(KEY_PATH)) {
  fail(`service account key not found: ${KEY_PATH}`);
}

initializeApp({ credential: cert(JSON.parse(readFileSync(KEY_PATH, 'utf8'))) });
const auth = getAuth();
const db = getFirestore();

const uids = [];

// 1) Google sign-in account (no password; nothing to leak or rotate here).
if (googleEmail) {
  const users = [];
  let page = await auth.listUsers(1000);
  do {
    users.push(...page.users);
  } while (page.pageToken && (page = await auth.listUsers(1000, page.pageToken)));
  const match = users.find(
    (u) =>
      u.email?.toLowerCase() === googleEmail.toLowerCase() &&
      u.providerData.some((p) => p.providerId === 'google.com'),
  );
  if (!match) {
    fail(
      `no Firebase Auth user with a Google provider for ${googleEmail}.\n` +
        '  Sign in once with that Google account in the published app first, then re-run.',
    );
  }
  uids.push(match.uid);
  console.log(`+ google account  ${googleEmail}  uid=${match.uid}`);
}

// 2) Email/password account. An existing account is reused untouched: this
//    script must never rotate a live admin password.
if (adminEmail) {
  let emailUid = null;
  try {
    const existing = await auth.getUserByEmail(adminEmail);
    emailUid = existing.uid;
    console.log(`= existing account  ${adminEmail}  uid=${emailUid}  (untouched)`);
    if (adminPass && readEnv('ADMIN_EMAIL_VERIFIED') !== '1') {
      console.log('  note: ADMIN_PASS is only used when the account is created.');
    }
  } catch {
    const created = await auth.createUser({
      email: adminEmail,
      password: adminPass,
      emailVerified: readEnv('ADMIN_EMAIL_VERIFIED') === '1',
    });
    emailUid = created.uid;
    console.log(`+ created account  ${adminEmail}  uid=${emailUid}`);
    if (!created.emailVerified) {
      console.log(
        '  note: email left unverified. Set ADMIN_EMAIL_VERIFIED=1 only if you own the mailbox.',
      );
    }
  }
  uids.push(emailUid);
}

if (uids.length === 0) fail('no admin UIDs were resolved; nothing was written.');

// arrayUnion, not a plain array: `set(..., {merge:true})` merges the document
// but REPLACES a field given as a raw array, so writing only the accounts named
// in this run would silently delete every other admin.
await db.doc('config/app').set(
  {
    adminUids: FieldValue.arrayUnion(...uids),
    updatedAt: FieldValue.serverTimestamp(),
  },
  { merge: true },
);

const after = ((await db.doc('config/app').get()).data()?.adminUids ?? []).map(String);
console.log('\nconfig/app.adminUids now contains:');
for (const uid of after) {
  console.log(`  - ${uid}${uids.includes(uid) ? '' : '  (already an admin, kept)'}`);
}
console.log(
  '\nTo take admin rights away again:\n' +
    "  node tools/admin_bootstrap.mjs --revoke <email-or-uid>",
);
console.log(
  '\nThe passphrase was not printed or stored. Remove it from your shell history\n' +
    '  (and rotate it, if you typed it into a shared terminal).',
);
