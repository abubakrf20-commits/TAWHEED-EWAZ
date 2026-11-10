"""
Download mushaf page images from GitHub repository.
Run once: python tools/download_mushaf_images.py

Source: Five-Prayers/quran-pages (604 Madani mushaf PNG images)
Output: assets/quran/pages/1.png ... 604.png
"""

import os
import sys
import time

try:
    import requests
except ImportError:
    print("ERROR: pip install requests")
    sys.exit(1)

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), '..', 'assets', 'quran', 'pages')
REPO = "Five-Prayers/quran-pages"
CDN = f"https://raw.githubusercontent.com/{REPO}/main/quran_pages"


def download_page(page_num):
    output_path = os.path.join(OUTPUT_DIR, f"{page_num}.png")
    if os.path.exists(output_path) and os.path.getsize(output_path) > 5000:
        return True

    url = f"{CDN}/{page_num}.png"
    try:
        resp = requests.get(url, timeout=30, headers={'User-Agent': 'TawheedApp/1.0'})
        if resp.status_code == 200 and len(resp.content) > 5000:
            with open(output_path, 'wb') as f:
                f.write(resp.content)
            return True
    except Exception:
        pass
    return False


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    print("=" * 50)
    print("  Mushaf Page Downloader")
    print(f"  Source: github.com/{REPO}")
    print("=" * 50)
    print(f"  Output: {OUTPUT_DIR}\n")

    success = 0
    failed = []

    for page in range(1, 605):
        output_path = os.path.join(OUTPUT_DIR, f"{page}.png")
        if os.path.exists(output_path) and os.path.getsize(output_path) > 5000:
            success += 1
            continue

        sys.stdout.write(f"\r  Downloading {page}/604...")
        sys.stdout.flush()

        if download_page(page):
            success += 1
        else:
            failed.append(page)

        time.sleep(0.2)

    print(f"\n\n{'=' * 50}")
    print(f"  DONE: {success}/604 pages")
    if failed:
        print(f"  Failed: {failed[:20]}{'...' if len(failed)>20 else ''}")
    print(f"{'=' * 50}")


if __name__ == '__main__':
    main()
