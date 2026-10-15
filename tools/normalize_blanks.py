#!/usr/bin/env python3
"""Collapse consecutive blank lines to one across text files. Keeps each file's BOM and line endings.

    python tools/normalize_blanks.py [PATH ...] [--ext md,py,gd] [--dry-run]

PATH is a file or directory (repeatable). A directory walks files whose suffix is in --ext
(default md,py,gd). Skips _logs, .git, archives. Writes through md_format_lib so BOM and EOL are kept.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log
import md_format_lib

SKIP = {".git", "_logs", "archives", ".archive_worktrees", "__pycache__"}

def iter_files(root: Path, paths: list[str], exts: set[str]) -> list[Path]:
    hits: list[Path] = []
    raw = paths or ["."]
    for item in raw:
        target = Path(item)
        if not target.is_absolute():
            target = (root / target).resolve()
        if target.is_file():
            if target.suffix.lstrip(".").lower() in exts:
                hits.append(target)
            continue
        if target.is_dir():
            for p in sorted(target.rglob("*")):
                if not p.is_file():
                    continue
                if any(part in SKIP for part in p.parts):
                    continue
                if p.suffix.lstrip(".").lower() in exts:
                    hits.append(p)
    return hits

def main(argv: list[str] | None = None) -> int:
    parser = agent_log.std_parser(
        "Collapse consecutive blank lines to one. Keeps BOM and line endings.",
        writes=True,
    )
    parser.add_argument("paths", nargs="*", help="File or directory (default: current repo)")
    parser.add_argument("--ext", default="md,py,gd", help="Comma-separated suffixes to include (default md,py,gd)")
    args = parser.parse_args(sys.argv[1:] if argv is None else argv)
    root = agent_log.resolve_root(args)
    exts = {e.strip().lstrip(".").lower() for e in args.ext.split(",") if e.strip()}
    files = iter_files(root, args.paths, exts)
    changed = 0
    lines = ["normalize-blanks", f"scanned={len(files)}"]
    for path in files:
        try:
            text, eol, bom = md_format_lib.read_text(path, with_meta=True)
        except OSError:
            continue
        cleaned = md_format_lib.collapse_blanks(text)
        if cleaned == text:
            continue
        changed += 1
        lines.append(path.relative_to(root).as_posix())
        if not args.dry_run:
            md_format_lib.write_text(path, cleaned, eol=eol, bom=bom)
    lines.append(f"changed={changed}")
    return agent_log.finish(
        "normalize-blanks",
        root,
        "\n".join(lines),
        "PASS",
        args=args,
        changed=changed,
        scanned=len(files),
    )

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
