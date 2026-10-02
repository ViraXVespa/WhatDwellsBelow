#!/usr/bin/env python3
"""Fail if live scripts/**/*.gd are at or over the ship floor, or if two scripts share a basename (dupes=). Linux twin of check_script_cap.ps1. Grok Bot owns this cap. Grok Build prove does not run it unless the User named size."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
import gd_lib
import repo_lib

DEFAULT_OVER_KB = 10


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = agent_log.std_parser("Check scripts/**/*.gd against the on-disk byte cap.", json_out=True)
    parser.add_argument(
        "--over-kb", "-OverKb",
        dest="over_kb",
        type=float,
        default=DEFAULT_OVER_KB,
        help="Bot-owned ship floor in KB. Limit is round(over_kb * 1000) bytes (default 10 -> 10000). Pass 5 for the Bot sweep target.",
    )
    parser.add_argument(
        "--git-changed", "-GitChanged",
        dest="git_changed",
        action="store_true",
        help="Only files listed by git status --porcelain -- scripts.",
    )
    parser.add_argument(
        "--path", "-Path",
        action="append",
        default=[],
        help="Explicit script path (repeatable). Relative to --root unless absolute.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    root = agent_log.resolve_root(args)
    limit = int(round(args.over_kb * 1000))

    args.path = agent_log.split_list(args.path)
    if args.path:
        files: list[Path] = []
        for raw in args.path:
            path = Path(raw)
            if not path.is_absolute():
                path = root / path
            if path.is_file():
                files.append(path)
    elif args.git_changed:
        found = repo_lib.git_changed(root, "scripts")
        if found is None:
            agent_log.fail("git status failed")
        files = [root / r for r in found if r.endswith(".gd") and (root / r).is_file()]
    else:
        files = gd_lib.iter_gd(root)

    over: list[tuple[int, str]] = []
    for path in files:
        size = path.stat().st_size
        if size >= limit:
            over.append((size, agent_log.rel(root, path)))
    over.sort(key=lambda row: (-row[0], row[1]))
    # basenames must stay unique repo-wide (editor tabs, quick-open, grep, bare code-map names): design/refactor.md Cluster folders
    by_name: dict[str, list[str]] = {}
    for gp in gd_lib.iter_gd(root):
        by_name.setdefault(gp.name, []).append(agent_log.rel(root, gp))
    mine = {agent_log.rel(root, f) for f in files}
    dupes = sorted((n, ps) for n, ps in by_name.items() if len(ps) > 1 and mine & set(ps))

    lines = [
        "script cap",
        "root=.",
        f"overKb={args.over_kb} limit={limit}",
        "measure=os.path.getsize (== Get-Item Length)",
        f"checked={len(files)} over={len(over)} dupes={len(dupes)}",
        "",
        "bytes\tpath",
    ]
    for size, rel in over:
        lines.append(f"{size}\t{rel}")
    for name, paths in dupes:
        lines.append(f"DUPE\t{name}\t" + " | ".join(paths))
    body = "\n".join(lines)
    return agent_log.finish(
        "script-cap", root, body, "FAIL" if over or dupes else "PASS", args=args,
        checked=len(files), over=len(over), dupes=len(dupes), limit=limit,
    )


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
