"""Bot-only size checks: who runs them, and the boot-file byte budgets they read.

Size limits are enforced by the Bot and by CI, never by Build or Web. A size check runs when the Bot passes
`--bot` (flag hidden from --help), when WDB_BOT is set, or when GitHub Actions runs it (GITHUB_ACTIONS). Anyone
else gets an INFO line and exit 0, with no limit, byte count or list printed. On Actions, a pull_request from a
Build or Web week branch (repo_lib.branch_kind) counts as "anyone else"; main pushes and Bot-branch PRs (bot/*, vendor-fixes, ...) run them.
`tools/data/bot_budgets.json` holds the per-file byte budgets of the boot files and the summed budgets of the read sets (read only in Bot mode); `no_budget` lists boot files left unbudgeted on purpose.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

import agent_log
import repo_lib

BUDGETS = "tools/data/bot_budgets.json"
SHIP_BYTES = 10_000  # Bot script floor (BOT.md)
SWEEP_BYTES = 5_000  # Bot sweep floor

def add_flag(ap: argparse.ArgumentParser) -> None:
    ap.add_argument("--bot", action="store_true", help=argparse.SUPPRESS)

def enabled(args: object = None) -> bool:
    if getattr(args, "bot", False) or os.environ.get("WDB_BOT"):
        return True
    if os.environ.get("GITHUB_ACTIONS") != "true":
        return False
    return os.environ.get("GITHUB_EVENT_NAME") != "pull_request" or repo_lib.branch_kind(os.environ.get("GITHUB_HEAD_REF", "")) == "bot"

def not_run(what: str, **kv: object) -> int:
    """The answer for a size tool run outside Bot mode: nothing measured, nothing printed but this."""
    print(f"{what}: Bot-only check, not run here.")
    return agent_log.emit_result("INFO", None, skipped=1, **kv)

def set_budgets(root: Path) -> dict[str, tuple[int, list[str]]]:
    """name -> (byte budget, files) for a group of files read together (the Build boot set, the Build start-read set)."""
    p = root / BUDGETS
    if not p.is_file():
        return {}
    raw = json.loads(p.read_text(encoding="utf-8-sig")).get("set_bytes") or {}
    return {str(k): (int(v["bytes"]), [str(f) for f in v.get("files", [])]) for k, v in raw.items() if isinstance(v, dict) and isinstance(v.get("bytes"), int)}

def boot_budgets(root: Path) -> dict[str, int]:
    p = root / BUDGETS
    if not p.is_file():
        return {}
    raw = json.loads(p.read_text(encoding="utf-8-sig")).get("boot_bytes") or {}
    return {str(k): int(v) for k, v in raw.items() if isinstance(v, int)}

def unbudgeted(root: Path) -> set[str]:
    """Boot files with no byte budget on purpose (`no_budget` in bot_budgets.json; reason: design/load-graph.md)."""
    p = root / BUDGETS
    if not p.is_file():
        return set()
    return {str(f) for f in json.loads(p.read_text(encoding="utf-8-sig")).get("no_budget") or []}
