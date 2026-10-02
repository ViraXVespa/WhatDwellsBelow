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


# Cluster-folder naming rule (design/refactor.md "Cluster folders"): helper `<stem>_<rest>.gd` lives at
# `<dir>/<stem>/<name>.gd` with the repeated stem trimmed (`<rest>`), unless `<rest>` is generic or too short or collides
# with another basename in the repo; then a qualifier is kept (last stem token, then more tokens, up to the full old name).
GENERIC = frozenset(
    "util utils parts misc core data base common helper helpers main types fx io act view flow text build host node page pages "
    "ui hub sub api ready near best late early step walk door draw kit norm make town bag req use meta prog roll geo quad span "
    "fold args pose rim spec emit dump set run stream bake val lock tick pack gate cells web desk pool anim chest prompt".split()
)


def helper_basenames(stem: str, keys: list[str], taken: set[str]) -> dict[str, str]:
    """{key: file basename without .gd} for helper keys (`<stem>_<rest>`) in cluster folder `<stem>/`.
    `taken` = basenames (no .gd) already in the repo that these must not equal (facades, loose scripts, other helpers)."""
    toks = stem.split("_")
    rest = {k: (k[len(stem) + 1:] if k.startswith(stem + "_") else k) for k in keys}
    level = {k: (1 if rest[k] in GENERIC or len(rest[k]) <= 2 else 0) for k in keys}

    def cand(k: str) -> str:
        n = level[k]
        if n == 0:
            return rest[k]
        return "_".join(toks[-n:] + [rest[k]]) if n <= len(toks) else stem + "_" + rest[k]

    for _ in range(len(toks) + 3):
        groups: dict[str, list[str]] = {}
        for k in keys:
            groups.setdefault(cand(k), []).append(k)
        bump = False
        for name, ks in groups.items():
            if len(ks) > 1 or name in taken:
                for k in ks:
                    if level[k] <= len(toks):
                        level[k] += 1
                        bump = True
        if not bump:
            break
    return {k: cand(k) for k in keys}


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
