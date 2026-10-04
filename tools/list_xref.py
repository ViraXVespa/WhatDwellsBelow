#!/usr/bin/env python3
"""Capped text search; writes a short hit list instead of dumping ripgrep into chat.

    python tools/list_xref.py --pattern pc-offload [--path design --path tools] [--include "*.gd"] [--regex]
Scans the project that holds the current directory (so a worktree is scanned from inside it), else this tool's own checkout;
--root overrides. The first output line prints the absolute scanned root, with a WARN when it is not the current directory's project.
Case-insensitive. Skips top-level archives/, .archive_worktrees/, _logs/, docs/. Summary: _logs/xref/<stamp>-xref.txt.
Old spellings: -Pattern -Path -Include -MaxHits -MaxFiles -Regex.
"""
from __future__ import annotations

import fnmatch
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log
import gd_lib

SKIP = {*gd_lib.SKIP_PARTS, "_logs", "docs", ".git"}


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Capped text search over scripts/scenes/tools/design.", json_out=True)
    ap.add_argument("pattern_pos", nargs="?", default="", help="Pattern (same as --pattern).")
    ap.add_argument("--pattern", "-Pattern", default="", help="Text to find (or pass it as the argument).")
    ap.add_argument("--path", "-Path", nargs="+", default=["scripts", "scenes", "tools", "design"], help="Files or dirs to search (default scripts scenes tools design).")
    ap.add_argument("--include", "-Include", default="*", help="Filename glob, e.g. *.gd")
    ap.add_argument("--max-hits", "-MaxHits", type=int, default=30, help="Max hits in total (default 30).")
    ap.add_argument("--max-files", "-MaxFiles", type=int, default=20, help="Max files listed (default 20).")
    ap.add_argument("--regex", "-Regex", action="store_true", help="Treat the pattern as a regular expression.")
    args = ap.parse_args(argv)
    cwd_root = None
    if not args.root:
        try:
            cwd_root = agent_log.repo_root(Path.cwd())
        except FileNotFoundError:
            pass
    root = agent_log.resolve_root(args.root or cwd_root)
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
    where = f"root={root}" + (f" WARN: the current directory's project is {cwd_root}, not this root; pass --root {cwd_root}" if cwd_root and cwd_root != root else "")
    body = [f"{where} pattern={pattern} mode={mode} include={args.include} path={','.join(paths)}",
            f"maxHits={args.max_hits} maxFiles={args.max_files} scanned={scanned} files={len(files_hit)} hits={len(hits)} truncated={trunc}",
            ""] + hits
    echo = f"{where}\nxref files={len(files_hit)} hits={len(hits)} scanned={scanned} truncated={trunc}"
    echo += "".join("\n" + h for h in hits[:args.max_hits])
    if trunc:
        echo += "\nnext: more hits exist; narrow with --path/--include or raise --max-hits"
    elif not hits:
        echo += "\nnext: no match; try a shorter pattern or --regex (search is case-insensitive over scripts scenes tools design)"
    return agent_log.finish("xref", root, "\n".join(body), "INFO", args=args, echo=echo, files=len(files_hit),
                            hits=len(hits), scanned=scanned, truncated=trunc)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
