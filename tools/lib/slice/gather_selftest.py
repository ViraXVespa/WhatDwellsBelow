"""`slice.py open` gather cases with a stub grok (library for open_slice.py --selftest; no model is ever called).

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
if "-m" in a:
    mode = os.environ.get("STUB_MODE", "ok")
    def adj(*w):
        subprocess.run([sys.executable, "tools/slice.py", "adjust", *w, "--root", "."], capture_output=True)
    if mode == "compact":
        adj("report", "--text", "partial before compact")
        print(json.dumps({"type": "system", "subtype": "compact_boundary"}))
        raise SystemExit(0)
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

    def go(mode: str, *a: str) -> tuple[int, str, list[dict]]:
        logf = td / f"log-{len(list(td.glob('log-*')))}.jsonl"
        env = dict(os.environ, WDB_GROK=str(td / "stub.py"), STUB_LOG=str(logf), STUB_WTS=str(td / "wts"), STUB_MODE=mode,
                   STUB_TOOLS=str(real), STUB_FILES=str(td / "files.txt"), WDB_OPEN_NO_PREPARE="1")  # no Godot download
        env.pop("WDB_ROLE", None)
        p = subprocess.run([*script, "--root", str(root), *a], capture_output=True, text=True, encoding="utf-8", errors="replace", env=env)
        calls = [json.loads(x) for x in logf.read_text(encoding="utf-8").splitlines()] if logf.is_file() else []
        return p.returncode, p.stdout + p.stderr, calls

    def main_call(calls: list[dict]) -> dict:
        return next((c for c in calls if "-s" in c["argv"]), {})

    code, out, calls = go("ok", "demo.part")
    agent = next((c for c in calls if "-m" in c["argv"]), {})
    sess = main_call(calls)
    wt = Path(sess.get("cwd", td / "none"))
    if code or not sess or not agent:
        bad.append(f"gather ok: the agent then the main session must run ({code}): {out[-300:]}")
    else:
        aa, ma = agent["argv"], sess["argv"]
        for need in ("grok-build-0.1", "--always-approve", "--output-format", "streaming-messages-json", "--include-partial-messages"):
            if need not in aa:
                bad.append(f"gather agent argv must carry {need}")
        if "--max-turns" not in aa or aa[aa.index("--max-turns") + 1] != str(gather_agent.TURN_CAP):
            bad.append("gather turn cap must stay a non-budget backstop, above a real gather")
        if agent["role"] != "gather" or sess["role"]:
            bad.append("WDB_ROLE=gather on the agent only")
        if any(b in ma for b in ("--fork-session", "--max-turns", "--prompt-file", "-p")):
            bad.append("the main session argv must stay interactive")
        sid = ma[ma.index("-s") + 1]
        sf = wt / "_logs" / "slice-state.json"
        st = json.loads(sf.read_text(encoding="utf-8")) if sf.is_file() else {}
        if st.get("session") != sid:
            bad.append(f"start must record the pre-assigned main session id ({st.get('session')} != {sid})")
        ctx = (wt / "session-context.md").read_text(encoding="utf-8") if (wt / "session-context.md").is_file() else ""
        if "the stub says so" not in ctx or "session-context.md" not in ma[-1] or "stub judgment" not in out:
            bad.append("the packet must hold the agent's index and the first message must name session-context.md; open prints the report")
        if "gather: agent" not in ctx or "area: demo.part" not in ctx or "door: demo" not in ctx:
            bad.append("the packet identity says `gather: agent` after the agent adjusted it, with door and area from the job")
        prompt = (wt / "_logs" / "gather" / "prompt.md").read_text(encoding="utf-8")
        if "Slice: area=demo.part door=demo job=demo.part\n" not in prompt or "task" in prompt.split("Slice:", 1)[1].split("\n", 1)[0] \
                or "docs.py task show" in prompt or re.search(r"\{\w+\}", prompt) or f"{gather_agent.py()} tools/slice.py adjust" not in prompt \
                or "The User's request" in prompt or "context is compacted" not in prompt or str(gather_agent.TURN_CAP) in prompt:
            bad.append("gather prompt: one consistent slice line, no task line without a task, this interpreter's name, no request block without one")
        if out.count("stub thought") != 1 or "gather: wdb__lookup action=names path=scripts/demo.gd" not in out:
            bad.append("open must print the gather thought once, as it streams, and the tool call")
    code, out, calls = go("halt", "demo.part")
    if code == 0 or "HALT: stub halt" not in out or main_call(calls):
        bad.append(f"a halt must refuse the launch: {out[-200:]}")
    code, out, calls = go("ok", "demo.part", "--review")
    if code or main_call(calls) or "--launch" not in out:
        bad.append("--review stops after the agent and prints the --launch command")
    else:
        code2, out2, calls2 = go("ok", "--launch", str(Path(next(c for c in calls if "-m" in c["argv"])["cwd"])))
        if code2 or not main_call(calls2):
            bad.append(f"--launch WT starts the main session after a review: {out2[-200:]}")
    code, out, calls = go("bad", "demo.part")
    if code == 0 or "INDEX FAILED" not in out or "nothere" not in out or main_call(calls):
        bad.append(f"an index that fails expand --check must not launch, and must name the bad item: {out[-300:]}")
    if gather_agent._stop_kind('{"type":"system","subtype":"compact_boundary"}') != "compact" \
            or gather_agent._stop_kind('{"type":"user","message":{"content":"mentions compact_boundary"}}') != "":
        bad.append("only a compact_boundary event stops the run, not the same words inside a tool result")
    code, out, calls = go("compact", "demo.part")
    if code == 0 or "context compacted" not in out or "Not launched" not in out or main_call(calls):
        bad.append(f"a context compact halts and does not launch: {out[-300:]}")
    code, out, calls = go("crash", "demo.part")
    crashed = next((c for c in calls if "-m" in c["argv"]), {})
    ctx = Path(crashed.get("cwd", td / "none")) / "session-context.md"
    if code == 0 or "GATHER STOPPED" not in out or "Not launched" not in out or main_call(calls) or ctx.is_file():
        bad.append(f"a crash halts and does not launch: {out[-300:]}")
    code, out, calls = go("ok", "demo.part", "--no-gather")
    sess = next((c for c in calls if c["argv"][:1] != ["worktree"] and "-m" not in c["argv"]), {})
    prompt = (sess.get("argv") or [""])[-1]
    wt = Path(sess.get("cwd", td / "none"))
    if code or any("-m" in c["argv"] for c in calls) or not sess or "-s" in sess.get("argv", []) \
            or "slice.py start --job demo.part" not in prompt or "separate gather" in prompt \
            or (wt / "session-plan.md").exists() or (wt / "session-context.md").exists():
        bad.append(f"--no-gather turns gathering off and launches the pre-gather command ({code}): {prompt[:180]!r} {out[-300:]}")
    code, out, calls = go("ok", "demo.part", "--no-gather", "--review")
    if code == 0 or "turns gathering off" not in out:
        bad.append(f"--no-gather cannot combine with --review: {out[-200:]}")
    code, out, calls = go("ok", "demo.part", "--prompt", "Fix the stub keyboard.")
    agent = next((c for c in calls if "-m" in c["argv"]), {})
    req = Path(agent.get("cwd", td / "none")) / "_logs" / "gather" / "prompt.md"
    if code or not req.is_file() or "The User's request:\n\nFix the stub keyboard." not in req.read_text(encoding="utf-8"):
        bad.append("the User's request (open's prompt) reaches the gather agent's prompt")
    bad += seed_only(go, main_call, td, root)
    return bad

def seed_only(go, main_call, td: Path, root: Path) -> list[str]:
    """--seed-only stops after the seed; a hand gather then `--launch WT --review` writes the packet; --in reuses a worktree."""
    bad: list[str] = []
    code, out, calls = go("ok", "demo.part", "--seed-only")
    wt = Path(next((ln.split(" ", 1)[1] for ln in out.splitlines() if ln.startswith("worktree ")), str(td / "none")))
    if code or any("-m" in c["argv"] for c in calls) or main_call(calls) or "seed-only" not in out \
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
    sess = next((c for c in calls if c["argv"][:1] != ["worktree"] and "-m" not in c["argv"]), {})
    if code or any(c["argv"][:2] == ["worktree", "create"] for c in calls) or not sess \
            or "slice.py start" not in (sess.get("argv") or [""])[-1] \
            or (Path(made[0]) / "session-context.md").exists():
        bad.append(f"--in WT --no-gather: no create, pre-gather command, no packet: {out[-300:]}")
    return bad

