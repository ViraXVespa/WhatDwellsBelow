#!/usr/bin/env python3
"""Open PNGs for the User in her default viewer, and print the path + description lines to paste into the message.

    python tools/show_png.py PATH[=one-line description] [PATH[=description] ...] [--no-open]
Run it once, with every picture the next ask refers to, after you have looked at them yourself and before you write the message and ask. It also prints the `Did not work:` lines built from this session's failed tool results since your last ask; they open the message.
Windows: each file opens through the default viewer (os.startfile), in the order given. Elsewhere (a Linux box, CI) nothing can open on her
screen: the lines are printed and the run still passes. A path that is not a file fails (exit 1) and nothing is opened.
Relative paths are taken from the current directory (the worktree).
"""
from __future__ import annotations

import os
import re
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log
import session_lib

EXT = re.compile(r"^(.*?\.(?:png|jpe?g|webp|gif|bmp))(?:=(.*))?$", re.I)


def split_item(item: str) -> tuple[str, str]:
    m = EXT.match(item)
    return (m.group(1), (m.group(2) or "").strip()) if m else (item, "")


def open_files(paths: list[Path], native: bool | None = None) -> int:
    """Open each file with the default viewer in order; returns how many were opened (0 when there is no viewer to open them in)."""
    if native is None:
        native = os.name == "nt"
    if not native:
        return 0
    n = 0
    for p in paths:
        try:
            os.startfile(str(p))  # type: ignore[attr-defined]
            n += 1
            time.sleep(0.4)
        except (OSError, AttributeError):
            print(f"WARN: could not open {p}")
    return n


def selftest() -> int:
    import tempfile

    bad = []
    if split_item(r"C:\a b\x.png=the pause page") != (r"C:\a b\x.png", "the pause page") or split_item("y.PNG") != ("y.PNG", ""):
        bad.append("PATH=description must split on the first '=' after the extension")
    with tempfile.TemporaryDirectory() as td:
        f = Path(td) / "a.png"
        f.write_bytes(b"x")
        if open_files([f], native=False) != 0:
            bad.append("a non-Windows run must open nothing")
        import subprocess

        p = subprocess.run([sys.executable, str(Path(__file__).resolve()), f"{f}=before", "--no-open"], capture_output=True, text=True)
        if p.returncode != 0 or "before" not in p.stdout or "opened=0" not in p.stdout:
            bad.append("a good path prints path - description and passes")
        p = subprocess.run([sys.executable, str(Path(__file__).resolve()), str(Path(td) / "nope.png")], capture_output=True, text=True)
        if p.returncode == 0 or "not a file" not in p.stdout + p.stderr:
            bad.append("a missing path must fail")
    for b in bad:
        print("FAIL " + b)
    return agent_log.emit_result("FAIL" if bad else "PASS", None, cmd="selftest", problems=len(bad))


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Open PNGs for the User and print path - description lines for the message.")
    ap.add_argument("items", nargs="*", help="PATH or PATH=one-line description")
    ap.add_argument("--no-open", action="store_true", help="Only print the lines.")
    ap.add_argument("--selftest", action="store_true", help="Run the built-in cases.")
    args = ap.parse_args(argv)
    if args.selftest:
        return selftest()
    if not args.items:
        agent_log.fail("pass PATH[=description] for each picture (example: python tools/show_png.py _logs/shot-flow/camp-pause-pages/01-a.png=\"Settings, after\")")
    rows = [(Path(split_item(i)[0]).expanduser(), split_item(i)[1]) for i in args.items]
    rows = [(p if p.is_absolute() else Path.cwd() / p, d) for p, d in rows]
    missing = [str(p) for p, _ in rows if not p.is_file()]
    if missing:
        agent_log.fail("not a file: " + "; ".join(missing))
    n = 0 if args.no_open else open_files([p for p, _ in rows])
    for p, d in rows:
        print(f"{p} - {d or '(no description given: say what is on it)'}")
    where = "opened on her screen" if n else "not opened (no viewer here); list them in the message"
    print(f"{where}: {n} of {len(rows)}")
    print(session_lib.failed_block())
    return agent_log.emit_result("PASS", opened=n, files=len(rows))


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
