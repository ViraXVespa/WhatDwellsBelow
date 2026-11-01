#!/usr/bin/env python3
"""Box-wide Godot slot lock: caps concurrent Godot launches across every checkout on the Bot box.

On only on the Bot box (/home/box exists and the user is `box`), never on GitHub Actions (CI / GITHUB_ACTIONS)
nor on other PCs. WDB_GODOT_SLOTS=N forces N slots anywhere; =0 turns it off. Default cap 1.
Slots are flock'd files in /workspace/.wdb-godot-slots/ (WDB_GODOT_SLOT_DIR overrides), outside any checkout, so
worktrees and other checkouts share them. The OS drops a flock when its holder dies, so a dead holder is reclaimed
at once; the holder note (pid/cmd/checkout/since) is only for the wait line. Sits on top of godot_lib's per-path lock.

    python3 tools/lib/godot_slots.py            # state: enabled, cap, holders
    python3 tools/lib/godot_slots.py --selftest
"""
from __future__ import annotations

import getpass
import json
import os
import sys
import time
from datetime import datetime
from pathlib import Path

DEFAULT_CAP = 1
BOX_DIR = "/workspace/.wdb-godot-slots"

def slots(env: dict | None = None, home_box: bool | None = None, user: str | None = None) -> int:
    """Slot cap; 0 = off."""
    env = os.environ if env is None else env
    forced = env.get("WDB_GODOT_SLOTS", "").strip()
    if forced:
        try:
            return max(0, int(forced))
        except ValueError:
            return 0
    if env.get("CI") or env.get("GITHUB_ACTIONS"):
        return 0
    if home_box is None:
        home_box = os.path.isdir("/home/box")
    if user is None:
        try:
            user = getpass.getuser()
        except Exception:
            user = ""
    return DEFAULT_CAP if (home_box and user == "box") else 0

def slot_dir() -> Path:
    return Path(os.environ.get("WDB_GODOT_SLOT_DIR") or BOX_DIR)

def _note(fh, cmd: str, checkout: str) -> None:
    fh.seek(0)
    fh.truncate()
    fh.write(json.dumps({"pid": os.getpid(), "cmd": cmd[:160], "checkout": checkout,
                         "since": datetime.now().strftime("%Y-%m-%d %H:%M:%S %Z").strip()}))
    fh.flush()

def holders(d: Path | None = None) -> list[dict]:
    out = []
    for p in sorted((d or slot_dir()).glob("slot-*.lock")):
        try:
            with open(p) as fh:
                if os.name != "nt":
                    import fcntl
                    try:
                        fcntl.flock(fh, fcntl.LOCK_SH | fcntl.LOCK_NB)
                        continue  # free: a dead holder's leftover note
                    except OSError:
                        pass
                out.append(json.loads(fh.read() or "{}"))
        except (OSError, ValueError):
            pass
    return out

def acquire(cmd: str = "", checkout: str = "", timeout: float = 3600, cap: int | None = None, say=print):
    """Take a slot; returns an open file handle to pass to release(), or None when off. Raises TimeoutError."""
    cap = slots() if cap is None else cap
    if cap <= 0 or os.name == "nt":
        return None
    import fcntl
    d = slot_dir()
    d.mkdir(parents=True, exist_ok=True)
    t0, said = time.monotonic(), ""
    while True:
        for i in range(cap):
            fh = open(d / f"slot-{i}.lock", "a+")
            try:
                fcntl.flock(fh, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except OSError:
                fh.close()
                continue
            _note(fh, cmd, checkout)
            return fh
        h = holders(d)[:cap]
        line = "; ".join(f"pid {x.get('pid')} {x.get('cmd', '')!s:.60} ({x.get('checkout')}) since {x.get('since')}" for x in h)
        if line != said:
            say(f"godot_slots: waiting on {line or 'a holder'}")
            said = line
        if time.monotonic() - t0 > timeout:
            raise TimeoutError(f"godot_slots: no slot in {timeout:.0f}s; holders: {line}")
        time.sleep(0.5)

def release(fh) -> None:
    if fh is None:
        return
    try:
        fh.seek(0)
        fh.truncate()
        fh.close()  # closing drops the flock
    except OSError:
        pass

class held:
    """with godot_slots.held(cmd, checkout): ... for launches that bypass godot_lib.run_godot."""
    def __init__(self, cmd: str = "", checkout: str = ""):
        self.cmd, self.checkout, self.fh = cmd, checkout, None

    def __enter__(self):
        self.fh = acquire(self.cmd, self.checkout)
        return self

    def __exit__(self, *exc) -> None:
        release(self.fh)

def selftest() -> int:
    import subprocess
    import tempfile
    fails = []
    cases = [({}, True, "box", 1), ({}, False, "box", 0), ({}, True, "vira", 0), ({"CI": "true"}, True, "box", 0),
             ({"GITHUB_ACTIONS": "true"}, True, "box", 0), ({"WDB_GODOT_SLOTS": "2", "CI": "1"}, False, "x", 2),
             ({"WDB_GODOT_SLOTS": "0"}, True, "box", 0)]
    for env, hb, u, want in cases:
        if slots(env, hb, u) != want:
            fails.append(f"detect {env} {hb} {u} -> {slots(env, hb, u)} want {want}")
    with tempfile.TemporaryDirectory() as td:
        os.environ["WDB_GODOT_SLOT_DIR"] = td
        hold = ("import sys,time;sys.path.insert(0,%r);import godot_slots as g;"
                "f=g.acquire('holder','co',cap=1);print('got',flush=True);time.sleep(float(sys.argv[1]))") % str(Path(__file__).parent)
        a = subprocess.Popen([sys.executable, "-c", hold, "1.5"], stdout=subprocess.PIPE, text=True)
        a.stdout.readline()
        lines: list[str] = []
        t = time.monotonic()
        fh = acquire("second", "co", timeout=10, cap=1, say=lines.append)
        waited = time.monotonic() - t
        release(fh)
        a.wait()
        if waited < 1.0 or not any("waiting on pid" in x and "holder" in x for x in lines):
            fails.append(f"queue: waited {waited:.2f}s lines={lines}")
        b = subprocess.Popen([sys.executable, "-c", hold, "60"], stdout=subprocess.PIPE, text=True)
        b.stdout.readline()
        b.kill()
        b.wait()
        t = time.monotonic()
        fh = acquire("reclaim", "co", timeout=5, cap=1, say=lambda s: None)
        if time.monotonic() - t > 1.0:
            fails.append("dead holder not reclaimed at once")
        release(fh)
    for f in fails:
        print("FAIL", f)
    print(f"godot_slots selftest fails={len(fails)}")
    return 1 if fails else 0

def main(argv: list[str] | None = None) -> int:
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import boot  # noqa: F401
    import agent_log
    ap = agent_log.std_parser("Box-wide Godot slot lock: print state (enabled cap, holders) or --selftest.")
    ap.add_argument("--selftest", action="store_true", help="detection cases, two contenders queue, dead-holder reclaim")
    args = ap.parse_args(argv)
    agent_log.resolve_root(args)
    if args.selftest:
        rc = selftest()
        return agent_log.emit_result("FAIL" if rc else "PASS", selftest=1)
    h = holders()
    print(f"godot_slots slots={slots()} dir={slot_dir()} holders={len(h)}")
    for x in h:
        print(f"  pid {x.get('pid')} {x.get('cmd', '')} ({x.get('checkout')}) since {x.get('since')}")
    return agent_log.emit_result("PASS", slots=slots(), holders=len(h))

if __name__ == "__main__":
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import agent_log as _al
    raise SystemExit(_al.guarded(main))
