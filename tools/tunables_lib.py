#!/usr/bin/env python3
"""Parse and patch one design/tunables.md row without loading the whole brief."""
from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

import md_format_lib as md

KEY_RE = re.compile(r"`([^`]+)`")
SLASH_RE = re.compile(r"\s*/\s*")


@dataclass
class Hit:
    key_cell: str
    live_cell: str
    aliases: list[str]
    section: str
    index: int
    live_col: int
    n_cols: int


def _cells(line: str) -> list[str]:
    return [c.strip() for c in line.strip().strip("|").split("|")]


def _aliases(key_cell: str) -> list[str]:
    out: list[str] = []
    seen: set[str] = set()

    def add(raw: str) -> None:
        token = raw.strip().strip("`")
        if not token:
            return
        key = token.lower()
        if key not in seen:
            seen.add(key)
            out.append(token)

    for tick in KEY_RE.findall(key_cell):
        add(tick)
        for part in SLASH_RE.split(tick):
            add(part)
    plain = KEY_RE.sub(r"\1", key_cell)
    for part in SLASH_RE.split(plain):
        add(part)
    add(key_cell)
    return out


def parse_hits(text: str) -> list[Hit]:
    hits: list[Hit] = []
    section = ""
    headers: list[str] | None = None
    live_col = 1
    key_col = 0
    for i, line in enumerate(text.splitlines(keepends=True)):
        if line.startswith("## "):
            section = line[3:].strip()
            headers = None
            continue
        if not line.startswith("|"):
            headers = None
            continue
        cells = _cells(line)
        if not cells:
            continue
        if set(cells[0]) <= set("-: "):
            continue
        low = [c.lower() for c in cells]
        if "key" in low or "parameter" in low:
            headers = low
            if "key" in low:
                key_col = low.index("key")
            elif "parameter" in low:
                key_col = low.index("parameter")
            else:
                key_col = 0
            if "live default" in low:
                live_col = low.index("live default")
            elif "live" in low:
                live_col = low.index("live")
            else:
                live_col = min(1, len(cells) - 1)
            continue
        if headers is None:
            continue
        if key_col >= len(cells) or live_col >= len(cells):
            continue
        key_cell = cells[key_col]
        live_cell = cells[live_col]
        hits.append(
            Hit(
                key_cell=key_cell,
                live_cell=live_cell,
                aliases=_aliases(key_cell),
                section=section,
                index=i,
                live_col=live_col,
                n_cols=len(cells),
            )
        )
    return hits


def _norm(token: str) -> str:
    return token.strip().strip("`").lower()


def find_hits(hits: list[Hit], needle: str) -> list[Hit]:
    want = _norm(needle)
    if not want:
        return []
    exact = [h for h in hits if any(_norm(a) == want for a in h.aliases)]
    if exact:
        return exact
    return [h for h in hits if any(want in _norm(a) or _norm(a) in want for a in h.aliases)]


def set_live_cell(line: str, live_col: int, value: str) -> str:
    nl = ""
    raw = line
    if raw.endswith("\r\n"):
        nl = "\r\n"
        raw = raw[:-2]
    elif raw.endswith("\n"):
        nl = "\n"
        raw = raw[:-1]
    cells = _cells(raw + "\n")
    while len(cells) <= live_col:
        cells.append("")
    cells[live_col] = value
    return "| " + " | ".join(cells) + " |" + nl


def format_hit(hit: Hit) -> list[str]:
    return [
        "key_cell=%s" % hit.key_cell,
        "live=%s" % hit.live_cell,
        "section=%s" % hit.section,
        "aliases=%s" % ", ".join(hit.aliases),
        "line=%d" % (hit.index + 1),
    ]
