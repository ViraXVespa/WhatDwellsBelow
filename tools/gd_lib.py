#!/usr/bin/env python3
"""GDScript file discovery and top-level func scanning shared by tools.

Import-only. split_funcs / facade_requal / list_unused_funcs keep their own
richer parsers (decorators, strings, class bodies); everything simple lives here.
"""
from __future__ import annotations

import re
from pathlib import Path

SKIP_PARTS = ("archives", ".archive_worktrees")
RE_FUNC = re.compile(r"^(static\s+)?func\s+(\w+)\s*\(")
DECL = re.compile(
    r"^(?P<indent>\t*)(?:static\s+)?(?:func|const|var|class_name|enum)\s+(?P<name>[A-Za-z_][A-Za-z0-9_]*)"
)


def iter_gd(root: Path, *, sub: str = "scripts") -> list[Path]:
    """Live .gd files under root/sub (archives and worktrees skipped), sorted."""
    base = root / sub
    if not base.is_dir():
        return []
    return sorted(p for p in base.rglob("*.gd") if p.is_file() and p.relative_to(root).parts[0] not in SKIP_PARTS)


def func_starts(text: str) -> list[tuple[str, int]]:
    """[(name, 1-based line)] for column-0 func / static func."""
    out: list[tuple[str, int]] = []
    for i, line in enumerate(text.splitlines(True), 1):
        m = RE_FUNC.match(line)
        if m:
            out.append((m.group(2), i))
    return out


def funcs_of(text: str) -> list[tuple[str, int, int, int]]:
    """[(name, start_line, end_line, utf8_bytes)] with each func ending where the next begins."""
    lines = text.splitlines(True)
    starts = func_starts(text)
    out: list[tuple[str, int, int, int]] = []
    for idx, (name, start) in enumerate(starts):
        end = (starts[idx + 1][1] - 1) if idx + 1 < len(starts) else len(lines)
        out.append((name, start, end, len("".join(lines[start - 1 : end]).encode("utf-8"))))
    return out


def func_count(text: str, name: str) -> int:
    return sum(1 for n, _ in func_starts(text) if n == name)


def func_span(text: str, name: str) -> tuple[int, int]:
    """0-based line range [start, end) of column-0 func `name`. ValueError if missing."""
    lines = text.splitlines(keepends=True)
    start = next((i for i, ln in enumerate(lines) if RE_FUNC.match(ln) and RE_FUNC.match(ln).group(2) == name), -1)
    if start < 0:
        raise ValueError(f"func {name} missing")
    end = start + 1
    while end < len(lines) and not RE_FUNC.match(lines[end]):
        end += 1
    return start, end


def decl_span(lines: list[str], name: str) -> tuple[int, int] | None:
    """[start, end) of the first func/const/var/enum named `name` up to the next same-indent decl."""
    for i, line in enumerate(lines):
        m = DECL.match(line)
        if m and m.group("name") == name:
            indent = m.group("indent")
            end = len(lines)
            for j in range(i + 1, len(lines)):
                n = DECL.match(lines[j])
                if n and n.group("indent") == indent:
                    end = j
                    break
            return i, end
    return None
