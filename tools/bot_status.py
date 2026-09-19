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

SHIP_BYTES = 10_000
SWEEP_BYTES = 5_000
GD_SKIP_PARTS = ("archives", ".archive_worktrees")
ALLOW_FILE = "tools/bot_allow.txt"
REUSE_FILE = "design/reuse-map.md"
OPT_FILE = "design/grok-bot-opt.md"


def _write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if not text.endswith("\n"):
        text += "\n"
    path.write_text(text, encoding="utf-8")


def _git(root: Path, *args: str) -> tuple[int, str]:
    try:
        proc = subprocess.run(
            ["git", *args],
            cwd=root,
            check=False,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError:
        return 127, "git-not-found"
    out = (proc.stdout or "").rstrip()
    err = (proc.stderr or "").rstrip()
    return proc.returncode, out if out else err


def _rel(root: Path, path: Path) -> str:
    try:
        return path.resolve().relative_to(root.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def iter_gd(root: Path) -> list[Path]:
    scripts = root / "scripts"
    if not scripts.is_dir():
        return []
    out: list[Path] = []
    for path in scripts.rglob("*.gd"):
        if not path.is_file():
            continue
        parts = set(path.parts)
        if parts & set(GD_SKIP_PARTS):
            continue
        out.append(path)
    return out


def list_oversize(root: Path, floor: int) -> list[tuple[int, str]]:
    rows: list[tuple[int, str]] = []
    for path in iter_gd(root):
        size = path.stat().st_size
        if size >= floor:
            rows.append((size, _rel(root, path)))
    rows.sort(key=lambda row: (-row[0], row[1]))
    return rows


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
    return items


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


def load_allow_globs(root: Path) -> list[str]:
    path = root / ALLOW_FILE
    if not path.is_file():
        return []
    globs: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        raw = line.split("#", 1)[0].strip()
        if raw:
            globs.append(raw)
    return globs


def glob_ok(rel: str, globs: list[str]) -> bool:
    from fnmatch import fnmatch

    posix = rel.replace("\\", "/")
    for pattern in globs:
        if pattern.startswith("!"):
            if fnmatch(posix, pattern[1:]):
                return False
            continue
        if fnmatch(posix, pattern):
            return True
    return False


def changed_paths(root: Path) -> list[str]:
    code, out = _git(root, "status", "--porcelain", "-u")
    if code != 0:
        return []
    paths: list[str] = []
    for line in out.splitlines():
        if len(line) < 4:
            continue
        rel = line[3:].strip()
        if " -> " in rel:
            rel = rel.split(" -> ", 1)[1]
        if rel:
            paths.append(rel.replace("\\", "/"))
    return paths


def git_state(root: Path) -> dict[str, str]:
    _code, branch = _git(root, "rev-parse", "--abbrev-ref", "HEAD")
    _code, tracking = _git(
        root, "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"
    )
    _code, porcelain = _git(root, "status", "--porcelain")
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
    err = (proc.stderr or proc.stdout or "").strip().splitlines()
    tail = err[-1] if err else f"exit={proc.returncode}"
    return f"FAIL {tail}"


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Print the Grok Bot punch list from live queues and file sizes."
    )
    parser.add_argument("--root", default=".")
    parser.add_argument(
        "--prove",
        action="store_true",
        help="Also check 10KB ship floor, allowlist on dirty paths, load-graph.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    root = Path(args.root).expanduser().resolve()
    if not (root / "AGENTS.md").is_file() or not (root / "design").is_dir():
        print("not a WhatDwellsBelow root", file=sys.stderr)
        return 2

    git = git_state(root)
    ship = list_oversize(root, SHIP_BYTES)
    sweep = [row for row in list_oversize(root, SWEEP_BYTES) if row[0] < SHIP_BYTES]
    brief = parse_reuse_brief(root)
    opts = parse_opt_queue(root)
    pending_opts = [item for item in opts if item["status"] not in ("done", "dropped")]
    globs = load_allow_globs(root)
    dirty = changed_paths(root)
    blocked = [rel for rel in dirty if globs and not glob_ok(rel, globs)]

    lines: list[str] = [
        "bot status",
        f"root={root}",
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
    lines.append(f"over_5kb_under_10kb count={len(sweep)}")
    for size, rel in sweep[:20]:
        lines.append(f"{size}\t{rel}")
    if len(sweep) > 20:
        lines.append(f"... +{len(sweep) - 20} more")
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

    body = "\n".join(lines)
    out = agent_log.ensure_agent_log_dir("bot-status", root) / "summary.txt"
    _write(out, body)
    print(body)
    print("")
    print(f"Summary -> {out}")
    return rc


if __name__ == "__main__":
    raise SystemExit(main())
