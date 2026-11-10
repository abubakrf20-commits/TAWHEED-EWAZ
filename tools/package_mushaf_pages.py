#!/usr/bin/env python3
"""
package_mushaf_pages.py

Packages the Golden-Mushaf page images (extracted from the "المصحف الذهبي"
app's `fahadv3` asset) into GitHub-hostable zip parts that the Tawheed app
downloads once and keeps forever.

Why parts? The full package is ~103 MB; GitHub serves files up to 100 MB and
jsDelivr caps at 20 MB, so the mushaf is split by page ranges (each part
~25 MB) and downloaded/extracted by the app in order.

Usage:
  python tools/package_mushaf_pages.py \
      --src <dir containing per-page strip folders, e.g. fahadv3/fahadv3> \
      --out <output dir>

Output (in --out):
  mushaf_pages_1of4.zip  pages 1..151
  mushaf_pages_2of4.zip  pages 152..302
  mushaf_pages_3of4.zip  pages 303..453
  mushaf_pages_4of4.zip  pages 454..604
  mushaf_pages.json      manifest: { "version": 1, "parts": [ ... ] }

Strip layout: page <p> is rendered by stacking its strips `<p>/<n>.png`
vertically, n = 1..stripCount(p), top to bottom.
"""

import argparse
import json
import os
import zipfile


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument('--src', required=True,
                   help='Directory with one sub-folder per page (1..604).')
    p.add_argument('--out', default='build/mushaf_pages',
                   help='Output directory for the zip parts + manifest.')
    p.add_argument('--parts', type=int, default=4,
                   help='Number of zip parts to split the pages into.')
    return p.parse_args()


def page_strip_counts(src):
    """Return {page: [strip filenames]} skipping non-page entries."""
    result = {}
    for name in os.listdir(src):
        full = os.path.join(src, name)
        if not os.path.isdir(full) or not name.isdigit():
            continue
        page = int(name)
        if not 1 <= page <= 604:
            continue
        strips = sorted(
            (f for f in os.listdir(full) if f.endswith('.png')),
            key=lambda f: int(f[:-4]),
        )
        result[page] = strips
    return result


def split_ranges(total_pages, parts):
    size = (total_pages + parts - 1) // parts
    ranges = []
    start = 1
    while start <= total_pages:
        end = min(start + size - 1, total_pages)
        ranges.append((start, end))
        start = end + 1
    return ranges


def main():
    args = parse_args()
    counts = page_strip_counts(args.src)
    if not counts:
        raise SystemExit('No page folders found under --src')
    print(f'{len(counts)} pages, {sum(len(v) for v in counts.values())} strips')

    os.makedirs(args.out, exist_ok=True)
    manifest_parts = []
    ranges = split_ranges(604, args.parts)

    for idx, (start, end) in enumerate(ranges, start=1):
        part_name = f'mushaf_pages_{idx}of{len(ranges)}.zip'
        part_path = os.path.join(args.out, part_name)
        total = 0
        with zipfile.ZipFile(part_path, 'w', zipfile.ZIP_STORED) as zf:
            for page in range(start, end + 1):
                strips = counts.get(page)
                if strips is None:
                    print(f'  WARN: page {page} missing, writing empty dir')
                    zf.writestr(f'mushaf_pages/{page}/', '')
                    continue
                for strip in strips:
                    zf.write(
                        os.path.join(args.src, str(page), strip),
                        f'mushaf_pages/{page}/{strip}',
                    )
                    total += 1
        size_mb = os.path.getsize(part_path) / (1024 * 1024)
        print(f'{part_name}: pages {start}-{end}, {total} strips, {size_mb:.1f} MB')
        manifest_parts.append({
            'file': part_name,
            'pagesFrom': start,
            'pagesTo': end,
            'sizeMB': round(size_mb, 1),
        })

    manifest = {
        'version': 1,
        'name': 'mushaf_pages',
        'description': 'Golden Mushaf (Madani 1441) page strips, top-to-bottom',
        'stripHeightPx': 232,
        'parts': manifest_parts,
    }
    manifest_path = os.path.join(args.out, 'mushaf_pages.json')
    with open(manifest_path, 'w', encoding='utf-8') as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
    print(f'manifest -> {manifest_path}')


if __name__ == '__main__':
    main()
