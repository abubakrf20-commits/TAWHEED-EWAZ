"""Inspect SVG-BR XML structure around verse IDs."""
import brotli, re, sys
sys.stdout.reconfigure(encoding='utf-8')

with open("hafs/kfqc/svg-br/003.svg.br", "rb") as f:
    svg = brotli.decompress(f.read()).decode("utf-8")

# Find verse-13 and print 500 chars before and 500 chars after
pattern = r'id="verse-13"'
for m in re.finditer(pattern, svg):
    start = max(0, m.start() - 300)
    end = min(len(svg), m.end() + 500)
    snippet = svg[start:end]
    print(f"=== Context around verse-13 (chars {m.start()}-{m.end()}) ===")
    print(snippet)
    print()
    break

# Also show the first occurrence of each major section
print("\n=== First 500 chars of SVG ===")
print(svg[:500])

# Check if verse IDs are inside <g> or <path>
print("\n=== Searching for <g id= vs <path id= ===")
g_pattern = r'<g\s+id="verse-'
p_pattern = r'<path\s+id="verse-'
g_matches = list(re.finditer(g_pattern, svg))
p_matches = list(re.finditer(p_pattern, svg))
print(f"<g id='verse-...'> count: {len(g_matches)}")
print(f"<path id='verse-...'> count: {len(p_matches)}")

# Also check any element with id containing verse-
any_pattern = r'<(\w+)\s+[^>]*id="verse-'
any_matches = list(re.finditer(any_pattern, svg))
tags = set(m.group(1) for m in any_matches)
print(f"Tags with verse IDs: {tags}")
print(f"Total verse ID elements: {len(any_matches)}")
