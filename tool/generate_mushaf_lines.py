#!/usr/bin/env python3
"""Generates assets/mushaf_lines.json — the exact 15-line Madani mushaf layout.

Sources (public):
  - zonetecde/mushaf-layout page JSONs (15-line Hafs text per page, with
    surah-header / basmala / text line types and per-line verse ranges)
  - its src/data/surahs.json (surah names + ayah counts)

Output schema:
  { "surahs": [{"s":1,"n":"الفاتحة","l":"سُورَةُ ٱلْفَاتِحَةِ","t":"Al-Fatihah","c":7},...],
    "pages": [ {"p":1,"j":1,"s":1,"l":[
        {"t":1,"x":"..."}                        t=1 surah-header
        {"t":2,"x":"..."}                        t=2 basmala
        {"t":0,"x":"...","f":"1:2","g":"1:2","a":["1:2"]}  t=0 text
    ]}, ...] }
"""
import json
import os
import sys

SRC = sys.argv[1] if len(sys.argv) > 1 else '/tmp/ml'
SURAHS_JSON = sys.argv[2] if len(sys.argv) > 2 else '/tmp/surahs.json'
OUT = sys.argv[3] if len(sys.argv) > 3 else 'assets/mushaf_lines.json'

# Canonical juz start ayahs (Hafs 'an 'Asim, 604-page Madani mushaf).
JUZ_STARTS = [
    (1, 1), (2, 142), (2, 253), (3, 93), (4, 24), (4, 148), (5, 82), (6, 111),
    (7, 88), (8, 41), (9, 93), (11, 6), (12, 53), (15, 1), (17, 1), (18, 75),
    (21, 1), (23, 1), (25, 21), (27, 56), (29, 46), (33, 31), (36, 28),
    (39, 32), (41, 47), (46, 1), (51, 31), (58, 1), (67, 1), (78, 1),
]
assert len(JUZ_STARTS) == 30

BISMALA = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ'

surahs_meta = json.load(open(SURAHS_JSON, encoding='utf-8'))
counts = {m['id']: m['totalAyah'] for m in surahs_meta}
assert len(counts) == 114

def parse_ref(s):
    su, ay = s.split(':')
    return int(su), int(ay)

def enumerate_refs(f, g):
    """All (surah, ayah) from f to g inclusive (may cross surahs)."""
    out = []
    s, a = f
    while True:
        out.append((s, a))
        if (s, a) == g:
            return out
        if a < counts[s]:
            a += 1
        else:
            s += 1
            a = 1

def load_page(p):
    return json.load(open(os.path.join(SRC, f'page-{p:03d}.json'), encoding='utf-8'))

# 1) juz start page per juz (first text line whose verse range contains it)
juz_start_page = [None] * 31
for j, (s0, a0) in enumerate(JUZ_STARTS, start=1):
    for p in range(1, 605):
        found = False
        for ln in load_page(p)['lines']:
            if ln['type'] != 'text':
                continue
            f, g = (parse_ref(x) for x in ln['verseRange'].split('-'))
            if f <= (s0, a0) <= g:
                juz_start_page[j] = p
                found = True
                break
        if found:
            break
    assert juz_start_page[j], f'juz {j} start not found'

# sanity checks on the canonical list against the real layout
assert juz_start_page[2] == 22, juz_start_page[2]   # juz 2 starts page 22
assert juz_start_page[29] == 562, juz_start_page[29]  # juz 29 (67:1) page 562
assert juz_start_page[30] == 582, juz_start_page[30]  # juz 30 (78:1) page 582

pages = []
for p in range(1, 605):
    d = load_page(p)
    lines = []
    header_surah = None
    for ln in d['lines']:
        typ = ln['type']
        if typ == 'surah-header':
            lines.append({'t': 1, 'x': ln['text']})
            if header_surah is None:
                header_surah = int(ln.get('surah', '0'))
        elif typ == 'basmala':
            lines.append({'t': 2, 'x': ln.get('text') or BISMALA})
        else:
            f, g = (parse_ref(x) for x in ln['verseRange'].split('-'))
            refs = enumerate_refs(f, g)
            lines.append({
                't': 0, 'x': ln['text'],
                'f': f'{f[0]}:{f[1]}', 'g': f'{g[0]}:{g[1]}',
                'a': [f'{s}:{a}' for s, a in refs],
            })
            if header_surah is None:
                header_surah = f[0]
    assert header_surah, f'page {p} header surah missing'
    # The dataset omits blank lines; the printed mushaf always has 15 rows.
    # Pad with blank rows (t=3) so every page renders a full 15-line grid.
    while len(lines) < 15:
        lines.append({'t': 3, 'x': ''})
    # juz of this page: largest juz whose start page <= p
    juz = max(j for j in range(1, 31) if juz_start_page[j] <= p)
    pages.append({'p': p, 'j': juz, 's': header_surah, 'l': lines})

assert len(pages) == 604
bad = [p['p'] for p in pages if len(p['l']) != 15]
assert not bad, f'pages without 15 lines: {bad}'
assert pages[0]['l'][0]['t'] == 1 and pages[0]['l'][0]['x'].startswith('سُورَةُ')
assert pages[-1]['l'][-1]['g'] == '114:6', pages[-1]['l'][-1]

surahs_out = [
    {'s': m['id'], 'n': m['arabic'], 'l': m['arabicLong'], 't': m['name'],
     'c': m['totalAyah']}
    for m in surahs_meta
]

os.makedirs(os.path.dirname(OUT) or '.', exist_ok=True)
with open(OUT, 'w', encoding='utf-8') as fh:
    json.dump({'meta': {'source': 'zonetecde/mushaf-layout (Hafs, Madani 604p)'},
               'surahs': surahs_out, 'pages': pages},
              fh, ensure_ascii=False, separators=(',', ':'))

size = os.path.getsize(OUT)
print(f'wrote {OUT} ({size/1e6:.2f} MB)')
print('juz start pages:', juz_start_page[1:])
