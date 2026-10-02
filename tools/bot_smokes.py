#!/usr/bin/env python3
"""Headless phase smokes for the Grok Bot Linux VM.

Not a boot step. Setup downloads the official Godot 4.7.2 Linux tools
binary only when the pin is missing. Editor playtest is out of scope.

  python tools/bot_smokes.py --doctor
  python tools/bot_smokes.py --setup
  python tools/bot_smokes.py --phases 1,2,6
  python tools/bot_smokes.py --door hub | --job hub.guild   (phases from routes.yaml smokes)
"""
from __future__ import annotations

import argparse
import os
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
from agent_log import repo_root  # noqa: F401  (bot_warnscan imports it from here)

VERSION = "4.7.2"
ZIP_NAME = "Godot_v4.7.2-stable_linux.x86_64.zip"
BIN_NAME = "Godot_v4.7.2-stable_linux.x86_64"
ZIP_URL = (
    "https://github.com/godotengine/godot-builds/releases/download/"
    "4.7.2-stable/" + ZIP_NAME
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
            "or install the Steam 4.7.2 tools build. This runner does not "
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


def main() -> int:
    p = agent_log.std_parser("Bot headless phase smokes")
    p.add_argument("--doctor", action="store_true")
    p.add_argument("--setup", action="store_true")
    p.add_argument("--phases", default="")
    p.add_argument("--door", default="", help="Phases mapped to this routes.yaml door (instead of --phases).")
    p.add_argument("--job", default="", help="Phases mapped to this routes.yaml door.job (instead of --phases).")
    p.add_argument("--timeout", type=int, default=120)
    p.add_argument("--verbose", action="store_true")
    ns = p.parse_args()
    root = agent_log.resolve_root(ns)
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
    if not ns.phases:
        print(f"ready\t{exe}")
        return agent_log.emit_result("PASS", mode="setup")
    phases = [int(x) for x in ns.phases.split(",") if x.strip()]
    rc = 0
    for n in phases:
        if n < 1 or n > 9:
            print(f"P{n}=FAIL\tout_of_range")
            rc = 1
            continue
        rc |= run_phase(exe, root, n, ns.timeout, ns.verbose)
    print(f"smokes={'PASS' if rc == 0 else 'FAIL'}")
    return agent_log.emit_result("PASS" if rc == 0 else "FAIL", phases=",".join(str(n) for n in phases))


if __name__ == "__main__":
    raise SystemExit(main())
