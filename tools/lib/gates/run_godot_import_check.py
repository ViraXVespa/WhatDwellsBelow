#!/usr/bin/env python3
"""Editor import / script-reload check. Per-path Godot lock; never kills godot*.

    python tools/gate.py import [--timeout-sec 180] [--no-static]
`--import` alone parses no script and loads no scene, so a parse error or a broken
ext_resource passed; after the import it runs the static compile of every live .gd and
scene (bot_smokes.static_compile = gate.py warnscan --areas static, errors only).
Summary: _logs/godot-import-check/<stamp>-godot-import-check.txt; RESULT carries clean=true|false.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402,F401
import agent_log
import godot_lib

def _selftest() -> int:
    import subprocess
    import tempfile
    with tempfile.TemporaryDirectory(prefix="wdb-import-st-") as td:
        t = Path(td)
        for rel, body in (("project.godot", 'config_version=5\n[application]\nconfig/name="t"\n'), ("scenes/.keep", ""),
                          ("scripts/a.gd", "extends Node\nfunc f() -> void:\n\tvar x :=\n")):
            (t / rel).parent.mkdir(parents=True, exist_ok=True)
            (t / rel).write_text(body, encoding="utf-8")
        r = subprocess.run([*boot.cmd("run_godot_import_check"), "--root", td, "--timeout-sec", "120"], capture_output=True, text=True, timeout=400)
    bad = [] if r.returncode != 0 and "scripts/a.gd" in r.stdout + r.stderr else [f"a parse error in scripts/a.gd did not FAIL the import check (rc={r.returncode})"]
    for b in bad:
        print("FAIL " + b)
    return agent_log.emit_result("FAIL" if bad else "PASS", None, cmd="selftest", problems=len(bad))

def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Headless editor import check.", json_out=True)
    ap.add_argument("--timeout-sec", type=int, default=180, help="Godot timeout in seconds (default 180).")
    ap.add_argument("--selftest", action="store_true", help="a throwaway project with a parse error in scripts/ must FAIL (the import alone passed it)")
    ap.add_argument("--no-static", action="store_true", help="skip the static compile of every live .gd and scene after the import")
    args = ap.parse_args(argv)
    if args.selftest:
        return _selftest()
    root, where = agent_log.cwd_scan_root(args)
    out_log = agent_log.run_path("godot-import-check", root, "import-out.log")
    err_log = agent_log.run_path("godot-import-check", root, "import-err.log")
    print("Running editor import check...")
    r = godot_lib.run_godot(root, root, ["--headless", "--editor", "--import", "--path", str(root), "--quit"],
                            out_log, err_log, args.timeout_sec)
    hits = godot_lib.grep_logs([err_log, out_log], r"SCRIPT ERROR:|Parse Error|Compile Error|ERROR: Failed|WARNING:")
    hard = any(godot_lib.HARD_RE.search(h) for h in hits)
    static: list[str] = []
    if not args.no_static:
        import contextlib
        import io
        from bot_smokes import static_compile
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            hard = static_compile(root) != 0 or hard
        static = buf.getvalue().splitlines()
    clean = r["status"] == "EXIT=0" and r["err_bytes"] == 0 and not hard
    body = [f"godot import check {where}", f"status={r['status']} ms={r['ms']} errBytes={r['err_bytes']} outBytes={r['out_bytes']}",
            *static, "", "--- highlights ---"] + (hits[:120] or ["(no SCRIPT ERROR / WARNING highlights)"])
    return agent_log.finish("godot-import-check", root, "\n".join(body), "PASS" if clean else "FAIL", args=args, retry=("gate.py import", body),
                            clean=str(clean).lower(), status_godot=r["status"])

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
