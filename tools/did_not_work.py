#!/usr/bin/env python3
"""List this session's failed tool steps, so the next message to the User can start with `Did not work: ...`.

    python tools/did_not_work.py [--session ID] [--file CHAT_HISTORY.jsonl]
A failed step is any terminal command with a non-zero exit or a `RESULT FAIL` line, and any other tool call that answered `Error...`; exploratory
ones count. It reads the Grok session's own chat_history.jsonl (found from $GROK_SESSION_ID, else --session; or pass --file) and prints each
failed step with its command and the line that shows the failure; steps after the last message that said `Did not work` are marked UNREPORTED.
Best effort over the session layout seen in real sessions (tools/session_lib.py): when the file cannot be found it says so and the rule still
applies by hand. It cannot see a step you skipped: say that yourself.
"""
from __future__ import annotations

import json
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log
import session_lib


def selftest() -> int:
    bad: list[str] = []
    rows = [
        {"type": "assistant", "content": "", "tool_calls": [{"id": "c1", "name": "run_terminal_command", "arguments": json.dumps({"command": "python tools/x.py"})},
                                                              {"id": "c2", "name": "read_file", "arguments": json.dumps({"target_file": "a.md"})},
                                                              {"id": "c3", "name": "run_terminal_command", "arguments": json.dumps({"command": "python tools/ok.py"})}]},
        {"type": "tool_result", "tool_call_id": "c1", "content": "exit: 1\nsomething\nRESULT FAIL a=1"},
        {"type": "tool_result", "tool_call_id": "c2", "content": "Error: a.md does not exist."},
        {"type": "tool_result", "tool_call_id": "c3", "content": "exit: 0\nthe text RESULT FAIL is quoted\nRESULT PASS"},
        {"type": "assistant", "content": "Did not work: python tools/x.py", "tool_calls": [{"id": "c4", "name": "run_terminal_command", "arguments": json.dumps({"command": "python tools/y.py"})}]},
        {"type": "tool_result", "tool_call_id": "c4", "content": "exit: 2\nboom"},
    ]
    st = session_lib.failed_steps(rows)
    if [s["what"] for s in st] != ["python tools/x.py", "a.md", "python tools/y.py"] or [s["reported"] for s in st] != [True, True, False]:
        bad.append(f"failed_steps wrong: {st}")
    with tempfile.TemporaryDirectory() as td:
        sd = Path(td) / "C%3A%5Cwt" / "sess-1"
        sd.mkdir(parents=True)
        (sd / "prompt_context.json").write_text(json.dumps({"agents_md_files": []}), encoding="utf-8")
        (sd / "chat_history.jsonl").write_text("\n".join(json.dumps(r) for r in [
            {"type": "system", "content": "s"}, {"type": "user", "content": [{"type": "text", "text": "The following skills are available: - pc-offload: x"}]}] + rows), encoding="utf-8")
        if session_lib.session_dir("sess-1", Path(td)) != sd or session_lib.session_dir("nope", Path(td)) is not None:
            bad.append("session_dir lookup wrong")
        said = session_lib.statement(sd)
        if "AGENTS.md: read by hand" not in said or "skills: pc-offload listed at start" not in said:
            bad.append(f"statement wrong: {said}")
        (sd / "prompt_context.json").write_text(json.dumps({"agents_md_files": [{"file_name": "Agents.md"}]}), encoding="utf-8")
        if "AGENTS.md: auto-loaded (Agents.md)" not in session_lib.statement(sd):
            bad.append("an auto-loaded agents file must be reported as auto-loaded")
    if "not verified" not in session_lib.statement(None) or "/session-info" not in session_lib.statement(None):
        bad.append("an unreadable session must say not verified and point at /session-info")
    for b in bad:
        print("FAIL " + b)
    return agent_log.emit_result("FAIL" if bad else "PASS", None, cmd="selftest", problems=len(bad))


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("List this session's failed tool steps (for the 'Did not work:' line).")
    ap.add_argument("--session", default="", help="Session id (default: $GROK_SESSION_ID).")
    ap.add_argument("--file", default="", help="A chat_history.jsonl to read instead of the session's own.")
    ap.add_argument("--selftest", action="store_true", help="Run the parser cases on a synthetic session.")
    args = ap.parse_args(argv)
    if args.selftest:
        return selftest()
    root = agent_log.resolve_root(args)
    path = Path(args.file) if args.file else None
    if path is None:
        sdir = session_lib.session_dir(args.session)
        path = sdir / "chat_history.jsonl" if sdir else None
    if path is None or not path.is_file():
        msg = ("NOT FOUND: could not find this session's chat_history.jsonl ($GROK_SESSION_ID empty, or the session store is elsewhere: set WDB_GROK_SESSIONS). "
               "The rule still applies: list every failed or skipped step yourself at the start of your next message as `Did not work: <command> <one line>`.")
        return agent_log.finish("did-not-work", root, msg, "INFO", args=args, echo=msg, found="no")
    steps = session_lib.failed_steps(session_lib._rows(path))
    lines = [f"failed steps={len(steps)} unreported={sum(1 for s in steps if not s['reported'])} (file {path.name})"]
    lines += [f"{'  ' if s['reported'] else 'UNREPORTED '}#{s['i']} {s['tool']}: {s['what']} -> {s['why']}" for s in steps]
    lines.append("Start your next message with `Did not work:` for every UNREPORTED line, and for any step you skipped.")
    body = "\n".join(lines)
    return agent_log.finish("did-not-work", root, body, "INFO", args=args, echo=body, found="yes", failed=len(steps),
                            unreported=sum(1 for s in steps if not s["reported"]))


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
