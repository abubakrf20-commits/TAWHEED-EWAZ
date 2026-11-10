import requests

repo = "Five-Prayers/quran-pages"
url = f"https://raw.githubusercontent.com/{repo}/main/quran_pages/1.png"
try:
    r = requests.get(url, timeout=15)
    print(f'Status: {r.status_code}, Size: {len(r.content)}B, Type: {r.headers.get("content-type", "unknown")}')
except Exception as e:
    print(f'FAIL: {e}')
