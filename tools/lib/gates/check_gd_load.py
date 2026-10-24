#!/usr/bin/env python3
"""Compile check: load every changed .gd inside the real project (autoloads present), so a parse or compile error fails.

    python tools/gate.py gd-load [--changed [--base REF] | --files a.gd b.gd | --all] [--timeout-sec 180] | --selftest
Default --changed: .gd files that differ from BASE in the working tree (committed or not) plus untracked ones; BASE = the
week branch grok-build-w{N}, else HEAD. A script that does not compile, or that cannot be instantiated, is listed with the
Godot error lines that name it; every file is loaded even after the first failure. The editor import check does not load
every script and a standalone `--script` parse has no autoloads, so neither stands in for this. Imports the project first
when .godot/imported is missing. Summary: _logs/gd-load-check/; Godot's full stderr is saved next to it and the summary
prints its leading lines and size, so read them. RESULT carries files= failed=. Run it once the unit's edits are complete (Change), and again in Prove.
Also fails (nul=) on Godot text files under res:// holding a NUL byte or a UTF-16 BOM, on a .gd string escape that makes a
NUL (\\u0000, \\x00), and on Godot's "Unicode parsing error ... Unexpected NUL" line. Also fails (d3d=) on a tracked texture
.import with Detect 3D on (detect_3d/compress_to not 0): the editor would rewrite it on import (mipmaps, VRAM compression).
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402,F401
import agent_log
import godot_lib
import repo_lib

LOADER = """extends SceneTree
func _initialize() -> void:
	var f := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.READ)
	while not f.eof_reached():
		var p := f.get_line().strip_edges()
		if p == "":
			continue
		var s = ResourceLoader.load(p, "GDScript", ResourceLoader.CACHE_MODE_REPLACE)
		var ok: bool = s is GDScript and (s.can_instantiate() or s.is_abstract())
		print("GDLOAD %s %s" % ["ok" if ok else "FAIL", p])
	quit(0)
"""

def pick(root: Path, args) -> list[str]:
    if args.files:
        return [f.replace("\\", "/") for f in agent_log.split_list(args.files)]
    if args.all:
        return sorted(p.relative_to(root).as_posix() for p in (root / "scripts").rglob("*.gd"))
    base = args.base or repo_lib.week_branch(root) or "HEAD"
    code, out = repo_lib.run_git(root, "diff", "--name-only", base)
    names = out.splitlines() if code == 0 else []
    code, out = repo_lib.run_git(root, "ls-files", "--others", "--exclude-standard")
    return [n for n in dict.fromkeys(names + (out.splitlines() if code == 0 else [])) if n.endswith(".gd")]

def selftest(timeout: int) -> int:
    import tempfile

    bad = []
    with tempfile.TemporaryDirectory() as td:
        t = Path(td)
        (t / "project.godot").write_text('config_version=5\n[application]\nconfig/name="t"\n[autoload]\nAuto="*res://auto.gd"\n', encoding="utf-8")
        (t / "auto.gd").write_text("extends Node\nvar val := 1\n", encoding="utf-8")
        (t / "good.gd").write_text("extends Node\nfunc f() -> int:\n\treturn Auto.val\n", encoding="utf-8")
        (t / "broken.gd").write_text("extends Node\nfunc f() -> int:\n\tvar x := 1)\n\treturn x\n", encoding="utf-8")
        run = lambda *fs: subprocess.run([*boot.cmd("check_gd_load"), "--root", td, "--timeout-sec", str(timeout), "--files", *fs], capture_output=True, text=True)  # noqa: E731
        ok, no = run("good.gd"), run("good.gd", "broken.gd")
        if "RESULT PASS" not in ok.stdout or "files=1 failed=0" not in ok.stdout:
            bad.append("good script (uses an autoload) did not pass: " + ok.stdout[-300:])
        if "RESULT FAIL" not in no.stdout or "failed=1" not in no.stdout or "FAIL broken.gd" not in no.stdout or "FAIL good.gd" in no.stdout:
            bad.append("stray ')' not reported as the only failure: " + no.stdout[-400:])
    for b in bad:
        print("FAIL " + b)
    return agent_log.emit_result("FAIL" if bad else "PASS", None, cmd="selftest", problems=len(bad))

TEXT_EXT = (".gd", ".tscn", ".tres", ".import", ".cfg", ".json", ".md", ".uid", ".godot", ".gdshader", ".csv", ".txt", ".svg")
NUL_ESC = re.compile(r"\\(u0{4}|x00|U0{6})")

def nul_scan(root: Path) -> list[str]:
    """Tracked Godot text files with a NUL byte or UTF-16 BOM, and .gd sources with a NUL string escape."""
    r = subprocess.run(["git", "-C", str(root), "ls-files", "-z"], capture_output=True)
    bad = []
    for rel in r.stdout.decode("utf-8", "replace").split("\0"):
        if not rel.endswith(TEXT_EXT) or not (root / rel).is_file():
            continue
        b = (root / rel).read_bytes()
        if b"\0" in b or b[:2] in (b"\xff\xfe", b"\xfe\xff"):
            bad.append(f"NUL {rel}: NUL byte or UTF-16 (Godot reads it as UTF-8 text)")
        elif rel.endswith(".gd") and NUL_ESC.search(b.decode("utf-8", "replace")):
            bad.append(f"NUL {rel}: string escape makes a NUL character (Godot logs 'Unexpected NUL')")
    return bad

def d3d_scan(root: Path) -> list[str]:
    """Tracked texture .import files with Detect 3D on (project default is off: project.godot [importer_defaults])."""
    r = subprocess.run(["git", "-C", str(root), "ls-files", "-z", "*.import"], capture_output=True)
    bad = []
    for rel in r.stdout.decode("utf-8", "replace").split("\0"):
        if rel and (root / rel).is_file() and re.search(rb"^detect_3d/compress_to=[1-9]", (root / rel).read_bytes(), re.M):
            bad.append(f"D3D {rel}: detect_3d/compress_to must be 0 (Detect 3D rewrites the import)")
    return bad

def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Load changed .gd files in the project; a parse or compile error fails.", json_out=True)
    ap.add_argument("--changed", action="store_true", help="Changed and untracked .gd vs BASE (default).")
    ap.add_argument("--base", default="", help="Git ref for --changed (default: the week branch, else HEAD).")
    ap.add_argument("--files", nargs="+", default=[], help="Repo-relative .gd paths to load.")
    ap.add_argument("--all", action="store_true", help="Every scripts/**/*.gd.")
    ap.add_argument("--selftest", action="store_true", help="Throwaway project with an autoload: a good script passes, a stray ')' fails.")
    ap.add_argument("--timeout-sec", type=int, default=180, help="Godot timeout in seconds (default 180).")
    args = ap.parse_args(argv)
    if args.selftest:
        return selftest(args.timeout_sec)
    root = agent_log.resolve_root(args)
    files = [f for f in pick(root, args) if f.endswith(".gd") and (root / f).is_file()]
    if not files:
        return agent_log.finish("gd-load-check", root, "no changed .gd files to load", "PASS", args=args, files=0, failed=0)
    out_log, err_log = (agent_log.run_path("gd-load-check", root, n) for n in ("out.log", "err.log"))
    lst, loader = (agent_log.run_path("gd-load-check", root, n) for n in ("files.txt", "loader.gd"))
    lst.write_text("\n".join("res://" + f for f in files) + "\n", encoding="utf-8")
    loader.write_text(LOADER, encoding="utf-8")
    if not (root / ".godot" / "imported").is_dir():
        print("importing the project first (no .godot/imported)...")
        godot_lib.run_godot(root, root, ["--headless", "--editor", "--import", "--path", str(root), "--quit"], timeout=args.timeout_sec)
        godot_lib.restore_import_churn(root)
    r = godot_lib.run_godot(root, root, ["--headless", "--audio-driver", "Dummy", "--path", str(root), "--script", str(loader), "--", str(lst)],
                            out_log, err_log, args.timeout_sec, stop_on_compile=False)
    seen = {}
    for ln in godot_lib._read(out_log).splitlines():
        if ln.startswith("GDLOAD "):
            _, st, p = ln.split(" ", 2)
            seen[p] = st
    errs, raw = [], (godot_lib._read(err_log) + "\n" + godot_lib._read(out_log)).splitlines()
    for i, ln in enumerate(raw):
        if ln.startswith(("SCRIPT ERROR", "ERROR", "WARNING", "Unicode parsing error")):
            at = raw[i + 1].strip() if i + 1 < len(raw) and raw[i + 1].strip().startswith("at:") else ""
            errs.append(f"{ln.strip()} {at}".strip())
    bad = [f for f in files if seen.get("res://" + f) != "ok"]
    nul = nul_scan(root) + [e for e in errs if "Unexpected NUL" in e][:1]
    d3d = d3d_scan(root)
    body = [f"root={root} base={args.base or 'week branch/HEAD'} files={len(files)} failed={len(bad)} status={r['status']} errBytes={r['err_bytes']}", ""]
    for f in bad:
        body.append(f"FAIL {f}" + ("" if "res://" + f in seen else "  (never reported: the run ended first)"))
        body += ["    " + e for e in errs if f in e][:6]
    body += nul + d3d[:10]
    if not bad:
        body.append(f"ok: {len(files)} script(s) load and compile with autoloads")
    other = [e for e in errs if not any(f in e for f in bad)]
    body += ["", f"other Godot output lines: {len(other)}, stderr {r['err_bytes']} bytes"
             + (f". Open {agent_log.rel(root, err_log)} before calling any of it harmless; first lines:" if other or r["err_bytes"] else "")]
    body += ["    " + e[:200] for e in other[:8]]
    return agent_log.finish("gd-load-check", root, "\n".join(body), "FAIL" if bad or nul or d3d else "PASS", args=args, retry=("gate.py gd-load", body),
                            files=len(files), failed=len(bad), nul=len(nul), d3d=len(d3d), status_godot=r["status"])

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
