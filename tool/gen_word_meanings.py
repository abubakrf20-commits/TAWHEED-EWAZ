# Generates the bundled Persian word-by-word meaning asset for the release
# build (audit finding B01: the mushaf word-meaning sheet is unreachable in
# release because _bundledPageVerses() ships no words).
#
# Source: quran.com public API v4 (`language=fa` selects the Persian
# word-by-word translation resource id 552). No credentials required.
#
# Output: assets/data/quran_word_meanings_fa.json.gz
#   {"meta": {...}, "pages": {"<page>": [[s, a, pos, uthmani, fa], ...]}}
# Only `char_type_name == "word"` rows are kept (end/pause markers carry no
# meaning and are never tap targets).
#
# Usage: python tool/gen_word_meanings.py
import gzip
import json
import sys
import time
import urllib.parse
import urllib.request

API = "https://api.quran.com/api/v4/verses/by_page/{p}?{q}"
OUT = "assets/data/quran_word_meanings_fa.json.gz"


def fetch(page: int, verse_page: int) -> dict:
    q = urllib.parse.urlencode(
        {
            "words": "true",
            "word_fields": "text_uthmani",
            "language": "fa",
            "per_page": 50,
            "page": verse_page,
        }
    )
    url = API.format(p=page, q=q)
    last_err = None
    for attempt in range(4):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "tawheeed-wordgen/1.0"})
            with urllib.request.urlopen(req, timeout=40) as r:
                return json.load(r)
        except Exception as e:  # noqa: BLE001 - retry any transient error
            last_err = e
            time.sleep(1.5 * (attempt + 1))
    raise RuntimeError(f"page {page} (verse_page {verse_page}) failed: {last_err}")


def main() -> int:
    pages: dict[str, list] = {}
    word_count = 0
    for p in range(1, 605):
        rows: list = []
        vp = 1
        while True:
            data = fetch(p, vp)
            verses = data.get("verses") or []
            for v in verses:
                s, a = v["verse_key"].split(":")
                for w in v.get("words") or []:
                    if w.get("char_type_name") != "word":
                        continue
                    fa = (w.get("translation") or {}).get("text") or ""
                    rows.append(
                        [int(s), int(a), int(w["position"]), w.get("text_uthmani") or "", fa]
                    )
            pg = data.get("pagination") or {}
            if not pg.get("next_page"):
                break
            vp += 1
        pages[str(p)] = rows
        word_count += len(rows)
        if p % 25 == 0 or p == 1:
            print(f"page {p}: +{len(rows)} words (total {word_count})", flush=True)

    payload = {
        "meta": {
            "lang": "fa",
            "source": "quran.com API v4 word-by-word translation (resource 552)",
            "generated": "2026-11-07",
            "words": word_count,
        },
        "pages": pages,
    }
    raw = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    with open(OUT, "wb") as f:
        f.write(gzip.compress(raw, 9))
    print(f"words={word_count} raw={len(raw)/1024:.0f}KB gz=", end="")
    import os

    print(f"{os.path.getsize(OUT)/1024:.0f}KB -> {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
