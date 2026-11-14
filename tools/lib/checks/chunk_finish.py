#!/usr/bin/env python3
"""Finish an unused-sweep chunk: run every verify phase the change set needs, rerun a failing phase once, then summarize.

Phases (changed set = git diff BASE..worktree plus untracked):
  selftest   lint.py unused --selftest                    when tools/lib/lint/ changed
  sweep      lint.py unused [--paths ..] [--baseline F]   always (chunk view when --paths)
  script-cap check.py script-cap --bot --path <changed>   when live scripts/**/*.gd changed
  code-map   docs.py code-map check                       when scripts/ changed
  gd-load    gate.py gd-load --files <changed .gd>        when live .gd still on disk changed
  prove      check.py prove --base BASE                   unless --no-prove
A failing phase reruns once (known flake: smokes P5 chest_ok=false) before it counts; the fatal line is printed.
With --plan-out PATH --chunk N and every phase green, the sweep's plan block is written there. Never commits."""
from __future__ import annotations

import re
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402,F401

import agent_log

FATAL = re.compile(r"SCRIPT ERROR|ok=false|Traceback|^FAIL\b|\bFAIL\s|^error:|RESULT FAIL", re.M)

def git(root: Path, *a: str) -> str:
    return subprocess.run(["git", *a], cwd=root, capture_output=True, text=True).stdout

def changed(root: Path, base: str) -> list[str]:
    names = git(root, "diff", "--name-only", base).split() + git(root, "ls-files", "--others", "--exclude-standard").split()
    return sorted(set(names))

def phases(root: Path, base: str, files: list[str], ns) -> list[tuple[str, list[str], int]]:
    py = sys.executable or "python3"
    live = [f for f in files if f.endswith(".gd") and f.startswith("scripts/")]
    on_disk = [f for f in files if f.endswith(".gd") and f.startswith(("scripts/", "tools/data/")) and (root / f).is_file()]
    sweep = [py, "tools/lint.py", "unused"] + (["--paths", *ns.paths] if ns.paths else []) + (["--baseline", ns.baseline] if ns.baseline else [])
    out = []
    if any(f.startswith("tools/lib/lint/") for f in files):
        out.append(("selftest", [py, "tools/lint.py", "unused", "--selftest"], 300))
    out.append(("sweep", sweep, 600))
    cap = [f for f in live if (root / f).is_file()]
    if cap:
        out.append(("script-cap", [py, "tools/check.py", "script-cap", "--bot"] + [x for f in cap for x in ("--path", f)], 300))
    if any(f.startswith("scripts/") for f in files):
        out.append(("code-map", [py, "tools/docs.py", "code-map", "check"], 300))
    if on_disk:
        out.append(("gd-load", [py, "tools/gate.py", "gd-load", "--files", *on_disk], 900))
    if not ns.no_prove:
        out.append(("prove", [py, "tools/check.py", "prove", "--base", base], 3600))
    return out

def run_phase(root: Path, cmd: list[str], timeout: int) -> tuple[bool, str, float]:
    t0 = time.perf_counter()
    try:
        p = subprocess.run(cmd, cwd=root, capture_output=True, text=True, timeout=timeout)
        text, ok = (p.stdout or "") + (p.stderr or ""), p.returncode == 0
    except subprocess.TimeoutExpired:
        text, ok = f"timeout after {timeout}s", False
    return ok, text, time.perf_counter() - t0

def fatal(text: str) -> str:
    hits = [m.group(0) for m in re.finditer(r"^.*$", text, re.M) if FATAL.search(m.group(0))]
    lines = [l for l in text.splitlines() if l.strip()]
    return (hits[0] if hits else (lines[-1] if lines else "no output")).strip()[:240]

def result_of(text: str) -> str:
    return next((l for l in reversed(text.splitlines()) if l.startswith("RESULT ")), "")[:200]

def selftest() -> list[str]:
    bad = []
    if fatal("a\nSHOT: ok=false err=x\nRESULT FAIL n=1\n") != "SHOT: ok=false err=x":
        bad.append("fatal: ok=false line not picked first")
    if fatal("x\ny\n") != "y":
        bad.append("fatal: last line fallback")

    class NS:
        paths, baseline, no_prove = ["scripts/ui"], None, False
    with __import__("tempfile").TemporaryDirectory() as tmp:
        root = Path(tmp)
        (root / "scripts/ui").mkdir(parents=True)
        (root / "scripts/ui/a.gd").write_text("extends Node\n", encoding="utf-8")
        names = [n for n, _c, _t in phases(root, "B", ["scripts/ui/a.gd", "scripts/ui/gone.gd", "tools/lib/lint/x.py"], NS)]
        if names != ["selftest", "sweep", "script-cap", "code-map", "gd-load", "prove"]:
            bad.append(f"phases: full set wrong {names}")
        cmds = {n: c for n, c, _t in phases(root, "B", ["scripts/ui/a.gd", "scripts/ui/gone.gd"], NS)}
        if "gone.gd" in " ".join(cmds["gd-load"]) or "--paths" not in cmds["sweep"] or cmds["prove"][-1] != "B":
            bad.append(f"phases: commands wrong {cmds}")
        NS.no_prove = True
        if [n for n, _c, _t in phases(root, "B", ["design/x.md"], NS)] != ["sweep"]:
            bad.append("phases: docs-only change should run the sweep only")
    return bad

def main() -> int:
    ap = agent_log.std_parser(__doc__.split("\n")[0])
    ap.add_argument("--paths", nargs="+", default=[], help="Chunk globs, passed to lint.py unused --paths.")
    ap.add_argument("--base", default=None, help="Diff base (default: origin/<branch>, as check.py prove).")
    ap.add_argument("--baseline", metavar="FILE", help="Chunk baseline from lint.py unused --save-baseline (before/after diff).")
    ap.add_argument("--plan-out", metavar="PATH", help="With --chunk N and all phases green: write the chunk's plan block there.")
    ap.add_argument("--chunk", metavar="N", help="Chunk label for --plan-out.")
    ap.add_argument("--no-prove", action="store_true", help="Skip prove (quick loop; the final finish must include it).")
    ap.add_argument("--selftest", action="store_true", help="Phase selection and fatal-line picking on fixtures.")
    ns = ap.parse_args()
    if ns.selftest:
        return agent_log.selftest_result(selftest())
    if ns.plan_out and not (ns.chunk and ns.paths):
        ap.error("--plan-out needs --chunk N and --paths")
    root = agent_log.resolve_root(ns)
    base = ns.base
    if not base:
        from check_prove import default_base
        base = default_base(root)[0]
    files = changed(root, base)
    lines, failed = [f"base={base} changed={len(files)}"], []
    for name, cmd, timeout in phases(root, base, files, ns):
        ok, text, secs = run_phase(root, cmd, timeout)
        note = ""
        if not ok:
            first = fatal(text)
            ok, text, more = run_phase(root, cmd, timeout)
            secs += more
            note = f" (rerun {'PASS: first run flaked: ' + first if ok else 'also failed'})"
        lines.append(f"{'PASS' if ok else 'FAIL'} {secs:6.1f}s {name}{note} :: {result_of(text) or ' '.join(cmd[1:])}")
        if not ok:
            failed.append(name)
            lines.append(f"  fatal: {fatal(text)}")
    if ns.plan_out and not failed:
        py = sys.executable or "python3"
        cmd = [py, "tools/lint.py", "unused", "--paths", *ns.paths, "--plan-out", ns.plan_out, "--chunk", ns.chunk] + (["--baseline", ns.baseline] if ns.baseline else [])
        ok, text, _s = run_phase(root, cmd, 600)
        lines.append(f"{'PASS' if ok else 'FAIL'} plan block -> {ns.plan_out} :: {result_of(text)}")
        failed += [] if ok else ["plan"]
    status = "FAIL" if failed else "PASS"
    return agent_log.finish("chunk-finish", root, "\n".join(lines), status, args=ns, echo="\n".join(lines),
                            phases=len([l for l in lines if l[:4] in ("PASS", "FAIL")]), failed=",".join(failed) or 0)

if __name__ == "__main__":
    raise SystemExit(main())
