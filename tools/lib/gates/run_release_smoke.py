#!/usr/bin/env python3
"""Release-mode smokes: the shipped path runs with no debug code, and a release export carries none of it.

    python tools/gate.py release [--modes flag,stripped] [--pck DIR] [--pck-debug DIR] [--timeout-sec 240]
flag:     a scratch copy of the project, debug folder kept, run with `--wdb-release` (a debug binary acting as release).
stripped: the same copy with scripts/debug/ deleted, as a release export leaves it (proves no shared code needs it).
Both add tools/data/release_smoke/release_drive.gd as an autoload in the copy only (title, hub, dungeon; REL: lines) and
FAIL on a script error, a debug node at runtime, balance read from user://debug_tunables.json or an old save's
`debug_bal`, or the drive not reaching the dungeon.
--pck DIR: DIR/*.pck must hold no `scripts/debug/` path (a release export, release.py export-web). --pck-debug DIR: it must
(a debug export, release.py export-web --debug). Logs: _logs/release-smoke/.
"""
from __future__ import annotations

import re
import shutil
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402,F401
import agent_log
import godot_lib

SKIP = {".git", "_logs", "docs", "_pages", ".archive_worktrees", ".archive_export_cache", "_out"}
DRIVE = 'ReleaseDrive="*res://tools/data/release_smoke/release_drive.gd"'
BAD = re.compile(r"SCRIPT ERROR:|Parse Error|Compile Error|ERROR: Failed to")

def scratch(root: Path, dest: Path) -> None:
    shutil.copytree(root, dest, ignore=lambda d, names: [n for n in names if Path(d) == root and n in SKIP], symlinks=True)
    pg = dest / "project.godot"
    pg.write_text(pg.read_text(encoding="utf-8").replace('App="*res://scripts/app.gd"', 'App="*res://scripts/app.gd"\n' + DRIVE), encoding="utf-8")

def run_mode(root: Path, proj: Path, mode: str, timeout: int) -> tuple[bool, list[str]]:
    se, so = agent_log.run_path("release-smoke", root, f"{mode}-err.log"), agent_log.run_path("release-smoke", root, f"{mode}-out.log")
    ga = godot_lib.headless_args(proj, *(["--wdb-release"] if mode == "flag" else []))
    r = godot_lib.run_godot(root, proj, ga, so, se, timeout)
    hits = godot_lib.grep_logs([se, so], r"^REL:|SCRIPT ERROR:|Parse Error|Compile Error|ERROR: Failed to")
    rel = " ".join(h for h in hits if h.startswith("REL:"))
    ok = (r["exit_code"] == 0 and not r["timed_out"] and not any(BAD.search(h) for h in hits)
          and "dbg_on=false" in rel and "tunables_ignored=true" in rel and "hub_ok=true dungeon_ok=true" in rel
          and not re.search(r"(debug_menu|playtest|anim_browser)=true", rel) and "tel=true" in rel)
    return ok, [f"{mode} {r['status']} ms={r['ms']} -> {'PASS' if ok else 'FAIL'}"] + hits[:30]

def pck_paths(d: Path) -> tuple[int, list[str]]:
    """(pck count, packed debug files) for DIR/*.pck. Counts file entries (.gdc, .remap) only: the uid cache and the
    shipped archive notes name debug paths as text, which is not code."""
    found: list[str] = []
    pcks = sorted(Path(d).glob("*.pck"))
    for p in pcks:
        found += sorted({m.group(0).decode("utf-8", "replace") for m in re.finditer(rb"scripts/debug/[A-Za-z0-9_./-]+?\.(?:gdc|gd\.remap|tscn\.remap|tres\.remap)", p.read_bytes())})
    return len(pcks), found

def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Release-mode smokes (no debug code at runtime) and the release PCK leak check.")
    ap.add_argument("--modes", default="flag,stripped", help="flag,stripped (default both); '' skips the runs.")
    ap.add_argument("--pck", default="", metavar="DIR", help="Release export dir: its .pck must hold no scripts/debug/ path.")
    ap.add_argument("--pck-debug", dest="pck_debug", default="", metavar="DIR", help="Debug export dir: its .pck must hold scripts/debug/.")
    ap.add_argument("--timeout-sec", type=int, default=240, help="Per-run timeout in seconds (default 240).")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    body, fail = [], 0
    modes = [m for m in args.modes.split(",") if m.strip()]
    if modes:
        with tempfile.TemporaryDirectory(prefix="wdb-rel-") as td:
            proj = Path(td) / "proj"
            scratch(root, proj)
            for mode in modes:
                if mode == "stripped":
                    shutil.rmtree(proj / "scripts" / "debug", ignore_errors=True)
                ok, lines = run_mode(root, proj, mode, args.timeout_sec)
                fail += 0 if ok else 1
                body += lines + [""]
    for d, want in ((args.pck, False), (args.pck_debug, True)):
        if d:
            n, found = pck_paths(Path(d))
            ok = n > 0 and (bool(found) == want)
            fail += 0 if ok else 1
            body.append(f"pck {'debug' if want else 'release'} {d}: pcks={n} debug_paths={len(found)} -> {'PASS' if ok else 'FAIL'}" + (f" e.g. {found[:3]}" if found and not want else ""))
    return agent_log.finish("release-smoke", root, "\n".join(body), "FAIL" if fail else "PASS", args=args, fail_signals=fail)

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
