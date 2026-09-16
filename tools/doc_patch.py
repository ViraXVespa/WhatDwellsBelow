#!/usr/bin/env python3
"""Idempotent documentation helpers for web / chat Phase 7 runners.

Scratch runners must import this module instead of copying replace logic:

    import sys
    from pathlib import Path
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import doc_patch as dp
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path


def repo_root(start: Path | None = None) -> Path:
    if start is None:
        start = Path(__file__).resolve()
    here = start if start.is_dir() else start.parent
    for cand in [here, *here.parents]:
        if (cand / "AGENTS.md").is_file() and (cand / "design").is_dir():
            return cand
    cwd = Path.cwd()
    if (cwd / "AGENTS.md").is_file() and (cwd / "design").is_dir():
        return cwd
    raise SystemExit("FAIL  run from the WhatDwellsBelow repo root")


def read_text(path: Path) -> str:
    if not path.is_file():
        raise SystemExit(f"FAIL  missing {path.as_posix()}")
    return path.read_text(encoding="utf-8")


def write_text(path: Path, text: str) -> None:
    if not text.endswith("\n"):
        text += "\n"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", newline="\n")
    print(f"  wrote {path.as_posix()} ({path.stat().st_size} bytes)")


def _variants(old: str) -> list[str]:
    out: list[str] = []
    seen: set[str] = set()

    def add(item: str) -> None:
        if item and item not in seen:
            seen.add(item)
            out.append(item)

    add(old)
    add(old.replace("\r\n", "\n"))
    if "\n" in old:
        add(re.sub(r" +\n", "\n", old))
        add(re.sub(r"\n", "  \n", old.replace("  \n", "\n")))
    tickless = re.sub(r"`(design/[\w./-]+\.md)`", r"\1", old)
    add(tickless)
    add(re.sub(r"(design/[\w./-]+\.md)", r"`\1`", tickless))
    return out


def replace_once(text: str, old: str, new: str, where: str) -> str:
    for cand in _variants(old):
        if cand in text:
            return text.replace(cand, new, 1)
    if new in text:
        print(f"  skip {where} (already applied)")
        return text
    raise SystemExit(f"FAIL  patch miss in {where}: {old[:96]!r}")


def replace_once_any(text: str, olds: list[str], new: str, where: str) -> str:
    if new in text:
        print(f"  skip {where} (already applied)")
        return text
    last = ""
    for old in olds:
        last = old
        for cand in _variants(old):
            if cand in text:
                return text.replace(cand, new, 1)
    raise SystemExit(f"FAIL  patch miss in {where}: {last[:96]!r}")


def patch_file(path: Path, old: str, new: str) -> None:
    text = replace_once(read_text(path), old, new, path.as_posix())
    write_text(path, text)


def set_read_when(path: Path, value: str) -> None:
    text = read_text(path)
    new_line = f"Read when: {value.rstrip()}"
    updated, n = re.subn(r"^Read when:.*$", new_line, text, count=1, flags=re.M)
    if n == 0:
        raise SystemExit(f"FAIL  no Read when in {path.as_posix()}")
    if updated == text:
        print(f"  skip {path.as_posix()} Read when (already applied)")
        return
    write_text(path, updated)


def ensure_line(path: Path, line: str, after: str | None = None) -> None:
    text = read_text(path)
    needle = line.rstrip("\n")
    if needle in text:
        print(f"  skip {path.as_posix()} ensure_line (already applied)")
        return
    insert = needle + "\n"
    if after is None:
        write_text(path, text.rstrip("\n") + "\n" + insert)
        return
    if after not in text:
        raise SystemExit(f"FAIL  ensure_line anchor miss in {path.as_posix()}: {after[:96]!r}")
    write_text(path, text.replace(after, after + insert, 1))


def drop_citations(path: Path, needles: list[str]) -> None:
    text = read_text(path)
    keep: list[str] = []
    changed = False
    for line in text.splitlines(keepends=True):
        if any(n in line for n in needles):
            changed = True
            continue
        keep.append(line)
    if not changed:
        print(f"  skip {path.as_posix()} drop_citations (already applied)")
        return
    write_text(path, "".join(keep))


def drop_table_column(path: Path, header: str) -> None:
    text = read_text(path)
    lines = text.splitlines(keepends=True)
    idx = None
    out: list[str] = []
    in_table = False
    changed = False
    for line in lines:
        if line.startswith("|") and header in line and idx is None:
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            if header in cells:
                idx = cells.index(header)
                in_table = True
        if in_table and line.startswith("|") and idx is not None:
            raw = line.strip().strip("|").split("|")
            if len(raw) > idx:
                raw.pop(idx)
                line = "| " + " | ".join(c.strip() for c in raw) + " |\n"
                changed = True
        elif in_table and not line.startswith("|"):
            in_table = False
        out.append(line)
    if not changed:
        print(f"  skip {path.as_posix()} drop_table_column (already applied)")
        return
    write_text(path, "".join(out))


def next_label(root: Path | None = None) -> str:
    """Baked version.json label with patch + 1. Ignore stamp commits."""
    root = repo_root(root)
    raw = json.loads((root / "scripts/data/version.json").read_text(encoding="utf-8"))
    epoch = int(raw["epoch"])
    series = int(raw["series"])
    patch = int(raw["patch"])
    return f"{epoch}.{series}.{patch + 1}"


def _ensure_summary(text: str, summary: str) -> tuple[str, bool]:
    line = f"Summary: {summary.strip()}"
    if re.search(r"^Summary:", text, re.I | re.M):
        return text, False
    if not text.endswith("\n"):
        text += "\n"
    return text + "\n" + line + "\n", True


def write_changelog(root: Path, bullets: list[str], label: str | None = None, summary: str | None = None) -> Path:
    root = repo_root(root)
    label = label or next_label(root)
    path = root / "design/changelog" / f"{label}.md"
    incoming = [b.rstrip() for b in bullets if b.strip()]
    if path.is_file():
        text = read_text(path)
        added = False
        for bullet in incoming:
            line = f"- {bullet}"
            if line in text or bullet in text:
                continue
            if not text.endswith("\n"):
                text += "\n"
            text += line + "\n"
            added = True
        if summary:
            text, sum_added = _ensure_summary(text, summary)
            added = added or sum_added
        if added:
            write_text(path, text)
        else:
            print(f"  skip {path.as_posix()} (bullets already present)")
        return path
    body = f"## {label}\n\n" + "".join(f"- {b}\n" for b in incoming)
    if summary:
        body += f"\nSummary: {summary}\n"
    write_text(path, body)
    return path


def run_checker(root: Path | None = None) -> int:
    root = repo_root(root)
    print("running tools/check_load_graph.py")
    proc = subprocess.run(
        [sys.executable, str(root / "tools/check_load_graph.py"), "--root", str(root)],
        cwd=str(root),
    )
    if proc.returncode != 0:
        print(f"FAIL  check_load_graph exit {proc.returncode}")
    return proc.returncode
