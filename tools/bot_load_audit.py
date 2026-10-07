#!/usr/bin/env python3
"""Bot-only: audit how much a Grok Build session read before its first ask, from its chat_history.jsonl (Bot and CI only: pass --bot).

    python tools/bot_load_audit.py --bot --session DIR | --file chat_history.jsonl
Lists the reads before the first ask_user_question (repo docs, skills, memory topics, scripts, pictures, searches), which of them the
session never named again (a name in later assistant text, reasoning or call arguments counts as used; a doc that shaped work silently
shows up as unused, so confirm before trimming), the call index of start_build_slice / list_route, and the share of reads that were
pictures. Numbers are bytes/characters of tool results; token figures are not in the logs. Elsewhere it prints "not run".
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
import bot_gate_lib


def _rows(path: Path) -> list[dict]:
    out = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        try:
            out.append(json.loads(line))
        except ValueError:
            pass
    return out


def _text(v: object) -> str:
    return v if isinstance(v, str) else json.dumps(v, ensure_ascii=False)


def _kind(path: str) -> str:
    p = path.replace("\\", "/").lower()
    if "memory-v2" in p:
        return "memory"
    if "/skills/" in p or p.endswith("skill.md"):
        return "skill"
    if p.endswith((".png", ".jpg", ".jpeg", ".webp")):
        return "image"
    if "/design/" in p or p.endswith(("agents.md", "bot.md")):
        return "doc"
    if "/_logs/" in p:
        return "log"
    if p.endswith((".gd", ".py", ".json", ".yaml", ".tscn")):
        return "code"
    return "other"


def audit(rows: list[dict]) -> dict:
    calls: dict[str, tuple[int, str, dict]] = {}
    results: dict[str, str] = {}
    for i, r in enumerate(rows):
        for tc in r.get("tool_calls") or []:
            try:
                args = json.loads(tc.get("arguments") or "{}")
            except ValueError:
                args = {}
            calls[tc["id"]] = (i, tc["name"], args if isinstance(args, dict) else {})
        if r.get("type") == "tool_result":
            results[r.get("tool_call_id", "")] = _text(r.get("content"))
    first_ask = next((i for i, r in enumerate(rows) for tc in r.get("tool_calls") or [] if tc["name"] == "ask_user_question"), len(rows))
    reads, xref, order = [], [0, 0], {}
    for cid, (i, name, a) in sorted(calls.items(), key=lambda kv: kv[1][0]):
        res = results.get(cid, "")
        cmd = str(a.get("command", ""))
        for key in ("start_build_slice", "list_route"):
            if key in cmd and key not in order:
                order[key] = i
        if i > first_ask:
            continue
        if name == "read_file":
            p = str(a.get("target_file") or a.get("path") or "")
            reads.append({"path": p, "kind": _kind(p), "chars": len(res), "row": i, "cid": cid})
        elif name == "list_dir":
            reads.append({"path": "list_dir " + str(a.get("target_directory", "")), "kind": "listing", "chars": len(res), "row": i, "cid": cid})
        elif name == "run_terminal_command" and "list_xref" in cmd:
            xref[0] += 1
            xref[1] += len(res)
    later = "\n".join(_text(r.get("content")) + _text(r.get("tool_calls")) for r in rows[first_ask:] if r.get("type") in ("assistant", "reasoning"))
    after_calls = "\n".join(json.dumps(a) for cid, (i, n, a) in calls.items() if i > first_ask)
    pool = (later + "\n" + after_calls).lower().replace("\\\\", "/").replace("\\", "/")
    for r in reads:
        base = Path(r["path"].replace("\\", "/")).name.lower()
        r["used"] = r["kind"] == "image" or r["kind"] == "listing" or base in pool or base.rsplit(".", 1)[0] in pool
    return {"first_ask_row": first_ask, "reads": reads, "xref": xref, "order": order,
            "calls_before_ask": sum(1 for v in calls.values() if v[0] <= first_ask)}


def report(res: dict) -> list[str]:
    reads = res["reads"]
    by: dict[str, list[int]] = {}
    for r in reads:
        k = by.setdefault(r["kind"], [0, 0])
        k[0] += 1
        k[1] += r["chars"] if r["kind"] != "image" else 0
    lines = [f"first ask at row {res['first_ask_row']}; tool calls before it: {res['calls_before_ask']}; reads: {len(reads)}",
             "by kind (count, result chars; pictures counted only): " + ", ".join(f"{k}={v[0]}/{v[1]}" for k, v in sorted(by.items())),
             f"list_xref before the first ask: {res['xref'][0]} calls, {res['xref'][1]} chars",
             "start_build_slice at row %s; list_route at row %s" % (res["order"].get("start_build_slice", "never"), res["order"].get("list_route", "never"))]
    unused = [r for r in reads if not r["used"]]
    lines.append(f"read before the first ask and not named again ({len(unused)}):")
    lines += [f"  row {r['row']}  {r['kind']}  {r['chars']}  {r['path']}" for r in sorted(unused, key=lambda r: -r["chars"])]
    return lines


def selftest() -> int:
    def call(i: str, name: str, **a: object) -> dict:
        return {"type": "assistant", "content": "", "tool_calls": [{"id": i, "name": name, "arguments": json.dumps(a)}]}

    rows = [call("1", "read_file", target_file="C:\\x\\design\\protocol.md"), {"type": "tool_result", "tool_call_id": "1", "content": "p" * 100},
            call("2", "read_file", target_file="C:\\x\\design\\ui-hud.md"), {"type": "tool_result", "tool_call_id": "2", "content": "h" * 50},
            call("3", "read_file", target_file="C:\\x\\shot.png"), {"type": "tool_result", "tool_call_id": "3", "content": "Read image file: C:\\x\\shot.png"},
            call("4", "ask_user_question", q="x"), {"type": "assistant", "content": "I used protocol.md", "tool_calls": []}]
    res = audit(rows)
    unused = [r["path"] for r in res["reads"] if not r["used"]]
    ok = res["first_ask_row"] == 6 and unused == ["C:\\x\\design\\ui-hud.md"] and any("ui-hud.md" in ln for ln in report(res))
    print("" if ok else "FAIL the audit must flag exactly the doc that was read and never named again")
    return agent_log.emit_result("PASS" if ok else "FAIL", None, cmd="selftest", problems=0 if ok else 1)


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Bot-only audit of one Grok Build session's reads before its first ask.")
    bot_gate_lib.add_flag(ap)
    ap.add_argument("--session", default="", help="Session folder (holds chat_history.jsonl).")
    ap.add_argument("--file", default="", help="A chat_history.jsonl.")
    ap.add_argument("--selftest", action="store_true", help="Run the built-in case.")
    args = ap.parse_args(argv)
    if args.selftest:
        return selftest()
    root = agent_log.resolve_root(args)
    if not bot_gate_lib.enabled(args):
        return bot_gate_lib.not_run("bot_load_audit")
    path = Path(args.file) if args.file else Path(args.session) / "chat_history.jsonl"
    if not path.is_file():
        agent_log.fail(f"no chat_history.jsonl at {path}; pass --session DIR or --file PATH")
    lines = report(audit(_rows(path)))
    return agent_log.finish("bot-load-audit", root, "\n".join(lines), "INFO", args=args, echo="\n".join(lines[:60]), reads=len(lines))


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
