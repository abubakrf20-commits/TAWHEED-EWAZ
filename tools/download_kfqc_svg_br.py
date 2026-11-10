"""Download KFQC Hafs svg-br pages + json from quranpedia/quran-svg.

Only the 604 standard mushaf pages (001..604) are fetched, plus the per-page
ayah-polygon JSON. Sources land under hafs/ as raw .svg.br files (decompressed
later by build_kfqc_webp.py).
"""
import os
import sys
import time
import urllib.request

BASE = "https://raw.githubusercontent.com/quranpedia/quran-svg/main/mushafs/hafs/kfqc"
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "hafs")
BR_DIR = os.path.join(ROOT, "kfqc", "svg-br")
JSON_DIR = os.path.join(ROOT, "kfqc", "json")
os.makedirs(BR_DIR, exist_ok=True)
os.makedirs(JSON_DIR, exist_ok=True)

OPENER = urllib.request.build_opener()
OPENER.addheaders = [("User-Agent", "opencode-build")]


def fetch(url, dest):
    for attempt in range(3):
        try:
            with OPENER.open(url, timeout=60) as resp:
                data = resp.read()
            with open(dest, "wb") as f:
                f.write(data)
            return True
        except Exception as e:
            print(f"  retry {attempt}: {e}", flush=True)
            time.sleep(2)
    return False


def main():
    pages = int(sys.argv[1]) if len(sys.argv) > 1 else 604
    failed = []
    for i in range(1, pages + 1):
        name = f"{i:03d}"
        br = os.path.join(BR_DIR, f"{name}.svg.br")
        if os.path.exists(br) and os.path.getsize(br) > 0:
            continue
        if fetch(f"{BASE}/svg-br/{name}.svg.br", br):
            print(f"br {name} ok", flush=True)
        else:
            failed.append(f"br {name}")

        js = os.path.join(JSON_DIR, f"{name}.json")
        if not os.path.exists(js):
            if fetch(f"{BASE}/json/{name}.json", js):
                print(f"json {name} ok", flush=True)
            else:
                failed.append(f"json {name}")
    if failed:
        print("FAILED:", ", ".join(failed))
        sys.exit(1)
    print(f"done: {pages} pages")


if __name__ == "__main__":
    main()