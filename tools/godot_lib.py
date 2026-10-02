#!/usr/bin/env python3
"""Godot launch + per-path lock for the run_* tools (python port of invoke_godot/godot_lock).

Rules: the lock key is the normalized --path dir; wait until that path is free;
a timeout or compile error kills ONLY the pid this call started, never godot*.

    python3 tools/godot_lib.py --path . --timeout-sec 5     # lock probe: locks, prints, unlocks
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


def run_godot(root: Path, godot_path: Path | str, args: list[str], out_log: Path | None = None,
              err_log: Path | None = None, timeout: int = 120, lock_timeout: int = 120,
              hold: int = 0, exe: str = "") -> dict:
    """Run Godot under the path lock. status: EXIT=<n> | COMPILE | TIMEOUT. Kills only its own pid."""
    exe_path = godot_exe(exe)
    path = norm_path(godot_path)
    args = list(args)
    if "--path" not in args:
        args = ["--path", path] + args
    lf = lock(root, path, lock_timeout, hold if hold > 0 else max(60, timeout + 30))
    t0 = time.monotonic()
    pid, status, code, timed_out = 0, "ERROR", -1, False
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
        proc = subprocess.Popen([str(exe_path)] + args, **kw)
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
            "out_bytes": size(out_log), "godot_path": path, "exe": str(exe_path)}


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
    out_dir = agent_log.ensure_agent_log_dir(job, root)
    out_log, err_log = out_dir / "out.log", out_dir / "err.log"
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
            "", "--- LOAD lines ---"] + (loads or ["(no LOAD: lines - check err.log if TIMEOUT)"])
    body += ["", "--- errors ---"] + (errs[:40] or ["(none)"])
    return agent_log.finish(job, root, "\n".join(body), "FAIL" if fail else "PASS", args=args,
                            fail_signals=fail, total_ms=total or -1)


def timing_parser(desc: str) -> "argparse.ArgumentParser":
    ap = agent_log.std_parser(desc, json_out=True)
    ap.add_argument("--timeout-sec", "-TimeoutSec", type=int, default=180, help="Godot timeout (default 180).")
    return ap


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Probe the per-path Godot lock: lock, print, unlock.")
    ap.add_argument("--path", "-Path", default=None, help="Godot --path to lock (default: repo root).")
    ap.add_argument("--timeout-sec", "-TimeoutSec", type=int, default=120)
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    try:
        lf = lock(root, args.path or root, args.timeout_sec)
    except GodotBusy as e:
        print(e)
        return agent_log.emit_result("FAIL", busy=1)
    unlock(lf)
    print(f"locked path={norm_path(args.path or root)} file={agent_log.rel(root, lf)}")
    return agent_log.emit_result("PASS", locked=1)


if __name__ == "__main__":
    raise SystemExit(main())
