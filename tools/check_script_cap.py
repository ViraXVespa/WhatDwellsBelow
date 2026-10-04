#!/usr/bin/env python3
"""Script name check: FAIL (exit 1) when two live scripts/**/*.gd share a basename (dupes=). Linux twin of check_script_cap.ps1.

    check_script_cap.py [--git-changed | --path P]    basenames must stay unique repo-wide
The Bot and CI also run the size checks of this tool (BOT.md); outside them only the name check runs.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
import bot_gate_lib
import gd_lib
import repo_lib

DEFAULT_OVER_KB = bot_gate_lib.SHIP_BYTES // 1000
SWEEP_OVER_KB = bot_gate_lib.SWEEP_BYTES / 1000


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = agent_log.std_parser("Check live scripts/**/*.gd: basenames unique repo-wide.", json_out=True)
    bot_gate_lib.add_flag(parser)
    sup = argparse.SUPPRESS  # Bot-only size options: BOT.md
    parser.add_argument("--over-kb", "-OverKb", dest="over_kb", type=float, default=None, help=sup)
    parser.add_argument("--list", action="store_true", help=sup)
    parser.add_argument("--under-kb", "-UnderKb", type=float, default=0, help=sup)
    parser.add_argument("--sweep", action="store_true", help=sup)
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
    bot = bot_gate_lib.enabled(args)
    if (args.sweep or args.list or args.over_kb is not None) and not bot:
        return bot_gate_lib.not_run("script size listing")
    if args.sweep:
        args.list, args.under_kb = True, 10.0
        args.over_kb = SWEEP_OVER_KB if args.over_kb is None else args.over_kb
    if args.over_kb is None:
        args.over_kb = SWEEP_OVER_KB if args.list else DEFAULT_OVER_KB
    limit = int(round(args.over_kb * 1000))
    if args.list:
        hi = int(round(args.under_kb * 1000)) if args.under_kb > 0 else None
        rows = gd_lib.sizes(root, limit, hi)
        under = f"{args.under_kb:g}" if hi else "none"
        body = ["root=.", f"overKb={args.over_kb:g} underKb={under} count={len(rows)}", "measure=on-disk bytes", "", "bytes\tpath"] + [f"{n}\t{r}" for n, r in rows]
        echo = [f"{len(rows)} scripts >= {args.over_kb:g}KB" + (f" and < {args.under_kb:g}KB" if hi else "")] + [f"{n:6d}  {r}" for n, r in rows[:30]]
        if len(rows) > 30:
            echo.append(f"... +{len(rows) - 30} more (summary file)")
        return agent_log.finish("script-cap", root, "\n".join(body), "INFO", args=args, echo="\n".join(echo), count=len(rows))

    args.path = agent_log.split_list(args.path)
    if args.path:
        files: list[Path] = []
        for raw in args.path:
            path = Path(raw)
            if not path.is_absolute():
                path = root / path
            if not path.is_file():
                agent_log.fail(f"--path {raw}: no such file (give repo-relative .gd paths, or omit for all scripts)")
            files.append(path)
    elif args.git_changed:
        found = repo_lib.git_changed(root, "scripts")
        if found is None:
            agent_log.fail("git status failed")
        files = [root / r for r in found if r.endswith(".gd") and (root / r).is_file()]
    else:
        files = gd_lib.iter_gd(root)

    over: list[tuple[int, str]] = []
    for path in files if bot else []:
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

    lines = ["script cap" if bot else "script names", "root=."]
    if bot:
        lines += [f"overKb={args.over_kb} limit={limit}", "measure=os.path.getsize (== Get-Item Length)",
                  f"checked={len(files)} over={len(over)} dupes={len(dupes)}", "", "bytes\tpath"]
        lines += [f"{size}\t{rel}" for size, rel in over]
    else:
        lines += [f"checked={len(files)} dupes={len(dupes)}", ""]
    for name, paths in dupes:
        lines.append(f"DUPE\t{name}\t" + " | ".join(paths))
    if over:
        lines.append("next: split the file (BOT.md size flow, design/refactor.md); do not raise --over-kb")
    if dupes:
        lines.append("next: DUPE = rename one file; basenames are unique repo-wide")
    kv = dict(checked=len(files), dupes=len(dupes))
    if bot:
        kv.update(over=len(over), limit=limit)
    return agent_log.finish("script-cap", root, "\n".join(lines), "FAIL" if over or dupes else "PASS", args=args, **kv)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
