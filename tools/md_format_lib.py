#!/usr/bin/env python3
"""Shared markdown formatting helpers for surgical doc edits.

Used by bot_opt, code_map_lib, patch_code_map, and doc_patch.
Not a markdown engine, CommonMark parser, or doc framework.
"""
from __future__ import annotations

import re
from pathlib import Path

TICK_RE = re.compile(r"`([^`]+)`")


def posix(rel: str) -> str:
    p = rel.replace("\\", "/").strip()
    while p.startswith("./"):
        p = p[2:]
    return p.lstrip("/")


def tick_wrap(token: str) -> str:
    return f"`{posix(token)}`"


def tick_tokens(text: str) -> list[str]:
    return [posix(t) for t in TICK_RE.findall(text) if posix(t)]


def force_lf(text: str) -> str:
    return text.replace("\r\n", "\n").replace("\r", "\n")


def ensure_trailing_newline(text: str) -> str:
    if not text.endswith("\n"):
        return text + "\n"
    return text


def write_utf8(path: Path, text: str, *, mkdir: bool = False) -> None:
    """UTF-8 text write with LF newlines and a trailing newline."""
    if mkdir:
        path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(ensure_trailing_newline(force_lf(text)), encoding="utf-8", newline="\n")


def write_lines(path: Path, lines: list[str], *, mkdir: bool = False) -> None:
    write_utf8(path, "\n".join(lines), mkdir=mkdir)


def path_tick_variants(old: str) -> list[str]:
    """Candidate spellings for replace-once, including design-path tick variants."""
    out: list[str] = []
    seen: set[str] = set()

    def add(item: str) -> None:
        if item and item not in seen:
            seen.add(item)
            out.append(item)

    add(old)
    add(force_lf(old))
    if "\n" in old:
        add(re.sub(r" +\n", "\n", old))
        add(re.sub(r"\n", "  \n", old.replace("  \n", "\n")))
    tickless = re.sub(r"`(design/[\w./-]+\.md)`", r"\1", old)
    add(tickless)
    add(re.sub(r"(design/[\w./-]+\.md)", r"`\1`", tickless))
    return out


def replace_once_text(text: str, old: str, new: str) -> str | None:
    """Replace the first matching path-tick variant. None if no candidate hits."""
    for cand in path_tick_variants(old):
        if cand in text:
            return text.replace(cand, new, 1)
    return None


def split_marker_block(text: str, begin: str, end: str) -> tuple[str, str, str] | None:
    """Split on HTML-comment markers. Mid includes begin through end (inclusive)."""
    i = text.find(begin)
    j = text.find(end)
    if i < 0 or j < 0 or j < i:
        return None
    j_end = j + len(end)
    return text[:i], text[i:j_end], text[j_end:]


def splice_marker_block(text: str, begin: str, end: str, new_block: str) -> str | None:
    """Replace the marked region (begin..end inclusive) with new_block."""
    parts = split_marker_block(text, begin, end)
    if parts is None:
        return None
    prefix, _mid, suffix = parts
    return prefix + new_block + suffix


def rewrite_table_row(file_lines: list[str], index: int, new_line: str) -> None:
    """Replace one table row in place, preserving the original line ending."""
    old_line = file_lines[index]
    if old_line.endswith("\r\n"):
        nl = "\r\n"
    elif old_line.endswith("\n"):
        nl = "\n"
    else:
        nl = ""
    file_lines[index] = new_line.rstrip("\r\n") + nl


def join_lines_keep_trailing(raw: str, file_lines: list[str]) -> str:
    """Join mutated keepends lines; restore a trailing newline if raw had one."""
    text = "".join(file_lines)
    if raw.endswith("\n") and not text.endswith("\n"):
        text += "\n"
    return text
