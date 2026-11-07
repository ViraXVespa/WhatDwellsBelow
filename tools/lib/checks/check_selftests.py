#!/usr/bin/env python3
"""Run every tool selftest in the repo, whatever changed (check.py prove --all runs it too). Read-only.

Discovery: each tools/**/*.py with its own --selftest flag (same rule as prove's @selftests), run through its entry
(`python3 tools/E.py SUB --selftest`) or by path when it has a __main__ block, plus EXTRA (selftests on a sub-subcommand).
Each runs with a timeout. A missing optional executable or module (grok, godot, chrome/edge, ffmpeg, a pip package) is SKIP
with its reason, never FAIL. git status must be the same after the sweep; a changed tree is a FAIL.
Against one commit: git worktree add --detach /tmp/wdb-st REV && (cd /tmp/wdb-st && python3 tools/check.py selftests); git worktree remove --force /tmp/wdb-st
"""
from __future__ import annotations

import re
import shutil
import subprocess
import sys
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402

import agent_log
from check_prove import SELFTEST_FLAG

EXTRA = [("tools/lib/docs/task_compact.py", "python3 tools/docs.py task compact --selftest")]
SUBSUB = {"tools/lib/docs/task.py"}  # its --selftest sits on a sub-subcommand (EXTRA)
EXES = ("grok", "godot", "chrome", "chromium", "msedge", "edge", "ffmpeg", "ffprobe", "gh", "tesseract")
SKIP_RE = re.compile(r"ModuleNotFoundError: No module named '([\w.]+)'|No such file or directory: '[^']*?(" + "|".join(EXES) + r")[^']*'"
                     r"|\b(" + "|".join(EXES) + r")\b[^\n]{0,40}\b(?:not found|not on PATH|missing|is not installed)|RESULT SKIP\b[^\n]*|not run: [^\n]+", re.I)

def discover(root: Path) -> list[tuple[str, str]]:
    ents = {f"tools/lib/{m}.py": (e, s) for e, rows in boot.entries(root / "tools").items() for s, m, _ in rows}
    out = dict(EXTRA)
    for p in sorted((root / "tools").rglob("*.py")):
        rel = p.relative_to(root).as_posix()
        src = p.read_text(encoding="utf-8", errors="replace")
        if rel in SUBSUB or rel in out or "/__pycache__/" in rel or not SELFTEST_FLAG.search(src) or re.search(r"^(COMMANDS|MODULE)\s*=", src, re.M):
            continue
        e = ents.get(rel)
        if e:
            out[rel] = f"python3 tools/{e[0]}.py {e[1] or ''} --selftest".replace("  ", " ")
        elif "__main__" in src:
            out[rel] = f"python3 {rel} --selftest"
    return sorted(out.items())

def classify(rc: int | None, text: str) -> tuple[str, str]:
    lines = [l for l in text.splitlines() if l.strip()]
    if rc is None:
        return "FAIL", "timeout"
    m = SKIP_RE.search(text)
    if rc != 0 and m:
        return "SKIP", m.group(0).strip()[:120]
    if rc == 0:
        return ("SKIP", m.group(0)[:120]) if m and re.match(r"RESULT SKIP|not run", m.group(0), re.I) else ("PASS", "")
    first = next((l for l in lines if re.search(r"FAIL|Error|error:|Traceback", l)), lines[-1] if lines else f"exit {rc}")
    return "FAIL", first.strip()[:200]

def run_one(root: Path, cmd: str, timeout: int) -> tuple[str, str, float]:
    t = time.time()
    with tempfile.TemporaryDirectory(prefix="wdb-st-") as td:
        env = {**__import__("os").environ, "TMPDIR": td}
        try:
            r = subprocess.run(cmd.split(), cwd=root, capture_output=True, text=True, timeout=timeout, env=env, stdin=subprocess.DEVNULL)
            st, why = classify(r.returncode, r.stdout + "\n" + r.stderr)
        except subprocess.TimeoutExpired:
            st, why = classify(None, "")
    return st, why, time.time() - t

def status(root: Path) -> str:
    return subprocess.run(["git", "status", "--porcelain", "--untracked-files=all"], cwd=root, capture_output=True, text=True).stdout

def sweep(root: Path, items: list[tuple[str, str]], timeout: int, jobs: int) -> list[tuple[str, str, str, str, float]]:
    with ThreadPoolExecutor(max_workers=jobs) as ex:
        res = list(ex.map(lambda it: run_one(root, it[1], timeout), items))
    return [(p, c, s, w, d) for (p, c), (s, w, d) in zip(items, res)]

def selftest() -> int:
    """Planted fixtures: one passing, one failing, one missing exe, one missing module; each must classify as planted."""
    with tempfile.TemporaryDirectory() as td:
        t = Path(td)
        cases = {"ok.py": ("print('RESULT PASS')", "PASS"), "bad.py": ("print('FAIL planted fault'); raise SystemExit(1)", "FAIL"),
                 "exe.py": ("import subprocess; subprocess.run(['grok-missing-x'])", "SKIP"), "mod.py": ("import no_such_mod_wdb", "SKIP"),
                 "slow.py": ("import time; time.sleep(5)", "FAIL")}
        for n, (src, _) in cases.items():
            (t / n).write_text(src.replace("grok-missing-x", "grok"), encoding="utf-8")
        got = sweep(t, [(n, f"{sys.executable} {n}") for n in cases], 2, 4)
    bad = [f"{p}: got {s} ({w}) want {cases[p][1]}" for p, _, s, w, _ in got if s != cases[p][1]]
    for b in bad:
        print("FAIL " + b)
    print(f"RESULT {'FAIL' if bad else 'PASS'} selftest check-selftests cases={len(cases)}")
    return 1 if bad else 0

def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser(__doc__.split("\n")[0])
    ap.add_argument("--timeout", type=int, default=300, help="Seconds per selftest (default 300).")
    ap.add_argument("--jobs", type=int, default=4, help="Parallel selftests (default 4).")
    ap.add_argument("--only", default="", help="Regex on the tool path: run only matching selftests.")
    ap.add_argument("--selftest", action="store_true", help="Planted pass / fail / missing-exe / missing-module / timeout fixtures must classify right.")
    args = ap.parse_args(sys.argv[1:] if argv is None else argv)
    if args.selftest:
        return selftest()
    root = agent_log.resolve_root(args)
    items = [it for it in discover(root) if not args.only or re.search(args.only, it[0])]
    before = status(root)
    rows = sweep(root, items, args.timeout, args.jobs)
    after = status(root)
    lines = [f"{s:4} {d:6.1f}s {p} :: {c}" + (f" :: {w}" if w else "") for p, c, s, w, d in rows]
    fails = [r for r in rows if r[2] == "FAIL"]
    if after != before:
        changed = sorted(set(after.splitlines()) ^ set(before.splitlines()))
        lines.append("FAIL tree changed by the sweep: " + "; ".join(changed[:5]))
    n = {k: sum(r[2] == k for r in rows) for k in ("PASS", "FAIL", "SKIP")}
    lines += ["", "failures:"] + [f"  {p}: {w}" for p, _, _, w, _ in fails] if fails else []
    ok = not fails and after == before
    return agent_log.finish("selftests", root, "\n".join(lines), "PASS" if ok else "FAIL", args=args, echo="\n".join(lines),
                            run=len(rows), passed=n["PASS"], failed=n["FAIL"] + (after != before), skipped=n["SKIP"])

if __name__ == "__main__":
    raise SystemExit(main())
