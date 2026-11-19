"""`slice.py open` gather cases with a stub grok (library for open_slice.py --selftest; no Ollama is ever called).

The stub ($WDB_GROK, a .py) creates the worktree (git worktree add + a copy of the tracked tools/), plays the gather
agent per $STUB_MODE (ok, halt, bad, crash; crash exits before the report, so open must halt and not launch) through the real `slice.py adjust`, and records every call in $STUB_LOG.
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
if a[:1] == ["run"]:
    mode = os.environ.get("STUB_MODE", "ok")
    def adj(*w):
        subprocess.run([sys.executable, "tools/slice.py", "adjust", *w, "--root", "."], capture_output=True)
    if mode == "compact":
        print(json.dumps({"type": "system", "subtype": "compact_boundary"}), flush=True)
        adj("add-names", "scripts/demo.gd", "--cand", "--when", "after compact")
        adj("report", "--text", "continued after compact")
        print(json.dumps({"num_turns": 4, "usage": {"input_tokens": 10, "output_tokens": 2}, "total_cost_usd": 0, "sessionId": "gather-1"}))
        raise SystemExit(0)
    if mode == "noreport":
        flag = Path("_logs/gather/stub-saw.txt")
        if not flag.is_file():
            flag.parent.mkdir(parents=True, exist_ok=True)
            flag.write_text("1", encoding="utf-8")
            raise SystemExit(0)
        adj("add-func", "scripts/demo.gd", "alpha", "--why", "edit")
        adj("report", "--text", "resumed after an early exit")
        raise SystemExit(0)
    if mode == "linger":
        import time
        adj("add-func", "scripts/demo.gd", "alpha", "--why", "edit")
        adj("add-names", "scripts/demo.gd", "--cand", "--when", "the change reaches it (named in the job doc)")
        adj("report", "--text", "lingered then stopped")
        time.sleep(30)
        raise SystemExit(9)
    if mode == "crash":
        adj("add-func", "scripts/demo.gd", "nothere")
        raise SystemExit(3)
    if mode == "bad":
        adj("add-func", "scripts/demo.gd", "nothere")
    if mode == "ok":
        print(json.dumps({"type": "content_block_delta", "delta": {"type": "thinking_delta", "thinking": "stub thought"}}), flush=True)
        print(json.dumps({"type": "content_block_stop"}), flush=True)
        print(json.dumps({"type": "assistant", "message": {"content": [
            {"type": "thinking", "thinking": "stub thought"},
            {"type": "tool_use", "name": "wdb__lookup", "input": {"action": "names", "path": "scripts/demo.gd"}}
        ]}}), flush=True)
    adj("add-names", "scripts/demo.gd", "--cand", "--when", "the stub says so")
    adj("report", "--text", "stub judgment", *(["--halt", "stub halt"] if mode == "halt" else []))
    print(json.dumps({"num_turns": 3, "usage": {"input_tokens": 10, "output_tokens": 2}, "total_cost_usd": 0, "sessionId": "gather-1"}))
'''

def run(script: list[str], td: Path) -> list[str]:
    import gather_agent
    import repo_lib

    bad: list[str] = []
    fed: list[str] = []
    feed = gather_agent.StreamFeed(write=fed.append)
    feed('{"type":"content_block_delta","delta":{"type":"thinking_delta","thinking":"hi"}}')
    feed('{"type":"assistant","message":{"content":[{"type":"thinking","thinking":"hi"},{"type":"tool_use","name":"wdb__lookup","input":{"action":"names","path":"scripts/demo.gd"}}]}}')
    shown = "".join(fed)
    if shown.count("hi") != 1 or "gather: wdb__lookup action=names path=scripts/demo.gd" not in shown:
        bad.append(f"a streamed thought is printed once, then the tool line: {shown!r}")
    fed2: list[str] = []
    feed2 = gather_agent.StreamFeed(write=fed2.append)
    feed2('{"type":"content_block_start","content_block":{"type":"tool_use","name":"wdb__lookup"}}')
    feed2('{"type":"content_block_delta","delta":{"type":"input_json_delta","partial_json":"{\\"action\\":\\"names\\",\\"path\\":\\"scripts/demo.gd\\"}"}}')
    feed2('{"type":"assistant","message":{"content":[{"type":"tool_use","name":"wdb__lookup","input":{"action":"names","path":"scripts/demo.gd"}}]}}')
    if "".join(fed2).count("gather: wdb__lookup action=names path=scripts/demo.gd") != 1:
        bad.append(f"a tool call streamed as input_json_delta is not printed again: {''.join(fed2)!r}")
    fed3: list[str] = []
    feed3 = gather_agent.StreamFeed(write=fed3.append)
    feed3('{"type":"text","part":{"text":"oc thought"}}')
    feed3('{"type":"tool_use","part":{"tool":"bash","state":{"status":"completed","input":{"command":"python tools/slice.py expand --check"}}}}')
    shown3 = "".join(fed3)
    if shown3.count("oc thought") != 1 or "gather: bash command=python tools/slice.py expand --check" not in shown3:
        bad.append(f"an opencode text and tool_use line must print: {shown3!r}")
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
    (td / "files.txt").write_text("\n".join(f for f in files.splitlines() if f.endswith((".py", ".json", ".md", ".txt", ".yaml"))), encoding="utf-8")
    (td / "stub.py").write_text(STUB, encoding="utf-8")
    (td / "wts").mkdir()

    def go(mode: str, *a: str, pick: str = "skip") -> tuple[int, str, list[dict]]:
        logf = td / f"log-{len(list(td.glob('log-*')))}.jsonl"
        env = dict(os.environ, WDB_GROK=str(td / "stub.py"), WDB_OPENCODE=str(td / "stub.py"), STUB_LOG=str(logf), STUB_WTS=str(td / "wts"), STUB_MODE=mode,
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

