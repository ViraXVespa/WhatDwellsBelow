#!/usr/bin/env python3
"""Headless phase smokes for the Grok Bot Linux VM.

Not a boot step. Setup downloads the official Godot 4.7.2 Linux tools
binary only when the pin is missing. Editor playtest is out of scope.

  python tools/gate.py bot-smokes --doctor
  python tools/gate.py bot-smokes --setup
  python tools/gate.py bot-smokes --phases 1,2,6 [--release]   (--release: gate.py release too)
Phases also run a static compile of every script and scene (--no-static skips it); a red phase prints its first errors.
  python tools/gate.py bot-smokes --door hub | --job hub.guild   (phases from routes.yaml smokes)
  python tools/gate.py bot-smokes --for scripts/world/player.gd   (which phases load a file; runs nothing)
"""
from __future__ import annotations

import argparse
import json
import os
import re
import stat
import subprocess
import sys
import zipfile
from pathlib import Path
from urllib.request import urlretrieve

_TOOLS = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402,F401

import agent_log
from load_routes import SMOKE_PHASES
from agent_log import repo_root  # noqa: F401  (bot_warnscan imports it from here)

from godot_lib import BIN_NAME, STEAM_WIN, VERSION, ZIP_NAME, ZIP_URL, pin_path, resolve_bin  # noqa: F401  (engine pin lives in godot_lib)

def setup(pin: Path) -> Path:
    if pin.is_file():
        print(f"setup=present\t{pin}")
        return pin
    if sys.platform != "linux":
        raise SystemExit(
            "FAIL setup: Linux pin missing. On Windows set GODOT_BIN "
            f"or install the Steam {VERSION} tools build. This runner does not "
            "download the Windows editor."
        )
    pin.parent.mkdir(parents=True, exist_ok=True)
    zpath = pin.parent / ZIP_NAME
    print(f"setup=download\t{ZIP_URL}")
    urlretrieve(ZIP_URL, zpath)
    with zipfile.ZipFile(zpath) as zf:
        names = [n for n in zf.namelist() if Path(n).name.startswith("Godot_v")]
        if not names:
            agent_log.fail("setup: zip had no Godot binary")
        zf.extract(names[0], pin.parent)
        extracted = pin.parent / names[0]
    if extracted.resolve() != pin.resolve():
        extracted.replace(pin)
    pin.chmod(pin.stat().st_mode | stat.S_IEXEC)
    zpath.unlink(missing_ok=True)
    print(f"setup=installed\t{pin}")
    return pin

def smoke_args(root: Path, phase: int, verbose: bool, flags: list[str] | None = None) -> list[str]:
    args = [
        "--headless",
        "--display-driver", "headless",
        "--audio-driver", "Dummy",
        "--path", str(root),
    ]
    if verbose:
        args.append("--verbose")
    args.extend(["--", *(flags or [f"--wdb-phase{phase}-smoke"])])
    return args

# Godot stderr lines that fail a phase. "SMOKE FAIL" is what a smoke check prints on a miss (e.g. smoke/marks_check.gd). A lambda whose captured node was freed runs with null (stale UI callback).
FATAL_ERR = ("SCRIPT ERROR", "Lambda capture at index", "SMOKE FAIL")
# A phase line reporting a failed check flag ("P5: extract_ok=false", "P5: campfire ... ok=false") also fails it.
FALSE_OK = re.compile(r"^P\d+: .*?(?:^|[^A-Za-z0-9])ok=false\b")

def _fatal(ln: str) -> bool:
    return any(sig in ln for sig in FATAL_ERR) or bool(FALSE_OK.search(ln))

# Phase 6 also runs the hub menu open timing (scripts/debug/open_timing.gd): real title -> hub load, then every
# menu's first and second open; fails when a first open stalls on two runs in a row (one retry; see run_phase).
OPEN_TIMING = ["--wdb-load-timing-smoke", "--wdb-open-timing"]
# ...and the baked frame-art check (art_bake.gd): every committed assets/ui/frames PNG matches what the art code draws.
FRAME_ART = ["--wdb-frame-art-check"]

def fatal_lines(text: str, limit: int = 4) -> list[str]:
    """The first distinct failing stderr lines (SCRIPT ERROR / SMOKE FAIL / ...) with Godot's `at:` line, so a red
    phase says why without opening the log."""
    out: list[str] = []
    lines = text.splitlines()
    for i, ln in enumerate(lines):
        if _fatal(ln) and "  " + ln.strip() not in out:
            out.append("  " + ln.strip())
            at = lines[i + 1].strip() if i + 1 < len(lines) else ""
            if at.startswith("at:"):
                out.append("    " + at)
            if sum(1 for o in out if not o.startswith("    ")) >= limit:
                break
    return out

def _selftest() -> int:
    red = ["SCRIPT ERROR: x", "P5: extract_ok=false", "P5: campfire hp 1->2 ok=false", "P3: genF2 ok=false gate=true",
           "P6: bleed_chip closed=true leak=false fresh_ok=false"]
    green = ["P5: extract_ok=true", "P5: prompt_no_a=false", "SHOT: ok=false err=host_gone", "P6: leak=false"]
    bad = [ln for ln in red if not _fatal(ln)] + [ln for ln in green if _fatal(ln)]
    if fatal_lines("SCRIPT ERROR: boom\n   at: f (res://a.gd:3)\nP5: x_ok=false") != ["  SCRIPT ERROR: boom", "    at: f (res://a.gd:3)", "  P5: x_ok=false"]:
        bad.append("fatal_lines")
    for ln in bad:
        print(f"selftest miss\t{ln}")
    return agent_log.emit_result("FAIL" if bad else "PASS", checks=len(red) + len(green) + 1)

def run_phase(exe: Path, root: Path, phase: int, timeout: int, verbose: bool, tag: str = "", flags: list[str] | None = None) -> int:
    log_dir = root / "_logs" / "smokes"
    log_dir.mkdir(parents=True, exist_ok=True)
    name = tag or f"phase{phase}"
    out = log_dir / f"{name}.out.txt"
    err = log_dir / f"{name}.err.txt"
    cmd = [str(exe), *smoke_args(root, phase, verbose, flags)]
    print("run\t" + " ".join(cmd))
    try:
        with out.open("w", encoding="utf-8") as so, err.open("w", encoding="utf-8") as se:
            proc = subprocess.run(
                cmd, stdout=so, stderr=se, timeout=timeout, check=False,
            )
    except subprocess.TimeoutExpired:
        print(f"{tag or f'P{phase}'}=TIMEOUT")
        return 1
    text = err.read_text(encoding="utf-8", errors="replace")
    bad = any(_fatal(ln) for ln in text.splitlines()) or proc.returncode != 0
    print(f"{tag or f'P{phase}'}={'FAIL' if bad else 'PASS'}\texit={proc.returncode}")
    if bad:
        print("\n".join(fatal_lines(text) + [f"log\t{agent_log.rel(root, err)}"]))
    if bad and tag:
        print("\n".join(ln for ln in text.splitlines() if ln.startswith("OPEN:")))
    if tag.startswith("open_timing"):
        import bench_env
        eng = next((ln[len("OPEN: env "):] for ln in text.splitlines() if ln.startswith("OPEN: env ")), "engine=unknown")
        line = bench_env.env_line(godot=bench_env.godot_version(str(exe)), headless=True) + " engine: " + eng
        (log_dir / f"{name}.env.txt").write_text(line + "\n", encoding="utf-8")
        print(line)
    if phase == 6 and not tag:
        timing = run_phase(exe, root, 6, timeout, verbose, "open_timing", OPEN_TIMING)
        if timing:
            # One retry: a first-open stall from code (e.g. a font fallback) shows on every run; a lone
            # one-sample spike on a shared box does not (seen ~1 in 8 headless runs, a different menu each time).
            timing = run_phase(exe, root, 6, timeout, verbose, "open_timing_retry", OPEN_TIMING)
        art = run_phase(exe, root, 6, timeout, verbose, "frame_art", FRAME_ART)
        return max(1 if bad else 0, timing, art)
    return 1 if bad else 0

# Static compile (bot_warnscan's `static` area: every scripts/**/*.gd and scenes/*.tscn) fails a smoke run on these kinds
# only; its gdscript warnings are warnscan's job. Catches what no picked phase loads (a broken ext_resource, a dead script).
STATIC_HARD = ("script-error", "load-failure", "crash", "error", "shader")

def static_compile(root: Path) -> int:
    out = root / "_logs" / "smokes" / "static.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.unlink(missing_ok=True)
    subprocess.run([*boot.cmd("bot_warnscan"), "--areas", "static", "--recheck", "0", "--out-json", str(out), "--root", str(root)],
                   cwd=root, capture_output=True, check=False)
    rows = json.loads(out.read_text(encoding="utf-8")) if out.is_file() else [{"kind": "error", "message": "no static report", "site": ""}]
    hard = [f for f in rows if f.get("kind") in STATIC_HARD]
    print(f"static={'FAIL' if hard else 'PASS'}\tcompile every live .gd and scene (gate.py warnscan --areas static)")
    for f in hard[:4]:
        print(f"  {f.get('kind')}: {str(f.get('message', ''))[:200]}  ({f.get('site', '')})")
    return 1 if hard else 0

def phases_for(files: list[str]) -> tuple[list[str], list[int]]:
    """(warnscan areas, smoke phases) that load these files: bot_warnscan_lib.changed_areas is the one source."""
    from bot_warnscan_lib import changed_areas
    areas = changed_areas(files)
    return areas, sorted({int(a[1:]) for a in areas if re.fullmatch(r"p\d", a)})

def main(argv: list[str] | None = None) -> int:
    p = agent_log.std_parser("Bot headless phase smokes")
    p.add_argument("--for", dest="for_files", nargs="+", default=[], metavar="FILE",
                   help="Repo file(s): print the warnscan areas and smoke phases that load them, then exit (no Godot; same source as bot_warnscan --changed).")
    p.add_argument("--doctor", action="store_true", help="Check the pinned Godot binary and print the setup state; run nothing.")
    p.add_argument("--setup", action="store_true", help=f"Download the official {VERSION} Linux binary if the pin is missing, then exit.")
    p.add_argument("--phases", default="", help="Smoke phases, comma list (example 1,2,6).")
    p.add_argument("--door", default="", help="Phases mapped to this routes.yaml door (instead of --phases).")
    p.add_argument("--job", default="", help="Phases mapped to this routes.yaml door.job (instead of --phases).")
    p.add_argument("--flows", nargs="?", const="mapped", default="", metavar="NAMES",
                   help="Also run shot flows headless (asserts, no pixels): NAMES comma list, or the --door/--job mapping when bare.")
    p.add_argument("--release", action="store_true", help="Also run gate.py release (release mode: no debug code, title to dungeon). Alone: just that.")
    p.add_argument("--no-gaps", action="store_true",
                   help="skip check_shot_gaps --changed (end gate: a new UI state without a shot flow FAILS this run)")
    p.add_argument("--no-static", action="store_true", help="skip the static compile of every script and scene (on by default when phases run)")
    p.add_argument("--timeout", "--timeout-sec", dest="timeout", type=int, default=120, help="Seconds per smoke phase (default 120).")
    p.add_argument("--verbose", action="store_true", help="Print each Godot command and longer failure output.")
    p.add_argument("--selftest", action="store_true", help="Check which stderr lines fail a phase; runs no Godot.")
    ns = p.parse_args(argv)
    if ns.selftest:
        return _selftest()
    root = agent_log.resolve_root(ns)
    if ns.for_files:
        files = [f.replace("\\", "/") for f in ns.for_files]
        gone = [f for f in files if not (root / f).exists()]
        if gone:
            agent_log.fail(f"{', '.join(gone)}: no such file (give repo-relative paths, example: --for scripts/world/player.gd)")
        areas, phases = phases_for(files)
        run = ",".join(map(str, phases)) or "1,2,6"
        print(f"areas={','.join(areas) or 'none'}" + ("" if phases else " (no phase loads it; BOT.md baseline 1,2,6)"))
        print(f"run: python tools/gate.py bot-smokes --phases {run}")
        print(f"warn: python tools/gate.py warnscan --areas {','.join(areas) or 'static'}   (or --changed)")
        return agent_log.emit_result("INFO", phases=run, areas=",".join(areas))
    for tok in [t for t in ns.phases.replace(" ", "").split(",") if t]:
        if not tok.isdigit() or int(tok) not in (0, *SMOKE_PHASES):
            agent_log.fail(f"bad phase {tok!r} in --phases. Valid phases are {SMOKE_PHASES[0]}-{SMOKE_PHASES[-1]} (comma list, example 1,2,6)")
    if ns.door or ns.job:
        from load_routes import check_route, load_routes
        bad_route = check_route(load_routes(root), ns.door, ns.job)
        if bad_route:
            agent_log.fail(bad_route)
    if (ns.door or ns.job) and not ns.phases:
        from load_routes import load_routes, smoke_phases
        ns.phases = ",".join(map(str, smoke_phases(load_routes(root), door=ns.door.strip(), job=ns.job.strip())))
    pin = pin_path()
    found = resolve_bin()
    if ns.doctor or (not ns.setup and not ns.phases and not ns.release):
        print(f"version={VERSION}")
        print(f"pin={pin}")
        print(f"bin={'missing' if found is None else found}")
        print("editor_playtest=forbidden")
        print("doctor=PASS")
        return agent_log.emit_result("PASS", mode="doctor", bin="missing" if found is None else "found")
    exe = found
    if ns.setup or exe is None:
        exe = setup(pin)
    if (ns.flows or ns.release) and not ns.phases:
        ns.phases = "0"
    if not ns.phases:
        print(f"ready\t{exe}")
        return agent_log.emit_result("PASS", mode="setup")
    phases = [int(x) for x in ns.phases.split(",") if x.strip() and x.strip() != "0"]
    rc = 0
    if ns.flows:
        names = ns.flows
        if names == "mapped":
            from load_routes import load_routes, shot_flows
            names = ",".join(shot_flows(load_routes(root), door=ns.door.strip(), job=ns.job.strip()))
        if names:
            cmd = [*boot.cmd("run_shot_flow"), "--no-pixels", "--flow", names, "--root", str(root)]
            print("run\t" + " ".join(cmd))
            frc = subprocess.run(cmd, check=False).returncode
            print(f"flows={'PASS' if frc == 0 else 'FAIL'}\t{names}")
            rc |= 1 if frc else 0
    if not ns.no_gaps and (phases or ns.flows):
        from load_routes import load_routes, shot_gaps_mode
        mode = shot_gaps_mode(load_routes(root), "bot")
        if mode != "off":
            cmd = [*boot.cmd("check_shot_gaps"), "--changed", "--root", str(root)]
            if mode == "advisory":
                cmd.append("--advisory")
            print("run\t" + " ".join(cmd))
            grc = subprocess.run(cmd, check=False).returncode
            print(f"gaps={'PASS' if grc == 0 else 'FAIL'}\t{mode}")
            rc |= 1 if grc else 0
    for n in phases:
        if n not in SMOKE_PHASES:
            print(f"P{n}=FAIL\tout_of_range")
            rc = 1
            continue
        rc |= run_phase(exe, root, n, ns.timeout, ns.verbose)
    if phases and not ns.no_static:
        rc |= static_compile(root)
    if ns.release:
        rrc = subprocess.run([*boot.cmd("run_release_smoke"), "--root", str(root)], check=False).returncode
        print(f"release={'PASS' if rrc == 0 else 'FAIL'}")
        rc |= 1 if rrc else 0
    print(f"smokes={'PASS' if rc == 0 else 'FAIL'}")
    return agent_log.emit_result("PASS" if rc == 0 else "FAIL", phases=",".join(str(n) for n in phases))

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
