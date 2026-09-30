#!/usr/bin/env python3
"""Pack and report What Dwells Below Grok sessions in a week window."""

from __future__ import annotations

import argparse
import os
import sys
from collections import Counter
from datetime import datetime
from pathlib import Path
from typing import Any

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
import grok_session_lib as gsl
import pack_grok_sessions as packer
import report_grok_sessions as reporter

WEEK5_SINCE = "2026-09-18"
WEEK5_UNTIL = "2026-09-29"
DEFAULT_TOP = 40
TEMP_MARKS = (
    "appdata\\local\\temp",
    "appdata/local/temp",
    "/tmp/",
    "\\temp\\",
    "_logs/agent-py",
    "wdb_match_proto",
    "wdb_report_peek",
)
TEXT_LIMIT = 220
PER_SESSION_THOUGHTS = 4


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Pack every WDB Grok session root in a week window."
    )
    parser.add_argument("--root", default=".")
    parser.add_argument("--since", default=WEEK5_SINCE)
    parser.add_argument("--until", default=WEEK5_UNTIL)
    parser.add_argument("--top", type=int, default=DEFAULT_TOP)
    parser.add_argument("--out-dir", default="")
    parser.add_argument("--pack-dir", default="")
    parser.add_argument("--copy-path", default="")
    parser.add_argument("--what-if", action="store_true")
    return parser.parse_args(argv)


def grok_sessions_home() -> Path:
    home = Path(os.environ.get("GROK_HOME", str(Path.home() / ".grok")))
    return home / "sessions"


def desktop_copy_path() -> Path:
    home = Path.home()
    for name in ("Desktop", "desktop"):
        path = home / name
        if path.is_dir():
            return path / "copy.txt"
    onedrive = home / "OneDrive" / "Desktop" / "copy.txt"
    if onedrive.parent.is_dir():
        return onedrive
    return home / "Desktop" / "copy.txt"


def discover_repo_roots(repo_root: Path) -> list[Path]:
    sessions = grok_sessions_home()
    found: list[Path] = []
    if not sessions.is_dir():
        return found
    encoded = packer._encode_cwd(repo_root)
    for child in sessions.iterdir():
        if not child.is_dir():
            continue
        name = child.name.lower()
        hit = child.name == encoded
        if "whatdwells" in name or "what-dwells" in name:
            hit = True
        marker = child / ".cwd"
        if marker.is_file():
            body = (gsl.read_text(marker) or "").strip()
            if body:
                try:
                    if Path(body).expanduser().resolve() == repo_root:
                        hit = True
                except OSError:
                    pass
        if hit:
            found.append(child)
    found.sort(key=lambda path: path.name)
    return found


def collect_week(
    repo_root: Path,
    since: datetime,
    until: datetime,
    top: int,
) -> tuple[list[Path], list[dict[str, Any]]]:
    roots = discover_repo_roots(repo_root)
    if not roots:
        roots = [packer.discover_session_root(repo_root, None)]
    merged: dict[str, dict[str, Any]] = {}
    for root in roots:
        for row in packer.collect_sessions(root, since, until):
            merged[str(row["session_id"])] = row
    rows = list(merged.values())
    rows.sort(
        key=lambda row: (
            -int(row.get("tokens") or 0),
            -int(row.get("uncached_tokens") or 0),
            -int(row.get("cost_ticks") or 0),
            row.get("when") or datetime.min,
            row.get("session_id") or "",
        )
    )
    return roots, rows[: max(1, top)]


def _text_blob(obj: Any) -> str:
    if isinstance(obj, str):
        return obj
    if isinstance(obj, dict):
        parts: list[str] = []
        for key in ("text", "content"):
            val = obj.get(key)
            if isinstance(val, str) and val.strip():
                parts.append(val)
            elif isinstance(val, (dict, list)):
                inner = _text_blob(val)
                if inner:
                    parts.append(inner)
        return "\n".join(parts)
    if isinstance(obj, list):
        return "\n".join(_text_blob(item) for item in obj)
    return ""


def _snip(text: str, limit: int = TEXT_LIMIT) -> str:
    body = " ".join(text.split())
    if len(body) <= limit:
        return body
    return body[: limit - 3] + "..."


def _iter_payloads(path: Path):
    if not path.is_file():
        return
    for row in gsl.iter_jsonl(path):
        payload = gsl.unwrap_update(row) or row
        yield row, payload


def _temp_key(label: str) -> str:
    low = label.replace("\\", "/").lower()
    if "/frame_" in low and low.endswith(".png"):
        return low.rsplit("/", 1)[0] + "/frame_*.png"
    return _snip(label, 140)


def scan_kinds(row: dict[str, Any]) -> tuple[Counter, list[str], list[str], list[str]]:
    session_dir = Path(row["dir"])
    kinds: Counter = Counter()
    thoughts: list[str] = []
    temps: list[str] = []
    py_c: list[str] = []
    seen_temp: set[str] = set()
    for src_name in ("updates.jsonl",):
        for raw, payload in _iter_payloads(session_dir / src_name):
            kind = str(gsl.event_kind(raw, payload) or raw.get("type") or "blank")
            kinds[kind] += 1
            if kind == "agent_thought_chunk":
                blob = _text_blob(payload).strip()
                if blob:
                    thoughts.append(_snip(blob))
            path = (gsl.event_path(raw, payload) or "").strip()
            cmd = (gsl.raw_command(payload) or "").strip()
            blob = f"{path} {cmd}".lower()
            if "python -c" in blob or "python3 -c" in blob:
                if cmd:
                    py_c.append(_snip(cmd, 140))
            if any(mark in blob for mark in TEMP_MARKS):
                key = _temp_key(path or cmd)
                if key and key not in seen_temp:
                    seen_temp.add(key)
                    temps.append(key)
    return kinds, thoughts, temps, py_c


def build_extract(rows: list[dict[str, Any]], roots: list[Path]) -> str:
    paid = [row for row in rows if int(row.get("tokens") or 0) > 0]
    lines = [
        "## week extract",
        f"roots: {len(roots)}",
        f"sessions: {len(paid)} paid / {len(rows)} packed",
    ]
    all_kinds: Counter = Counter()
    for row in paid:
        kinds, thoughts, temps, py_c = scan_kinds(row)
        all_kinds.update(kinds)
        lines.append(
            f"- {row.get('session_id')} tokens={int(row.get('tokens') or 0)} "
            f"thoughts={len(thoughts)} temp={len(temps)} python_c={len(py_c)} "
            f"title={row.get('title', '')}"
        )
        for thought in thoughts[:PER_SESSION_THOUGHTS]:
            lines.append(f"  think: {thought}")
        extra = len(thoughts) - PER_SESSION_THOUGHTS
        if extra > 0:
            lines.append(f"  think_more: {extra}")
        for temp in temps[:8]:
            lines.append(f"  temp: {temp}")
        if len(temps) > 8:
            lines.append(f"  temp_more: {len(temps) - 8}")
        for cmd in py_c[:4]:
            lines.append(f"  python_c: {cmd}")
        if len(py_c) > 4:
            lines.append(f"  python_c_more: {len(py_c) - 4}")
    lines.append("## kinds")
    for kind, count in all_kinds.most_common():
        if kind.startswith("tool_"):
            continue
        lines.append(f"{count:7} {kind}")
    return "\n".join(lines) + "\n"


def write_packet(path: Path, chunks: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(item for item in chunks if item), encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    repo_root = Path(args.root).expanduser().resolve()
    now = packer._now_local()
    until = packer._parse_when(args.until or None, now)
    since = packer._parse_when(args.since or None, until)
    roots, rows = collect_week(repo_root, since, until, int(args.top))
    extract = build_extract(rows, roots)
    copy_path = (
        Path(args.copy_path).expanduser()
        if args.copy_path
        else desktop_copy_path()
    )
    if args.what_if:
        write_packet(copy_path, [extract])
        print(f"copy: {copy_path}")
        print("RESULT what-if=PASS")
        return 0
    if args.pack_dir:
        pack_dir = Path(args.pack_dir).expanduser().resolve()
    else:
        pack_dir = agent_log.ensure_agent_log_dir("grok-sessions-pack", repo_root)
    if args.out_dir:
        out_dir = Path(args.out_dir).expanduser().resolve()
    else:
        out_dir = agent_log.ensure_agent_log_dir("grok-sessions-week", repo_root)
    out_dir.mkdir(parents=True, exist_ok=True)
    packer.write_pack(rows, pack_dir)
    packer.write_summary(
        pack_dir / "summary.txt",
        ok=True,
        session_root=grok_sessions_home(),
        since=since,
        until=until,
        rows=rows,
        out_dir=pack_dir,
    )
    report_rc = reporter.main(
        [
            "--root",
            str(repo_root),
            "--pack-dir",
            str(pack_dir),
            "--out-dir",
            str(out_dir),
        ]
    )
    extract_path = out_dir / "extract.txt"
    extract_path.write_text(extract, encoding="utf-8")
    tools_hist = out_dir / "tools_histogram_Summed.txt"
    chunks = []
    pack_summary = pack_dir / "summary.txt"
    week_summary = out_dir / "summary.txt"
    if pack_summary.is_file():
        chunks.append(pack_summary.read_text(encoding="utf-8"))
    if week_summary.is_file():
        body = week_summary.read_text(encoding="utf-8")
        keep: list[str] = []
        skip = False
        for line in body.splitlines():
            if line.startswith("## top turns") or line.startswith("## paths"):
                skip = True
                continue
            if line.startswith("## ") and skip:
                skip = False
            if skip:
                continue
            keep.append(line)
        chunks.append("\n".join(keep) + "\n")
    if tools_hist.is_file():
        chunks.append(tools_hist.read_text(encoding="utf-8"))
    chunks.append(extract)
    write_packet(copy_path, chunks)
    print(f"copy: {copy_path}")
    mark = "PASS" if report_rc == 0 else "FAIL"
    print(f"RESULT pack=PASS report={mark} week={len(rows)}")
    return 0 if report_rc == 0 else 1


if __name__ == "__main__":
    sys.exit(int(main()))
