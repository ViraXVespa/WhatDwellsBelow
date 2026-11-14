"""The `slice.py open` gather step (library; import only): run start for the main session, seed, cheap agent, packet.

Order in a new worktree WT (open_slice.py calls these):
    1. start(): `slice.py start <flags>` in WT with GROK_SESSION_ID = the main session's pre-assigned id (`grok -s SID`),
       so slice state records the main session and session-plan.md gets its mechanical seed.
    2. agent(): the cheap model (MODEL) edits only the index, through `slice.py adjust`, under WDB_ROLE=gather
       (wdb-pretool.py denies edits, other shell, and other MCP tools). Its prompt is tools/data/gather/gather-prompt.md.
       A crash, timeout or bad exit falls back to the seed with a loud WARN (the seed is never lost: adjust logs each op).
    3. finish(): after a crash, `plan --refresh --clean` restores the seed. Then open's own `slice.py expand --check`
       (it does not trust the agent): a failure stops before launch; then `expand --out session-context.md` writes the packet.
A `_logs/gather/halt` file (adjust report --halt) also makes open refuse to launch. The first message for the main session is
tools/data/gather/build-first.md. No model call happens here outside agent(); tests pass a stub as `grok`.
"""
from __future__ import annotations

import json
import os
import shlex
import subprocess
import sys
from pathlib import Path

MODEL = "grok-build-0.1"
TIMEOUT = 300
MAX_TURNS = 12
DATA = Path(__file__).resolve().parents[2] / "data" / "gather"
GATHER = "_logs/gather"

def start_cmd(area: str, door: str, job: str, tid: str, t: dict | None) -> list[str]:
    """The `slice.py start` argv the first message used to name (task handoff, task, or door/job)."""
    import handoff_lib
    import task_lib

    t = t or {}
    if t.get("from") and t.get("door"):
        words = shlex.split(handoff_lib.from_task_cmd(t["door"], tid, t.get("job", "")))
    else:
        words = ["python", "tools/slice.py", "start", task_lib.start_flag(area), area] + (["--task", tid] if tid else [])
    return [sys.executable, *words[1:]]

def grok_exe() -> str | None:
    """grok on PATH, or $WDB_GROK (selftests: a stub; a .py runs under this Python)."""
    import shutil

    return os.environ.get("WDB_GROK") or shutil.which("grok")

def runnable(argv: list[str]) -> list[str]:
    return [sys.executable, *argv] if argv and argv[0].endswith(".py") else argv

def _run(argv: list[str], wt: Path, env: dict | None = None, timeout: int | None = None) -> tuple[int, str]:
    try:
        p = subprocess.run(runnable(argv), cwd=wt, capture_output=True, text=True, encoding="utf-8", errors="replace",
                           env=env, timeout=timeout)
    except subprocess.TimeoutExpired as exc:
        return 124, f"timeout after {timeout}s " + str(exc.stdout or "")[-400:]
    except OSError as exc:
        return 127, f"cannot run {argv[0]}: {exc}"
    return p.returncode, (p.stdout or "") + (p.stderr or "")

def meta(wt: Path) -> dict:
    f = wt / GATHER / "open.json"
    try:
        return json.loads(f.read_text(encoding="utf-8")) if f.is_file() else {}
    except (OSError, json.JSONDecodeError):
        return {}

def set_meta(wt: Path, **kv: object) -> None:
    (wt / GATHER).mkdir(parents=True, exist_ok=True)
    (wt / GATHER / "open.json").write_text(json.dumps({**meta(wt), **kv}, indent=1) + "\n", encoding="utf-8")

def start(wt: Path, argv: list[str], sid: str, tid: str = "", extra: str = "") -> tuple[int, str]:
    """Run start for the main session and record what --launch needs in _logs/gather/open.json."""
    set_meta(wt, sid=sid, start=argv, task=tid, extra=extra, agent_ok=False)
    code, out = _run([*argv, "--root", str(wt)], wt, env=dict(os.environ, GROK_SESSION_ID=sid))
    (wt / GATHER / "start.txt").write_text(out, encoding="utf-8")
    return code, out

def agent_argv(grok: str, wt: Path, prompt_file: Path) -> list[str]:
    return [grok, "-m", MODEL, "--prompt-file", str(prompt_file), "--cwd", str(wt), "--trust", "--always-approve",
            "--max-turns", str(MAX_TURNS), "--effort", "low", "--output-format", "json", "--no-subagents",
            "--disable-web-search", "--no-memory"]

def render(template: str, **kv: str) -> str:
    text = (DATA / template).read_text(encoding="utf-8")
    for k, v in kv.items():
        text = text.replace("{" + k + "}", v)
    return text

def usage(out: str) -> str:
    """'turns=N tokens=in/out cost=$X session=ID' from grok's JSON output (last JSON object), or ''."""
    for line in reversed(out.strip().splitlines()):
        try:
            d = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(d, dict):
            u = d.get("usage") or {}
            return (f"turns={d.get('num_turns', '?')} tokens={u.get('input_tokens', '?')}/{u.get('output_tokens', '?')} "
                    f"cost=${d.get('total_cost_usd', '?')} session={d.get('sessionId') or d.get('session_id') or '?'}")
    return ""

def agent(grok: str, wt: Path, area: str, door: str, job: str, tid: str) -> tuple[bool, str]:
    """(ok, one line). Runs the cheap model once; never raises."""
    prompt = wt / GATHER / "prompt.md"
    prompt.write_text(render("gather-prompt.md", area=area, door=door or "(none)", job=job or "(none)",
                             task=tid or "(none)", max_turns=str(MAX_TURNS)), encoding="utf-8")
    code, out = _run(agent_argv(grok, wt, prompt), wt, env=dict(os.environ, WDB_ROLE="gather"), timeout=TIMEOUT)
    (wt / GATHER / "agent.txt").write_text(out, encoding="utf-8")
    use = usage(out)
    if code != 0:
        return False, f"WARN GATHER AGENT FAILED (exit {code}{', timeout' if code == 124 else ''}): launching with the mechanical seed. {use}".rstrip()
    return True, f"gather agent: done. {use}".rstrip()

def finish(wt: Path, restore: bool) -> tuple[bool, list[str]]:
    """open's own `expand --check` (it does not trust the agent), then session-context.md. restore: the agent crashed,
    so drop its partial adjustments first (seed only). (ok, lines); not ok = do not launch."""
    def py(*a: str) -> tuple[int, str]:
        return _run([sys.executable, "tools/slice.py", *a, "--root", str(wt)], wt)

    if restore:
        py("plan", "--refresh", "--clean")
    code, out = py("expand", "--check")
    if code != 0:
        bad = [ln for ln in out.splitlines() if ln.strip() and not ln.startswith("RESULT")][:8]
        return False, ["INDEX FAILED `slice.py expand --check`; not launched:"] + bad + [
            f"Fix it in {wt} with `python tools/slice.py adjust ...` (or `plan --refresh --clean` for the seed), then: python tools/slice.py open --launch {wt}"]
    py("expand", "--out", "session-context.md")
    return True, []

def halted(wt: Path) -> str:
    f = wt / GATHER / "halt"
    return f.read_text(encoding="utf-8").strip() if f.is_file() else ""

def report(wt: Path) -> str:
    f = wt / GATHER / "report.md"
    return f.read_text(encoding="utf-8").strip() if f.is_file() else "(the gather agent wrote no report)"

def first_message(start_argv: list[str], tid: str, warn: list[str], extra: str = "") -> str:
    shown = "python " + " ".join(start_argv[1:])
    task_line = f", then the task file once (`python tools/docs.py task show {tid}`)" if tid else ""
    text = render("build-first.md", start=shown, task_line=task_line, warn="\n".join(warn)).strip()
    return text + ("\n\n" + extra.strip() if extra.strip() else "")
