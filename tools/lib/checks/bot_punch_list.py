#!/usr/bin/env python3
"""Linux-first Grok Bot punch list (Bot and CI only: pass --bot, or CI sets it). Read queues on disk; do not invent rows."""

from __future__ import annotations

import argparse
import fnmatch
import json
import re
import subprocess
import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402,F401

import agent_log
import bot_gate_lib
import gd_lib
import repo_lib
import task_lib

SHIP_BYTES = bot_gate_lib.SHIP_BYTES
SWEEP_BYTES = bot_gate_lib.SWEEP_BYTES
ALLOW_FILE = repo_lib.ALLOW_FILE
REUSE_FILE = "design/reuse-map.md"
OPT_FILE = "design/tasks/opt-*.md"

def list_oversize(root: Path, floor: int) -> list[tuple[int, str]]:
    return gd_lib.sizes(root, floor)

def parse_reuse_brief(root: Path) -> list[str]:
    path = root / REUSE_FILE
    if not path.is_file():
        return []
    text = path.read_text(encoding="utf-8")
    match = re.search(r"(?im)^##\s+Brief\s*$", text)
    if not match:
        return []
    rest = text[match.end() :]
    nxt = re.search(r"(?im)^##\s+", rest)
    if nxt:
        rest = rest[: nxt.start()]
    items: list[str] = []
    for found in re.finditer(r"(?m)^\s*(\d+)\.\s+(.*?)(?=^\s*\d+\.\s+|\Z)", rest, re.S):
        body = " ".join(found.group(2).split())
        if body:
            items.append(body)
    if items:
        return items
    prose = re.sub(r"(?s)<!--.*?-->", "", rest)
    lines = [ln.strip() for ln in prose.splitlines() if ln.strip()]
    return [" ".join(lines)] if lines else []

def parse_opt_queue(root: Path) -> list[dict[str, str]]:
    """Bot opt items: the owner-bot task files design/tasks/opt-N.md (a done item is deleted)."""
    return [{"id": tid, "status": t.get("status", ""), "title": t.get("title", "")}
            for tid, t in sorted(task_lib.load(root).items()) if t.get("owner") == "bot" and tid.startswith("opt-")]

def git_state(root: Path) -> dict[str, str]:
    _code, branch = repo_lib.run_git(root, "rev-parse", "--abbrev-ref", "HEAD")
    _code, tracking = repo_lib.run_git(
        root, "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"
    )
    _code, porcelain = repo_lib.run_git(root, "status", "--porcelain")
    dirty = "dirty" if porcelain else "clean"
    return {
        "branch": branch or "unknown",
        "upstream": tracking if tracking and "fatal" not in tracking.lower() else "none",
        "worktree": dirty,
    }

def shipped_changelogs(root: Path) -> list[str]:
    """design/changelog/*.md on origin/main that this branch (commits or worktree) changed."""
    _c, base = repo_lib.run_git(root, "merge-base", "origin/main", "HEAD")
    _c, out = repo_lib.run_git(root, "diff", "--name-only", base.strip() or "HEAD", "--", "design/changelog")
    return [rel for rel in out.split() if rel.endswith(".md") and repo_lib.run_git(root, "cat-file", "-e", f"origin/main:{rel}")[0] == 0
            and repo_lib.run_git(root, "diff", "--quiet", "origin/main", "--", rel)[0] != 0]

def run_check(root: Path, stem: str, *args: str) -> str:
    """PASS, or FAIL plus the first non-RESULT line, for one read-only check run under the repo root."""
    proc = subprocess.run(
        [*boot.cmd(stem), "--root", str(root), *args],
        cwd=root,
        check=False,
        capture_output=True,
        text=True,
    )
    if proc.returncode == 0:
        return "PASS"
    out = (proc.stderr or proc.stdout or "").strip().splitlines()
    err = [ln for ln in out if ln.startswith(("NEW", "STALE", "NOWHY"))] or [ln for ln in out if not ln.startswith(("RESULT", "Summary"))]
    tail = err[0][:160] if err else f"exit={proc.returncode}"
    return f"FAIL {tail}"

def explore(root: Path, lines: list[str]) -> bool:
    """check.py prove's diff scan: DRIFT rows, and textsize --gate when its rule fires (UI scripts). True on a failure."""
    import check_prove
    import prove_graph
    base = prove_graph.git(root, "merge-base", "origin/main", "HEAD").strip()
    if not base:
        lines.append("drift=skip no merge-base with origin/main")
        return False
    a = check_prove.analyse(root, base, None)
    drift = sorted(set(a["drift"]))
    lines.append(f"drift={'FAIL' if drift else 'PASS'} count={len(drift)} (rows: python tools/check.py prove --plan)")
    lines.extend(f"drift\t{row}" for row in drift[:8])
    rules = json.loads(check_prove.RULES.read_text(encoding="utf-8"))["checks"]
    rule = next(r for r in rules if r["id"] == "textsize")
    hits = [c.path for c in a["changes"] if any(fnmatch.fnmatch(c.path, g) for g in rule["when"])]
    text = "skip (no UI script changed)"
    if hits:
        proc = subprocess.run(rule["cmd"].split(), cwd=root, capture_output=True, text=True)
        text = f"{'PASS' if proc.returncode == 0 else 'FAIL'} <- {hits[0]}" + (f" +{len(hits) - 1}" if len(hits) > 1 else "")
    lines.append(f"textsize_gate={text}")
    return bool(drift) or text.startswith("FAIL")

def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = agent_log.std_parser(
        "Print the Grok Bot punch list from live queues and file sizes.", json_out=True
    )
    bot_gate_lib.add_flag(parser)
    parser.add_argument(
        "--prove",
        action="store_true",
        help="Also check the allowlist on uncommitted and unpushed paths, the load graph, the dupes gate, tunables drift (docs.py tunable diff), code-map check (every live .gd mapped), the tool-docs catalog and --stale-refs, diff drift and (UI scripts changed) textsize --gate.",
    )
    parser.add_argument("--no-explore", action="store_true", help="With --prove: skip the drift scan and textsize (check.py prove runs those itself).")
    return parser.parse_args(argv)

def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    if not bot_gate_lib.enabled(args):
        agent_log.resolve_root(args)
        return bot_gate_lib.not_run("bot punch list")
    try:
        root = agent_log.resolve_root(args)
    except FileNotFoundError as exc:
        agent_log.fail(str(exc))

    git = git_state(root)
    ship = list_oversize(root, SHIP_BYTES)
    sweep = [row for row in list_oversize(root, SWEEP_BYTES) if row[0] < SHIP_BYTES]
    brief = parse_reuse_brief(root)
    opts = parse_opt_queue(root)
    pending_opts = [item for item in opts if item["status"] not in ("done", "dropped")]
    globs = repo_lib.load_allowlist(root)
    dirty = sorted(set(repo_lib.git_changed(root, renames=False) or []) | set(repo_lib.unpushed(root)))  # uncommitted + unpushed
    blocked = [rel for rel in dirty if globs and not repo_lib.allowed(rel, globs)]

    lines: list[str] = [
        "bot status",
        "root=.",
        f"measure=os.path.getsize (== Get-Item Length)",
        f"ship_floor={SHIP_BYTES}",
        f"branch={git['branch']}",
        f"upstream={git['upstream']}",
        f"worktree={git['worktree']}",
        f"bot_md={'yes' if (root / 'BOT.md').is_file() else 'no'}",
        f"allowlist={ALLOW_FILE if globs else 'missing'}",
        "",
        f"over_10kb count={len(ship)}",
    ]
    for size, rel in ship:
        lines.append(f"{size}\t{rel}")
    lines.append("")
    lines.append(f"over_5kb_under_10kb count={len(sweep)} (rows: python tools/check.py script-cap --sweep)")
    lines.append("")
    lines.append(f"reuse_brief count={len(brief)} file={REUSE_FILE}")
    if not brief:
        lines.append("(empty - reuse job stops)")
    else:
        for idx, item in enumerate(brief, start=1):
            snippet = item if len(item) <= 140 else item[:137] + "..."
            lines.append(f"{idx}. {snippet}")
    lines.append("")
    lines.append(
        f"opt_queue open={len(pending_opts)} files={OPT_FILE} (python tools/docs.py task show opt-N)"
    )
    for item in pending_opts:
        title = f" {item['title']}" if item["title"] else ""
        lines.append(f"{item['id']} ({item['status']}){title}")
    lines.append("")
    lines.append("do_not_invent_queue_rows=yes")
    lines.append("one_flow_one_pr=yes")
    lines.append("squash_merge_user_only=yes")

    rc = 0
    if args.prove:
        lines.append("")
        lines.append("prove")
        cap_fail = len(ship)
        lines.append(f"script_cap={'FAIL' if cap_fail else 'PASS'} over={cap_fail}")
        if globs:
            lines.append(
                f"allowlist={'FAIL' if blocked else 'PASS'} changed={len(dirty)} blocked={len(blocked)}"
            )
            for rel in blocked:
                lines.append(f"blocked\t{rel}")
        else:
            lines.append(f"allowlist=skip missing {ALLOW_FILE}")
        graph = run_check(root, "check_load_graph", "--bot")
        lines.append(f"load_graph={graph}")
        dupes = run_check(root, "list_dupes", "--gate")
        lines.append(f"dupes_gate={dupes} (rows: python tools/lint.py dupes --gate -v)")
        tunables = run_check(root, "tunables", "diff")
        lines.append(f"tunables_diff={tunables} (rows: python tools/docs.py tunable diff)")
        code_map = run_check(root, "code_map", "check")
        lines.append(f"code_map={code_map} (rows: python tools/docs.py code-map check)")
        tool_docs = run_check(root, "check_tool_docs")
        lines.append(f"tool_docs={tool_docs} (rows: python tools/check.py tool-docs)")
        stale = run_check(root, "check_tool_docs", "--stale-refs")
        lines.append(f"stale_refs={stale} (rows: python tools/check.py tool-docs --stale-refs)")
        shipped = shipped_changelogs(root)
        lines.append(f"changelog_shipped={'FAIL' if shipped else 'PASS'} (an entry in a changelog already on origin/main: use docs.py patch changelog, next label)")
        for rel in shipped:
            lines.append(f"shipped\t{rel}")
        repro = run_check(root, "check_hub_bake", "--rebake")
        lines.append(f"bake_repro={repro} (rows: python tools/bake.py check --rebake)")
        explore_bad = False if args.no_explore else explore(root, lines)
        if cap_fail or blocked or explore_bad or any(r.startswith("FAIL") for r in (graph, dupes, tunables, code_map, tool_docs, stale, repro)) or shipped:
            rc = 1

    status = "FAIL" if rc else "PASS"
    return agent_log.finish(
        "bot-status", root, "\n".join(lines), status, args=args,
        over10kb=len(ship), over5kb=len(sweep), brief=len(brief), opt_pending=len(pending_opts),
    )

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
