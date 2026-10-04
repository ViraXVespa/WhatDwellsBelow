#!/usr/bin/env python3
"""List git-changed paths with on-disk bytes (git status --porcelain), largest first; or compare change history.

    python tools/list_changed.py [--scope scripts,tools] [--head] [--log-count 10]
    python tools/list_changed.py --history DOC.md CODE.gd [MORE ...] [--per-path 5]
--history: for each path its latest commits (date, sha, subject), then which path changed last. A doc and its code
disagree: the newer change is probably the truth; if the dates are close or the subjects do not explain it, ask.
Read the summary, do not paste git diffs. Each run writes _logs/changed/<stamp>-changed.txt (read_summary.py --job changed).
Old spellings: -Scope -Head -LogCount.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log
import repo_lib

DEFAULT_SCOPE = ["scripts", "scenes", "tools", "design", ".grok/skills", ".cursor/skills"]


def history(root: Path, args: argparse.Namespace, where: str) -> int:
    paths = [p.replace("\\", "/").strip("/") for p in agent_log.split_list(args.history)]
    missing = [p for p in paths if not (root / p).exists()]
    if missing:
        agent_log.fail(f"--history {', '.join(missing)}: not a repo path")
    dirty = set(repo_lib.git_changed(root) or [])
    body, stamps = [where, f"history paths={len(paths)} per_path={args.per_path}", ""], {}
    for p in paths:
        code, out = repo_lib.run_git(root, "log", "-n", str(max(1, args.per_path)), "--format=%ct%x09%cs%x09%h%x09%s", "--", p)
        rows = [r.split("\t", 3) for r in out.splitlines() if code == 0 and r.count("\t") >= 3]
        stamps[p] = int(rows[0][0]) if rows else 0
        state = " (uncommitted edits)" if p in dirty else ""
        body.append(f"{p}{state}" + ("" if rows else "  no commits"))
        body += [f"  {r[1]} {r[2]} {r[3][:100]}" for r in rows]
    ranked = sorted(paths, key=lambda p: -stamps[p])
    verdict = "same"
    if len(ranked) > 1 and stamps[ranked[0]] > stamps[ranked[1]]:
        verdict = ranked[0]
        days = (stamps[ranked[0]] - stamps[ranked[1]]) / 86400
        body += ["", f"newer={ranked[0]} (last changed {days:.1f} days after {ranked[1]})"]
    elif len(ranked) > 1:
        body += ["", "newer=same (same commit time): ask if the subjects do not settle it"]
    echo = "\n".join(body)
    return agent_log.finish("changed", root, "\n".join(body), "INFO", args=args, echo=echo, newer=verdict, paths=len(paths))


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("List git-changed paths in scope with sizes.", json_out=True)
    ap.add_argument("--scope", "-Scope", nargs="+", default=DEFAULT_SCOPE, help="Path prefixes, comma or space separated.")
    ap.add_argument("--head", "-Head", action="store_true", help="Append HEAD sha and recent log.")
    ap.add_argument("--log-count", "-LogCount", type=int, default=10, help="Log lines shown with --head (default 10).")
    ap.add_argument("--history", nargs="+", metavar="PATH", default=[], help="Compare the change history of these paths (a doc and its code): latest commits each, and which changed last.")
    ap.add_argument("--per-path", type=int, default=5, help="With --history: commits listed per path (default 5).")
    args = ap.parse_args(argv)
    root, where = agent_log.cwd_scan_root(args)
    if args.history:
        return history(root, args, where)
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
    body = [where, f"scope={','.join(scope)} count={len(rows)}", "measure=git status --porcelain + file bytes", "",
            "state\tbytes\tKB\tpath"] + [f"{s}\t{n}\t{n / 1000:.2f}\t{r}" for n, s, r in rows]
    if args.head:
        sha = repo_lib.run_git(root, "rev-parse", "HEAD")[1].strip()
        log = repo_lib.run_git(root, "log", "-n", str(args.log_count), "--oneline")[1].splitlines()
        body += ["", f"HEAD={sha}", f"logCount={len(log)}"] + [f"  {ln}" for ln in log]
    echo = [where, f"Changed in scope: {len(rows)} paths"] + [f"{s:>3} {n:6d}  {r}" for n, s, r in rows[:30]]
    if len(rows) > 30:
        echo.append(f"... +{len(rows) - 30} more (see summary)")
    return agent_log.finish("changed", root, "\n".join(body), "INFO", args=args, echo="\n".join(echo), count=len(rows))


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
