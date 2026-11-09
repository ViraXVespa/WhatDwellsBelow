#!/usr/bin/env python3
"""List git-changed paths with on-disk bytes (git status --porcelain), largest first; or compare change history.

    python tools/find.py changed [--scope scripts,tools] [--head] [--log-count 10]
    python tools/find.py changed --prior-week
    python tools/find.py changed --since REV
    python tools/find.py changed --history DOC.md CODE.gd [MORE ...] [--per-path 5]
--prior-week: paths that differ between the previous "Grok Build Week N" seed and this week's seed.
--since REV: committed paths that differ from that commit to HEAD. On a clean tree, --head prints the log and no paths.
--history: for each path its latest commits (date, sha, subject), then which path changed last. A doc and its code
disagree: the newer change is probably the truth; if the dates are close or the subjects do not explain it, ask.
Read the summary, do not paste git diffs. Each run writes _logs/changed/<stamp>-changed.txt (session.py summary --job changed).

"""
from __future__ import annotations

import argparse
import re
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402,F401
import agent_log
import repo_lib

DEFAULT_SCOPE = ["scripts", "scenes", "tools", "design", ".grok/skills", ".cursor/skills", "AGENTS.md", "BOT.md"]
_WEEK_SEED = re.compile(r"^Grok Build Week \d+(?: \(#\d+\))?$")


def _in_scope(rel: str, scope: list[str]) -> bool:
    return any(rel == s or rel.startswith(s + "/") for s in scope)


def _scope(root: Path, args: argparse.Namespace) -> list[str]:
    scope = [s.replace("\\", "/").strip("/") for s in agent_log.split_list(args.scope)]
    nope = [] if args.scope is DEFAULT_SCOPE else [s for s in scope if not (root / s).exists()]
    if nope:
        agent_log.fail(f"--scope {', '.join(nope)}: not a repo path (scope = path prefixes, example: --scope scripts tools)")
    return scope


def _rev(root: Path, rev: str) -> str:
    code, out = repo_lib.run_git(root, "rev-parse", "--verify", rev + "^{commit}")
    if code != 0 or not out.strip():
        agent_log.fail(f"{rev}: not a commit")
    return out.strip()


def _week_seeds(root: Path) -> list[tuple[str, str]]:
    """Newest first: (full sha, exact 'Grok Build Week N' subject)."""
    code, out = repo_lib.run_git(root, "log", "-n", "40", "--format=%H%x09%s", "--grep=^Grok Build Week ")
    rows = []
    if code == 0:
        for line in out.splitlines():
            sha, _, subject = line.partition("\t")
            if sha and _WEEK_SEED.fullmatch(subject):
                rows.append((sha, subject))
    return rows


def _diff_rows(root: Path, start: str, end: str, scope: list[str]) -> list[tuple[int, str, str]]:
    code, out = repo_lib.run_git(root, "diff", "--name-status", "--find-renames", start, end)
    if code != 0:
        agent_log.fail(f"git diff {start[:12]} {end[:12]} failed")
    rows, seen = [], set()
    for line in out.splitlines():
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        rel = parts[-1].strip().strip('"').replace("\\", "/")
        if rel in seen or not _in_scope(rel, scope):
            continue
        seen.add(rel)
        full = root / rel
        n = full.stat().st_size if full.is_file() else 0
        rows.append((n, parts[0][:1], rel))
    rows.sort(key=lambda r: (-r[0], r[2]))
    return rows


def _range(root: Path, args: argparse.Namespace) -> tuple[str, str, str, str]:
    """(start sha, end sha, label, note). --prior-week ends at this week's seed, not at later commits."""
    if args.prior_week:
        seeds = _week_seeds(root)
        if len(seeds) < 2:
            agent_log.fail("--prior-week needs two commits titled 'Grok Build Week N' or 'Grok Build Week N (#PR)'; pass --since REV")
        end_sha, end_subj = seeds[0]
        start_sha, start_subj = seeds[1]
        note = ""
        if _rev(root, "HEAD") != end_sha:
            note = "headAfterSeed=yes (commits after this week's seed are not in the list; use --since that seed for those)"
        return start_sha, end_sha, f"{start_subj}..{end_subj}", note
    return _rev(root, args.since), _rev(root, "HEAD"), args.since, ""


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


def _selftest() -> int:
    bad = []
    if "AGENTS.md" not in DEFAULT_SCOPE or "BOT.md" not in DEFAULT_SCOPE:
        bad.append("default scope must include AGENTS.md and BOT.md")
    try:
        with tempfile.TemporaryDirectory() as td:
            root = repo_lib.selftest_repo(td, empty_commit=True)
            git = repo_lib.git_test
            (root / "scripts" / "a.gd").write_text("a\n", encoding="utf-8")
            git(root, "add", "-A")
            git(root, "commit", "-qm", "Grok Build Week 9")
            (root / "scripts" / "b.gd").write_text("b\n", encoding="utf-8")
            git(root, "add", "-A")
            git(root, "commit", "-qm", "Grok Build Week 10 (#76)")
            (root / "scripts" / "mid.gd").write_text("mid\n", encoding="utf-8")
            git(root, "add", "-A")
            git(root, "commit", "-qm", "Grok Build Week 10 extra notes")
            (root / "AGENTS.md").write_text("agents\n", encoding="utf-8")
            git(root, "add", "-A")
            git(root, "commit", "-qm", "Grok Build Week 11")
            (root / "scripts" / "c.gd").write_text("c\n", encoding="utf-8")
            git(root, "add", "-A")
            git(root, "commit", "-qm", "after seed")
            seeds = _week_seeds(root)
            if [s for _, s in seeds] != ["Grok Build Week 11", "Grok Build Week 10 (#76)", "Grok Build Week 9"]:
                bad.append("week seeds must be newest first and accept a (#PR) title, got " + ",".join(s for _, s in seeds))
            else:
                prior = {rel for _n, _s, rel in _diff_rows(root, seeds[1][0], seeds[0][0], DEFAULT_SCOPE)}
                if prior != {"scripts/mid.gd", "AGENTS.md"}:
                    bad.append("prior week must list only scripts/mid.gd and AGENTS.md, got " + ",".join(sorted(prior)))
                later = {rel for _n, _s, rel in _diff_rows(root, seeds[0][0], "HEAD", DEFAULT_SCOPE)}
                if later != {"scripts/c.gd"}:
                    bad.append("--since the current seed must list scripts/c.gd only, got " + ",".join(sorted(later)))
    except Exception as exc:
        bad.append("changed selftest fixture failed: " + type(exc).__name__)
    return agent_log.selftest_result(bad)


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("List git-changed paths in scope with sizes.", json_out=True)
    ap.add_argument("--scope", nargs="+", default=DEFAULT_SCOPE, help="Path prefixes, comma or space separated. Default includes AGENTS.md and BOT.md.")
    ap.add_argument("--head", action="store_true", help="Print the HEAD sha and the recent log. On a clean tree this is the log only.")
    ap.add_argument("--log-count", type=int, default=10, help="Log lines shown with --head (default 10).")
    ap.add_argument("--since", default="", help="Committed paths that differ from this commit to HEAD. Not the worktree.")
    ap.add_argument("--prior-week", action="store_true", help="Paths that differ between the previous Grok Build Week seed and this week's seed.")
    ap.add_argument("--history", nargs="+", metavar="PATH", default=[], help="Compare the change history of these paths (a doc and its code): latest commits each, and which changed last.")
    ap.add_argument("--per-path", type=int, default=5, help="With --history: commits listed per path (default 5).")
    ap.add_argument("--selftest", action="store_true", help="Check default scope and prior-week range on a temp repo.")
    args = ap.parse_args(argv)
    if args.selftest:
        return _selftest()
    root, where = agent_log.cwd_scan_root(args)
    if args.history:
        return history(root, args, where)
    if args.since and args.prior_week:
        agent_log.fail("pass either --since REV or --prior-week")
    scope = _scope(root, args)
    ranged = bool(args.since or args.prior_week)
    note = ""
    if ranged:
        start, end, label, note = _range(root, args)
        rows = _diff_rows(root, start, end, scope)
        measure = f"measure=git diff --name-status {start[:12]} {end[:12]}"
        intro = f"range={label} count={len(rows)}"
    else:
        _, out = repo_lib.run_git(root, "status", "--porcelain", "--untracked-files=all")
        rows, seen = [], set()
        for line in out.splitlines():
            if len(line) < 4:
                continue
            code, rest = line[:2], line[3:]
            rel = rest.split(" -> ")[-1].strip().strip('"').replace("\\", "/")
            if rel in seen or not _in_scope(rel, scope):
                continue
            seen.add(rel)
            full = root / rel
            if full.is_dir():
                continue
            n = full.stat().st_size if full.exists() else 0
            rows.append((n, "D" if not full.exists() else code.strip(), rel))
        rows.sort(key=lambda r: (-r[0], r[2]))
        start = end = ""
        measure = "measure=git status --porcelain + file bytes"
        intro = f"scope={','.join(scope)} count={len(rows)}"
    body = [where, intro, measure]
    if note:
        body.append(note)
    if ranged:
        dirty = [p for p in (repo_lib.git_changed(root) or []) if _in_scope(p, scope)]
        if dirty:
            body.append(f"worktree={len(dirty)} (omitted; this list is the commit range only)")
    body += ["", "state\tbytes\tKB\tpath"] + [f"{s}\t{n}\t{n / 1000:.2f}\t{r}" for n, s, r in rows]
    title = f"Changed since {label}: {len(rows)} paths" if ranged else f"Changed in scope: {len(rows)} paths"
    echo = [where, title] + [f"{s:>3} {n:6d}  {r}" for n, s, r in rows[:30]]
    if ranged and note:
        echo.append(note)
    if len(rows) > 30:
        echo.append(f"... +{len(rows) - 30} more (see summary)")
    if args.head:
        sha = repo_lib.run_git(root, "rev-parse", "HEAD")[1].strip()
        log = repo_lib.run_git(root, "log", "-n", str(args.log_count), "--oneline")[1].splitlines()
        body += ["", f"HEAD={sha}", f"logCount={len(log)}"] + [f"  {ln}" for ln in log]
        echo += [f"HEAD={sha}"] + [f"  {ln}" for ln in log]
    kv = {"count": len(rows)}
    if ranged:
        kv["since"] = start[:12]
        kv["until"] = end[:12]
    return agent_log.finish("changed", root, "\n".join(body), "INFO", args=args, echo="\n".join(echo), **kv)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
