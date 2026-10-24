#!/usr/bin/env python3
"""Literal-blind clone finder used by `lint.py dupes` (kinds `run` and `clone`).

A line is loosened before it is compared: strings -> "S", numbers -> N, bare lowercase names
(locals, params, members; not calls, not `.attr`, not keywords, not Capitalized types/consts) -> L,
a unary minus is dropped and binary + / - become one operator. So copies that differ only in
positions, sizes, colors, names, signs or local variable names compare equal.
  run    >= --min-run consecutive lines with the same loose form but different text in one file
         (an unrolled loop: 4 `_post(body, Vector3(+-x, y, +-z))` calls, 8 corner vertices)
  clone  >= --min-clone consecutive loose lines repeated in 2+ places, same file or across files
         (4 wall builders that differ only in names, signs and corner order)
Data rows (dict / array entries, bare literals) are not runs: a table is the fix, not the smell. Nor are calls
that each carry prose (a string over 30 chars: argparse help, UI copy): that text is the content, not a literal.
"""
from __future__ import annotations

import hashlib
import re
from collections import defaultdict

STR = re.compile(r'"(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\'')
NUM = re.compile(r"(?<![\w.])\d+(?:\.\d+)?(?:e-?\d+)?\b")
NAME = re.compile(r"(?<![\w.@$])([a-z_]\w*)\b(?!\s*\()")
KEEP = {
    "and", "or", "not", "in", "is", "if", "elif", "else", "for", "while", "return", "var", "const", "func",
    "static", "pass", "break", "continue", "match", "true", "false", "null", "self", "await", "as", "def",
    "class", "import", "from", "with", "lambda", "yield", "try", "except", "finally", "raise", "del",
    "global", "assert", "async", "extends", "signal", "enum", "super", "preload", "load",
}
UNARY = re.compile(r"(^|[(\[{,=:]\s*|\breturn\s+|[*/]\s*)-\s*")
BINOP = re.compile(r"\s[+-]\s")
DATA = re.compile(r'^(?:"S"|N|\[|\{|\(|L\s*,|"S"\s*:|L\s*:\s*[^=])')
TRIVIAL = re.compile(r"^(pass|return|return L|else:|\)|\]|\}|\),|\],|\},)$")
CALL = re.compile(r"^[\w.]+\(.*\)$")

def numeric(s: str) -> str:
    """Strings masked, numbers masked, unary minus and +/- dropped; names kept."""
    return BINOP.sub(" ~ ", UNARY.sub(r"\1", NUM.sub("N", STR.sub('"S"', s.strip()))))

def loose(s: str) -> str:
    s = NUM.sub("N", STR.sub('"S"', s.strip()))
    s = NAME.sub(lambda m: m.group(1) if m.group(1) in KEEP else "L", s)
    s = UNARY.sub(r"\1", s)
    return BINOP.sub(" ~ ", s)

def _key(lines: list[str]) -> str:
    return hashlib.md5("\n".join(lines).encode()).hexdigest()[:12]

def runs(seqs: dict[str, list[tuple[int, str]]], min_run: int) -> list[dict]:
    """Unrolled loops: min_run+ adjacent lines, one loose form, at least two different texts."""
    out = []
    for rel, seq in seqs.items():
        lo = [loose(s) for _, s in seq]
        i = 0
        while i < len(seq):
            j = i
            while j + 1 < len(seq) and lo[j + 1] == lo[i]:
                j += 1
            n = j - i + 1
            raw = {s for _, s in seq[i:j + 1]}
            prose = all(any(len(m) > 32 for m in STR.findall(s)) for s in raw)
            if n >= min_run and len(raw) > 1 and CALL.match(lo[i]) and len({numeric(s) for s in raw}) == 1 and not prose:
                out.append({"kind": "run", "lines": n, "copies": n, "score": n - 1, "key": _key([lo[i]]),
                            "where": ["%s:%d-%d" % (rel, seq[i][0], seq[j][0])]})
            i = j + 1
    return out

def clones(seqs: dict[str, list[tuple[int, str]]], min_clone: int, header) -> list[dict]:
    """Loose block clones (same file or across files), each grown to its longest common length."""
    lo = {r: [loose(s) for _, s in seq] for r, seq in seqs.items()}
    wins: dict[str, list[tuple[str, int]]] = defaultdict(list)
    for r, ls in lo.items():
        for i in range(len(ls) - min_clone + 1):
            w = ls[i:i + min_clone]
            if len(set(w)) < 3 or sum(1 for s in w if header.match(s) or TRIVIAL.match(s) or DATA.match(s)) * 2 >= len(w):
                continue
            wins["\n".join(w)].append((r, i))
    out, used = [], defaultdict(set)
    for occ in sorted(wins.values(), key=lambda o: (-len(o), o)):
        occ = _spread(occ, min_clone)
        if len(occ) < 2 or any(i in used[r] for r, i in occ):
            continue
        n = min_clone
        while all(i + n < len(lo[r]) for r, i in occ) and len({lo[r][i + n] for r, i in occ}) == 1 \
                and not _hits(occ, n + 1):
            n += 1
        for r, i in occ:
            used[r].update(range(i, i + n))
        spans = [(r, seqs[r][i][0], seqs[r][i + n - 1][0]) for r, i in occ]
        out.append({"kind": "clone", "lines": n, "copies": len(occ), "score": (len(occ) - 1) * n,
                    "key": _key(lo[occ[0][0]][occ[0][1]:occ[0][1] + n]), "where": ["%s:%d-%d" % s for s in spans]})
    return out

def _spread(occ, n):
    """Drop copies overlapping an earlier copy in the same file (a window sliding over its own run)."""
    keep, last = [], {}
    for r, i in sorted(occ):
        if r in last and i < last[r] + n:
            continue
        keep.append((r, i))
        last[r] = i
    return keep

def _hits(occ, n) -> bool:
    by = defaultdict(list)
    for r, i in occ:
        by[r].append(i)
    return any(b < a + n for v in by.values() for a, b in zip(sorted(v), sorted(v)[1:]))
