"""`slice.py open` gather cases with a stub grok (library for open_slice.py --selftest; no Ollama is ever called).

The stub ($WDB_GROK, a .py) creates the worktree (git worktree add + a copy of the tracked tools/) and records every call in $STUB_LOG.
Open does not start a separate gather process.
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

STUB = r'''
import json, os, shutil, subprocess, sys
from pathlib import Path
a = sys.argv[1:]
log = {"argv": a, "cwd": os.getcwd(), "role": os.environ.get("WDB_ROLE", "")}
with open(os.environ["STUB_LOG"], "a", encoding="utf-8") as fh:
    fh.write(json.dumps(log) + "\n")
if a[:2] == ["worktree", "create"]:
    wt = Path(os.environ["STUB_WTS"]) / a[2]
    n = 0
    while wt.exists():
        n += 1
        wt = Path(os.environ["STUB_WTS"]) / f"{a[2]}-{n}"
    subprocess.run(["git", "worktree", "add", "-q", "--detach", str(wt), a[4]], check=True, capture_output=True)
    src = Path(os.environ["STUB_TOOLS"])
    for rel in Path(os.environ["STUB_FILES"]).read_text(encoding="utf-8").splitlines():
        (wt / rel).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src / rel, wt / rel)
    print(wt)
    raise SystemExit(0)
'''

def run(script: list[str], td: Path) -> list[str]:
    import repo_lib

    bad: list[str] = []
    real = Path(__file__).resolve().parents[3]
    (td / "g").mkdir()
    root = repo_lib.selftest_repo(td / "g")
    (root / "design").mkdir()
    (root / "design" / "routes.yaml").write_text(
        "version: 1\ndoors:\n  demo:\n    file: design/demo.md\n    read_when: \"x\"\n    jobs:\n      part: design/demo-part.md\n", encoding="utf-8")
    (root / "design" / "demo.md").write_text("# Demo\n\nCode: `scripts/demo.gd`\n", encoding="utf-8")
    (root / "design" / "demo-part.md").write_text("# Part\n\nJob sentence.\n", encoding="utf-8")
    (root / "design" / "code-map.md").write_text("# Live code map\n\n| System | Live files |\n|--------|------------|\n| Demo | `scripts/demo.gd` |\n", encoding="utf-8")
    (root / "scripts" / "demo.gd").write_text("extends Node\n\nfunc alpha() -> void:\n\tpass\n", encoding="utf-8")
    (root / ".gitignore").write_text("_logs/\nsession-plan.md\n/session-context.md\n/tools/\n", encoding="utf-8")
    repo_lib.git_test(root, "add", "-A")
    repo_lib.git_test(root, "commit", "-qm", "seed")
    repo_lib.git_test(root, "branch", "grok-build-w9")
    files = subprocess.run(["git", "ls-files", "tools"], cwd=real, capture_output=True, text=True).stdout
    (td / "files.txt").write_text("\n".join(
        f for f in files.splitlines()
        if f.endswith((".py", ".json", ".md", ".txt", ".yaml")) and (real / f).is_file()), encoding="utf-8")
    (td / "stub.py").write_text(STUB, encoding="utf-8")
    (td / "wts").mkdir()

    def go(mode: str, *a: str, pick: str = "skip") -> tuple[int, str, list[dict]]:
        logf = td / f"log-{len(list(td.glob('log-*')))}.jsonl"
        env = dict(os.environ, WDB_GROK=str(td / "stub.py"), STUB_LOG=str(logf), STUB_WTS=str(td / "wts"), STUB_MODE=mode,
                   STUB_TOOLS=str(real), STUB_FILES=str(td / "files.txt"), WDB_OPEN_NO_PREPARE="1", WDB_GATHER_PICK=pick)  # no Godot, no Ollama
        env.pop("WDB_ROLE", None)
        p = subprocess.run([*script, "--root", str(root), *a], capture_output=True, text=True, encoding="utf-8", errors="replace", env=env)
        calls = [json.loads(x) for x in logf.read_text(encoding="utf-8").splitlines()] if logf.is_file() else []
        return p.returncode, p.stdout + p.stderr, calls

    def main_call(calls: list[dict]) -> dict:
        return next((c for c in calls if "-s" in c["argv"]), {})

    code, out, calls = go("ok", "demo.part")
    sess = main_call(calls)
    wt = Path(sess.get("cwd", td / "none"))
    if code or not sess or any(c["argv"][:1] == ["run"] for c in calls):
        bad.append(f"open launches the main session and does not start a gather agent ({code}): {out[-300:]}")
    else:
        ma = sess["argv"]
        if sess["role"]:
            bad.append("the main session must not carry WDB_ROLE")
        if any(b in ma for b in ("--fork-session", "--max-turns", "--prompt-file", "-p")):
            bad.append("the main session argv must stay interactive")
        sid = ma[ma.index("-s") + 1]
        sf = wt / "_logs" / "slice-state.json"
        st = json.loads(sf.read_text(encoding="utf-8")) if sf.is_file() else {}
        if st.get("session") != sid:
            bad.append(f"start must record the pre-assigned main session id ({st.get('session')} != {sid})")
        ctx = (wt / "session-context.md").read_text(encoding="utf-8") if (wt / "session-context.md").is_file() else ""
        if "only the mechanical seed" not in ma[-1] or "door: demo" not in ctx or "gather: agent" in ctx:
            bad.append("the packet is the mechanical seed and the first message tells the main session to close it")
    code, out, calls = go("ok", "demo.part", "--review")
    wt_line = next((ln.split(" ", 1)[1].strip() for ln in out.splitlines() if ln.startswith("worktree ")), "")
    if code or main_call(calls) or "--launch" not in out or not wt_line:
        bad.append(f"--review stops after the seed packet and prints the --launch command: {out[-200:]}")
    else:
        code2, out2, calls2 = go("ok", "--launch", wt_line)
        if code2 or not main_call(calls2):
            bad.append(f"--launch WT starts the main session after a review: {out2[-200:]}")
    code, out, calls = go("ok", "demo.part", "--no-gather")
    sess = next((c for c in calls if c["argv"][:1] not in (["worktree"], ["run"])), {})
    prompt = (sess.get("argv") or [""])[-1]
    wt = Path(sess.get("cwd", td / "none"))
    if code or any(c["argv"][:1] == ["run"] for c in calls) or not sess or "-s" in sess.get("argv", []) \
            or "slice.py start --job demo.part" not in prompt or "separate gather" in prompt \
            or (wt / "session-plan.md").exists() or (wt / "session-context.md").exists():
        bad.append(f"--no-gather turns gathering off and launches the pre-gather command ({code}): {prompt[:180]!r} {out[-300:]}")
    code, out, calls = go("ok", "demo.part", "--no-gather", "--review")
    if code == 0 or "turns gathering off" not in out:
        bad.append(f"--no-gather cannot combine with --review: {out[-200:]}")
    code, out, calls = go("ok", "title", "--review")
    launched = [c for c in calls if "--cwd" in c.get("argv", []) or "--trust" in c.get("argv", [])]
    if code == 0 or launched or "does not start the main session" not in out:
        bad.append(f"--review on a name that is not a door must not start grok ({code}): {out[-300:]}")
    code, out, calls = go("ok", "demo.part", "--prompt", "Fix the stub keyboard.")
    sess = main_call(calls)
    prompt = (sess.get("argv") or [""])[-1]
    if code or "Fix the stub keyboard." not in prompt or "only the mechanical seed" not in prompt:
        bad.append("the User's request is appended to the main session's first message")
    code, out, calls = go("ok", "demo.part", "--review", pick="mark")
    wt_line = next((ln.split(" ", 1)[1].strip() for ln in out.splitlines() if ln.startswith("worktree ")), "")
    wt = Path(wt_line) if wt_line else td / "none"
    ctx = (wt / "session-context.md").read_text(encoding="utf-8") if (wt / "session-context.md").is_file() else ""
    plan = (wt / "session-plan.md").read_text(encoding="utf-8") if (wt / "session-plan.md").is_file() else ""
    if code or main_call(calls) or "gather: agent" not in plan or "scripts/demo.gd:alpha" not in ctx or "chain marked" not in out:
        bad.append(f"a stub chain inlines the func and does not launch ({code}): {out[-400:]}")
    else:
        code2, out2, calls2 = go("ok", "--launch", str(wt), pick="skip")
        sess = main_call(calls2)
        prompt = (sess.get("argv") or [""])[-1]
        if code2 or not sess or "already refined the packet" not in prompt or "only the mechanical seed" in prompt:
            bad.append(f"--launch after a stub chain uses the refined first message: {prompt[:220]!r} {out2[-200:]}")
    bad += seed_only(go, main_call, td, root)
    return bad

def seed_only(go, main_call, td: Path, root: Path) -> list[str]:
    """--seed-only stops after the seed; a hand gather then `--launch WT --review` writes the packet; --in reuses a worktree."""
    bad: list[str] = []
    code, out, calls = go("ok", "demo.part", "--seed-only")
    wt = Path(next((ln.split(" ", 1)[1] for ln in out.splitlines() if ln.startswith("worktree ")), str(td / "none")))
    if code or any(c["argv"][:1] == ["run"] for c in calls) or main_call(calls) or "seed-only" not in out \
            or not (wt / "session-plan.md").is_file() or (wt / "session-context.md").exists():
        bad.append(f"--seed-only: start and seed only (no agent, packet or launch): {out[-300:]}")
        return bad
    subprocess.run([sys.executable, "tools/slice.py", "adjust", "add-names", "scripts/demo.gd", "--cand", "--when", "by hand",
                    "--root", str(wt)], cwd=wt, capture_output=True, env=dict(os.environ, WDB_ROLE="gather"))
    code, out, calls = go("ok", "--launch", str(wt), "--review")
    ctx = (wt / "session-context.md").read_text(encoding="utf-8") if (wt / "session-context.md").is_file() else ""
    meta = json.loads((wt / "_logs" / "gather" / "open.json").read_text(encoding="utf-8"))
    if code or main_call(calls) or "by hand" not in ctx or "gather: agent" not in ctx or not meta.get("agent_ok"):
        bad.append(f"--launch WT --review after a hand gather: packet + report, agent_ok, no launch: {out[-300:]}")
    env = dict(os.environ, STUB_LOG=str(td / "in.jsonl"), STUB_WTS=str(td / "wts"), STUB_TOOLS=str(Path(__file__).resolve().parents[3]),
               STUB_FILES=str(td / "files.txt"))
    made = subprocess.run([sys.executable, str(td / "stub.py"), "worktree", "create", "wdb-in", "--ref", "grok-build-w9"],
                          cwd=root, capture_output=True, text=True, env=env).stdout.strip().splitlines()[-1:]
    if not made:
        return bad + ["--in: the stub could not make a worktree to reuse"]
    code, out, calls = go("ok", "demo.part", "--in", made[0], "--no-gather")
    sess = next((c for c in calls if c["argv"][:1] not in (["worktree"], ["run"])), {})
    if code or any(c["argv"][:2] == ["worktree", "create"] for c in calls) or not sess \
            or "slice.py start" not in (sess.get("argv") or [""])[-1] \
            or (Path(made[0]) / "session-context.md").exists():
        bad.append(f"--in WT --no-gather: no create, pre-gather command, no packet: {out[-300:]}")
    return bad

