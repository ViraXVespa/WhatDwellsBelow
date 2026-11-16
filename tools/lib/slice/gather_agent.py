"""The `slice.py open` gather step (library; import only): run start for the main session, seed, cheap agent, packet.

Order in a new worktree WT (open_slice.py calls these):
    1. start(): `slice.py start <flags>` in WT with GROK_SESSION_ID = the main session's pre-assigned id (`grok -s SID`),
       so slice state records the main session and session-plan.md gets its mechanical seed.
    2. agent(): the cheap model (MODEL) edits only the index, through `slice.py adjust`, under WDB_ROLE=gather
       (wdb-pretool.py denies edits, other shell, and other MCP tools). Its prompt is tools/data/gather/gather-prompt.md.
       A crash, timeout, turn cap or context compact writes `_logs/gather/halt` and does not launch (the seed stays
       on disk; adjust logs each op). Thoughts and tool calls print as each stream line arrives.
       A finished report with exit 0 continues.
    3. finish(): `plan --refresh --clean` restores the seed only when a warn is set and there is no halt file.
       Then open's own `slice.py expand --check`
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
import threading
from pathlib import Path

MODEL = "grok-build-0.1"
TIMEOUT = 3600  # hung-process guard. Auto-compact is the working stop; a finished gather is minutes.
TURN_CAP = 10000  # not a working budget (one model round; parallel tool calls count once). Compact stops the run first.
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
            "--max-turns", str(TURN_CAP), "--output-format", "streaming-messages-json", "--include-partial-messages"]

def py() -> str:
    """The interpreter name to print in commands: python on Windows, python3 where only that exists (the Linux box)."""
    name = Path(sys.executable).stem.lower()
    return "python3" if name.startswith("python3") else "python"

def render(template: str, **kv: str) -> str:
    text = (DATA / template).read_text(encoding="utf-8")
    for k, v in {"py": py(), **kv}.items():
        text = text.replace("{" + k + "}", v)
    return text

def ident(area: str, door: str, job: str) -> tuple[str, str, str]:
    """(area, door, job) as the seed, the start card and the prompt show them: door from a door.job, area defaults to the job."""
    door = door or (job.split(".", 1)[0] if "." in job else "")
    return area or job or door, door, job

def slice_line(area: str, door: str, job: str, tid: str) -> str:
    area, door, job = ident(area, door, job)
    return " ".join(f"{k}={v}" for k, v in (("area", area), ("door", door), ("job", job), ("task", tid)) if v)

def _json_line(line: str) -> dict | None:
    s = line.strip()
    if not s.startswith("{"):
        return None
    try:
        d = json.loads(s)
    except json.JSONDecodeError:
        return None
    return d if isinstance(d, dict) else None

def _stop_kind(line: str) -> str:
    """'compact' or 'turns' when this stream line is that stop, else ''."""
    d = _json_line(line)
    if not d:
        return ""
    subtype, typ = str(d.get("subtype") or ""), str(d.get("type") or "")
    if subtype == "compact_boundary" or typ == "compact_boundary" or typ.startswith("auto_compact"):
        return "compact"
    if typ == "max_turns_reached" or subtype == "error_max_turns":
        return "turns"
    reason = str(d.get("stop_reason") or d.get("stopReason") or "")
    if reason in ("max_turns", "max_turn_requests"):
        return "turns"
    return ""

def live(text: str) -> None:
    """Print gather progress now. Open captures nothing until the process exits, so this is the live view."""
    if not text:
        return
    try:
        sys.stdout.write(text)
        sys.stdout.flush()
    except (OSError, UnicodeError):
        return

class StreamFeed:
    """Print thoughts as deltas arrive, then one line per tool call. A later copy of the same thought or tool is skipped."""

    def __init__(self, write=None) -> None:
        self._write = write or live
        self._thinking = False
        self._streamed = False
        self._pending: dict | None = None
        self._said: set[str] = set()

    def __call__(self, line: str) -> None:
        d = _json_line(line)
        if not d:
            return
        typ = str(d.get("type") or "")
        if typ == "message_start":
            self._said.clear()
            self._streamed = False
            self._pending = None
        elif typ == "content_block_start":
            block = d.get("content_block")
            self._pending = block if isinstance(block, dict) and str(block.get("type") or "") == "tool_use" else None
        elif typ == "content_block_delta":
            self._delta(d.get("delta"))
        elif typ in ("content_block_stop", "message_stop") and self._thinking:
            self._write("\n")
            self._thinking = False
        elif typ == "thought":
            if not self._streamed:
                self._paragraph(str(d.get("data") or ""))
        elif typ == "tool_call":
            raw = d.get("rawInput")
            self._say_tool({"name": d.get("toolName") or d.get("title") or "tool", "input": raw if isinstance(raw, dict) else {}})
        elif typ == "assistant":
            self._assistant(d)
        elif typ == "user":
            self._user(d)
        elif typ == "error":
            msg = str(d.get("message") or "").strip().splitlines()
            if msg:
                self._write("gather: " + msg[0][:160] + "\n")

    def _paragraph(self, text: str) -> None:
        text = text.strip()
        if text:
            self._close_thought()
            self._write("gather: " + text + "\n")
            self._streamed = True

    def _close_thought(self) -> None:
        if self._thinking:
            self._write("\n")
            self._thinking = False

    def _delta(self, delta: object) -> None:
        if not isinstance(delta, dict):
            return
        kind = str(delta.get("type") or "")
        if kind in ("thinking_delta", "reasoning_delta", "thinking"):
            text = str(delta.get("thinking") or delta.get("reasoning") or delta.get("text") or "")
            if not text:
                return
            if not self._thinking:
                self._write("gather: ")
            self._thinking = True
            self._streamed = True
            self._write(text)
            return
        if kind != "input_json_delta" or not isinstance(self._pending, dict):
            return
        raw = str(delta.get("partial_json") or "")
        try:
            inp = json.loads(raw) if raw.strip().startswith("{") else None
        except json.JSONDecodeError:
            return
        if isinstance(inp, dict):
            self._say_tool({**self._pending, "input": inp})
            self._pending = None

    def _say_tool(self, block: dict) -> None:
        line = "gather: " + _tool_brief(block)
        if line in self._said:
            return
        self._said.add(line)
        self._close_thought()
        self._write(line + "\n")

    def _assistant(self, d: dict) -> None:
        msg = d.get("message") if isinstance(d.get("message"), dict) else {}
        content = msg.get("content") if isinstance(msg, dict) else None
        self._close_thought()
        if isinstance(content, list):
            for block in content:
                if not isinstance(block, dict):
                    continue
                kind = str(block.get("type") or "")
                if kind in ("thinking", "reasoning"):
                    if not self._streamed:
                        self._paragraph(str(block.get("thinking") or block.get("text") or ""))
                elif kind == "tool_use":
                    self._say_tool(block)
                elif kind == "text":
                    self._paragraph(str(block.get("text") or ""))
        self._streamed = False
        self._pending = None
        self._said.clear()

    def _user(self, d: dict) -> None:
        msg = d.get("message") if isinstance(d.get("message"), dict) else {}
        content = msg.get("content") if isinstance(msg, dict) else None
        if not isinstance(content, list):
            return
        for block in content:
            if not isinstance(block, dict) or block.get("type") != "tool_result" or not block.get("is_error"):
                continue
            head = str(block.get("content") or "").strip().splitlines()
            self._write("gather: tool failed" + (": " + head[0][:160] if head else "") + "\n")

def _tool_brief(block: dict) -> str:
    name = str(block.get("name") or "tool")
    raw = block.get("input")
    inp = raw if isinstance(raw, dict) else {}
    bits = [f"{k}={inp[k]}" for k in ("action", "path", "name", "pattern", "command", "target_file") if inp.get(k)]
    return (name + " " + " ".join(bits)).strip()[:180]

def _kill(proc: subprocess.Popen) -> None:
    if os.name == "nt":
        subprocess.run(["taskkill", "/F", "/T", "/PID", str(proc.pid)], capture_output=True)
    else:
        proc.kill()

def _stream(argv: list[str], wt: Path, env: dict, timeout: int) -> tuple[int, str, str]:
    """(code, output, why). why is set when the run compacted or hit the turn cap; the process is killed then.
    Thoughts and tool lines are printed as each stream line arrives."""
    proc = subprocess.Popen(runnable(argv), cwd=wt, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, encoding="utf-8", errors="replace", env=env, bufsize=1)
    lines: list[str] = []
    kind = ""
    feed = StreamFeed()

    def read() -> None:
        nonlocal kind
        assert proc.stdout is not None
        try:
            for line in proc.stdout:
                lines.append(line)
                try:
                    feed(line)
                except Exception:
                    pass
                kind = kind or _stop_kind(line)
                if kind:
                    _kill(proc)
                    break
        except OSError:
            return

    thread = threading.Thread(target=read, daemon=True)
    thread.start()
    try:
        code = proc.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        _kill(proc)
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            pass
        thread.join(timeout=5)
        return 124, "".join(lines), f"timeout after {timeout}s"
    thread.join(timeout=5)
    why = {"compact": "context compacted before the packet was finished", "turns": "turn cap reached"}.get(kind, "")
    if code is None:
        code = 1 if why else 0
    return code, "".join(lines), why

def usage(out: str) -> str:
    """'turns=N tokens=in/out cost=$X session=ID' from grok's JSON output (last JSON object), or ''."""
    for line in reversed(out.strip().splitlines()):
        d = _json_line(line)
        if not isinstance(d, dict) or "usage" not in d and "num_turns" not in d:
            continue
        u = d.get("usage") or {}
        if not isinstance(u, dict):
            u = {}
        return (f"turns={d.get('num_turns', '?')} tokens={u.get('input_tokens', '?')}/{u.get('output_tokens', '?')} "
                f"cost=${d.get('total_cost_usd', '?')} session={d.get('sessionId') or d.get('session_id') or '?'}")
    return ""

def prompt_text(area: str, door: str, job: str, tid: str, request: str = "") -> str:
    """The gather prompt: no task line without a task; the User's request (open's prompt) appended when there is one."""
    text = render("gather-prompt.md", slice=slice_line(area, door, job, tid),
                  task_step=f", then the task file once: design/tasks/{tid}.md (read it whole; it is the assignment)" if tid else "",
                  request_step=", and the User's request at the end of this prompt" if request.strip() else "")
    return text.rstrip() + ("\n\nThe User's request:\n\n" + request.strip() + "\n" if request.strip() else "\n")

def _note_stop(wt: Path, reason: str) -> None:
    """Record an unfinished gather so open refuses to launch. Keeps a halt or report the agent already wrote."""
    d = wt / GATHER
    d.mkdir(parents=True, exist_ok=True)
    text = reason.strip() + "\n"
    if not (d / "halt").is_file():
        (d / "halt").write_text(text, encoding="utf-8")
    if not (d / "report.md").is_file():
        (d / "report.md").write_text(text, encoding="utf-8")

def agent(grok: str, wt: Path, area: str, door: str, job: str, tid: str, request: str = "") -> tuple[bool, str]:
    """(ok, one line). Runs the cheap model once; never raises. An unfinished run writes a halt and does not launch."""
    prompt = wt / GATHER / "prompt.md"
    prompt.write_text(prompt_text(area, door, job, tid, request), encoding="utf-8")
    code, out, why = _stream(agent_argv(grok, wt, prompt), wt, dict(os.environ, WDB_ROLE="gather", PYTHONUNBUFFERED="1"), TIMEOUT)
    (wt / GATHER / "agent.txt").write_text(out, encoding="utf-8")
    use = usage(out)
    if not why and code != 0:
        why = f"exit {code}"
    if not why and not (wt / GATHER / "report.md").is_file() and not halted(wt):
        why = "no report"
    if why:
        reason = (f"GATHER STOPPED ({why}). Not launched. The index may be partial; "
                  f"`{py()} tools/slice.py plan --refresh --clean` restores the seed. "
                  f"Delete {GATHER}/halt before `slice.py open --launch` to start the main session anyway. {use}").rstrip()
        _note_stop(wt, reason)
        return False, reason
    return True, f"gather agent: done. {use}".rstrip()

def finish(wt: Path, restore: bool) -> tuple[bool, list[str]]:
    """open's own `expand --check` (it does not trust the agent), then session-context.md. restore: the agent crashed,
    so drop its partial adjustments first (seed only). (ok, lines); not ok = do not launch."""
    def run(*a: str) -> tuple[int, str]:
        return _run([sys.executable, "tools/slice.py", *a, "--root", str(wt)], wt)

    live("open: expand --check\n")
    if restore:
        run("plan", "--refresh", "--clean")
    code, out = run("expand", "--check")
    if code != 0:
        live("open: expand --check failed\n")
        bad = [ln for ln in out.splitlines() if ln.strip() and not ln.startswith("RESULT")][:8]
        return False, ["INDEX FAILED `slice.py expand --check`; not launched:"] + bad + [
            f"Fix it in {wt} with `{py()} tools/slice.py adjust ...` (or `plan --refresh --clean` for the seed), then: {py()} tools/slice.py open --launch {wt}"]
    live("open: writing session-context.md\n")
    run("expand", "--out", "session-context.md")
    live("open: packet written\n")
    return True, []

def gathered(wt: Path) -> bool:
    """True when the index identity says the gather agent refined the seed (`gather: agent`, set by slice.py adjust)."""
    import plan_index as pi

    try:
        text = (wt / "session-plan.md").read_text(encoding="utf-8-sig")
    except OSError:
        return False
    return pi.parse(pi.split_plan(text)[1]).get("gather") == "agent"

def halted(wt: Path) -> str:
    f = wt / GATHER / "halt"
    return f.read_text(encoding="utf-8").strip() if f.is_file() else ""

def report(wt: Path) -> str:
    f = wt / GATHER / "report.md"
    return f.read_text(encoding="utf-8").strip() if f.is_file() else "(the gather agent wrote no report)"

def first_message(start_argv: list[str], tid: str, warn: list[str], extra: str = "", refined: bool = True) -> str:
    """Main-session prompt after a gather. refined: the agent finished; otherwise the packet is the mechanical seed."""
    shown = py() + " " + " ".join(start_argv[1:])
    task_line = f" (design/tasks/{tid}.md; read it whole; it is the assignment)" if tid else ""
    packet = (DATA / ("packet-refined.md" if refined else "packet-seed.md")).read_text(encoding="utf-8").strip()
    text = render("build-first.md", start=shown, task_line=task_line, warn="\n".join(warn), packet=packet).strip()
    return text + ("\n\n" + extra.strip() if extra.strip() else "")
