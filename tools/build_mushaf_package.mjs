#!/usr/bin/env node
/**
 * build_mushaf_package.mjs
 *
 * Builds a downloadable mushaf package from the KFQC SVG dataset
 * (hafs/kfqc): converts every page SVG to WebP, bundles the ayah-polygon
 * JSON, and zips everything into one file ready to upload to a host/CDN.
 *
 * Requires: Node.js 18+ and `sharp` + `archiver` (see package.json in this
 * folder — run `npm install` here once).
 *
 * Usage:
 *   node build_mushaf_package.mjs --input <svgDir> --json <jsonDir>
 *       [--output build/mushaf] [--width 1240] [--quality 85]
 *       [--format webp|png] [--zip] [--name hafs_kfqc]
 *
 * Alternatives for size comparison:
 *   --mode br     zip the svg-br/ (brotli SVGs) folder as-is, no conversion
 *   --mode svg    zip the raw svg/ folder as-is, no conversion
 *   --mode qcf4   package the official QCF4 per-page fonts (604 zips) ready
 *                 for upload; the app downloads them from `{baseUrl}/QCF4_tajweed_NNN.zip`
 *
 * Examples:
 *   node build_mushaf_package.mjs --mode br --input ../../../../hafs/kfqc/svg-br
 *   node build_mushaf_package.mjs --width 1240 --quality 85
 *   node build_mushaf_package.mjs --mode qcf4 --input <qcf_plus>/assets/fonts/qcf_tajweed
 */
import { mkdir, readdir, copyFile, rm } from 'node:fs/promises';
import { existsSync, createWriteStream } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';
import archiver from 'archiver';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function parseArgs() {
  const a = process.argv.slice(2);
  const get = (name, dflt) => {
    const i = a.indexOf('--' + name);
    return i >= 0 && a[i + 1] ? a[i + 1] : dflt;
  };
  const has = (name) => a.includes('--' + name);
  return {
    input: get('input', path.join(__dirname, '../../../../hafs/kfqc/svg')),
    json: get('json', ''),
    output: get('output', path.join(__dirname, '../build/mushaf')),
    name: get('name', 'hafs_kfqc'),
    width: parseInt(get('width', '1240'), 10),
    quality: parseInt(get('quality', '85'), 10),
    format: get('format', 'webp'),
    mode: get('mode', 'convert'), // convert | br | svg
    zip: has('zip') || get('zip', '') === 'true',
  };
}

const args = parseArgs();

async function zipDir(dir, zipPath) {
  await new Promise((resolve, reject) => {
    const out = createWriteStream(zipPath);
    const archive = archiver('zip', { zlib: { level: 9 } });
    out.on('close', resolve);
    archive.on('error', reject);
    archive.pipe(out);
    archive.directory(dir, false);
    archive.finalize();
  });
}

function fmtMB(bytes) {
  return (bytes / 1024 / 1024).toFixed(1) + ' MB';
}

async function copyJsonInto(outDir) {
  const jsonDir = args.json || path.join(path.dirname(args.input), 'json');
  if (!existsSync(jsonDir)) {
    console.warn('[warn] json dir not found:', jsonDir, '(verse-tap polygons skipped)');
    return 0;
  }
  const dest = path.join(outDir, 'json');
  await mkdir(dest, { recursive: true });
  const files = await readdir(jsonDir);
  let bytes = 0;
  for (const f of files) {
    const src = path.join(jsonDir, f);
    const st = await import('node:fs/promises').then((m) => m.stat(src));
    if (st.isFile()) {
      await copyFile(src, path.join(dest, f));
      bytes += st.size;
    }
  }
  return bytes;
}

async function convertPages(svgDir, outPagesDir) {
  const files = (await readdir(svgDir))
    .filter((f) => /^\d{3}\.svg$/i.test(f))
    .sort();
  if (files.length === 0) {
    throw new Error('No NNN.svg pages found in ' + svgDir);
  }
  console.log(`Converting ${files.length} pages: width=${args.width} ${args.format} q=${args.quality}`);
  let total = 0;
  const t0 = Date.now();
  for (let i = 0; i < files.length; i++) {
    const src = path.join(svgDir, files[i]);
    const out = path.join(outPagesDir, files[i].replace(/\.svg$/i, '.' + args.format));
    const info = await sharp(src)
      .resize({ width: args.width })
      [args.format === 'png' ? 'png' : 'webp']({ quality: args.quality })
      .toFile(out);
    total += info.size;
    if ((i + 1) % 100 === 0 || i === files.length - 1) {
      console.log(
        `  ${String(i + 1).padStart(3)}/${files.length} pages — ${fmtMB(total)} so far (avg ${(total / (i + 1) / 1024).toFixed(0)} KB/page)`
      );
    }
  }
  const secs = ((Date.now() - t0) / 1000).toFixed(0);
  console.log(`Rendered in ${secs}s.`);
  return { count: files.length, total };
}

async function main() {
  const outRoot = path.resolve(args.output);
  const outPages = path.join(outRoot, 'pages');
  await rm(outRoot, { recursive: true, force: true });
  await mkdir(outPages, { recursive: true });

  let totalBytes = 0;
  if (args.mode === 'qcf4') {
    // Official QCF4 per-page fonts: copy the 604 page-font zips as-is into
    // a flat folder ready to upload to a host/CDN. The app downloads each
    // page from `{baseUrl}/QCF4_tajweed_NNN.zip` on demand.
    const files = (await readdir(args.input)).filter((f) => /^QCF4_tajweed_\d{3}\.zip$/i.test(f)).sort();
    if (files.length === 0) {
      throw new Error('No QCF4_tajweed_NNN.zip files found in ' + args.input);
    }
    for (const f of files) {
      await copyFile(path.join(args.input, f), path.join(outPages, f));
      const st = await import('node:fs/promises').then((m) => m.stat(path.join(args.input, f)));
      totalBytes += st.size;
    }
    console.log(`Packaged ${files.length} QCF4 page fonts (${fmtMB(totalBytes)}).`);
    console.log('Upload the folder to your host; set mushafBaseUrl in the app accordingly.');
    console.log('The app will fetch: {baseUrl}/QCF4_tajweed_NNN.zip for each page.');
  } else if (args.mode === 'br' || args.mode === 'svg') {
    // No conversion: copy the (already compressed) SVGs as-is.
    const files = (await readdir(args.input)).filter((f) => !f.startsWith('.'));
    for (const f of files) {
      await copyFile(path.join(args.input, f), path.join(outPages, f));
    }
    totalBytes = files.reduce((acc, f) => acc + 0, 0);
    for (const f of files) {
      const st = await import('node:fs/promises').then((m) => m.stat(path.join(args.input, f)));
      totalBytes += st.size;
    }
    console.log(`Copied ${files.length} files from ${args.mode === 'br' ? 'svg-br' : 'svg'} (no conversion).`);
  } else {
    const r = await convertPages(args.input, outPages);
    totalBytes = r.total;
  }

  const jsonBytes = await copyJsonInto(outRoot);
  console.log(`Page files: ${fmtMB(totalBytes)} | JSON polygons: ${fmtMB(jsonBytes)}`);

  if (args.zip) {
    const zipPath = path.join(path.dirname(outRoot), `${args.name}.zip`);
    await zipDir(outRoot, zipPath);
    const st = await import('node:fs/promises').then((m) => m.stat(zipPath));
    console.log('──────────────────────────────────────');
    console.log(`FINAL: ${fmtMB(st.size)}  ->  ${zipPath}`);
    console.log(`(extracted on phone: ~${fmtMB(totalBytes + jsonBytes)} on disk)`);
  } else {
    console.log('Done. Folder:', outRoot, `(${fmtMB(totalBytes + jsonBytes)})`);
    console.log('Run with --zip to also produce the .zip archive.');
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
