#!/usr/bin/env python3
"""Godot launch + per-path lock for the run_* tools.

Rules: the lock key is the normalized --path dir; wait until that path is free;
a timeout or compile error kills ONLY the pid this call started, never godot*.

    python3 tools/godot_lib.py --path . --timeout-sec 5     # lock probe: locks, prints, unlocks
    python3 tools/godot_lib.py --display                    # which display GUI runs (shots, bakes) will use

GUI runs (`run_godot(..., gui=True)`) need a real renderer: pick_display() takes $DISPLAY, else the first live
X socket, else wraps the command in xvfb-run (software GL). Headless smokes never need a display.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log

COMPILE_RE = re.compile(r"Parse Error|Compile Error|Failed to compile|Failed to load script")
HARD_RE = re.compile(r"SCRIPT ERROR:|Parse Error|Compile Error|ERROR: Failed")


class GodotBusy(RuntimeError):
    pass


def godot_exe(override: str = "") -> Path:
    if override:
        p = Path(override)
        if not p.is_file():
            raise FileNotFoundError(f"godot_lib: Godot not found at {override}")
        return p
    import bot_smokes

    p = bot_smokes.resolve_bin()
    if p is None:
        raise FileNotFoundError("godot_lib: no Godot (set GODOT_BIN, or run tools/bot_smokes.py --setup)")
    return p


def norm_path(path: Path | str) -> str:
    return str(Path(path).resolve()).rstrip("\\/")


def path_key(path: Path | str) -> str:
    return hashlib.sha256(norm_path(path).lower().encode("utf-8")).hexdigest()[:16]


def lock_dir(root: Path) -> Path:
    d = Path(root) / "_logs" / "godot-lock"
    d.mkdir(parents=True, exist_ok=True)
    return d


def lock_file(root: Path, path: Path | str) -> Path:
    return lock_dir(root) / (path_key(path) + ".lock")


def procs_on_path(path: Path | str) -> list[dict]:
    """Running godot* processes whose command line names this --path (best effort)."""
    needle = norm_path(path).lower()
    hits: list[dict] = []
    if os.name == "nt":
        cmd = ["powershell", "-NoProfile", "-Command",
               "Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^godot' } | "
               "Select-Object ProcessId,CommandLine | ConvertTo-Json -Compress"]
        try:
            out = subprocess.run(cmd, capture_output=True, text=True, timeout=30).stdout.strip()
            rows = json.loads(out) if out else []
        except (OSError, subprocess.SubprocessError, ValueError):
            return hits
        for r in rows if isinstance(rows, list) else [rows]:
            if needle in str(r.get("CommandLine") or "").lower():
                hits.append({"pid": int(r["ProcessId"]), "command": r["CommandLine"]})
        return hits
    proc = Path("/proc")
    if not proc.is_dir():
        return hits
    for d in proc.iterdir():
        if not d.name.isdigit():
            continue
        try:
            argv = (d / "cmdline").read_bytes().decode("utf-8", "replace").split("\0")
        except OSError:
            continue
        if argv and Path(argv[0]).name.lower().startswith("godot") and needle in " ".join(argv).lower():
            hits.append({"pid": int(d.name), "command": " ".join(argv)})
    return hits


def lock_fresh(lf: Path) -> bool:
    try:
        exp = datetime.fromisoformat(json.loads(lf.read_text(encoding="utf-8"))["expires_utc"])
        if exp.tzinfo is None:
            exp = exp.replace(tzinfo=timezone.utc)
        return exp > datetime.now(timezone.utc)
    except (OSError, ValueError, KeyError):
        return False


def lock(root: Path, path: Path | str, timeout: int = 120, hold: int = 180) -> Path:
    """Take the per-path lock; returns the lock file. Raises GodotBusy on timeout."""
    norm = norm_path(path)
    lf = lock_file(root, norm)
    deadline = time.monotonic() + max(5, timeout)
    while time.monotonic() < deadline:
        if not procs_on_path(norm) and not lock_fresh(lf):
            now = datetime.now(timezone.utc)
            body = {"path": norm, "holder_pid": os.getpid(), "created_utc": now.isoformat(),
                    "expires_utc": (now + timedelta(seconds=max(30, hold))).isoformat()}
            lf.write_text(json.dumps(body, indent=2), encoding="utf-8")
            return lf
        time.sleep(0.4)
    pids = ",".join(str(p["pid"]) for p in procs_on_path(norm))
    raise GodotBusy(f"godot_lock: busy path={norm} foreignPids={pids} lock={lf}")


def unlock(lf: Path | None) -> None:
    if lf is not None:
        try:
            lf.unlink()
        except OSError:
            pass


def _read(p: Path | None) -> str:
    try:
        return p.read_text(encoding="utf-8", errors="replace") if p and p.is_file() else ""
    except OSError:
        return ""


XVFB_SCREEN = "-screen 0 1280x800x24 +extension GLX +render -noreset"


def _x_live(display: str) -> bool:
    """True when an X server answers on `display` (xdpyinfo when present, else the socket file)."""
    if not display:
        return False
    num = display.split(":")[-1].split(".")[0]
    if not os.path.exists(f"/tmp/.X11-unix/X{num}"):
        return False
    from shutil import which
    if which("xdpyinfo"):
        return subprocess.run(["xdpyinfo", "-display", display], capture_output=True).returncode == 0
    return True


def pick_display() -> tuple[str, str]:
    """(kind, display): ('env'|'socket', ':N') for an existing X, ('xvfb', '') to wrap in xvfb-run, ('none', '')."""
    if os.name == "nt":
        return "env", os.environ.get("DISPLAY", "")
    cur = os.environ.get("DISPLAY", "")
    if _x_live(cur):
        return "env", cur
    socks = sorted(Path("/tmp/.X11-unix").glob("X*")) if Path("/tmp/.X11-unix").is_dir() else []
    for s in socks:
        d = ":" + s.name[1:]
        if _x_live(d):
            return "socket", d
    from shutil import which
    if which("xvfb-run"):
        return "xvfb", ""
    return "none", ""


def run_godot(root: Path, godot_path: Path | str, args: list[str], out_log: Path | None = None,
              err_log: Path | None = None, timeout: int = 120, lock_timeout: int = 120,
              hold: int = 0, exe: str = "", gui: bool = False) -> dict:
    """Run Godot under the path lock. status: EXIT=<n> | COMPILE | TIMEOUT. Kills only its own pid.

    gui=True: the run needs a real renderer (pixels, light bakes). Uses pick_display(); result["display"]
    is env|socket|xvfb|none (none still launches, so the run fails loudly)."""
    exe_path = godot_exe(exe)
    path = norm_path(godot_path)
    args = list(args)
    if "--path" not in args:
        args = ["--path", path] + args
    lf = lock(root, path, lock_timeout, hold if hold > 0 else max(60, timeout + 30))
    t0 = time.monotonic()
    pid, status, code, timed_out, dkind = 0, "ERROR", -1, False, "none"
    handles = []
    try:
        kw: dict = {}
        for key, p in (("stdout", out_log), ("stderr", err_log)):
            if p:
                p.parent.mkdir(parents=True, exist_ok=True)
                fh = open(p, "wb")
                handles.append(fh)
                kw[key] = fh
            else:
                kw[key] = subprocess.DEVNULL
        cmd, env = [str(exe_path)] + args, None
        if gui:
            dkind, disp = pick_display()
            if dkind == "xvfb":
                cmd = ["xvfb-run", "-a", "-s", XVFB_SCREEN] + cmd
            elif disp:
                env = dict(os.environ, DISPLAY=disp)
        proc = subprocess.Popen(cmd, env=env, start_new_session=(os.name != "nt" and gui), **kw)
        pid = proc.pid
        ended = compile_hit = False
        while time.monotonic() - t0 < timeout:
            if proc.poll() is not None:
                ended = True
                break
            if COMPILE_RE.search(_read(err_log) + _read(out_log)):
                compile_hit = True
                break
            time.sleep(0.25)
        if compile_hit or not ended:
            if gui and os.name != "nt":
                import signal
                try:
                    os.killpg(proc.pid, signal.SIGKILL)  # xvfb-run wrapper + Godot, our own group only
                except ProcessLookupError:
                    pass
            else:
                proc.kill()
            proc.wait()
            time.sleep(0.4)
            status, code, timed_out = ("COMPILE", 1, False) if compile_hit else ("TIMEOUT", -1, True)
        else:
            code = proc.returncode or 0
            status = f"EXIT={code}"
    finally:
        for fh in handles:
            fh.close()
        unlock(lf)
    size = lambda p: p.stat().st_size if p and p.is_file() else 0  # noqa: E731
    return {"status": status, "exit_code": code, "timed_out": timed_out, "pid": pid,
            "ms": int((time.monotonic() - t0) * 1000), "err_bytes": size(err_log),
            "out_bytes": size(out_log), "godot_path": path, "exe": str(exe_path),
            "display": (dkind if gui else "n/a")}


def headless_args(root: Path, *app_args: str) -> list[str]:
    """Standard smoke argv: headless, dummy audio, --path root, then `-- app_args`."""
    a = ["--headless", "--display-driver", "headless", "--audio-driver", "Dummy", "--path", str(root)]
    return a + (["--"] + list(app_args) if app_args else [])


def grep_logs(logs: list[Path], pattern: str) -> list[str]:
    """Matching lines from the logs, in order, duplicates dropped."""
    rx = re.compile(pattern)
    out: list[str] = []
    for lg in logs:
        for line in _read(lg).splitlines():
            if rx.search(line) and line not in out:
                out.append(line)
    return out


def timing_job(args, job: str, title: str, flag: str, running: str, extra: list[str] | None = None) -> int:
    """Shared body of run_load_timing / run_dungeon_load_timing: run one --wdb-*-smoke, parse LOAD: lines."""
    root = agent_log.resolve_root(args)
    out_log, err_log = agent_log.run_path(job, root, "out.log"), agent_log.run_path(job, root, "err.log")
    print(running)
    r = run_godot(root, root, headless_args(root, flag, *(extra or [])), out_log, err_log, args.timeout_sec)
    loads = grep_logs([err_log, out_log], r"^LOAD:")
    errs = grep_logs([err_log, out_log], r"SCRIPT ERROR:|Parse Error|Compile Error|ERROR: Failed to")
    total, has_ok = "", False
    for h in loads:
        m = re.search(r"total_ms=(\d+)", h)
        total = m.group(1) if m else total
        has_ok = has_ok or "ok=true" in h
    fail = int(r["status"] == "TIMEOUT") + int(r["status"].startswith("EXIT=") and r["status"] != "EXIT=0")
    fail += int(bool(errs)) + int(not has_ok or total == "")
    body = [f"{title} root=.", f"status={r['status']} wall_ms={r['ms']} errBytes={r['err_bytes']} outBytes={r['out_bytes']}",
            "", "--- LOAD lines ---"] + (loads or ["(no LOAD: lines - check the err log if TIMEOUT)"])
    body += ["", "--- errors ---"] + (errs[:40] or ["(none)"])
    marks = sorted(((int(m.group(2)), m.group(1)) for h in loads if (m := re.search(r"mark=(\w+) t=\d+ dt=(\d+)", h))), reverse=True)
    echo = [body[0], body[1], "slowest: " + " ".join(f"{n}={dt}ms" for dt, n in marks[:5])]
    echo += ["errors:"] + errs[:5] if errs else []
    return agent_log.finish(job, root, "\n".join(body), "FAIL" if fail else "PASS", args=args, legacy=False,
                            echo="\n".join(echo), retry=(f"{job} (load timing)", body), fail_signals=fail, total_ms=total or -1)


def timing_parser(desc: str) -> "argparse.ArgumentParser":
    ap = agent_log.std_parser(desc, json_out=True)
    ap.add_argument("--timeout-sec", "-TimeoutSec", type=int, default=180, help="Godot timeout (default 180).")
    return ap


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Probe the per-path Godot lock: lock, print, unlock. --display reports the GUI display choice.")
    ap.add_argument("--display", action="store_true", help="print which display GUI runs (shots, bakes) will use, then exit")
    ap.add_argument("--path", "-Path", default=None, help="Godot --path to lock (default: repo root).")
    ap.add_argument("--timeout-sec", "-TimeoutSec", type=int, default=120, help="Seconds to wait for the lock (default 120).")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    if args.display:
        kind, disp = pick_display()
        print(f"display kind={kind} display={disp or '-'}")
        return agent_log.emit_result("FAIL" if kind == "none" else "PASS", display=kind)
    try:
        lf = lock(root, args.path or root, args.timeout_sec)
    except GodotBusy as e:
        print(e)
        return agent_log.emit_result("FAIL", busy=1)
    unlock(lf)
    print(f"locked path={norm_path(args.path or root)} file={agent_log.rel(root, lf)}")
    return agent_log.emit_result("PASS", locked=1)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
