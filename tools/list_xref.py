#!/usr/bin/env python3
"""Capped text search; writes a short hit list instead of dumping ripgrep into chat.

    python3 tools/list_xref.py --pattern pc-offload [--path design --path tools] [--include "*.gd"] [--regex]
Case-insensitive. Skips top-level archives/, .archive_worktrees/, _logs/, docs/. Summary: _logs/xref/summary.txt.
Old spellings: -Pattern -Path -Include -MaxHits -MaxFiles -Regex.
"""
from __future__ import annotations

import fnmatch
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log

SKIP = {"archives", ".archive_worktrees", "_logs", "docs", ".git"}


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Capped text search over scripts/scenes/tools/design.", json_out=True)
    ap.add_argument("pattern_pos", nargs="?", default="", help="Pattern (same as --pattern).")
    ap.add_argument("--pattern", "-Pattern", default="")
    ap.add_argument("--path", "-Path", nargs="+", default=["scripts", "scenes", "tools", "design"])
    ap.add_argument("--include", "-Include", default="*", help="Filename glob, e.g. *.gd")
    ap.add_argument("--max-hits", "-MaxHits", type=int, default=30)
    ap.add_argument("--max-files", "-MaxFiles", type=int, default=20)
    ap.add_argument("--regex", "-Regex", action="store_true")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    pattern = args.pattern or args.pattern_pos
    if not pattern:
        agent_log.fail("pass --pattern TEXT")
    rx = re.compile(pattern if args.regex else re.escape(pattern), re.IGNORECASE)
    paths = agent_log.split_list(args.path)
    hits: list[str] = []
    files_hit: set[str] = set()
    scanned, trunc = 0, False
    for raw in paths:
        base = Path(raw)
        base = base if base.is_absolute() else root / base
        if not base.exists():
            continue
        cands = [base] if base.is_file() else sorted(base.rglob("*"))
        for f in cands:
            if not f.is_file() or SKIP & set(f.relative_to(root).parts[:1]) or not fnmatch.fnmatch(f.name, args.include):
                continue
            scanned += 1
            if len(files_hit) >= args.max_files or len(hits) >= args.max_hits:
                trunc = True
                break
            try:
                data = f.read_bytes()
            except OSError:
                continue
            if b"\0" in data[:2048]:
                continue
            rel = agent_log.rel(root, f)
            for n, line in enumerate(data.decode("utf-8", "replace").splitlines(), 1):
                if rx.search(line):
                    files_hit.add(rel)
                    if len(hits) >= args.max_hits:
                        trunc = True
                        break
                    text = line.strip()
                    hits.append(f"{rel}:{n}:{text[:160] + '...' if len(text) > 160 else text}")
        if trunc:
            break
    mode = "regex" if args.regex else "simple"
    body = [f"root=. pattern={pattern} mode={mode} include={args.include} path={','.join(paths)}",
            f"maxHits={args.max_hits} maxFiles={args.max_files} scanned={scanned} files={len(files_hit)} hits={len(hits)} truncated={trunc}",
            ""] + hits
    echo = f"xref files={len(files_hit)} hits={len(hits)} scanned={scanned} truncated={trunc}"
    return agent_log.finish("xref", root, "\n".join(body), "INFO", args=args, echo=echo, files=len(files_hit),
                            hits=len(hits), scanned=scanned, truncated=trunc)


if __name__ == "__main__":
    raise SystemExit(main())
