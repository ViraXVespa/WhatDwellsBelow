#!/usr/bin/env python3
"""Gate, exceptions file, summary-first report and selftest for `lint.py dupes`.

Gated rows: every `run`, plus any other kind with score >= --gate-score. A gated row passes only when
tools/data/dupes_allow.json lists its key with a reason ("why"); an allow entry whose key no longer
matches is stale and fails too, so the file is always the exact list of kept exceptions.
Keys hash kind + files + the loosened text of the first copy, so they survive line shifts.
"""
from __future__ import annotations

import hashlib
import json
import shutil
import tempfile
from collections import Counter
from pathlib import Path

import dupes_clone as C

ALLOW = "tools/data/dupes_allow.json"
FIXTURE = "tools/data/dupes-fixture"

def _span(w: str) -> tuple[str, int, int]:
    f, rest = w.rsplit(":", 1)
    a, b = rest.split(" ")[0].split("-")
    return f, int(a), int(b)

def add_keys(rows: list[dict], seqs: dict) -> None:
    seen: Counter = Counter()
    for r in rows:
        f, a, b = _span(r["where"][0])
        text = [C.loose(s) for n, s in seqs.get(f, []) if a <= n <= b]
        files = sorted({_span(w)[0] for w in r["where"]})
        k = hashlib.md5("\n".join([r["kind"], *files, *text]).encode()).hexdigest()[:12]
        seen[k] += 1
        r["key"] = k if seen[k] == 1 else "%s-%d" % (k, seen[k])

def drop_covered(clones: list[dict], others: list[dict]) -> list[dict]:
    """A clone whose every copy sits inside an exact/shape/near/block/nblock copy is already reported."""
    have = [_span(w) for r in others for w in r["where"]]
    def inside(w):
        f, a, b = _span(w)
        return any(f == g and x <= a and b <= y for g, x, y in have)
    return [c for c in clones if not all(inside(w) for w in c["where"])]

def gated(rows: list[dict], score: int) -> list[dict]:
    return [r for r in rows if r["kind"] == "run" or r["score"] >= score]

def load_allow(root: Path) -> list[dict]:
    p = root / ALLOW
    return json.loads(p.read_text(encoding="utf-8")) if p.is_file() else []

def check(root: Path, rows: list[dict], score: int) -> dict:
    allow = {a["key"]: a for a in load_allow(root)}
    g = gated(rows, score)
    keys = {r["key"] for r in g}
    return {"gated": g, "new": [r for r in g if r["key"] not in allow],
            "kept": [r for r in g if r["key"] in allow],
            "stale": [a for k, a in allow.items() if k not in keys],
            "nowhy": [a for a in allow.values() if not str(a.get("why", "")).strip()]}

def summary(rows: list[dict], kinds, top_files: int = 8) -> list[str]:
    """Counts first: per kind, finding files, then the files with the most findings."""
    per = Counter(_span(w)[0] for r in rows for w in {*(r["where"])})
    out = ["summary findings=%d files=%d %s" % (len(rows), len(per), " ".join(
        "%s=%d" % (k, sum(1 for r in rows if r["kind"] == k)) for k in kinds))]
    out += ["  %3d  %s" % (n, f) for f, n in per.most_common(top_files)]
    return out

def row_line(r: dict) -> str:
    return "%-6s score=%-4d lines=%-3d copies=%-2d key=%s  %s" % (
        r["kind"], r["score"], r["lines"], r["copies"], r.get("key", ""), " | ".join(r["where"]))

def allow_rows(rows: list[dict], why: str) -> list[dict]:
    return [{"key": r["key"], "kind": r["kind"], "where": r["where"], "why": why} for r in rows]

def selftest(root: Path, build) -> list[str]:
    """Copy the pre-fix stall builder (two files) into a scratch repo; the sweep must flag the four
    _post calls (run), the four wall builders (clone, one file) and the post body (clone across files);
    a data table and a loop must stay quiet."""
    errs: list[str] = []
    tmp = Path(tempfile.mkdtemp(prefix="dupes-selftest-"))
    try:
        (tmp / "scripts").mkdir()
        (tmp / "tools").mkdir()
        for src in sorted((root / FIXTURE).glob("*.gd.txt")):
            shutil.copy(src, tmp / "scripts" / src.name[:-4])
        rows = build(tmp)
        where = lambda k: [w for r in rows if r["kind"] == k for w in r["where"]]
        runs, clones = where("run"), [r for r in rows if r["kind"] == "clone"]
        if not any(w.startswith("scripts/old_mesh_tent.gd:") for w in runs):
            errs.append("four _post(...) calls not flagged as a run")
        if not any(r["copies"] >= 3 and all(w.startswith("scripts/old_build_parts.gd:") for w in r["where"]) for r in clones):
            errs.append("wall builders (3+ copies in one file) not flagged as a clone")
        if not any(len({_span(w)[0] for w in r["where"]}) > 1 for r in clones):
            errs.append("post body copied into a second file not flagged as a cross-file clone")
        if any("quiet.gd" in w for r in rows for w in r["where"]):
            errs.append("data table / loop in quiet.gd flagged (false positive)")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    return errs
