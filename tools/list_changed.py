#!/usr/bin/env python3
"""List git-changed paths with on-disk bytes (git status --porcelain), largest first.

    python3 tools/list_changed.py [--scope scripts,tools] [--head] [--log-count 10]
Read the summary, do not paste git diffs. Summary: _logs/changed/summary.txt.
Old spellings: -Scope -Head -LogCount.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log
import repo_lib

DEFAULT_SCOPE = ["scripts", "scenes", "tools", "design", ".grok/skills", ".cursor/skills"]


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("List git-changed paths in scope with sizes.", json_out=True)
    ap.add_argument("--scope", "-Scope", nargs="+", default=DEFAULT_SCOPE, help="Path prefixes, comma or space separated.")
    ap.add_argument("--head", "-Head", action="store_true", help="Append HEAD sha and recent log.")
    ap.add_argument("--log-count", "-LogCount", type=int, default=10, help="Log lines shown with --head (default 10).")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    scope = [s.replace("\\", "/").strip("/") for s in agent_log.split_list(args.scope)]
    nope = [] if args.scope is DEFAULT_SCOPE else [s for s in scope if not (root / s).exists()]
    if nope:
        agent_log.fail(f"--scope {', '.join(nope)}: not a repo path (scope = path prefixes, example: --scope scripts tools)")
    _, out = repo_lib.run_git(root, "status", "--porcelain", "--untracked-files=all")
    rows, seen = [], set()
    for line in out.splitlines():
        if len(line) < 4:
            continue
        code, rest = line[:2], line[3:]
        rel = rest.split(" -> ")[-1].strip().strip('"').replace("\\", "/")
        if rel in seen or not any(rel == s or rel.startswith(s + "/") for s in scope):
            continue
        seen.add(rel)
        full = root / rel
        if full.is_dir():
            continue
        n = full.stat().st_size if full.exists() else 0
        rows.append((n, "D" if not full.exists() else code.strip(), rel))
    rows.sort(key=lambda r: (-r[0], r[2]))
    body = ["root=.", f"scope={','.join(scope)} count={len(rows)}", "measure=git status --porcelain + file bytes", "",
            "state\tbytes\tKB\tpath"] + [f"{s}\t{n}\t{n / 1000:.2f}\t{r}" for n, s, r in rows]
    if args.head:
        sha = repo_lib.run_git(root, "rev-parse", "HEAD")[1].strip()
        log = repo_lib.run_git(root, "log", "-n", str(args.log_count), "--oneline")[1].splitlines()
        body += ["", f"HEAD={sha}", f"logCount={len(log)}"] + [f"  {ln}" for ln in log]
    echo = [f"Changed in scope: {len(rows)} paths"] + [f"{s:>3} {n:6d}  {r}" for n, s, r in rows[:30]]
    if len(rows) > 30:
        echo.append(f"... +{len(rows) - 30} more (see summary)")
    return agent_log.finish("changed", root, "\n".join(body), "INFO", args=args, echo="\n".join(echo), count=len(rows))


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
