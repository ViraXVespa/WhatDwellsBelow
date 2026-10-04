"""Selftest for start_build_slice.py (`python tools/start_build_slice.py --selftest`), kept apart to keep that tool small."""
from __future__ import annotations

import os
import subprocess
import sys
import tempfile
from pathlib import Path

import agent_log
import retry_lib


def selftest(script: Path) -> int:
    """No week branch fails with no FORK line; a week branch gives FORK; --session adds -r/--fork-session and is saved."""
    me = str(script)
    bad: list[str] = []

    def run(root: Path, *a: str) -> tuple[int, str]:
        p = subprocess.run([sys.executable, me, "--root", str(root), "--area", "demo", *a], capture_output=True, text=True, encoding="utf-8", errors="replace", env={**os.environ, "GROK_SESSION_ID": ""})
        return p.returncode, p.stdout + p.stderr

    with tempfile.TemporaryDirectory() as td:
        root = Path(td)
        for a in (("init", "-q"), ("-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "--allow-empty", "-m", "a")):
            subprocess.run(["git", *a], cwd=root, check=True, capture_output=True)
        (root / "project.godot").write_text("")
        (root / "scripts" / "data").mkdir(parents=True)
        (root / "scripts" / "data" / "version.json").write_text('{"epoch": 0, "series": 9, "patch": 0}\n')
        code, out = run(root, "--dry-run")
        if code == 0 or "FORK grok" in out or "NO WEEK BRANCH" not in out or "week_start.py" not in out:
            bad.append(f"no week branch: code={code} must fail loudly without a FORK line")
        code, out = run(root, "--ref", "HEAD", "--dry-run")
        if code != 0 or "FORK grok --worktree=wdb-demo-" not in out or "--ref HEAD" not in out:
            bad.append("--ref HEAD must print a FORK line")
        subprocess.run(["git", "branch", "grok-build-w9"], cwd=root, check=True, capture_output=True)
        code, out = run(root, "--dry-run")
        if code != 0 or "--ref grok-build-w9" not in out or "main" in out.split("FORK", 1)[1].split("\n", 1)[0] or "WARN no gather session" not in out:
            bad.append("week branch must give FORK --ref grok-build-w9 and the no-session WARN")
        code, out = run(root, "--session", "sess-1")
        if code != 0 or "-r sess-1 --fork-session" not in out:
            bad.append("--session must add -r ID --fork-session")
        saved = retry_lib.state_path(root)
        if saved is None or not saved.is_file() or "sess-1" not in saved.read_text(encoding="utf-8"):
            bad.append("gather session was not saved")
        code, out = run(root, "--session", "sess-2", "--dry-run")
        if saved and saved.is_file() and "sess-2" in saved.read_text(encoding="utf-8"):
            bad.append("--dry-run saved a session")
    for b in bad:
        print("FAIL " + b)
    return agent_log.emit_result("FAIL" if bad else "PASS", None, cmd="selftest", problems=len(bad))
