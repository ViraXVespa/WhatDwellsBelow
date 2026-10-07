#!/usr/bin/env python3
"""Compile check: load every changed .gd inside the real project (autoloads present), so a parse or compile error fails.

    python tools/check_gd_load.py [--changed [--base REF] | --files a.gd b.gd | --all] [--timeout-sec 180] | --selftest
Default --changed: .gd files that differ from BASE in the working tree (committed or not) plus untracked ones; BASE = the
week branch grok-build-w{N}, else HEAD. A script that does not compile, or that cannot be instantiated, is listed with the
Godot error lines that name it; every file is loaded even after the first failure. The editor import check does not load
every script and a standalone `--script` parse has no autoloads, so neither stands in for this. Imports the project first
when .godot/imported is missing. Summary: _logs/gd-load-check/; Godot's full stderr is saved next to it and the summary
prints its leading lines and size, so read them. RESULT carries files= failed=. Small batches: run it after each edit pass.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
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
        run = lambda *fs: subprocess.run([sys.executable, str(Path(__file__).resolve()), "--root", td, "--timeout-sec", str(timeout), "--files", *fs], capture_output=True, text=True)  # noqa: E731
        ok, no = run("good.gd"), run("good.gd", "broken.gd")
        if "RESULT PASS" not in ok.stdout or "files=1 failed=0" not in ok.stdout:
            bad.append("good script (uses an autoload) did not pass: " + ok.stdout[-300:])
        if "RESULT FAIL" not in no.stdout or "failed=1" not in no.stdout or "FAIL broken.gd" not in no.stdout or "FAIL good.gd" in no.stdout:
            bad.append("stray ')' not reported as the only failure: " + no.stdout[-400:])
    for b in bad:
        print("FAIL " + b)
    return agent_log.emit_result("FAIL" if bad else "PASS", None, cmd="selftest", problems=len(bad))


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
        if ln.startswith(("SCRIPT ERROR", "ERROR", "WARNING")):
            at = raw[i + 1].strip() if i + 1 < len(raw) and raw[i + 1].strip().startswith("at:") else ""
            errs.append(f"{ln.strip()} {at}".strip())
    bad = [f for f in files if seen.get("res://" + f) != "ok"]
    body = [f"root={root} base={args.base or 'week branch/HEAD'} files={len(files)} failed={len(bad)} status={r['status']} errBytes={r['err_bytes']}", ""]
    for f in bad:
        body.append(f"FAIL {f}" + ("" if "res://" + f in seen else "  (never reported: the run ended first)"))
        body += ["    " + e for e in errs if f in e][:6]
    if not bad:
        body.append(f"ok: {len(files)} script(s) load and compile with autoloads")
    other = [e for e in errs if not any(f in e for f in bad)]
    body += ["", f"other Godot output lines: {len(other)}, stderr {r['err_bytes']} bytes"
             + (f". Open {agent_log.rel(root, err_log)} before calling any of it harmless; first lines:" if other or r["err_bytes"] else "")]
    body += ["    " + e[:200] for e in other[:8]]
    return agent_log.finish("gd-load-check", root, "\n".join(body), "FAIL" if bad else "PASS", args=args, retry=("check_gd_load.py", body),
                            files=len(files), failed=len(bad), status_godot=r["status"])


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
