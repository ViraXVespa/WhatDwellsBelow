"""The `slice.py open` gather step (library; import only): run start for the main session, the local chain, then the packet.

Order in a new worktree WT (open_slice.py calls these):
    1. start(): `slice.py start <flags>` in WT with GROK_SESSION_ID = the main session's pre-assigned id (`grok -s SID`),
       so slice state records the main session and session-plan.md gets its mechanical seed.
    2. local_chain(): Ollama role sessions (`slice.py gather-pick --chain`). A pick sets `gather: agent`.
       A miss or invalid JSON on mark leaves the mechanical seed (`gather: seed`). A scout page with no final answer is skipped.
       `--seed-only` skips this step. WDB_GATHER_PICK=skip is the open selftest and does not call Ollama.
    3. finish(): `plan --refresh --clean` restores the seed only when a warn is set and there is no halt file.
       Then open's own `slice.py expand --check`
       (it does not trust the chain): a failure stops before launch; then `expand --out session-context.md` writes the packet.
A `_logs/gather/halt` file (adjust report --halt) also makes open refuse to launch. The first message for the main session is
tools/data/gather/build-first.md plus packet-refined.md when the chain marked funcs, otherwise packet-seed.md.
Tests pass a stub as `grok`.
"""
from __future__ import annotations

import json
import os
import re
import shlex
import subprocess
import sys
from pathlib import Path

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

def py() -> str:
    """The interpreter name to print in commands: python on Windows, python3 where only that exists (the Linux box)."""
    name = Path(sys.executable).stem.lower()
    return "python3" if name.startswith("python3") else "python"

def render(template: str, **kv: str) -> str:
    text = (DATA / template).read_text(encoding="utf-8")
    for k, v in {"py": py(), **kv}.items():
        text = text.replace("{" + k + "}", v)
    return text

def live(text: str) -> None:
    """Print gather progress now. Open captures nothing until the process exits, so this is the live view."""
    if not text:
        return
    try:
        sys.stdout.write(text)
        sys.stdout.flush()
    except (OSError, UnicodeError):
        return

def _section(text: str, heading: str) -> list[str]:
    lines: list[str] = []
    on = False
    for line in text.splitlines():
        if line.startswith("### "):
            if on:
                break
            on = line.startswith(f"### {heading}")
            continue
        if on:
            lines.append(line)
    return lines

def _index_text(wt: Path) -> str:
    path = wt / "session-plan.md"
    return path.read_text(encoding="utf-8") if path.is_file() else ""

def core_has_func(text: str) -> bool:
    return any(" func `" in line for line in _section(text, "Core"))

_SEED_WHEN = re.compile(
    r"the change reaches it \("
    r"|the change touches door-wide rules or a sibling job"
    r"| - when: the change reaches \S+ code$")

def seed_candidate_ids(text: str) -> list[str]:
    """Ids still carrying a mechanical seed condition. A candidate the agent rewrote (any other when) stays."""
    ids: list[str] = []
    for line in _section(text, "Candidates"):
        if not _SEED_WHEN.search(line):
            continue
        match = re.match(r"-\s+([CK]\d+)\b", line.strip())
        if match:
            ids.append(match.group(1))
    return ids

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

def local_chain(wt: Path, door: str, job: str, task: str, say) -> int:
    """Run the Ollama role chain in wt. Returns how many funcs were marked, or 0 when the seed stays.

    Never raises. WDB_GATHER_PICK=skip returns 0 without a model. WDB_GATHER_PICK=mark stubs
    scripts/demo.gd:alpha for the open selftest.
    """
    import gather_pick

    mode = os.environ.get("WDB_GATHER_PICK", "")
    if mode == "skip":
        say("open: gather skipped\n")
        return 0

    def stub(messages: list[dict[str, str]], _model: str) -> str:
        user = messages[-1]["content"] if messages else ""
        if user.startswith("Role: scout"):
            if "scripts/demo.gd" in user:
                return json.dumps({"read": ["scripts/demo.gd"]})
            return json.dumps({"read": []})
        if user.startswith("Role: mark") and "File: scripts/demo.gd" in user:
            return json.dumps({"edit": [{"path": "scripts/demo.gd", "func": "alpha", "why": "the edit"}]})
        if user.startswith("Role: trim"):
            return json.dumps({"keep": ["alpha"]})
        if user.startswith("Role: review"):
            return json.dumps({"drop": []})
        return json.dumps({"read": []})

    complete = stub if mode == "mark" else gather_pick.ollama_complete
    try:
        rep = gather_pick.chain(wt, door, job, task, gather_pick.MODEL, complete, False, say)
    except Exception as exc:
        say(f"open: gather failed; the mechanical seed stays ({exc})\n")
        return 0
    if rep.route != "pick":
        say("open: gather left the mechanical seed\n")
        return 0
    return rep.accepted

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
