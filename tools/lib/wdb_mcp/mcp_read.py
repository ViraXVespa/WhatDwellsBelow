"""File reads for the wdb MCP `lookup` (lines, doc sections, doc outlines). No CLI of its own; mcp_tools.py calls it.

Every read is a list of lines with a `## path ...` header; refusals raise core.Refused. Reads go straight to the file
(no command run), stay under the repo root and follow core.denied().
"""
from __future__ import annotations

import re
from pathlib import Path

import mcp_core as core

HEAD_RE = re.compile(r"^(#+)\s+(.*)$")
OUTLINE_PARAS = 3  # a doc with fewer headings than this also lists its paragraph starts

def _headings(lines: list[str]) -> list[tuple[int, int, str]]:
    """(1-based line, level, title) of every markdown heading outside code fences."""
    out, fence = [], False
    for i, ln in enumerate(lines, 1):
        if ln.startswith("```"):
            fence = not fence
        m = None if fence else HEAD_RE.match(ln)
        if m:
            out.append((i, len(m.group(1)), m.group(2).strip()))
    return out

def heading_span(lines: list[str], heading: str) -> tuple[int, int] | None:
    """1-based [a, b] of a heading's section (up to the next heading of the same or higher level)."""
    heads = _headings(lines)
    want = heading.strip().lower()
    for k, (i, lvl, title) in enumerate(heads):
        if title.lower() == want:
            nxt = next((j for j, lv, _ in heads[k + 1:] if lv <= lvl), len(lines) + 1)
            return i, nxt - 1
    return None

def outline(lines: list[str], rel: str) -> list[str]:
    """Headings with their line spans; a doc with few headings also lists where each paragraph or list starts, so a
    caller can pick `lines` ranges (or `slice.py adjust add-doc PATH --lines A-B`)."""
    heads = _headings(lines)
    rows = [f"## {rel} outline ({len(lines)} lines; doc path#Heading for a section, lines start/end for a range)"]
    for k, (i, lvl, title) in enumerate(heads):
        nxt = next((j for j, lv, _ in heads[k + 1:] if lv <= lvl), len(lines) + 1)
        rows.append(f"L{i}-{nxt - 1} {'#' * lvl} {title}")
    if len(heads) < OUTLINE_PARAS:
        for i, ln in enumerate(lines, 1):
            if ln.strip() and not HEAD_RE.match(ln) and (i == 1 or not lines[i - 2].strip()):
                rows.append(f"  L{i}: {ln.strip()[:72]}")
    return rows

def read(root: Path, action: str, path: str, start: int, end: int) -> list[str]:
    """Body lines for lookup lines / doc / names of a .py. doc: `path#Heading` the full section; no heading: always the
    outline (all=true only stops it paging; the whole file is `lines` with no start/end)."""
    rel, _, heading = path.partition("#")
    why = core.denied(rel)
    if why:
        raise core.Refused(why)
    src = root / rel
    if not src.resolve().is_relative_to(root.resolve()):
        raise core.Refused("path leaves the repo")
    if not src.is_file():
        raise core.Refused(f"{rel} is not a file under the repo root")
    lines = src.read_text(encoding="utf-8-sig", errors="replace").splitlines()
    if action in ("names", "all_names"):  # Python: find.py scripts is GDScript only
        import show_func

        return [f"{rel} defs: " + ", ".join(show_func.declared_names(lines, True))]
    if action == "doc" and heading.strip():
        span = heading_span(lines, heading)
        if span is None:
            titles = list(dict.fromkeys(t for _, _, t in _headings(lines)))[:20]
            raise core.Refused(f"no heading {heading!r} in {rel}; headings: " + " | ".join(titles))
        a, b = span
    elif action == "doc":
        return outline(lines, rel)
    else:
        a, b = max(1, start or 1), min(len(lines), end or len(lines))
    return [f"## {rel} L{a}-{b} of {len(lines)}"] + lines[a - 1:b]
