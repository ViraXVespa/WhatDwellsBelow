#!/usr/bin/env python3
"""Parse Grok CLI session signals / updates for pack and report runners."""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable, Iterator


def as_int(value: Any) -> int:
    if isinstance(value, bool) or value is None:
        return 0
    if isinstance(value, (int, float)):
        return int(value)
    return 0


def read_text(path: Path) -> str | None:
    if not path.is_file():
        return None
    return path.read_text(encoding="utf-8-sig")


def load_json(path: Path) -> Any | None:
    text = read_text(path)
    if text is None or not text.strip():
        return None
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return None


def iter_jsonl(path: Path) -> Iterator[dict[str, Any]]:
    if not path.is_file():
        return
    with path.open("r", encoding="utf-8-sig") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(row, dict):
                yield row


def unwrap_update(row: dict[str, Any]) -> dict[str, Any] | None:
    params = row.get("params")
    if isinstance(params, dict) and isinstance(params.get("update"), dict):
        return params["update"]
    upd = row.get("update")
    if isinstance(upd, dict) and (
        "sessionUpdate" in upd or "usage" in upd
    ):
        return upd
    if "sessionUpdate" in row:
        return row
    return None


def event_kind(row: dict[str, Any], payload: dict[str, Any] | None) -> str:
    src = payload if payload is not None else row
    return str(src.get("sessionUpdate") or "")


def usage_from_payload(payload: dict[str, Any] | None) -> dict[str, int]:
    empty = {
        "total": 0,
        "uncached": 0,
        "cost_ticks": 0,
        "input": 0,
        "cached": 0,
        "output": 0,
    }
    if not isinstance(payload, dict):
        return empty
    usage = payload.get("usage")
    if not isinstance(usage, dict):
        return empty
    inp = as_int(usage.get("inputTokens"))
    cached = as_int(usage.get("cachedReadTokens"))
    output = as_int(usage.get("outputTokens"))
    total = as_int(usage.get("totalTokens"))
    if not total:
        total = inp + output
    return {
        "total": total,
        "uncached": max(inp - cached, 0) + output,
        "cost_ticks": as_int(usage.get("costUsdTicks")),
        "input": inp,
        "cached": cached,
        "output": output,
    }


def meta_total(row: dict[str, Any], payload: dict[str, Any] | None) -> int:
    best = 0
    for blob in (row.get("_meta"), (payload or {}).get("_meta")):
        if isinstance(blob, dict):
            hit = as_int(blob.get("totalTokens"))
            if hit > best:
                best = hit
    return best


def _tool_title(payload: dict[str, Any]) -> str:
    title = payload.get("title")
    if isinstance(title, str) and title.strip():
        return title.strip().split()[0]
    return ""


def tool_name(row: dict[str, Any], payload: dict[str, Any] | None) -> str | None:
    src = payload if payload is not None else row
    kind = event_kind(row, payload)
    if kind not in ("tool_call", "tool_call_update"):
        return None
    meta = src.get("_meta")
    if isinstance(meta, dict):
        tool = meta.get("x.ai/tool")
        if isinstance(tool, dict):
            name = tool.get("name")
            if isinstance(name, str) and name.strip():
                return name.strip()
    raw = src.get("rawInput")
    if isinstance(raw, dict):
        variant = raw.get("variant")
        if isinstance(variant, str) and variant.strip():
            mapped = {
                "ReadFile": "read_file",
                "Bash": "run_terminal_command",
                "SearchReplace": "search_replace",
                "Write": "write",
                "Grep": "grep",
                "ListDir": "list_dir",
            }
            if variant in mapped:
                return mapped[variant]
    title = _tool_title(src)
    junk = {
        "[bg]", "powershell", "&", "$brief", "Web", "Plan",
        "kill", "multi-wait", "Execute",
    }
    if title and title not in junk and not title.startswith("["):
        return title
    return None


def _first_str(obj: Any, keys: tuple[str, ...]) -> str:
    if not isinstance(obj, dict):
        return ""
    for key in keys:
        val = obj.get(key)
        if isinstance(val, str) and val.strip():
            return val.strip()
    return ""


def event_path(row: dict[str, Any], payload: dict[str, Any] | None) -> str:
    src = payload if payload is not None else row
    raw = src.get("rawInput")
    path = _first_str(
        raw,
        (
            "target_file",
            "file_path",
            "path",
            "Path",
            "targetFile",
        ),
    )
    if path:
        return path
    locs = src.get("locations")
    if isinstance(locs, list):
        for loc in locs:
            hit = _first_str(loc, ("path", "file_path", "target_file"))
            if hit:
                return hit
    out = src.get("rawOutput")
    path = _first_str(out, ("absolute_path", "path", "file_path"))
    if path:
        return path
    if isinstance(out, dict):
        path = _first_str(out.get("EditsApplied"), ("absolute_path", "path"))
        if path:
            return path
    return ""


INTERCEPT_TOOLS = frozenset(
    {
        "grep",
        "list_dir",
        "run_terminal_command",
        "read_file",
        "web_search",
        "web_fetch",
    }
)

GIT_HINTS = ("git status", "git log", "git diff")


def intercept_label(tool: str, path: str, raw_command: str) -> str | None:
    low_path = path.replace("\\", "/").lower()
    low_cmd = raw_command.lower()
    if tool == "grep":
        return "grep"
    if tool == "list_dir" and any(
        part in low_path
        for part in ("/scripts", "/design", "/tools", "/scenes")
    ):
        return "tree_list_dir"
    if "design/code-map.md" in low_path:
        return "raw_code_map"
    if "/notes/" in low_path or low_path.endswith("/notes"):
        return "notes"
    if "memory-v2" in low_path and "/topics/" in low_path:
        return "memory_topic"
    if tool == "run_terminal_command":
        for hint in GIT_HINTS:
            if hint in low_cmd:
                return "git_porcelain"
    return None


def raw_command(payload: dict[str, Any] | None) -> str:
    if not isinstance(payload, dict):
        return ""
    raw = payload.get("rawInput")
    if isinstance(raw, dict):
        cmd = raw.get("command")
        if isinstance(cmd, str):
            return cmd
    return ""


@dataclass
class Turn:
    index: int
    tools: list[str] = field(default_factory=list)
    paths: list[tuple[str, str]] = field(default_factory=list)
    intercepts: list[str] = field(default_factory=list)
    usage: dict[str, int] = field(default_factory=dict)
    meta_max: int = 0
    compact: bool = False


def _new_turn(index: int) -> Turn:
    return Turn(index=index, usage=usage_from_payload(None))


def iter_turns(rows: Iterable[dict[str, Any]]) -> list[Turn]:
    turns: list[Turn] = []
    current = _new_turn(1)
    started = False

    def bump() -> None:
        nonlocal current, started
        if started or current.tools or current.usage.get("total"):
            turns.append(current)
            current = _new_turn(len(turns) + 1)
        started = False

    for row in rows:
        payload = unwrap_update(row)
        kind = event_kind(row, payload)
        if kind == "user_message_chunk":
            if started:
                bump()
            started = True
            continue
        if kind == "sessionUpdate" and str(
            (payload or row).get("sessionUpdate")
        ) == "user_message_chunk":
            if started:
                bump()
            started = True
            continue
        tool = tool_name(row, payload)
        path = event_path(row, payload)
        cmd = raw_command(payload)
        if tool:
            if tool not in current.tools:
                current.tools.append(tool)
            if path:
                current.paths.append((tool, path))
            label = intercept_label(tool, path, cmd)
            if label and label not in current.intercepts:
                current.intercepts.append(label)
        hit = meta_total(row, payload)
        if hit > current.meta_max:
            current.meta_max = hit
        if "compact" in kind.lower() or "compaction" in kind.lower():
            current.compact = True
        if kind == "turn_completed":
            current.usage = usage_from_payload(payload)
            started = True
            bump()
            started = False
    if started or current.tools or current.usage.get("total"):
        turns.append(current)
    return turns


def signals_metrics(path: Path) -> dict[str, int]:
    data = load_json(path)
    if not isinstance(data, dict):
        return {
            "context_tokens": 0,
            "tokens_before_compaction": 0,
            "signal_turns": 0,
            "tool_calls": 0,
            "compaction_count": 0,
        }
    return {
        "context_tokens": as_int(data.get("contextTokensUsed")),
        "tokens_before_compaction": as_int(
            data.get("totalTokensBeforeCompaction")
        ),
        "signal_turns": as_int(data.get("turnCount")),
        "tool_calls": as_int(data.get("toolCallCount")),
        "compaction_count": as_int(data.get("compactionCount")),
    }


def updates_metrics(path: Path) -> dict[str, Any]:
    turns = iter_turns(iter_jsonl(path))
    totals = {
        "turn_tokens": 0,
        "uncached_tokens": 0,
        "cost_ticks": 0,
        "completed_turns": 0,
        "meta_max": 0,
        "compact_events": 0,
    }
    for turn in turns:
        totals["turn_tokens"] += as_int(turn.usage.get("total"))
        totals["uncached_tokens"] += as_int(turn.usage.get("uncached"))
        totals["cost_ticks"] += as_int(turn.usage.get("cost_ticks"))
        if as_int(turn.usage.get("total")) or as_int(turn.usage.get("cost_ticks")):
            totals["completed_turns"] += 1
        if turn.meta_max > totals["meta_max"]:
            totals["meta_max"] = turn.meta_max
        if turn.compact:
            totals["compact_events"] += 1
    totals["turns"] = turns
    return totals


def session_metrics(session_dir: Path) -> dict[str, Any]:
    sig = signals_metrics(session_dir / "signals.json")
    upd = updates_metrics(session_dir / "updates.jsonl")
    tokens = (
        as_int(upd["turn_tokens"])
        or as_int(sig["context_tokens"])
        or as_int(upd["meta_max"])
        or as_int(sig["tokens_before_compaction"])
    )
    out = dict(sig)
    out.update({k: v for k, v in upd.items() if k != "turns"})
    out["tokens"] = tokens
    out["turns"] = upd["turns"]
    later = max(as_int(upd["completed_turns"]) - 1, 0)
    if as_int(sig["compaction_count"]) or as_int(upd["compact_events"]):
        out["compaction_tax"] = as_int(sig["context_tokens"]) * later
    else:
        out["compaction_tax"] = 0
    return out


def add_count(bucket: dict[str, dict[str, int]], key: str, **delta: int) -> None:
    row = bucket.setdefault(
        key,
        {
            "count": 0,
            "turns": 0,
            "uncached": 0,
            "cost_ticks": 0,
            "tokens": 0,
        },
    )
    for name, value in delta.items():
        row[name] = as_int(row.get(name)) + as_int(value)


def accumulate_turn(
    tool_hist: dict[str, dict[str, int]],
    path_hist: dict[str, dict[str, int]],
    intercept_hist: dict[str, dict[str, int]],
    turn: Turn,
) -> None:
    n_tools = max(len(turn.tools), 1)
    share_uncached = as_int(turn.usage.get("uncached")) // n_tools
    share_cost = as_int(turn.usage.get("cost_ticks")) // n_tools
    share_tokens = as_int(turn.usage.get("total")) // n_tools
    for tool in turn.tools:
        add_count(
            tool_hist,
            tool,
            count=1,
            turns=1,
            uncached=share_uncached,
            cost_ticks=share_cost,
            tokens=share_tokens,
        )
    for tool, path in turn.paths:
        add_count(
            path_hist,
            f"{tool}\t{path}",
            count=1,
            turns=1,
            uncached=share_uncached,
            cost_ticks=share_cost,
            tokens=share_tokens,
        )
    for label in turn.intercepts:
        add_count(
            intercept_hist,
            label,
            count=1,
            turns=1,
            uncached=share_uncached,
            cost_ticks=share_cost,
            tokens=share_tokens,
        )


def sort_hist(
    bucket: dict[str, dict[str, int]],
) -> list[tuple[str, dict[str, int]]]:
    return sorted(
        bucket.items(),
        key=lambda item: (
            -as_int(item[1].get("cost_ticks")),
            -as_int(item[1].get("uncached")),
            -as_int(item[1].get("count")),
            item[0],
        ),
    )
