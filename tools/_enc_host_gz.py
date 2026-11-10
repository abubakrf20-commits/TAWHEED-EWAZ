# -*- coding: utf-8 -*-
"""Compress the categorized hadeeth_enc.db for hosting (zopfli gzip)."""
import os
import sys

from zopfli.gzip import compress

SRC = r"assets\hadeeth_enc.db"
OUT = r"TAWHEED-EWAZ\hadeeth_enc\hadeeth_enc.db.gz"

os.makedirs(os.path.dirname(OUT), exist_ok=True)
raw = open(SRC, "rb").read()
out = compress(raw, numiterations=15)
open(OUT, "wb").write(out)
print(f"raw={len(raw):,}  gz={len(out):,}  ({len(out) / 1024 / 1024:.2f} MB)")
