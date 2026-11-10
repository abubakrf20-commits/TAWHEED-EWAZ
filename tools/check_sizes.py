import json, os, sys
sys.stdout.reconfigure(encoding='utf-8')

pages_dir = 'tools/mushaf_build/pages'
sizes = []
for f in sorted(os.listdir(pages_dir)):
    if f.endswith('.webp'):
        sizes.append(os.path.getsize(os.path.join(pages_dir, f)))

print(f'Total WebP files: {len(sizes)}')
print(f'Min size: {min(sizes):,} bytes ({min(sizes)/1024:.1f} KB)')
print(f'Max size: {max(sizes):,} bytes ({max(sizes)/1024:.1f} KB)')
print(f'Avg size: {sum(sizes)//len(sizes):,} bytes ({sum(sizes)//len(sizes)//1024:.1f} KB)')
print(f'Total size: {sum(sizes):,} bytes ({sum(sizes)//1024//1024:.1f} MB)')

print('\nManifest check:')
with open('tools/mushaf_build/manifest.json', 'r') as f:
    manifest = json.load(f)
print(f'Version: {manifest["version"]}')
print(f'Total pages in manifest: {len(manifest["pages"])}')
print(f'Generated at: {manifest["generated_at"]}')
# Check page 1 and 300
for p in ['001', '002', '003', '300', '604']:
    entry = manifest['pages'].get(p, {})
    print(f'  page {p}: {entry}')
