#!/usr/bin/env python3
from __future__ import annotations

from agent_log import rel



def _present_over(png, pid):
    import ctypes
    from ctypes import wintypes
    user32 = ctypes.windll.user32
    gdi32 = ctypes.windll.gdi32
    PW_RENDERFULLCONTENT = 2
    found = []

    @ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    def _enum(hwnd, _lparam):
        if not user32.IsWindowVisible(hwnd):
            return True
        proc = wintypes.DWORD()
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(proc))
        if proc.value == pid:
            found.append(hwnd)
        return True

    user32.EnumWindows(_enum, 0)
    if not found:
        return False
    hwnd = found[0]
    rect = wintypes.RECT()
    user32.GetClientRect(hwnd, ctypes.byref(rect))
    w, h = rect.right, rect.bottom
    if w < 32 or h < 32:
        return False
    hdc = user32.GetDC(hwnd)
    mem = gdi32.CreateCompatibleDC(hdc)
    bmp = gdi32.CreateCompatibleBitmap(hdc, w, h)
    gdi32.SelectObject(mem, bmp)
    ok = user32.PrintWindow(hwnd, mem, PW_RENDERFULLCONTENT)
    user32.ReleaseDC(hwnd, hdc)
    if not ok:
        gdi32.DeleteObject(bmp)
        gdi32.DeleteDC(mem)
        return False
    class BMI(ctypes.Structure):
        _fields_ = [
            ("biSize", wintypes.DWORD), ("biWidth", wintypes.LONG), ("biHeight", wintypes.LONG),
            ("biPlanes", wintypes.WORD), ("biBitCount", wintypes.WORD), ("biCompression", wintypes.DWORD),
            ("biSizeImage", wintypes.DWORD), ("biXPelsPerMeter", wintypes.LONG), ("biYPelsPerMeter", wintypes.LONG),
            ("biClrUsed", wintypes.DWORD), ("biClrImportant", wintypes.DWORD),
        ]
    bmi = BMI()
    bmi.biSize = ctypes.sizeof(BMI)
    bmi.biWidth = w
    bmi.biHeight = -h
    bmi.biPlanes = 1
    bmi.biBitCount = 32
    buf = ctypes.create_string_buffer(w * h * 4)
    gdi32.GetDIBits(mem, bmp, 0, h, buf, ctypes.byref(bmi), 0)
    gdi32.DeleteObject(bmp)
    gdi32.DeleteDC(mem)
    try:
        from PIL import Image
    except ImportError:
        return False
    img = Image.frombuffer("RGBA", (w, h), buf, "raw", "BGRA", 0, 1)
    img.convert("RGB").save(png)
    print("present_png=%s %dx%d" % (png, w, h))
    return True

"""Posed-camera postcard tool. Not a numbered P1-P9 smoke.

Modes:
  web   full-res PNG + Windows clipboard (paste into chat)
  build scaled PNG under the session shots dir
  user  full-res PNG and open it

Numbers live here, not in a prompt.
"""


import argparse
import ctypes
import json
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
import godot_lib

JOB = "shots"
BUILD_SCALE_PCT = 50
SETTLE_MS = 1000
TIMEOUT_SEC = 180
WARN_BYTES = 2048
RENDER_DRIVER = "opengl3"
RENDER_METHOD = "gl_compatibility"


def _root() -> Path:
    return agent_log.repo_root(_TOOLS.parent)


def _load_recipe(root: Path, name: str) -> dict:
    path = root / "tools" / "shot-recipes.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    rec = data.get(name)
    if not isinstance(rec, dict) or not rec.get("frames"):
        raise SystemExit("FAIL unknown shot recipe " + name)
    return rec


def _recipe_poses(rec: dict) -> str:
    bits: list[str] = []
    for fr in rec.get("frames") or []:
        kind = str(fr.get("kind") or "play")
        look = fr.get("look") or [16.5, 15.0]
        off = fr.get("offset") or [0.0, 0.0]
        zoom = fr.get("zoom")
        if zoom is None:
            zoom = rec.get("zoom", 1.0)
        px = fr.get("px", rec.get("px", look[0]))
        pz = fr.get("pz", rec.get("pz", look[1]))
        face = fr.get("face", "down")
        bits.append("%s,%s,%s,%s,%s,%s,%s,%s,%s" % (kind, look[0], look[1], off[0], off[1], zoom, px, pz, face))
    return ";".join(bits)


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
    if os.name != "nt":
        return []
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


def _shot_pid() -> int:
    logs = Path(__file__).resolve().parents[1] / "_logs"
    hits = sorted(logs.rglob("invoke.txt"), key=lambda p: p.stat().st_mtime)
    if not hits:
        return 0
    for line in hits[-1].read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith("PID="):
            raw = line.split("=", 1)[1].strip()
            return int(raw) if raw.isdigit() else 0
    return 0


def _hide_godot_taskbar(pids: set[int]) -> int:
    if os.name != "nt" or not pids:
        return 0
    user32 = ctypes.windll.user32
    GWL_EXSTYLE = -20
    WS_EX_TOOLWINDOW = 0x00000080
    WS_EX_APPWINDOW = 0x00040000
    SWP_NOSIZE = 0x0001
    SWP_NOZORDER = 0x0004
    SWP_NOACTIVATE = 0x0010
    SWP_FRAMECHANGED = 0x0020
    SW_HIDE = 0
    SW_SHOWNA = 8
    hits = 0
    found: list[int] = []
    styled = getattr(_hide_godot_taskbar, "_styled", set())
    _hide_godot_taskbar._styled = styled

    @ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)
    def _cb(hwnd: int, _lp: int) -> bool:
        pid = ctypes.c_uint(0)
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
        if pid.value in pids:
            found.append(int(hwnd))
        return True

    _hide_godot_taskbar._cb = _cb
    user32.GetWindowLongPtrW.restype = ctypes.c_longlong
    user32.GetWindowLongPtrW.argtypes = [ctypes.c_void_p, ctypes.c_int]
    user32.SetWindowLongPtrW.restype = ctypes.c_longlong
    user32.SetWindowLongPtrW.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_longlong]
    user32.EnumWindows(_cb, 0)
    for hwnd in found:
        if hwnd in styled:
            continue
        style = user32.GetWindowLongPtrW(hwnd, GWL_EXSTYLE)
        style = (style | WS_EX_TOOLWINDOW) & ~WS_EX_APPWINDOW
        user32.SetWindowLongPtrW(hwnd, GWL_EXSTYLE, style)
        user32.ShowWindow(hwnd, SW_HIDE)
        user32.ShowWindow(hwnd, SW_SHOWNA)
        user32.SetWindowPos(hwnd, 0, 80, 80, 0, 0, SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED)
        styled.add(hwnd)
        hits += 1
    return hits


def _taskbar_watch(stop: threading.Event, before: set[int], png: Path | None = None) -> None:
    while not stop.is_set():
        live = set(_godot_pids()) - before
        if png is not None:
            for pid in live:
                _present_over(png, pid)
        stop.wait(0.2)


def _godot_args(
    root: Path,
    png: Path,
    seed: int,
    floor_n: int,
    scale_pct: int,
    settle_ms: int,
    extra: list[str],
    poses: str,
) -> list[str]:
    godot_args = [
        "--audio-driver",
        "Dummy",
        "--rendering-method",
        RENDER_METHOD,
        "--rendering-driver",
        RENDER_DRIVER,
        "--path",
        str(root),
        "--",
        "--wdb-shot",
        f"--wdb-shot-seed={seed}",
        "--wdb-shot-show=1",
        f"--wdb-shot-floor={floor_n}",
        f"--wdb-shot-out={png}",
        f"--wdb-shot-scale={scale_pct}",
        f"--wdb-shot-settle-ms={settle_ms}",
    ] + extra
    if poses:
        godot_args.append("--wdb-shot-poses=" + poses)
    return godot_args


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



def _clipboard_png(png: Path) -> str:
    if os.name != 'nt' or not png.is_file():
        return 'skip'
    import ctypes
    from ctypes import wintypes
    gdiplus = ctypes.windll.gdiplus
    user32 = ctypes.windll.user32
    gdi32 = ctypes.windll.gdi32
    kernel32 = ctypes.windll.kernel32
    kernel32.GlobalAlloc.restype = ctypes.c_void_p
    kernel32.GlobalLock.restype = ctypes.c_void_p
    kernel32.GlobalLock.argtypes = [ctypes.c_void_p]
    kernel32.GlobalUnlock.argtypes = [ctypes.c_void_p]
    user32.SetClipboardData.argtypes = [ctypes.c_uint, ctypes.c_void_p]
    user32.SetClipboardData.restype = ctypes.c_void_p
    user32.OpenClipboard.argtypes = [ctypes.c_void_p]
    class _Startup(ctypes.Structure):
        _fields_ = [
            ('GdiplusVersion', ctypes.c_uint32),
            ('DebugEventCallback', ctypes.c_void_p),
            ('SuppressBackgroundThread', ctypes.c_int),
            ('SuppressExternalCodecs', ctypes.c_int),
        ]
    class _Hdr(ctypes.Structure):
        _fields_ = [
            ('biSize', wintypes.DWORD),
            ('biWidth', wintypes.LONG),
            ('biHeight', wintypes.LONG),
            ('biPlanes', wintypes.WORD),
            ('biBitCount', wintypes.WORD),
            ('biCompression', wintypes.DWORD),
            ('biSizeImage', wintypes.DWORD),
            ('biXPelsPerMeter', wintypes.LONG),
            ('biYPelsPerMeter', wintypes.LONG),
            ('biClrUsed', wintypes.DWORD),
            ('biClrImportant', wintypes.DWORD),
        ]
    token = ctypes.c_ulong()
    if gdiplus.GdiplusStartup(ctypes.byref(token), ctypes.byref(_Startup(1, None, 0, 0)), None) != 0:
        return 'fail'
    image = ctypes.c_void_p()
    if gdiplus.GdipCreateBitmapFromFile(ctypes.c_wchar_p(str(png)), ctypes.byref(image)) != 0:
        return 'fail'
    width = ctypes.c_uint()
    height = ctypes.c_uint()
    gdiplus.GdipGetImageWidth(image, ctypes.byref(width))
    gdiplus.GdipGetImageHeight(image, ctypes.byref(height))
    w = int(width.value)
    h = int(height.value)
    scale = 1.0
    while (w * scale) * (h * scale) * 3 > 3500000:
        scale *= 0.9
    tw = max(1, int(w * scale))
    th = max(1, int(h * scale))
    small = ctypes.c_void_p()
    if gdiplus.GdipGetImageThumbnail(image, tw, th, ctypes.byref(small), None, None) != 0:
        gdiplus.GdipDisposeImage(image)
        return 'fail'
    hbmp = ctypes.c_void_p()
    if gdiplus.GdipCreateHBITMAPFromBitmap(small, ctypes.byref(hbmp), 0x00FFFFFF) != 0:
        return 'fail'
    stride = ((tw * 3 + 3) // 4) * 4
    hdr = _Hdr()
    hdr.biSize = ctypes.sizeof(_Hdr)
    hdr.biWidth = tw
    hdr.biHeight = th
    hdr.biPlanes = 1
    hdr.biBitCount = 24
    hdr.biCompression = 0
    hdr.biSizeImage = stride * th
    total = ctypes.sizeof(_Hdr) + int(hdr.biSizeImage)
    hglob = kernel32.GlobalAlloc(0x0002, total)
    ptr = kernel32.GlobalLock(hglob)
    if not hglob or not ptr:
        return 'fail'
    ctypes.memmove(ptr, ctypes.byref(hdr), ctypes.sizeof(hdr))
    hdc = user32.GetDC(None)
    rows = gdi32.GetDIBits(hdc, hbmp, 0, th, ctypes.c_void_p(ptr + ctypes.sizeof(hdr)), ctypes.byref(hdr), 0)
    user32.ReleaseDC(None, hdc)
    kernel32.GlobalUnlock(hglob)
    if rows == 0:
        return 'fail'
    if not user32.OpenClipboard(None):
        return 'fail'
    user32.EmptyClipboard()
    placed = user32.SetClipboardData(8, hglob)
    user32.CloseClipboard()
    gdi32.DeleteObject(hbmp)
    gdiplus.GdipDisposeImage(small)
    gdiplus.GdipDisposeImage(image)
    gdiplus.GdiplusShutdown(token)
    print('clip_px=%dx%d dib_bytes=%d' % (tw, th, total))
    time.sleep(0.5)
    return 'ok' if placed else 'fail'


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
    p = agent_log.std_parser("Capture a play-camera postcard from a pinned dungeon seed.")
    p.add_argument("--mode", choices=("web", "build", "user"), default="user")
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--scene", choices=("dungeon", "camp", "hub"), default="dungeon")
    p.add_argument("--floor", type=int, default=1)
    p.add_argument("--scale", type=int, default=0, help="PNG scale percent; 0 picks mode default")
    p.add_argument("--settle-ms", type=int, default=SETTLE_MS)
    p.add_argument("--timeout-sec", type=int, default=TIMEOUT_SEC)
    p.add_argument("--out", default="", help="PNG path override")
    p.add_argument("--show", action="store_true", help="leave the Godot window visible")
    p.add_argument("--hud", type=int, default=-1, help="1=HUD on, 0=HUD off; -1 uses recipe")
    p.add_argument("--width", type=int, default=0)
    p.add_argument("--height", type=int, default=0)
    p.add_argument("--zoom", type=float, default=1.0)
    p.add_argument("--px", default="", help="player world X; empty keeps spawn")
    p.add_argument("--pz", default="", help="player world Z; empty keeps spawn")
    p.add_argument("--cx", type=float, default=0.0, help="camera look offset X")
    p.add_argument("--cz", type=float, default=0.0, help="camera look offset Z")
    p.add_argument("--taskbar", type=int, default=0, help="1=show taskbar entry")
    p.add_argument("--recipe", default="", help="tools/shot-recipes.json key; empty is the play camera")
    args = p.parse_args(argv)

    root = _root()
    recipe_name = args.recipe
    poses = ""
    if recipe_name:
        rec = _load_recipe(root, recipe_name)
        poses = _recipe_poses(rec)
        if args.scene == "dungeon" and str(rec.get("scene") or "") in ("camp", "hub"):
            args.scene = "camp"
        if rec.get("scene"):
            args.scene = str(rec.get("scene"))
        if "hud" in rec:
            args.hud = 0 if int(rec.get("hud", 1)) == 0 else 1
        if rec.get("zoom") is not None:
            args.zoom = float(rec.get("zoom"))
        if rec.get("px") not in (None, ""):
            args.px = str(rec.get("px"))
        if rec.get("pz") not in (None, ""):
            args.pz = str(rec.get("pz"))
    if args.hud < 0:
        args.hud = 1
    out_dir = _out_dir(root)
    scale_pct = args.scale if args.scale > 0 else (
        BUILD_SCALE_PCT if args.mode == "build" else 100
    )
    scale_pct = max(1, min(100, scale_pct))
    png = Path(args.out) if args.out else (out_dir / f"shot-s{args.seed}-f{args.floor}.png")
    png.parent.mkdir(parents=True, exist_ok=True)

    godot_args = _godot_args(root, png, max(1, args.seed), max(1, args.floor), scale_pct, max(0, args.settle_ms),
                             _extra_flags(args), poses)
    before = set(_godot_pids())
    stop = threading.Event()
    watcher = threading.Thread(target=_taskbar_watch, args=(stop, before, png), daemon=True)
    if False:
        watcher.start()
    try:
        try:
            run = godot_lib.run_godot(root, root, godot_args, out_dir / "out.log", out_dir / "err.log",
                                      max(1, args.timeout_sec))
        except (FileNotFoundError, godot_lib.GodotBusy) as exc:
            agent_log.fail(str(exc))
    finally:
        stop.set()
    marks = {"STATUS": run["status"], "EXIT": str(run["exit_code"]), "MS": str(run["ms"]),
             "TIMEOUT": str(run["timed_out"]), "PID": str(run["pid"])}
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
        "root=.",
        f"mode={args.mode} seed={max(1, args.seed)} floor={max(1, args.floor)} "
        f"scale={scale_pct} settle_ms={max(0, args.settle_ms)} method={RENDER_METHOD} driver={RENDER_DRIVER}",
        f"status={status} wall_ms={marks.get('MS', '-1')} timeout={timed_out}",
        f"png={rel(root, png)} bytes={nbytes} w={width} h={height}",
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
    summary = out_dir / "summary.txt"
    lines.append(agent_log.result_line(
        "FAIL" if band == "fail" else ("INFO" if band == "warn" else "PASS"),
        agent_log.rel(root, summary),
        band=band, shot_ok=str(shot_ok).lower(), bytes=nbytes, clipboard=clip, open=opened,
    ))
    text = "\n".join(lines) + "\n"
    summary.write_text(text, encoding="utf-8")
    sys.stdout.write(text)
    return 0 if band != "fail" else 1


if __name__ == "__main__":
    raise SystemExit(main())
