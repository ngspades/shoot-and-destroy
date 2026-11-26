#!/usr/bin/env python3
"""Requirement bookkeeping.

  * every requirement id (#req("ID" ...)) is unique,
  * every id has exactly one row in src/matrix.typ and every row has a requirement,
  * every id mentioned in the prose names a defined requirement,
  * with --site DIR: every id is an anchor in the built page.
"""
import re
import sys
from collections import Counter
from pathlib import Path

root = Path(__file__).resolve().parent.parent
src = root / "src"
ID = r"[A-Z]-[A-Z0-9]+-\d+"
bad = []

defined = []
for f in sorted((src / "parts").glob("*.typ")):
    defined += re.findall(r'#req\("(%s)"' % ID, f.read_text())
for i, n in Counter(defined).items():
    if n > 1:
        bad.append("duplicate requirement id %s" % i)

rows = re.findall(r'^\s*\("(%s)", "(\w+)"' % ID, (src / "matrix.typ").read_text(), re.M)
mx = [r[0] for r in rows]
for i, n in Counter(mx).items():
    if n > 1:
        bad.append("%s has %d rows in the matrix" % (i, n))
for i in set(defined) - set(mx):
    bad.append("%s is not in the matrix" % i)
for i in set(mx) - set(defined):
    bad.append("matrix row %s has no requirement" % i)
if defined != [i for i in mx if i in set(defined)]:
    bad.append("matrix order differs from document order")
for _, s in rows:
    if s not in ("supported", "partial", "progress", "no", "na"):
        bad.append("unknown status " + s)

known = set(defined)
for f in sorted(src.rglob("*.typ")):
    if f.name == "matrix.typ":
        continue
    for m in re.findall(r"\b(%s)\b" % ID, f.read_text()):
        if m not in known:
            bad.append("%s mentions undefined %s" % (f.name, m))

if "--site" in sys.argv:
    page = (Path(sys.argv[sys.argv.index("--site") + 1]) / "index.html").read_text()
    for i in defined:
        if 'id="%s"' % i not in page:
            bad.append("%s is not an anchor in the built page" % i)

print("check_reqs: %d requirements, %d matrix rows" % (len(defined), len(mx)))
for b in sorted(set(bad)):
    print("  " + b)
if bad:
    sys.exit(1)
print("check_reqs: ok")
