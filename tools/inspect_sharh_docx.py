import re
import sys

from docx import Document

path = sys.argv[1]
bab_idx = int(sys.argv[2])       # paragraph index of a bab marker
span = int(sys.argv[3]) if len(sys.argv) > 3 else 80
doc = Document(path)
for i in range(bab_idx, min(bab_idx + span, len(doc.paragraphs))):
    p = doc.paragraphs[i]
    t = p.text.strip()
    if not t:
        continue
    s = p.style.name if p.style is not None else "None"
    print(f"[{i}] <{s}> {t[:120]}")
