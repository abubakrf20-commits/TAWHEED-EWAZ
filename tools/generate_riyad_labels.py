# -*- coding: utf-8 -*-
"""Generate assets/riyad_hadith_labels.json from the 6 source Word volumes.

Ground truth for hadith-vs-intro classification is the SOURCE ITSELF:
sharh_to_sqlite.parse_volume() marks an entry as a real narration exactly
when its paragraph starts with a printed number ('N- matn') in one of the
two typesetting schemes used by the Word files:
  - 'bab'    : per-bab numbering, style 'احادیث' (mostly vols 1-3)
  - 'global' : continuous riyad numbering >= 200 (mostly vols 4-6)

Output JSON consumed by the app (indexed by db hadith_number-1, which is
the insertion order of sharh_to_sqlite/build_riyad_db):
  {"v":1,"total":2078,"flags":[...],"nums":[...]}
  flags[i] 1 = real hadith, 0 = intro (muqaddima) entry
  nums[i]  = display number (canonical sequential over flagged entries)
Also prints an alignment report between cumulative counting and the
embedded global numbers so we can prove the numbering is book-exact.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sharh_to_sqlite as S


def main():
    all_chapters = []
    for f in S.FILES:
        chs = S.parse_volume(os.path.join(S.ROOT, f))
        all_chapters.extend(chs)

    entries = [h for ch in all_chapters for h in ch["hadiths"]]
    total = len(entries)
    flags = [1 if h.get("no") else 0 for h in entries]
    src_nos = [int(h.get("no") or 0) for h in entries]
    schemes = [h.get("scheme") for h in entries]

    n_hadith = sum(flags)
    print(f"entries={total}  hadiths(exact per source)={n_hadith}  "
          f"intro={total - n_hadith}")

    # ── scheme regions ───────────────────────────────────────────
    first_global_i = next((i for i, s in enumerate(schemes)
                           if s == "global"), None)
    last_bab_i = max((i for i, s in enumerate(schemes) if s == "bab"),
                     default=-1)
    print(f"first global-numbered hadith at entry #{first_global_i + 1}"
          if first_global_i is not None else "no global scheme found")
    print(f"last bab-numbered hadith at entry #{last_bab_i + 1}")

    # ── alignment check: cumulative count vs embedded global nos ─
    cum = 0
    mismatches = []
    for i, h in enumerate(entries):
        if not flags[i]:
            continue
        cum += 1
        if schemes[i] == "global" and src_nos[i] != cum:
            mismatches.append((i + 1, cum, src_nos[i]))
    print(f"\nglobal-scheme vs cumulative-sequence mismatches: "
          f"{len(mismatches)}")
    for e, c, g in mismatches[:15]:
        print(f"  entry#{e}  cumulative={c}  printed-global={g}")
    if mismatches:
        diffs = sorted({g - c for _, c, g in mismatches})
        print(f"  distinct offsets(g-c): {diffs[:10]}"
              f"{' ...' if len(diffs) > 10 else ''}")
        # where does the offset stabilise?
        stable = mismatches[-1]
        print(f"  final mismatch: cumulative={stable[1]} printed={stable[2]}")
    print(f"cumulative hadith count at end = {cum} "
          f"(printed book reaches {max(src_nos)})")

    # ── dedupe: same printed number + identical matn = typeset dup ─
    # vol4 prints the Ayat-al-Kursi hadith (no 1026) twice; keep the first
    # occurrence numbered, demote repeats to unnumbered entries.
    import re as _re
    _DIAC = _re.compile(r"[\u064B-\u065F\u0670\u0640\u06D6-\u06ED\s]+")

    def _key(m):
        return _DIAC.sub("", (m or ""))[:60]

    seen = {}
    demoted = []
    for i in range(total):
        if not flags[i]:
            continue
        n = src_nos[i]
        prev_i = seen.get(n)
        if prev_i is not None and _key(entries[prev_i]["matn"]) == \
                _key(entries[i]["matn"]):
            flags[i] = 0
            demoted.append(f"entry#{i + 1} duplicates #{prev_i + 1} "
                           f"(no {n})")
            continue
        seen[n] = i
    for d in demoted:
        print(f"demoted: {d}")

    # ── repair local typesetting slips -> strict increasing run ──
    # '...,612,612,614,...' (second 612 is really 613); genuine gaps
    # (skipped numbers like 86, 100, ...) stay untouched.
    idxs = [i for i in range(total) if flags[i]]
    repairs = []
    for k in range(1, len(idxs)):
        i, p = idxs[k], idxs[k - 1]
        if src_nos[i] > src_nos[p]:
            continue
        nxt = None
        for k2 in range(k + 1, len(idxs)):
            if src_nos[idxs[k2]] > src_nos[p]:
                nxt = src_nos[idxs[k2]]
                break
        cand = src_nos[p] + 1
        if nxt is None or cand < nxt:
            repairs.append(f"entry#{i + 1}: {src_nos[i]} -> {cand}")
            src_nos[i] = cand
        else:
            src_nos[i], src_nos[p] = src_nos[p], src_nos[i]
            repairs.append(f"entry#{p + 1}/#{i + 1}: swapped")
    for r in repairs:
        print(f"repaired: {r}")

    seq = [src_nos[i] for i in idxs]
    assert all(a < b for a, b in zip(seq, seq[1:])), "repair failed"
    dupes = len(seq) - len(set(seq))
    holes = [(a, b) for a, b in zip(seq, seq[1:]) if b > a + 1]
    skipped = sorted(set(range(seq[0], seq[-1] + 1)) - set(seq))
    print(f"\nfinal printed numbers: count={len(seq)} range={seq[0]}.."
          f"{seq[-1]} duplicates={dupes}")
    print(f"skipped numbers in this edition: {len(skipped)} -> {skipped}")

    nums = [src_nos[i] if flags[i] else 0 for i in range(total)]
    n_hadith = sum(flags)
    data = {"v": 1, "total": total, "hadithTotal": n_hadith,
            "flags": flags, "nums": nums}
    out = os.path.join(S.ROOT, "assets", "riyad_hadith_labels.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump(data, f, separators=(",", ":"))
    print(f"\nwritten {out} ({os.path.getsize(out)} bytes)")


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
