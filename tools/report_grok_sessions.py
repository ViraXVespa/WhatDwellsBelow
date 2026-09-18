#!/usr/bin/env python3
"""Paste-sized reports from a grok-sessions pack or live session root."""

from __future__ import annotations

import argparse
import json
import sys
from datetime import timedelta
from pathlib import Path
from typing import Any

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import grok_session_lib as gsl
import agent_log
import pack_grok_sessions as packer


def _write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if not text.endswith("\n"):
        text += "\n"
    path.write_text(text, encoding="utf-8")


def _fmt_usd(ticks: int) -> str:
    return f"${int(ticks) / 10_000_000_000:.4f}"


def _table(headers: list[str], rows: list[list[str]]) -> list[str]:
    lines = ["\t".join(headers)]
    lines.extend("\t".join(row) for row in rows)
    return lines


def _metrics_from_pack(pack_dir: Path, rank: int, item: dict[str, Any]) -> dict[str, Any]:
    sid = str(item.get("session_id") or "")
    title = str(item.get("title") or sid)
    updates = pack_dir / f"updates_{rank}.jsonl"
    signals = gsl.load_json(pack_dir / f"signals_{rank}.json")
    if not isinstance(signals, dict):
        signals = {}
    turns = list(gsl.iter_turns(gsl.iter_jsonl(updates))) if updates.is_file() else []
    turn_tokens = sum(int(turn.usage.get("total") or 0) for turn in turns)
    turn_uncached = sum(int(turn.usage.get("uncached") or 0) for turn in turns)
    turn_cost = sum(int(turn.usage.get("cost_ticks") or 0) for turn in turns)
    completed = sum(
        1
        for turn in turns
        if int(turn.usage.get("total") or 0) or int(turn.usage.get("cost_ticks") or 0)
    )
    context = int(signals.get("contextTokensUsed") or item.get("context_tokens") or 0)
    compacts = int(signals.get("compactionCount") or 0)
    later = max(completed - 1, 0)
    return {
        "rank": rank,
        "session_id": sid,
        "title": title,
        "tokens": turn_tokens or int(item.get("tokens") or 0),
        "uncached_tokens": turn_uncached or int(item.get("uncached_tokens") or 0),
        "cost_ticks": turn_cost or int(item.get("cost_ticks") or 0),
        "context_tokens": context,
        "tokens_before_compaction": int(
            signals.get("totalTokensBeforeCompaction") or 0
        ),
        "compaction_count": compacts,
        "completed_turns": completed,
        "signal_turns": int(signals.get("turnCount") or 0),
        "tool_calls": int(signals.get("toolCallCount") or 0),
        "compaction_tax": context * later if compacts else 0,
        "turns": turns,
    }


def load_from_pack(pack_dir: Path) -> list[dict[str, Any]]:
    summed = gsl.load_json(pack_dir / "summary_Summed.json")
    if not isinstance(summed, list):
        return []
    rows: list[dict[str, Any]] = []
    for item in summed:
        if not isinstance(item, dict):
            continue
        rank = int(item.get("rank") or 0)
        if rank <= 0:
            continue
        rows.append(_metrics_from_pack(pack_dir, rank, item))
    rows.sort(key=lambda row: int(row.get("rank") or 0))
    return rows


def build_report(rows: list[dict[str, Any]]) -> str:
    tools: dict[str, dict[str, int]] = {}
    paths: dict[str, dict[str, int]] = {}
    intercepts: dict[str, dict[str, int]] = {}
    top_turns: list[dict[str, Any]] = []
    for row in rows:
        for turn in row.get("turns") or []:
            gsl.accumulate_turn(tools, paths, intercepts, turn)
            counts = turn.tool_counts or {tool: 1 for tool in turn.tools}
            tools_note = ",".join(f"{tool}:{n}" for tool, n in sorted(counts.items()))
            targets = ";".join(f"{t}:{p}" for t, p in turn.paths)
            top_turns.append(
                {
                    "title": row["title"],
                    "session_id": row["session_id"],
                    "turn": turn.index,
                    "tokens": turn.usage.get("total", 0),
                    "uncached": turn.usage.get("uncached", 0),
                    "cost_ticks": turn.usage.get("cost_ticks", 0),
                    "tools": tools_note,
                    "path_or_command": targets,
                    "same_path_reads": turn.same_path_reads,
                    "same_command_repeats": turn.same_command_repeats,
                    "loop": turn.loop_line,
                }
            )
    top_turns.sort(
        key=lambda item: (
            -int(item["cost_ticks"]),
            -int(item["uncached"]),
            -int(item["tokens"]),
        )
    )
    lines = ["status: PASS", f"sessions: {len(rows)}", "", "## sessions"]
    lines.extend(
        _table(
            ["title", "uncached", "usd", "tokens", "context", "compacts", "tax", "id"],
            [
                [
                    str(row["title"]),
                    str(row.get("uncached_tokens", 0)),
                    _fmt_usd(int(row.get("cost_ticks") or 0)),
                    str(row.get("tokens", 0)),
                    str(row.get("context_tokens", 0)),
                    str(row.get("compaction_count", 0)),
                    str(row.get("compaction_tax", 0)),
                    str(row["session_id"]),
                ]
                for row in rows
            ],
        )
    )
    lines.extend(["", "## tools"])
    lines.extend(
        _table(
            ["tool", "count", "turns", "uncached", "usd"],
            [
                [
                    key,
                    str(stats.get("count", 0)),
                    str(stats.get("turns", 0)),
                    str(stats.get("uncached", 0)),
                    _fmt_usd(int(stats.get("cost_ticks") or 0)),
                ]
                for key, stats in gsl.sort_hist(tools)[:30]
            ],
        )
    )
    lines.extend(["", "## top turns"])
    lines.extend(
        _table(
            ["usd", "uncached", "tokens", "turn", "tools", "path_or_command", "same_path_reads", "same_command_repeats", "loop", "title"],
            [
                [
                    _fmt_usd(int(item["cost_ticks"])),
                    str(item["uncached"]),
                    str(item["tokens"]),
                    str(item["turn"]),
                    item["tools"],
                    item.get("path_or_command", ""),
                    str(item.get("same_path_reads", 0)),
                    str(item.get("same_command_repeats", 0)),
                    str(item.get("loop", "")),
                    item["title"],
                ]
                for item in top_turns[:20]
            ],
        )
    )
    compact_rows = [
        row
        for row in rows
        if int(row.get("compaction_count") or 0)
        or int(row.get("compaction_tax") or 0)
    ]
    lines.extend(["", "## compaction"])
    lines.extend(
        _table(
            ["title", "compacts", "before", "context", "tax", "usd"],
            [
                [
                    str(row["title"]),
                    str(row.get("compaction_count", 0)),
                    str(row.get("tokens_before_compaction", 0)),
                    str(row.get("context_tokens", 0)),
                    str(row.get("compaction_tax", 0)),
                    _fmt_usd(int(row.get("cost_ticks") or 0)),
                ]
                for row in compact_rows
            ],
        )
    )
    lines.extend(["", "## intercepts"])
    lines.extend(
        _table(
            ["label", "count", "turns", "uncached", "usd"],
            [
                [
                    key,
                    str(stats.get("count", 0)),
                    str(stats.get("turns", 0)),
                    str(stats.get("uncached", 0)),
                    _fmt_usd(int(stats.get("cost_ticks") or 0)),
                ]
                for key, stats in gsl.sort_hist(intercepts)
            ],
        )
    )
    lines.extend(["", "## paths"])
    lines.extend(
        _table(
            ["count", "uncached", "usd", "tool_path"],
            [
                [
                    str(stats.get("count", 0)),
                    str(stats.get("uncached", 0)),
                    _fmt_usd(int(stats.get("cost_ticks") or 0)),
                    key.replace("\t", " "),
                ]
                for key, stats in gsl.sort_hist(paths)[:40]
            ],
        )
    )
    return "\n".join(lines) + "\n"


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Write a paste-sized Grok session burn report."
    )
    parser.add_argument("--root", default=".", help="Repo root")
    parser.add_argument("--pack-dir", default="", help="Existing pack dir")
    parser.add_argument("--session-root", default="", help="Live session dir")
    parser.add_argument("--since", default="", help="Local start time")
    parser.add_argument("--until", default="", help="Local end time")
    parser.add_argument("--top", type=int, default=10)
    parser.add_argument("--out-dir", default="")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    repo_root = Path(args.root).expanduser().resolve()
    if args.pack_dir:
        pack_dir = Path(args.pack_dir).expanduser().resolve()
    else:
        try:
            pack_dir = agent_log.agent_log_dir("grok-sessions-pack", repo_root)
        except (OSError, ValueError):
            pack_dir = repo_root / "_logs" / "grok-sessions-pack"
    if args.out_dir:
        out_dir = Path(args.out_dir).expanduser().resolve()
    else:
        out_dir = agent_log.ensure_agent_log_dir("grok-sessions-report", repo_root)
    now = packer._now_local()
    until = packer._parse_when(args.until or None, now)
    since = packer._parse_when(args.since or None, until - timedelta(hours=24))
    if args.session_root:
        rows = packer.collect_sessions(
            Path(args.session_root).expanduser().resolve(),
            since,
            until,
        )[: max(1, int(args.top))]
    elif (pack_dir / "summary_Summed.json").is_file():
        rows = load_from_pack(pack_dir)
    else:
        rows = packer.collect_sessions(
            packer.discover_session_root(repo_root, None),
            since,
            until,
        )[: max(1, int(args.top))]
    body = build_report(rows)
    _write(out_dir / "summary.txt", body)
    _write(
        out_dir / "meta.json",
        json.dumps(
            {"sessions": len(rows), "ids": [row["session_id"] for row in rows]},
            indent=2,
        ),
    )
    print(body, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
