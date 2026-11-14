"""`lint.py unused --apply` doc follow-up: drop EXACT stale references to symbols the passes just deleted.

Exact (edited): a deleted file's tick in design/code-map.md (resolved path equal, never a basename guess), and a
design/root .md bullet or table row whose every code span names a removed symbol (stale qualified `Class.member`,
a bare `name`/`name()` with no remaining GDScript def, or a deleted file path) and that has no indented continuation.
Everything else report_stale_docs found (prose, mixed lines, headings, plain words) stays a stale_docs warning.
A line whose code spans also name a surviving definition is never touched."""
from __future__ import annotations

import re
from pathlib import Path

SPAN_RE = re.compile(r"`([^`]+)`")
LIST_RE = re.compile(r"^\s*(?:[-*+]|\d+\.)\s+\S")
ROW_RE = re.compile(r"^\s*\|.*\|\s*$")
SEP_RE = re.compile(r"^\s*\|[\s:|-]+\|\s*$")

def _norm(span: str) -> str:
    """`Mod.fn(a, b)` -> Mod.fn; `fn()` -> fn; paths stay."""
    s = span.strip()
    return re.sub(r"\(.*\)$", "", s).strip()

def _code_map(root: Path, files: list[str]) -> list[dict]:
    import code_map_lib as cm
    path = root / "design" / "code-map.md"
    if not files or not path.is_file():
        return []
    raw = path.read_text(encoding="utf-8")
    lines = raw.split("\n")
    fixed = []
    for row in cm.parse_rows(raw):
        live = row.live
        for rel in files:
            hit = next((m for m, _t, res in cm._iter_ticks(live) if res == rel), None)
            if hit is not None:
                live = cm._drop_tick(live, hit)
                fixed.append(dict(rel="design/code-map.md", line=row.index + 1, name=rel, why="deleted file tick removed"))
        if live != row.live:
            lines[row.index] = cm.format_row(row.system, live)
    if fixed:
        path.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    return fixed

def fix(root: Path, applied_items: list[tuple[str, str, str]], stale: list[dict]) -> tuple[list[dict], list[dict]]:
    """(fixed, still_stale). applied_items: (kind, rel, name) from list_unused_funcs._applied_items."""
    files = sorted({rel for kind, rel, _n in applied_items if kind == "file"})
    fixed = _code_map(root, files)
    by_line: dict[tuple[str, int], list[dict]] = {}
    for s in stale:
        by_line.setdefault((s["rel"], s["line"]), []).append(s)
    drop: dict[str, set[int]] = {}
    for (doc, no), items in by_line.items():
        if doc == "design/code-map.md" and files:
            continue  # code-map ticks are handled above; the table row itself stays
        p = root / doc
        lines = p.read_text(encoding="utf-8").split("\n") if p.is_file() else []
        if not 0 < no <= len(lines):
            continue
        line = lines[no - 1]
        if not (LIST_RE.match(line) or (ROW_RE.match(line) and not SEP_RE.match(line))):
            continue
        nxt = lines[no] if no < len(lines) else ""
        if LIST_RE.match(line) and nxt.strip() and nxt[:1].isspace() and not LIST_RE.match(nxt):
            continue  # bullet with a continuation paragraph: fuzzy
        dead = {s["name"] for s in items} | set(files)
        spans = [_norm(x) for x in SPAN_RE.findall(line)]
        if not spans or any(sp not in dead for sp in spans):
            continue
        drop.setdefault(doc, set()).add(no)
        fixed += [dict(s, why="line dropped (" + s["why"] + ")") for s in items]
    for doc, nos in drop.items():
        p = root / doc
        lines = p.read_text(encoding="utf-8").split("\n")
        p.write_text("\n".join(x for i, x in enumerate(lines, 1) if i not in nos), encoding="utf-8", newline="\n")
    gone = {(f["rel"], f["line"], f["name"]) for f in fixed}
    return fixed, [s for s in stale if (s["rel"], s["line"], s["name"]) not in gone]
