#!/usr/bin/env python3
"""Commit the slice after her yes, only when the build gate ran after your last edit, or the skip is said out loud.

    python tools/commit_slice.py [--message-file _logs/commit-msg.txt] [--gate-skipped "why"] [--dry-run]
The gate is `python tools/run_build_gate.py --batch`, plus `--visual JOB` only when that job has a shot flow. This tool reads its newest summary in _logs/build-gate: it must end in
`RESULT PASS` and be newer than every changed file. With no passing gate it stops (exit 1) and prints both ways forward. `--gate-skipped WHY`
commits anyway and prints the line `Did not work: gate not run (WHY)` that opens your final message.
Staged: every change, new `.import` sidecars included; sidecars Godot only modified (churn) are left out and counted. Nothing is pushed.
Commit only after she said to commit.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log


def git(root: Path, *a: str) -> subprocess.CompletedProcess:
    return subprocess.run(["git", "-C", str(root), *a], capture_output=True, text=True, encoding="utf-8", errors="replace")


def changed(root: Path) -> list[tuple[str, str]]:
    """[(XY status, path)] from `git status --porcelain -z`, _logs/ left out."""
    out = git(root, "status", "--porcelain=v1", "-z", "--untracked-files=all").stdout.split("\0")
    rows, i = [], 0
    while i < len(out):
        e = out[i]
        i += 1
        if len(e) < 4:
            continue
        if e[0] in "RC":
            i += 1
        if not e[3:].startswith("_logs/"):
            rows.append((e[:2], e[3:]))
    return rows


def gate_state(root: Path, rows: list[tuple[str, str]]) -> str:
    """'' when the newest build-gate summary passed after the last edit; else the reason it did not."""
    found = sorted((root / "_logs" / "build-gate").glob("*-build-gate.txt"))
    sp = found[-1] if found else root / "_logs" / "build-gate" / "none"
    if not sp.is_file():
        return "no build gate summary in _logs/build-gate"
    last = [ln for ln in sp.read_text(encoding="utf-8", errors="replace").splitlines() if ln.startswith("RESULT ")]
    if not last or not last[-1].startswith("RESULT PASS"):
        return f"the newest build gate did not pass ({last[-1] if last else 'no RESULT line'})"
    stale = [p for _, p in rows if not p.endswith(".import") and (root / p).is_file() and (root / p).stat().st_mtime > sp.stat().st_mtime]
    return f"{len(stale)} file(s) changed after the last gate, e.g. {stale[0]}" if stale else ""


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Commit the slice after the build gate (or an explicit skip).", writes=True)
    ap.add_argument("--message-file", default="_logs/commit-msg.txt", help="Commit message file inside the worktree (default _logs/commit-msg.txt).")
    ap.add_argument("--gate-skipped", default="", metavar="WHY", help="Commit without a passing gate; prints the `Did not work: gate not run` line for your message.")
    ap.add_argument("--selftest", action="store_true", help="Run the built-in cases.")
    args = ap.parse_args(argv)
    if args.selftest:
        return selftest()
    root = agent_log.resolve_root(args)
    msg = Path(args.message_file)
    msg = msg if msg.is_absolute() else root / msg
    if not msg.is_file():
        agent_log.fail(f"write the commit message to {args.message_file} first (inside the worktree)")
    rows = changed(root)
    if not rows:
        agent_log.fail("nothing to commit")
    why = gate_state(root, rows)
    if why and not args.gate_skipped.strip():
        agent_log.fail(f"gate: {why}. Run `python tools/run_build_gate.py --batch` (add `--visual JOB` only when that job has a shot flow), or commit with --gate-skipped \"why\" and open your final message with `Did not work: gate not run (why)`")
    churn = [p for st, p in rows if p.endswith(".import") and st.strip() == "M"]
    paths = [p for _, p in rows if p not in churn]
    if not paths:
        agent_log.fail(f"only {len(churn)} modified .import sidecar(s) changed (Godot churn): nothing to commit")
    if args.dry_run:
        print(f"would commit {len(paths)} path(s), leave out {len(churn)} modified .import sidecar(s)" + (f"; gate skipped: {args.gate_skipped}" if why else ""))
        return agent_log.emit_result("PASS", dry_run=True, paths=len(paths), left_out=len(churn))
    p = subprocess.run(["git", "-C", str(root), "add", "-A", "--pathspec-from-file=-"], input="\n".join(paths) + "\n", capture_output=True, text=True, encoding="utf-8")
    if p.returncode:
        agent_log.fail("git add failed: " + (p.stderr or p.stdout).strip()[:300])
    c = git(root, "commit", "-F", str(msg))
    if c.returncode:
        agent_log.fail("git commit failed: " + (c.stderr or c.stdout).strip()[:300])
    sha = git(root, "rev-parse", "--short", "HEAD").stdout.strip()
    print(f"committed {sha}: {len(paths)} path(s); {len(churn)} modified .import sidecar(s) left uncommitted (Godot churn); not pushed")
    if why:
        print(f"Did not work: gate not run ({args.gate_skipped.strip()})")
    return agent_log.emit_result("PASS", commit=sha, paths=len(paths), left_out=len(churn), gate="skipped" if why else "passed")


def selftest() -> int:
    import os
    import tempfile
    import time

    bad: list[str] = []
    me = str(Path(__file__).resolve())
    with tempfile.TemporaryDirectory() as td:
        r = Path(td)
        env = {**os.environ, "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t", "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@t"}
        for a in (["init", "-q"], ["config", "core.autocrlf", "false"]):
            git(r, *a)
        (r / "project.godot").write_text("x", encoding="utf-8")
        (r / "a.txt").write_text("1", encoding="utf-8")
        (r / "x.png.import").write_text("1", encoding="utf-8")
        git(r, "add", "-A")
        subprocess.run(["git", "-C", str(r), "commit", "-qm", "base"], env=env, capture_output=True)
        (r / "a.txt").write_text("2", encoding="utf-8")
        (r / "x.png.import").write_text("2", encoding="utf-8")
        (r / "new.png.import").write_text("n", encoding="utf-8")
        (r / "_logs").mkdir()
        (r / "_logs" / "commit-msg.txt").write_text("slice\n", encoding="utf-8")

        def run(*a: str) -> subprocess.CompletedProcess:
            return subprocess.run([sys.executable, me, "--root", str(r), *a], capture_output=True, text=True, env=env)

        p = run()
        if p.returncode == 0 or "gate" not in p.stdout + p.stderr:
            bad.append("no gate summary must stop the commit")
        g = r / "_logs" / "build-gate"
        g.mkdir()
        time.sleep(1.1)
        (g / "20260101-000000-build-gate.txt").write_text("RESULT PASS fail_signals=0\n", encoding="utf-8")
        p = run("--dry-run")
        if p.returncode != 0 or "leave out 1 modified .import" not in p.stdout:
            bad.append("a passing gate: dry run counts the churn sidecar left out: " + p.stdout + p.stderr)
        p = run()
        if p.returncode != 0 or "committed" not in p.stdout or "Did not work" in p.stdout:
            bad.append("a passing gate commits: " + p.stdout + p.stderr)
        files = git(r, "show", "--name-only", "--format=", "HEAD").stdout.split()
        if sorted(files) != ["a.txt", "new.png.import"]:
            bad.append(f"commit holds the edit and the new sidecar only, got {files}")
        (r / "a.txt").write_text("3", encoding="utf-8")
        p = run()
        if p.returncode == 0:
            bad.append("a file changed after the gate must stop the commit")
        p = run("--gate-skipped", "no Godot here")
        if p.returncode != 0 or "Did not work: gate not run (no Godot here)" not in p.stdout:
            bad.append("--gate-skipped commits and prints the Did not work line: " + p.stdout + p.stderr)
    for b in bad:
        print("FAIL " + b)
    return agent_log.emit_result("FAIL" if bad else "PASS", None, cmd="selftest", problems=len(bad))


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
