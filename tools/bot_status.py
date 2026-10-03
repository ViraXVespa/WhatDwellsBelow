#!/usr/bin/env python3
"""Linux-first Grok Bot punch list. Read queues on disk; do not invent rows."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
import gd_lib
import repo_lib

SHIP_BYTES = 10_000
SWEEP_BYTES = 5_000
ALLOW_FILE = repo_lib.ALLOW_FILE
REUSE_FILE = "design/reuse-map.md"
OPT_FILE = "design/grok-bot-opt.md"


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
    path = root / OPT_FILE
    if not path.is_file():
        return []
    text = path.read_text(encoding="utf-8")
    items: list[dict[str, str]] = []
    for block in re.finditer(
        r"(?ims)^###\s+(opt-\d+)\s*\(([^)]+)\)\s*$(.*?)(?=^###\s+opt-\d+|\Z)",
        text,
    ):
        oid, status, body = block.group(1), block.group(2).strip(), block.group(3)
        title = ""
        tmatch = re.search(r"(?im)^\s*Title:\s*(.+)$", body)
        if tmatch:
            title = tmatch.group(1).strip()
        items.append({"id": oid, "status": status.lower(), "title": title})
    if items:
        return items
    for oid, status in re.findall(r"(?i)\b(opt-\d+)\s*\(([^)]+)\)", text):
        items.append({"id": oid, "status": status.strip().lower(), "title": ""})
    return items


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


def run_load_graph(root: Path) -> str:
    script = _TOOLS / "check_load_graph.py"
    if not script.is_file():
        return "skip (missing tools/check_load_graph.py)"
    proc = subprocess.run(
        [sys.executable, str(script), "--root", str(root)],
        cwd=root,
        check=False,
        capture_output=True,
        text=True,
    )
    if proc.returncode == 0:
        return "PASS"
    err = [ln for ln in (proc.stderr or proc.stdout or "").strip().splitlines() if not ln.startswith(("RESULT", "Summary"))]
    tail = err[0] if err else f"exit={proc.returncode}"
    return f"FAIL {tail}"


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = agent_log.std_parser(
        "Print the Grok Bot punch list from live queues and file sizes.", json_out=True
    )
    parser.add_argument(
        "--prove",
        action="store_true",
        help="Also check 10KB ship floor, allowlist on dirty paths, load-graph.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
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
    dirty = repo_lib.git_changed(root) or []
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
    lines.append(f"over_5kb_under_10kb count={len(sweep)} (rows: python3 tools/check_script_cap.py --sweep)")
    lines.append("")
    lines.append(f"reuse_brief count={len(brief)} file={REUSE_FILE}")
    if not brief:
        lines.append("(empty — reuse job stops)")
    else:
        for idx, item in enumerate(brief, start=1):
            snippet = item if len(item) <= 140 else item[:137] + "..."
            lines.append(f"{idx}. {snippet}")
    lines.append("")
    lines.append(
        f"opt_queue pending={len(pending_opts)} total={len(opts)} file={OPT_FILE}"
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
                f"allowlist={'FAIL' if blocked else 'PASS'} dirty={len(dirty)} blocked={len(blocked)}"
            )
            for rel in blocked:
                lines.append(f"blocked\t{rel}")
        else:
            lines.append(f"allowlist=skip missing {ALLOW_FILE}")
        graph = run_load_graph(root)
        lines.append(f"load_graph={graph}")
        if cap_fail or blocked or graph.startswith("FAIL"):
            rc = 1

    status = "FAIL" if rc else "PASS"
    return agent_log.finish(
        "bot-status", root, "\n".join(lines), status, args=args,
        over10kb=len(ship), over5kb=len(sweep), brief=len(brief), opt_pending=len(pending_opts),
    )


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
