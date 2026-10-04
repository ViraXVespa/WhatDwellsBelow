#!/usr/bin/env python3
"""Headless phase smokes for the Grok Bot Linux VM.

Not a boot step. Setup downloads the official Godot 4.7.2 Linux tools
binary only when the pin is missing. Editor playtest is out of scope.

  python tools/bot_smokes.py --doctor
  python tools/bot_smokes.py --setup
  python tools/bot_smokes.py --phases 1,2,6
  python tools/bot_smokes.py --door hub | --job hub.guild   (phases from routes.yaml smokes)
  python tools/bot_smokes.py --for scripts/world/player.gd   (which phases load a file; runs nothing)
"""
from __future__ import annotations

import argparse
import os
import re
import stat
import subprocess
import sys
import zipfile
from pathlib import Path
from urllib.request import urlretrieve

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
from load_routes import SMOKE_PHASES
from agent_log import repo_root  # noqa: F401  (bot_warnscan imports it from here)

VERSION = "4.7.2"
BIN_NAME = f"Godot_v{VERSION}-stable_linux.x86_64"
ZIP_NAME = BIN_NAME + ".zip"
ZIP_URL = (
    "https://github.com/godotengine/godot-builds/releases/download/"
    f"{VERSION}-stable/" + ZIP_NAME
)
STEAM_WIN = (
    "C:\\Program Files (x86)\\Steam\\steamapps\\common\\"
    "Godot Engine\\godot.windows.opt.tools.64.exe"
)


def pin_path() -> Path:
    env = os.environ.get("GODOT_BIN", "").strip()
    if env:
        return Path(env)
    if Path("/workspace").is_dir():
        return Path("/workspace/godot") / BIN_NAME
    return Path.home() / ".local" / "share" / "wdb-godot" / BIN_NAME


def resolve_bin() -> Path | None:
    pin = pin_path()
    if pin.is_file():
        return pin
    steam = Path(STEAM_WIN)
    if steam.is_file():
        return steam
    return None


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


def smoke_args(root: Path, phase: int, verbose: bool) -> list[str]:
    args = [
        "--headless",
        "--display-driver", "headless",
        "--audio-driver", "Dummy",
        "--path", str(root),
    ]
    if verbose:
        args.append("--verbose")
    args.extend(["--", f"--wdb-phase{phase}-smoke"])
    return args


def run_phase(exe: Path, root: Path, phase: int, timeout: int, verbose: bool) -> int:
    log_dir = root / "_logs" / "smokes"
    log_dir.mkdir(parents=True, exist_ok=True)
    out = log_dir / f"phase{phase}.out.txt"
    err = log_dir / f"phase{phase}.err.txt"
    cmd = [str(exe), *smoke_args(root, phase, verbose)]
    print("run\t" + " ".join(cmd))
    try:
        with out.open("w", encoding="utf-8") as so, err.open("w", encoding="utf-8") as se:
            proc = subprocess.run(
                cmd, stdout=so, stderr=se, timeout=timeout, check=False,
            )
    except subprocess.TimeoutExpired:
        print(f"P{phase}=TIMEOUT")
        return 1
    text = err.read_text(encoding="utf-8", errors="replace")
    bad = "SCRIPT ERROR" in text or proc.returncode != 0
    print(f"P{phase}={'FAIL' if bad else 'PASS'}\texit={proc.returncode}")
    return 1 if bad else 0


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
    p.add_argument("--no-gaps", action="store_true",
                   help="skip check_shot_gaps --changed (end gate: a new UI state without a shot flow FAILS this run)")
    p.add_argument("--timeout", "--timeout-sec", dest="timeout", type=int, default=120, help="Seconds per smoke phase (default 120).")
    p.add_argument("--verbose", action="store_true", help="Print each Godot command and longer failure output.")
    ns = p.parse_args(argv)
    root = agent_log.resolve_root(ns)
    if ns.for_files:
        files = [f.replace("\\", "/") for f in ns.for_files]
        gone = [f for f in files if not (root / f).exists()]
        if gone:
            agent_log.fail(f"{', '.join(gone)}: no such file (give repo-relative paths, example: --for scripts/world/player.gd)")
        areas, phases = phases_for(files)
        run = ",".join(map(str, phases)) or "1,2,6"
        print(f"areas={','.join(areas) or 'none'}" + ("" if phases else " (no phase loads it; BOT.md baseline 1,2,6)"))
        print(f"run: python tools/bot_smokes.py --phases {run}")
        print(f"warn: python tools/bot_warnscan.py --areas {','.join(areas) or 'static'}   (or --changed)")
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
    if ns.doctor or (not ns.setup and not ns.phases):
        print(f"version={VERSION}")
        print(f"pin={pin}")
        print(f"bin={'missing' if found is None else found}")
        print("editor_playtest=forbidden")
        print("doctor=PASS")
        return agent_log.emit_result("PASS", mode="doctor", bin="missing" if found is None else "found")
    exe = found
    if ns.setup or exe is None:
        exe = setup(pin)
    if ns.flows and not ns.phases:
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
            cmd = [sys.executable, str(Path(__file__).resolve().parent / "run_shot_flow.py"), "--no-pixels", "--flow", names, "--root", str(root)]
            print("run\t" + " ".join(cmd))
            frc = subprocess.run(cmd, check=False).returncode
            print(f"flows={'PASS' if frc == 0 else 'FAIL'}\t{names}")
            rc |= 1 if frc else 0
    if not ns.no_gaps and (phases or ns.flows):
        from load_routes import load_routes, shot_gaps_mode
        mode = shot_gaps_mode(load_routes(root), "bot")
        if mode != "off":
            cmd = [sys.executable, str(Path(__file__).resolve().parent / "check_shot_gaps.py"), "--changed", "--root", str(root)]
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
    print(f"smokes={'PASS' if rc == 0 else 'FAIL'}")
    return agent_log.emit_result("PASS" if rc == 0 else "FAIL", phases=",".join(str(n) for n in phases))


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
