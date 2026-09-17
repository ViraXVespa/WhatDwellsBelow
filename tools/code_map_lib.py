#!/usr/bin/env python3
"""Parse and mutate the live-files table in design/code-map.md.

Used by list_code_map_row.py, patch_code_map.py, and check_code_map.py.
Do not dump the whole map into a session; runners write _logs summaries.
"""
from __future__ import annotations

import re
from typing import NamedTuple

TICK_RE = re.compile(r"`([^`]+)`")
ROW_RE = re.compile(r"^\|\s*(.*?)\s*\|\s*(.*?)\s*\|\s*$")
FILE_SUFFIXES = (
    ".gd",
    ".tscn",
    ".json",
    ".py",
    ".ps1",
    ".html",
    ".cfg",
    ".yml",
    ".yaml",
)


class Row(NamedTuple):
    system: str
    live: str
    listed: list[str]
    index: int


def posix(rel: str) -> str:
    p = rel.replace("\\", "/")
    while p.startswith("./"):
        p = p[2:]
    return p.lstrip("/")


def row_paths(live_cell: str) -> list[str]:
    found: list[str] = []
    last_dir = ""
    for raw in TICK_RE.findall(live_cell):
        token = posix(raw.strip())
        if not token:
            continue
        if "/" in token:
            last_dir = token.rsplit("/", 1)[0]
            found.append(token)
            continue
        if last_dir:
            found.append(f"{last_dir}/{token}")
        found.append(token)
    return found


def matches(needle: str, listed: list[str]) -> bool:
    n = posix(needle)
    base = n.rsplit("/", 1)[-1]
    for item in listed:
        if item == n or item.endswith("/" + n):
            return True
        if item == base or item.rsplit("/", 1)[-1] == base:
            return True
    return False


def parse_rows(text: str) -> list[Row]:
    rows: list[Row] = []
    seen_header = False
    for index, line in enumerate(text.splitlines()):
        m = ROW_RE.match(line)
        if not m:
            continue
        left, right = m.group(1).strip(), m.group(2).strip()
        if left.lower() == "system" and "live" in right.lower():
            seen_header = True
            continue
        if not seen_header:
            continue
        if set(left.replace("-", "")) == set() or left.startswith("-"):
            continue
        rows.append(Row(left, right, row_paths(right), index))
    return rows


def find_system(rows: list[Row], needle: str) -> Row | None:
    n = needle.strip().lower()
    if not n:
        return None
    exact = [row for row in rows if row.system.lower() == n]
    if len(exact) == 1:
        return exact[0]
    prefixes = [row for row in rows if row.system.lower().startswith(n)]
    if len(prefixes) == 1:
        return prefixes[0]
    if len(exact) > 1:
        return None
    subs = [row for row in rows if n in row.system.lower()]
    if len(subs) == 1:
        return subs[0]
    return None


def system_choices(rows: list[Row], needle: str) -> list[str]:
    n = needle.strip().lower()
    names = [row.system for row in rows]
    if not n:
        return names
    hits = [row.system for row in rows if n in row.system.lower()]
    return hits or names


def _parent(path: str) -> str:
    p = posix(path)
    if p.endswith("/"):
        return p.rstrip("/")
    if "/" not in p:
        return ""
    return p.rsplit("/", 1)[0]


def _iter_ticks(live: str) -> list[tuple[re.Match[str], str, str]]:
    """(match, token, resolved path) in left-to-right order."""
    out: list[tuple[re.Match[str], str, str]] = []
    last_dir = ""
    for m in TICK_RE.finditer(live):
        token = posix(m.group(1).strip())
        if not token:
            continue
        if "/" in token:
            last_dir = token.rsplit("/", 1)[0]
            resolved = token
        elif last_dir:
            resolved = f"{last_dir}/{token}"
        else:
            resolved = token
        out.append((m, token, resolved))
    return out


def format_row(system: str, live: str) -> str:
    return f"| {system} | {live} |"


def add_path(live: str, path: str) -> tuple[str, str, str]:
    """Return (new_live, as_token, action) where action is added|skip."""
    needle = posix(path)
    if not needle:
        return live, "", "skip"
    if matches(needle, row_paths(live)):
        return live, needle, "skip"
    base = needle.rsplit("/", 1)[-1]
    parent = _parent(needle)
    ticks = _iter_ticks(live)
    last_same: re.Match[str] | None = None
    same_count = 0
    for m, _token, resolved in ticks:
        if parent and _parent(resolved) == parent:
            last_same = m
            same_count += 1
    if last_same is not None and parent:
        sep = " + " if same_count == 1 else ", "
        token = base
        insert = f"{sep}`{token}`"
        new_live = live[: last_same.end()] + insert + live[last_same.end() :]
        return new_live, token, "added"
    token = needle
    sep = "; " if live.strip() else ""
    new_live = live.rstrip() + f"{sep}`{token}`"
    return new_live, token, "added"


def _drop_tick(live: str, m: re.Match[str]) -> str:
    pre = live[: m.start()]
    post = live[m.end() :]
    if pre.endswith(" + ") and post.startswith(", "):
        nxt = TICK_RE.match(post[2:])
        if nxt and "/" not in nxt.group(1).strip():
            return pre + post[2:]
        return pre[: -len(" + ")] + post
    for sep in (", ", " + ", "; "):
        if pre.endswith(sep):
            return pre[: -len(sep)] + post
    for sep in (" + ", ", ", "; "):
        if post.startswith(sep):
            return pre + post[len(sep) :]
    return pre + post


def remove_path(live: str, path: str) -> tuple[str, str, str]:
    """Return (new_live, resolved, action) where action is removed|skip."""
    needle = posix(path)
    ticks = _iter_ticks(live)
    for m, _token, resolved in ticks:
        if matches(needle, [_token, resolved]):
            return _drop_tick(live, m), resolved, "removed"
    return live, needle, "skip"


def _rename_token(old_token: str, old_resolved: str, new_path: str) -> str:
    new_p = posix(new_path)
    new_base = new_p.rsplit("/", 1)[-1]
    new_dir = _parent(new_p)
    old_dir = _parent(old_resolved)
    if new_dir and new_dir != old_dir:
        return new_p
    if "/" in old_token:
        return new_p if "/" in new_p else (
            f"{old_dir}/{new_base}" if old_dir else new_base
        )
    return new_base


def rename_path(live: str, old: str, new: str) -> tuple[str, str, str, str]:
    """Return (new_live, old_resolved, new_token, action)."""
    needle = posix(old)
    new_p = posix(new)
    ticks = _iter_ticks(live)
    for m, token, resolved in ticks:
        if matches(needle, [token, resolved]):
            new_token = _rename_token(token, resolved, new_p)
            new_live = live[: m.start()] + f"`{new_token}`" + live[m.end() :]
            return new_live, resolved, new_token, "renamed"
    return live, needle, new_p, "skip"


def is_dir_token(token: str) -> bool:
    return posix(token).endswith("/")


def file_is_mapped(rel: str, rows: list[Row]) -> bool:
    n = posix(rel)
    listed: list[str] = []
    for row in rows:
        listed.extend(row.listed)
    if matches(n, listed):
        return True
    for item in listed:
        p = posix(item)
        if not p.endswith("/"):
            continue
        prefix = p if p.endswith("/") else p + "/"
        if n.startswith(prefix) or n.startswith(p.rstrip("/") + "/"):
            return True
    return False


def listed_file_paths(rows: list[Row]) -> list[str]:
    """Full-path ticks only. Basename ticks inherit last_dir and are not checked."""
    seen: set[str] = set()
    out: list[str] = []
    for row in rows:
        for raw in TICK_RE.findall(row.live):
            p = posix(raw.strip())
            if not p or p.endswith("/") or "/" not in p:
                continue
            if not any(p.endswith(suf) for suf in FILE_SUFFIXES):
                continue
            if p in seen:
                continue
            seen.add(p)
            out.append(p)
    return out
