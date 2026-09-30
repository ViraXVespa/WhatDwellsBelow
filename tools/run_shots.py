#!/usr/bin/env python3
"""Posed-camera postcard tool. Not a numbered P1-P9 smoke.

Modes:
  web   full-res PNG + Windows clipboard (paste into chat)
  build scaled PNG under the session shots dir
  user  full-res PNG and open it

Numbers live here, not in a prompt.
"""

from __future__ import annotations

import argparse
import ctypes
import os
import subprocess
import sys
import threading
import time
from datetime import datetime, timezone
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log

JOB = "shots"
BUILD_SCALE_PCT = 50
SETTLE_MS = 1000
TIMEOUT_SEC = 180
WARN_BYTES = 2048
RENDER_DRIVER = "d3d12"


def _root() -> Path:
    return agent_log.repo_root(_TOOLS.parent)


def _out_dir(root: Path) -> Path:
    try:
        return agent_log.ensure_agent_log_dir(JOB, root)
    except FileNotFoundError:
        fallback = root / "_logs" / JOB
        fallback.mkdir(parents=True, exist_ok=True)
        return fallback


def _extra_flags(args: argparse.Namespace) -> list[str]:
    extra = [
        f"--wdb-shot-hud={1 if args.hud else 0}",
        f"--wdb-shot-taskbar={1 if args.taskbar else 0}",
        f"--wdb-shot-zoom={args.zoom}",
        f"--wdb-shot-cx={args.cx}",
        f"--wdb-shot-cz={args.cz}",
        "--wdb-shot-scene=camp" if getattr(args, "scene", "dungeon") in ("camp", "hub") else "--wdb-shot-scene=dungeon",
    ]
    if args.width > 0:
        extra.append(f"--wdb-shot-width={args.width}")
    if args.height > 0:
        extra.append(f"--wdb-shot-height={args.height}")
    if args.px != "":
        extra.append(f"--wdb-shot-px={args.px}")
    if args.pz != "":
        extra.append(f"--wdb-shot-pz={args.pz}")
    return extra


def _godot_pids() -> list[int]:
    r = subprocess.run(
        ["tasklist", "/FO", "CSV", "/NH"],
        capture_output=True,
        text=True,
    )
    pids: list[int] = []
    for line in (r.stdout or "").splitlines():
        low = line.lower()
        if "godot" not in low:
            continue
        parts = line.split(",")
        if len(parts) < 2:
            continue
        try:
            pids.append(int(parts[1].strip().strip('"')))
        except ValueError:
            continue
    return pids


def _hide_godot_taskbar() -> int:
    if os.name != "nt":
        return 0
    user32 = ctypes.windll.user32
    GWL_EXSTYLE = -20
    WS_EX_TOOLWINDOW = 0x00000080
    WS_EX_APPWINDOW = 0x00040000
    SWP_NOSIZE = 0x0001
    SWP_NOMOVE = 0x0002
    SWP_NOZORDER = 0x0004
    SWP_FRAMECHANGED = 0x0020
    hits = 0
    pids = set(_godot_pids())
    if not pids:
        return 0
    found: list[int] = []

    @ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)
    def _cb(hwnd: int, _lp: int) -> bool:
        pid = ctypes.c_uint(0)
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
        if pid.value in pids:
            found.append(int(hwnd))
        return True

    user32.EnumWindows(_cb, 0)
    for hwnd in found:
        style = user32.GetWindowLongW(hwnd, GWL_EXSTYLE)
        style = (style | WS_EX_TOOLWINDOW) & ~WS_EX_APPWINDOW
        user32.SetWindowLongW(hwnd, GWL_EXSTYLE, style)
        user32.SetWindowPos(
            hwnd, 0, 0, 0, 0, 0,
            SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED,
        )
        hits += 1
    return hits


def _taskbar_watch(stop: threading.Event) -> None:
    while not stop.is_set():
        _hide_godot_taskbar()
        stop.wait(0.2)


def _ps_literal(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def _write_invoke_ps1(
    root: Path,
    tools: Path,
    out_dir: Path,
    png: Path,
    seed: int,
    floor_n: int,
    scale_pct: int,
    settle_ms: int,
    timeout_sec: int,
    show_window: bool,
    extra: list[str],
) -> Path:
    godot_args = [
        "--audio-driver",
        "Dummy",
        "--rendering-driver",
        RENDER_DRIVER,
        "--path",
        str(root),
        "--",
        "--wdb-shot",
        f"--wdb-shot-seed={seed}",
        "--wdb-shot-show=1" if show_window else "--wdb-shot-show=0",
            "--wdb-shot-floor={floor_n}",
        f"--wdb-shot-out={png}",
        f"--wdb-shot-scale={scale_pct}",
        f"--wdb-shot-settle-ms={settle_ms}",
    ] + extra
    arg_lines = ",\n    ".join(_ps_literal(a) for a in godot_args)
    body = (
        f". {_ps_literal(str(tools / 'invoke_godot.ps1'))}\n"
        f"$godotArgs = @(\n    {arg_lines}\n)\n"
        f"$r = Invoke-WdbGodot -RepoRoot {_ps_literal(str(root))} "
        f"-GodotPath {_ps_literal(str(root))} "
        f"-GodotArgs $godotArgs "
        f"-OutLog {_ps_literal(str(out_dir / 'out.log'))} "
        f"-ErrLog {_ps_literal(str(out_dir / 'err.log'))} "
        f"-TimeoutSec {int(timeout_sec)}\n"
        f"$mark = Join-Path {_ps_literal(str(out_dir))} 'invoke.txt'\n"
        "$lines = @(\n"
        "    ('STATUS=' + [string]$r.Status),\n"
        "    ('EXIT=' + [string]$r.ExitCode),\n"
        "    ('MS=' + [string]$r.Ms),\n"
        "    ('TIMEOUT=' + [string]$r.TimedOut),\n    ('PID=' + [string]$r.Pid)\n"
        ")\n"
        "$lines | Set-Content -Path $mark -Encoding utf8\n"
    )
    path = out_dir / "_invoke.ps1"
    path.write_text(body, encoding="utf-8")
    return path


def _read_invoke_mark(out_dir: Path) -> dict[str, str]:
    path = out_dir / "invoke.txt"
    marks: dict[str, str] = {}
    if not path.is_file():
        return marks
    for raw in path.read_text(encoding="utf-8-sig").splitlines():
        if "=" not in raw:
            continue
        key, val = raw.split("=", 1)
        marks[key.strip()] = val.strip()
    return marks


def _shot_lines(out_dir: Path) -> list[str]:
    hits: list[str] = []
    for name in ("err.log", "out.log"):
        path = out_dir / name
        if not path.is_file():
            continue
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            if line.startswith("SHOT:"):
                hits.append(line)
    return hits


def _error_lines(out_dir: Path) -> list[str]:
    hits: list[str] = []
    needles = (
        "SCRIPT ERROR:",
        "Parse Error",
        "Compile Error",
        "ERROR: Failed to",
    )
    for name in ("err.log", "out.log"):
        path = out_dir / name
        if not path.is_file():
            continue
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            if any(n in line for n in needles):
                hits.append(line)
    return hits


def _png_info(png: Path) -> tuple[int, int, int]:
    if not png.is_file():
        return 0, 0, 0
    data = png.read_bytes()
    nbytes = len(data)
    width = 0
    height = 0
    if len(data) >= 24 and data[:8] == b"\x89PNG\r\n\x1a\n":
        width = int.from_bytes(data[16:20], "big")
        height = int.from_bytes(data[20:24], "big")
    return nbytes, width, height



def _kill_shot_pid(marks: dict[str, str]) -> None:
    raw = marks.get("PID", "").strip()
    if not raw.isdigit():
        return
    subprocess.run(
        ["taskkill", "/PID", raw, "/T", "/F"],
        capture_output=True,
        text=True,
        check=False,
    )


def _clipboard_png(png: Path) -> str:
    if not png.is_file():
        return "skip"
    ps = (
        "Add-Type -AssemblyName System.Drawing\n"
        "Add-Type -AssemblyName System.Windows.Forms\n"
        f"$path = {_ps_literal(str(png))}\n"
        "$img = [System.Drawing.Image]::FromFile($path)\n"
        "try {\n"
        "    $data = New-Object System.Windows.Forms.DataObject\n"
        "    $data.SetImage($img)\n"
        "    $bytes = [System.IO.File]::ReadAllBytes($path)\n"
        "    $ms = New-Object System.IO.MemoryStream\n"
        "    $null = $ms.Write($bytes, 0, $bytes.Length)\n"
        "    $ms.Position = 0\n"
        "    $data.SetData('PNG', $ms)\n"
        "    $files = New-Object System.Collections.Specialized.StringCollection\n"
        "    $null = $files.Add($path)\n"
        "    $data.SetFileDropList($files)\n"
        "    [System.Windows.Forms.Clipboard]::SetDataObject($data, $true)\n"
        "} finally {\n"
        "    $img.Dispose()\n"
        "}\n"
    )
    r = subprocess.run(
        ["powershell", "-STA", "-NoProfile", "-Command", ps],
        capture_output=True,
        text=True,
    )
    if r.returncode != 0:
        return "fail"
    check = subprocess.run(
        [
            "powershell",
            "-STA",
            "-NoProfile",
            "-Command",
            "Add-Type -AssemblyName System.Windows.Forms; "
            "if ([System.Windows.Forms.Clipboard]::ContainsImage()) { 'has' } "
            "elseif ([System.Windows.Forms.Clipboard]::ContainsFileDropList()) { 'has' } "
            "else { 'empty' }",
        ],
        capture_output=True,
        text=True,
    )
    got = (check.stdout or "").strip()
    return "ok" if got == "has" else "empty"


def _open_png(png: Path) -> str:
    if not png.is_file():
        return "skip"
    try:
        os.startfile(str(png))  # type: ignore[attr-defined]
        return "ok"
    except AttributeError:
        opened = subprocess.run(["xdg-open", str(png)], capture_output=True)
        return "ok" if opened.returncode == 0 else "fail"
    except OSError:
        return "fail"


def _band(ok: bool, nbytes: int, width: int, height: int) -> str:
    if not ok or nbytes <= 0 or width <= 0 or height <= 0:
        return "fail"
    if nbytes < WARN_BYTES:
        return "warn"
    return "good"


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(
        prog="run_shots.py",
        description="Capture a play-camera postcard from a pinned dungeon seed.",
    )
    p.add_argument("--mode", choices=("web", "build", "user"), default="user")
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--scene", choices=("dungeon", "camp", "hub"), default="dungeon")
    p.add_argument("--floor", type=int, default=1)
    p.add_argument("--scale", type=int, default=0, help="PNG scale percent; 0 picks mode default")
    p.add_argument("--settle-ms", type=int, default=SETTLE_MS)
    p.add_argument("--timeout-sec", type=int, default=TIMEOUT_SEC)
    p.add_argument("--out", default="", help="PNG path override")
    p.add_argument("--show", action="store_true", help="leave the Godot window visible")
    p.add_argument("--hud", type=int, default=1, help="1=HUD on, 0=HUD off")
    p.add_argument("--width", type=int, default=0)
    p.add_argument("--height", type=int, default=0)
    p.add_argument("--zoom", type=float, default=1.0)
    p.add_argument("--px", default="", help="player world X; empty keeps spawn")
    p.add_argument("--pz", default="", help="player world Z; empty keeps spawn")
    p.add_argument("--cx", type=float, default=0.0, help="camera look offset X")
    p.add_argument("--cz", type=float, default=0.0, help="camera look offset Z")
    p.add_argument("--taskbar", type=int, default=0, help="1=show taskbar entry")
    args = p.parse_args(argv)

    root = _root()
    out_dir = _out_dir(root)
    scale_pct = args.scale if args.scale > 0 else (
        BUILD_SCALE_PCT if args.mode == "build" else 100
    )
    scale_pct = max(1, min(100, scale_pct))
    png = Path(args.out) if args.out else (out_dir / f"shot-s{args.seed}-f{args.floor}.png")
    png.parent.mkdir(parents=True, exist_ok=True)

    invoke = _write_invoke_ps1(
        root,
        _TOOLS,
        out_dir,
        png,
        max(1, args.seed),
        max(1, args.floor),
        scale_pct,
        max(0, args.settle_ms),
        max(1, args.timeout_sec),
        args.show,
        _extra_flags(args),
    )
    stop = threading.Event()
    watcher = threading.Thread(target=_taskbar_watch, args=(stop,), daemon=True)
    if not args.show and args.taskbar == 0:
        watcher.start()
    try:
        subprocess.run(
            ["powershell", "-NoProfile", "-File", str(invoke)],
            cwd=str(root),
            capture_output=True,
        )
    finally:
        stop.set()
    marks = _read_invoke_mark(out_dir)
    _kill_shot_pid(marks)
    import time as _time
    _time.sleep(0.3)
    shot_hits = _shot_lines(out_dir)
    err_hits = _error_lines(out_dir)
    nbytes, width, height = _png_info(png)
    shot_ok = any("ok=true" in line for line in shot_hits)
    timed_out = marks.get("TIMEOUT", "").lower() in {"true", "1"}
    status = marks.get("STATUS", "missing")
    clip = "n/a"
    opened = "n/a"
    if args.mode == "web":
        clip = _clipboard_png(png)
    elif args.mode == "user":
        opened = _open_png(png)

    ok = (
        (not timed_out)
        and status == "EXIT=0"
        and shot_ok
        and nbytes > 0
        and not err_hits
    )
    band = _band(ok, nbytes, width, height)
    if not ok:
        band = "fail"

    lines = [
        f"shots {datetime.now(timezone.utc).isoformat()}",
        f"root={root}",
        f"mode={args.mode} seed={max(1, args.seed)} floor={max(1, args.floor)} "
        f"scale={scale_pct} settle_ms={max(0, args.settle_ms)} driver={RENDER_DRIVER}",
        f"status={status} wall_ms={marks.get('MS', '-1')} timeout={timed_out}",
        f"png={png} bytes={nbytes} w={width} h={height}",
        f"clipboard={clip} open={opened} band={band}",
        "",
        "--- SHOT lines ---",
    ]
    if shot_hits:
        lines.extend(shot_hits)
    else:
        lines.append("(none)")
    lines.append("")
    lines.append("--- errors ---")
    if err_hits:
        lines.extend(err_hits[:40])
    else:
        lines.append("(none)")
    lines.append("")
    lines.append(
        f"RESULT band={band} shot_ok={str(shot_ok).lower()} "
        f"bytes={nbytes} clipboard={clip} open={opened}"
    )
    summary = out_dir / "summary.txt"
    text = "\n".join(lines) + "\n"
    summary.write_text(text, encoding="utf-8")
    sys.stdout.write(text)
    return 0 if band != "fail" else 1


if __name__ == "__main__":
    sys.exit(main())
