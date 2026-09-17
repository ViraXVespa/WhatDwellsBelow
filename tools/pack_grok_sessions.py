#!/usr/bin/env python3
"""Pack the costliest Grok CLI sessions in a time window for paste-over."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any
from urllib.parse import quote

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import grok_session_lib as gsl

PACK_FILES: tuple[tuple[str, str], ...] = (
    ("summary.json", "summary"),
    ("signals.json", "signals"),
    ("updates.jsonl", "updates"),
    ("chat_history.jsonl", "chat_history"),
    ("system_prompt.txt", "system_prompt"),
    ("prompt_context.json", "prompt_context"),
)

REPORT_STEMS = (
    "tools_histogram",
    "turns_top",
    "compaction",
    "paths_histogram",
    "intercepts",
)


def _now_local() -> datetime:
    return datetime.now().astimezone()


def _parse_when(raw: str | None, fallback: datetime) -> datetime:
    if raw is None or not raw.strip():
        return fallback
    text = raw.strip()
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    for fmt in (
        "%Y-%m-%dT%H:%M:%S.%f%z",
        "%Y-%m-%dT%H:%M:%S%z",
        "%Y-%m-%dT%H:%M:%S.%f",
        "%Y-%m-%dT%H:%M:%S",
        "%Y-%m-%d %H:%M:%S",
        "%Y-%m-%d %H:%M",
        "%Y-%m-%d",
    ):
        try:
            parsed = datetime.strptime(text, fmt)
            if parsed.tzinfo is None:
                return parsed.replace(tzinfo=fallback.tzinfo)
            return parsed.astimezone(fallback.tzinfo)
        except ValueError:
            continue
    raise SystemExit(f"unrecognized datetime: {raw}")


def _as_dt(value: Any, tzinfo) -> datetime | None:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        raw = float(value)
        if raw > 1e12:
            raw /= 1000.0
        return datetime.fromtimestamp(raw, tz=tzinfo)
    if not isinstance(value, str) or not value.strip():
        return None
    text = value.strip()
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    try:
        parsed = datetime.fromisoformat(text)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=tzinfo)
    return parsed.astimezone(tzinfo)


def _session_when(summary: Any, session_dir: Path, tzinfo) -> datetime | None:
    if isinstance(summary, dict):
        for key in (
            "last_active_at",
            "updated_at",
            "updatedAt",
            "modifiedAt",
            "created_at",
            "createdAt",
        ):
            hit = _as_dt(summary.get(key), tzinfo)
            if hit is not None:
                return hit
    try:
        return datetime.fromtimestamp(session_dir.stat().st_mtime, tz=tzinfo)
    except OSError:
        return None


def _session_title(summary: Any, session_id: str) -> str:
    if isinstance(summary, dict):
        for key in (
            "generated_title",
            "session_summary",
            "title",
            "summary",
            "name",
        ):
            val = summary.get(key)
            if isinstance(val, str) and val.strip():
                return val.strip()
    return session_id


def _encode_cwd(cwd: Path) -> str:
    return quote(str(cwd), safe="")


def _looks_like_session(path: Path) -> bool:
    if not path.is_dir():
        return False
    return any((path / name).is_file() for name, _stem in PACK_FILES)


def discover_session_root(repo_root: Path, override: str | None) -> Path:
    if override:
        return Path(override).expanduser()
    grok_home = Path(os.environ.get("GROK_HOME", str(Path.home() / ".grok")))
    sessions = grok_home / "sessions"
    encoded = _encode_cwd(repo_root)
    direct = sessions / encoded
    if direct.is_dir():
        return direct
    if sessions.is_dir():
        for child in sessions.iterdir():
            marker = child / ".cwd"
            if not marker.is_file():
                continue
            body = (gsl.read_text(marker) or "").strip()
            if body and Path(body).resolve() == repo_root:
                return child
    return direct


def collect_sessions(
    session_root: Path,
    since: datetime,
    until: datetime,
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    if not session_root.is_dir():
        return rows
    tzinfo = since.tzinfo
    for child in session_root.iterdir():
        if not _looks_like_session(child):
            continue
        summary = gsl.load_json(child / "summary.json")
        when = _session_when(summary, child, tzinfo)
        if when is None or when < since or when > until:
            continue
        metrics = gsl.session_metrics(child)
        row: dict[str, Any] = {
            "session_id": child.name,
            "dir": child,
            "summary": summary,
            "title": _session_title(summary, child.name),
            "when": when,
        }
        row.update(metrics)
        rows.append(row)
    rows.sort(
        key=lambda row: (
            -int(row["tokens"]),
            -int(row["uncached_tokens"]),
            -int(row["cost_ticks"]),
            row["when"],
            row["session_id"],
        )
    )
    return rows


def _clear_out_dir(out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    stems = {stem for _name, stem in PACK_FILES}
    stems.update(REPORT_STEMS)
    for path in out_dir.iterdir():
        if not path.is_file():
            continue
        if path.name == "summary.txt":
            path.unlink()
            continue
        for stem in stems:
            if path.name.startswith(stem + "_"):
                path.unlink()
                break


def _copy_ranked(row: dict[str, Any], rank: int, out_dir: Path) -> dict[str, bool]:
    present: dict[str, bool] = {}
    src_dir: Path = row["dir"]
    for name, stem in PACK_FILES:
        src = src_dir / name
        dest = out_dir / f"{stem}_{rank}{src.suffix}"
        if src.is_file():
            shutil.copy2(src, dest)
            present[name] = True
        else:
            present[name] = False
    return present


def _write_json(path: Path, payload: Any) -> None:
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def _record_meta(
    rank: int, row: dict[str, Any], source_name: str, missing: bool
) -> dict[str, Any]:
    return {
        "rank": rank,
        "session_id": row["session_id"],
        "title": row["title"],
        "tokens": row["tokens"],
        "uncached_tokens": row.get("uncached_tokens", 0),
        "cost_ticks": row.get("cost_ticks", 0),
        "context_tokens": row.get("context_tokens", 0),
        "updated_at": row["when"].isoformat(),
        "source": source_name,
        "missing": missing,
    }


def _write_summed_json(
    out_dir: Path,
    stem: str,
    suffix: str,
    rows: list[dict[str, Any]],
    source_name: str,
) -> None:
    records: list[dict[str, Any]] = []
    for rank, row in enumerate(rows, start=1):
        src = row["dir"] / source_name
        exists = src.is_file()
        data: Any = None
        if exists:
            if suffix == ".json":
                data = gsl.load_json(src)
            else:
                data = gsl.read_text(src)
        rec = _record_meta(rank, row, source_name, not exists)
        rec["data"] = data
        records.append(rec)
    _write_json(out_dir / f"{stem}_Summed{suffix}", records)


def _write_summed_jsonl(
    out_dir: Path,
    stem: str,
    rows: list[dict[str, Any]],
    source_name: str,
) -> None:
    dest = out_dir / f"{stem}_Summed.jsonl"
    with dest.open("w", encoding="utf-8", newline="\n") as out:
        for rank, row in enumerate(rows, start=1):
            src = row["dir"] / source_name
            marker = _record_meta(rank, row, source_name, not src.is_file())
            marker["_pack"] = True
            out.write(json.dumps(marker, ensure_ascii=False) + "\n")
            if not src.is_file():
                continue
            with src.open("r", encoding="utf-8-sig") as fh:
                for line in fh:
                    if line.endswith("\n"):
                        out.write(line)
                    else:
                        out.write(line + "\n")


def _write_summed_txt(
    out_dir: Path,
    stem: str,
    rows: list[dict[str, Any]],
    source_name: str,
) -> None:
    dest = out_dir / f"{stem}_Summed.txt"
    chunks: list[str] = []
    for rank, row in enumerate(rows, start=1):
        src = row["dir"] / source_name
        chunks.append(
            f"===== rank={rank} session_id={row['session_id']} "
            f"tokens={row['tokens']} missing={not src.is_file()} ====="
        )
        if src.is_file():
            chunks.append(gsl.read_text(src) or "")
        else:
            chunks.append("")
    dest.write_text("\n".join(chunks).rstrip() + "\n", encoding="utf-8")


def _hist_payload(bucket: dict[str, dict[str, int]]) -> list[dict[str, Any]]:
    rows = []
    for key, stats in gsl.sort_hist(bucket):
        item = {"key": key}
        item.update(stats)
        rows.append(item)
    return rows


def _write_hist_pair(
    out_dir: Path, stem: str, rank: int | None, bucket: dict[str, dict[str, int]]
) -> None:
    payload = _hist_payload(bucket)
    suffix = "Summed" if rank is None else str(rank)
    _write_json(out_dir / f"{stem}_{suffix}.json", payload)
    lines = ["key\tcount\tturns\ttokens\tuncached\tcost_ticks"]
    for item in payload[:80]:
        lines.append(
            f"{item['key']}\t{item.get('count', 0)}\t{item.get('turns', 0)}\t"
            f"{item.get('tokens', 0)}\t{item.get('uncached', 0)}\t"
            f"{item.get('cost_ticks', 0)}"
        )
    (out_dir / f"{stem}_{suffix}.txt").write_text(
        "\n".join(lines) + "\n", encoding="utf-8"
    )


def _write_reports(rows: list[dict[str, Any]], out_dir: Path) -> None:
    tools_all: dict[str, dict[str, int]] = {}
    paths_all: dict[str, dict[str, int]] = {}
    intercepts_all: dict[str, dict[str, int]] = {}
    top_turns: list[dict[str, Any]] = []
    compact_rows: list[dict[str, Any]] = []
    for rank, row in enumerate(rows, start=1):
        tools: dict[str, dict[str, int]] = {}
        paths: dict[str, dict[str, int]] = {}
        intercepts: dict[str, dict[str, int]] = {}
        turns = row.get("turns") or []
        for turn in turns:
            gsl.accumulate_turn(tools, paths, intercepts, turn)
            gsl.accumulate_turn(tools_all, paths_all, intercepts_all, turn)
            top_turns.append(
                {
                    "rank": rank,
                    "session_id": row["session_id"],
                    "title": row["title"],
                    "turn": turn.index,
                    "tokens": turn.usage.get("total", 0),
                    "uncached": turn.usage.get("uncached", 0),
                    "cost_ticks": turn.usage.get("cost_ticks", 0),
                    "tools": list(turn.tools),
                    "intercepts": list(turn.intercepts),
                    "compact": turn.compact,
                }
            )
        _write_hist_pair(out_dir, "tools_histogram", rank, tools)
        _write_hist_pair(out_dir, "paths_histogram", rank, paths)
        _write_hist_pair(out_dir, "intercepts", rank, intercepts)
        compact_rows.append(
            {
                "rank": rank,
                "session_id": row["session_id"],
                "title": row["title"],
                "compaction_count": row.get("compaction_count", 0),
                "compact_events": row.get("compact_events", 0),
                "tokens_before_compaction": row.get(
                    "tokens_before_compaction", 0
                ),
                "context_tokens": row.get("context_tokens", 0),
                "completed_turns": row.get("completed_turns", 0),
                "compaction_tax": row.get("compaction_tax", 0),
            }
        )
    _write_hist_pair(out_dir, "tools_histogram", None, tools_all)
    _write_hist_pair(out_dir, "paths_histogram", None, paths_all)
    _write_hist_pair(out_dir, "intercepts", None, intercepts_all)
    top_turns.sort(
        key=lambda item: (
            -int(item["cost_ticks"]),
            -int(item["uncached"]),
            -int(item["tokens"]),
        )
    )
    _write_json(out_dir / "turns_top_Summed.json", top_turns[:50])
    lines = ["session\tturn\ttokens\tuncached\tcost_ticks\ttools\ttitle"]
    for item in top_turns[:30]:
        tools = ",".join(item["tools"])
        lines.append(
            f"{item['session_id']}\t{item['turn']}\t{item['tokens']}\t"
            f"{item['uncached']}\t{item['cost_ticks']}\t{tools}\t{item['title']}"
        )
    (out_dir / "turns_top_Summed.txt").write_text(
        "\n".join(lines) + "\n", encoding="utf-8"
    )
    _write_json(out_dir / "compaction_Summed.json", compact_rows)
    clines = ["rank\tid\tcompacts\tbefore\tcontext\tturns\ttax\ttitle"]
    for item in compact_rows:
        clines.append(
            f"{item['rank']}\t{item['session_id']}\t"
            f"{item['compaction_count']}\t{item['tokens_before_compaction']}\t"
            f"{item['context_tokens']}\t{item['completed_turns']}\t"
            f"{item['compaction_tax']}\t{item['title']}"
        )
    (out_dir / "compaction_Summed.txt").write_text(
        "\n".join(clines) + "\n", encoding="utf-8"
    )


def write_pack(rows: list[dict[str, Any]], out_dir: Path) -> None:
    _clear_out_dir(out_dir)
    for rank, row in enumerate(rows, start=1):
        row["present"] = _copy_ranked(row, rank, out_dir)
    for name, stem in PACK_FILES:
        suffix = Path(name).suffix
        if suffix == ".jsonl":
            _write_summed_jsonl(out_dir, stem, rows, name)
        elif suffix == ".txt":
            _write_summed_txt(out_dir, stem, rows, name)
        else:
            _write_summed_json(out_dir, stem, suffix, rows, name)
    _write_reports(rows, out_dir)


def write_summary(
    path: Path,
    *,
    ok: bool,
    session_root: Path,
    since: datetime,
    until: datetime,
    rows: list[dict[str, Any]],
    out_dir: Path,
    error: str = "",
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        f"status: {'PASS' if ok else 'FAIL'}",
        f"session_root: {session_root}",
        f"since: {since.isoformat()}",
        f"until: {until.isoformat()}",
        f"packed: {len(rows)}",
        f"out_dir: {out_dir}",
    ]
    if error:
        lines.append(f"error: {error}")
    for rank, row in enumerate(rows, start=1):
        present = row.get("present") or {}
        have = ",".join(
            stem for name, stem in PACK_FILES if present.get(name)
        )
        lines.append(
            f"{rank}. tokens={row['tokens']} "
            f"uncached={row.get('uncached_tokens', 0)} "
            f"cost_ticks={row.get('cost_ticks', 0)} "
            f"context={row.get('context_tokens', 0)} "
            f"turns={row.get('completed_turns', 0)}/"
            f"{row.get('signal_turns', 0)} "
            f"tools={row.get('tool_calls', 0)} "
            f"id={row['session_id']} "
            f"when={row['when'].isoformat()} "
            f"title={row['title']} files={have}"
        )
    summed = ", ".join(
        f"{stem}_Summed{Path(name).suffix}" for name, stem in PACK_FILES
    )
    lines.append(f"summed: {summed}")
    lines.append(
        "reports: tools_histogram_Summed.txt, paths_histogram_Summed.txt, "
        "intercepts_Summed.txt, turns_top_Summed.txt, compaction_Summed.txt"
    )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Copy the top Grok sessions in a time range into _logs."
    )
    parser.add_argument("--root", default=".", help="Repo root (default: .)")
    parser.add_argument("--session-root", default="", help="Override session dir")
    parser.add_argument("--since", default="", help="Local start time")
    parser.add_argument("--until", default="", help="Local end time")
    parser.add_argument("--top", type=int, default=10, help="Max sessions")
    parser.add_argument(
        "--include-empty",
        action="store_true",
        help="Keep zero-token plan stubs in the pack",
    )
    parser.add_argument(
        "--out-dir",
        default="",
        help="Output dir (default: <root>/_logs/grok-sessions-pack)",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    repo_root = Path(args.root).expanduser().resolve()
    now = _now_local()
    until = _parse_when(args.until or None, now)
    since = _parse_when(args.since or None, until - timedelta(hours=24))
    if since > until:
        raise SystemExit("--since must be <= --until")
    top = max(1, int(args.top))
    session_root = discover_session_root(
        repo_root, args.session_root or None
    ).resolve()
    out_dir = (
        Path(args.out_dir).expanduser().resolve()
        if args.out_dir
        else (repo_root / "_logs" / "grok-sessions-pack")
    )
    summary_path = out_dir / "summary.txt"
    if not session_root.is_dir():
        write_summary(
            summary_path,
            ok=False,
            session_root=session_root,
            since=since,
            until=until,
            rows=[],
            out_dir=out_dir,
            error="session root missing",
        )
        print(summary_path.read_text(encoding="utf-8"), end="")
        return 1
    rows = collect_sessions(session_root, since, until)
    if not args.include_empty:
        rows = [
            row for row in rows
            if int(row.get("tokens") or 0)
            or int(row.get("completed_turns") or 0)
        ]
    rows = rows[:top]
    write_pack(rows, out_dir)
    write_summary(
        summary_path,
        ok=True,
        session_root=session_root,
        since=since,
        until=until,
        rows=rows,
        out_dir=out_dir,
    )
    print(summary_path.read_text(encoding="utf-8"), end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
