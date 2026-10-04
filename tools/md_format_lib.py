#!/usr/bin/env python3
"""Shared markdown formatting helpers for surgical doc edits.

Used by bot_opt, code_map_lib, doc_patch, and the tool CLIs.
Single home for text I/O: read_text (BOM/EOL aware), detect_eol, write_text (EOL kept).
Not a markdown engine, CommonMark parser, or doc framework.
"""
from __future__ import annotations

import re
from pathlib import Path

TICK_RE = re.compile(r"`([^`]+)`")

_FOUR_SPACES = "    "


def is_gdscript_path(path: Path | str | None) -> bool:
    if path is None:
        return False
    return Path(str(path)).suffix.lower() == ".gd"


def leading_spaces_to_tabs(text: str) -> str:
    """Map each leading run of four spaces to one tab. Mid-line spaces stay."""
    text = force_lf(text)
    out: list[str] = []
    for line in text.split("\n"):
        i = 0
        n = 0
        while line.startswith(_FOUR_SPACES, i):
            n += 1
            i += 4
        out.append(("\t" * n) + line[i:])
    return "\n".join(out)


def maybe_gd_indent(text: str, path: Path | str | None) -> str:
    if is_gdscript_path(path):
        return leading_spaces_to_tabs(text)
    return text


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


def force_crlf(text: str) -> str:
    return force_lf(text).replace("\n", "\r\n")


def write_utf8(path: Path, text: str, *, mkdir: bool = False) -> None:
    """UTF-8 text write with CRLF newlines and a trailing newline."""
    text = maybe_gd_indent(text, path)
    if mkdir:
        path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(ensure_trailing_newline(force_lf(text)).replace("\n", "\r\n"), encoding="utf-8", newline="")

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


def replace_once_text(
    text: str, old: str, new: str, *, path: Path | str | None = None
) -> str | None:
    """Replace the first matching path-tick variant. None if no candidate hits.

    For .gd targets, retry after mapping leading four-space runs to tabs on
    both the needle and the replacement.
    """
    for cand in path_tick_variants(old):
        if cand in text:
            return text.replace(cand, maybe_gd_indent(new, path), 1)
    if is_gdscript_path(path):
        old_gd = leading_spaces_to_tabs(old)
        new_gd = leading_spaces_to_tabs(new)
        if old_gd != old or new_gd != new:
            for cand in path_tick_variants(old_gd):
                if cand in text:
                    return text.replace(cand, new_gd, 1)
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


def detect_eol(raw: bytes | str) -> str:
    """CRLF if the first line break is CRLF, else LF."""
    if isinstance(raw, bytes):
        i = raw.find(b"\n")
        return "\r\n" if i > 0 and raw[i - 1:i] == b"\r" else "\n"
    i = raw.find("\n")
    return "\r\n" if i > 0 and raw[i - 1] == "\r" else "\n"


def read_text(path: Path | str, *, with_meta: bool = False):
    """Decode UTF-8 (BOM stripped), return LF text. with_meta -> (text, eol, bom)."""
    raw = Path(path).read_bytes()
    bom = raw.startswith(b"\xef\xbb\xbf")
    if bom:
        raw = raw[3:]
    text = force_lf(raw.decode("utf-8"))
    if with_meta:
        return text, detect_eol(raw), bom
    return text


def write_text(
    path: Path | str,
    text: str,
    *,
    eol: str = "keep",
    bom: bool | None = None,
    mkdir: bool = False,
) -> None:
    """Write UTF-8. eol: keep (existing file's, else CRLF repo default), crlf, lf.

    bom: None keeps the existing file's BOM. A trailing newline is ensured.
    """
    path = Path(path)
    prior = path.read_bytes() if path.is_file() else b""
    if eol == "keep":
        eol = "crlf" if not prior else ("crlf" if detect_eol(prior) == "\r\n" else "lf")
    if bom is None:
        bom = prior.startswith(b"\xef\xbb\xbf")
    text = ensure_trailing_newline(force_lf(maybe_gd_indent(text, path)))
    if eol == "crlf":
        text = text.replace("\n", "\r\n")
    if mkdir:
        path.parent.mkdir(parents=True, exist_ok=True)
    data = text.encode("utf-8")
    path.write_bytes((b"\xef\xbb\xbf" if bom else b"") + data)
