#!/usr/bin/env python3
"""List, show, add, status, or remove items in design/grok-bot-opt.md.

    python tools/bot_opt.py --list
    python tools/bot_opt.py --id opt-001
    python tools/bot_opt.py --add --title "..." --cluster Hub --files a.gd,b.gd --body-file path
    python tools/bot_opt.py --add --title "..." --cluster Hub --body "one line"
    python tools/bot_opt.py --replace opt-001 --title "..." --cluster Hub --body-file path
    python tools/bot_opt.py --status opt-001=done
    python tools/bot_opt.py --remove opt-001

Writes _logs/bot-opt/summary.txt. Agents read that file only.
Do not open design/grok-bot-opt.md to park or list items.
"""
from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

import agent_log
import md_format_lib as md

QUEUE_REL = "design/grok-bot-opt.md"
BEGIN = "<!-- bot-opt:begin -->"
END = "<!-- bot-opt:end -->"
NEXT_RE = re.compile(r"<!-- bot-opt:next=(\d+) -->")
HEAD_RE = re.compile(r"^### (opt-\d+) \((pending|done|dropped)\)\s*$")
STATUSES = ("pending", "done", "dropped")
TITLE_MAX = 120
CLUSTER_MAX = 80


@dataclass
class Item:
    item_id: str
    status: str
    title: str
    cluster: str
    files: list[str]
    suggestion: str


def posix(rel: str) -> str:
    return md.posix(rel)


def norm_id(raw: str) -> str | None:
    s = raw.strip().lower()
    if s.startswith("opt-"):
        s = s[4:]
    if not s.isdigit():
        return None
    return f"opt-{int(s):03d}"


def parse_files(raw: str) -> list[str]:
    ticks = md.tick_tokens(raw)
    if ticks:
        return ticks
    out: list[str] = []
    for part in raw.split(","):
        token = posix(part)
        if token:
            out.append(token)
    return out


def format_files(files: list[str]) -> str:
    if not files:
        return ""
    return ", ".join(md.tick_wrap(p) for p in files)


def _write(path: Path, lines: list[str]) -> None:
    md.write_lines(path, lines)


def render_item(item: Item) -> str:
    lines = [
        f"### {item.item_id} ({item.status})",
        f"- Title: {item.title}",
        f"- Cluster: {item.cluster}",
        f"- Files: {format_files(item.files)}".rstrip(),
        "",
        item.suggestion.rstrip(),
    ]
    return "\n".join(lines)


def render_block(next_id: int, items: list[Item]) -> str:
    lines = [BEGIN, f"<!-- bot-opt:next={next_id} -->"]
    if items:
        lines.append("")
        lines.append("\n\n".join(render_item(it) for it in items))
        lines.append("")
    lines.append(END)
    return "\n".join(lines)


def parse_item(block: str) -> Item | str:
    lines = block.splitlines()
    if not lines:
        return "empty-item"
    m = HEAD_RE.match(lines[0])
    if not m:
        return "bad-heading"
    item_id, status = m.group(1), m.group(2)
    title = ""
    cluster = ""
    files: list[str] = []
    body_start = 1
    i = 1
    while i < len(lines):
        line = lines[i]
        if line.startswith("- Title:"):
            title = line[len("- Title:") :].strip()
        elif line.startswith("- Cluster:"):
            cluster = line[len("- Cluster:") :].strip()
        elif line.startswith("- Files:"):
            files = parse_files(line[len("- Files:") :])
        elif line.strip() == "":
            i += 1
            body_start = i
            break
        else:
            return f"bad-meta:{item_id}"
        i += 1
        body_start = i
    suggestion = "\n".join(lines[body_start:]).strip()
    if not title or not cluster:
        return f"missing-meta:{item_id}"
    return Item(item_id, status, title, cluster, files, suggestion)


def parse_queue(text: str) -> tuple[str, int, list[Item], str] | str:
    parts = md.split_marker_block(text, BEGIN, END)
    if parts is None:
        return "missing-markers"
    prefix, region, suffix = parts
    # region is begin..end inclusive; inner historically excluded END
    inner = region[: -len(END)]
    nm = NEXT_RE.search(inner)
    if not nm:
        return "missing-next"
    next_id = int(nm.group(1))
    rest = inner[nm.end() :]
    chunks: list[str] = []
    current: list[str] = []
    for line in rest.splitlines():
        if HEAD_RE.match(line):
            if current:
                chunks.append("\n".join(current).strip())
            current = [line]
            continue
        if current:
            current.append(line)
    if current:
        chunks.append("\n".join(current).strip())
    leftover = rest
    if chunks:
        leftover = rest.split(chunks[0], 1)[0]
    if leftover.strip() and leftover.strip() not in {BEGIN, ""}:
        # Allow only begin/next already consumed; leftover before first heading
        # must be whitespace.
        pre = rest
        if chunks:
            pre = rest[: rest.find(chunks[0])]
        if pre.strip():
            return "garbage-in-queue"
    items: list[Item] = []
    for chunk in chunks:
        parsed = parse_item(chunk)
        if isinstance(parsed, str):
            return parsed
        items.append(parsed)
    return prefix, next_id, items, suffix


def find_item(items: list[Item], item_id: str) -> Item | None:
    for item in items:
        if item.item_id == item_id:
            return item
    return None


def suggestion_block(suggestion: str) -> list[str]:
    return ["--- suggestion ---", suggestion.rstrip(), "---"]


def item_lines(item: Item, include_body: bool) -> list[str]:
    files = ", ".join(item.files) if item.files else ""
    lines = [
        f"id={item.item_id}",
        f"status={item.status}",
        f"cluster={item.cluster}",
        f"title={item.title}",
        f"files={files}",
    ]
    if include_body:
        body = item.suggestion.rstrip()
        lines.append(f"suggestion_lines={len(body.splitlines()) if body else 0}")
        lines.append("")
        lines.extend(suggestion_block(body))
    return lines


def counts(items: list[Item]) -> dict[str, int]:
    out = {name: 0 for name in STATUSES}
    for item in items:
        if item.status in out:
            out[item.status] += 1
    return out


def result_line(action: str, items: list[Item], extra: str = "") -> str:
    c = counts(items)
    parts = [
        f"RESULT action={action}",
        f"count={len(items)}",
        f"pending={c['pending']}",
        f"done={c['done']}",
        f"dropped={c['dropped']}",
    ]
    if extra:
        parts.append(extra)
    return " ".join(parts)


def load_body(args: argparse.Namespace, root: Path) -> tuple[str | None, str | None]:
    has_body = bool(args.body)
    has_file = bool(args.body_file)
    if has_body and has_file:
        return None, "need-body-xor-body-file"
    if not has_body and not has_file:
        return None, "need-body-xor-body-file"
    if has_body:
        return str(args.body).strip(), None
    path = Path(args.body_file)
    if not path.is_absolute():
        path = (root / path).resolve()
    if not path.is_file():
        return None, "missing-body-file"
    return path.read_text(encoding="utf-8").strip(), None


def note_fields(
    args: argparse.Namespace, root: Path
) -> tuple[tuple[str, str, list[str], str] | None, str | None]:
    title = (args.title or "").strip()
    cluster = (args.cluster or "").strip()
    body, body_err = load_body(args, root)
    if not title or not cluster:
        return None, "need-title-cluster"
    if body_err:
        return None, body_err
    if not body:
        return None, "empty-body"
    if len(title) > TITLE_MAX or len(cluster) > CLUSTER_MAX:
        return None, "title-or-cluster-too-long"
    if "\n" in title or "\n" in cluster:
        return None, "newline-in-meta"
    return (title, cluster, parse_files(args.files or ""), body), None


def main() -> int:
    ap = argparse.ArgumentParser(
        description="List or patch the Grok Bot optimization queue."
    )
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--list", action="store_true", help="List ids and titles")
    g.add_argument("--id", dest="show_id", help="Show one item (opt-001 or 1)")
    g.add_argument("--add", action="store_true", help="Append a pending item")
    g.add_argument("--replace", help="Replace note fields on an existing id")
    g.add_argument("--status", help="Set status: opt-001=done")
    g.add_argument("--remove", help="Delete an item by id")
    ap.add_argument("--title", default="", help="Title for --add / --replace")
    ap.add_argument("--cluster", default="", help="Cluster / system for --add / --replace")
    ap.add_argument("--files", default="", help="Comma-separated live paths for --add / --replace")
    ap.add_argument("--body", default="", help="Suggestion text for --add / --replace")
    ap.add_argument("--body-file", default="", help="UTF-8 file with suggestion text")
    ap.add_argument("--root", default=".", help="Repo root (default: cwd)")
    args = ap.parse_args()

    root = Path(args.root).resolve()
    queue_path = root / QUEUE_REL
    out_dir = agent_log.ensure_agent_log_dir("bot-opt", root)
    summary = out_dir / "summary.txt"
    out_dir.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).isoformat()

    action = "list"
    if args.show_id:
        action = "show"
    elif args.add:
        action = "add"
    elif args.replace:
        action = "replace"
    elif args.status:
        action = "status"
    elif args.remove:
        action = "remove"
    elif args.list:
        action = "list"

    lines = [
        f"bot-opt {action} {stamp}",
        f"root={root}",
        f"queue={QUEUE_REL}",
    ]

    if not queue_path.is_file():
        lines += ["", "RESULT action=" + action + " error=missing-queue"]
        _write(summary, lines)
        print(f"Summary -> {summary}")
        return 1

    parsed = parse_queue(queue_path.read_text(encoding="utf-8"))
    if isinstance(parsed, str):
        lines += ["", f"RESULT action={action} error={parsed}"]
        _write(summary, lines)
        print(f"Summary -> {summary}")
        return 1
    prefix, next_id, items, suffix = parsed

    def save(new_next: int, new_items: list[Item]) -> None:
        block = render_block(new_next, new_items)
        md.write_utf8(queue_path, prefix + block + suffix)

    if action == "list":
        lines.append(f"next={next_id:03d}")
        lines.append(f"count={len(items)}")
        lines.append("")
        for item in items:
            lines.extend(item_lines(item, include_body=False))
            lines.append("")
        lines.append(result_line("list", items))
        _write(summary, lines)
        print(f"count={len(items)} pending={counts(items)['pending']}")
        print(f"Summary -> {summary}")
        return 0

    if action == "show":
        item_id = norm_id(args.show_id or "")
        if item_id is None:
            lines += ["", "RESULT action=show error=bad-id"]
            _write(summary, lines)
            print(f"Summary -> {summary}")
            return 1
        item = find_item(items, item_id)
        if item is None:
            lines.append("ids=" + ", ".join(it.item_id for it in items))
            lines += ["", f"RESULT action=show error=not-found id={item_id}"]
            _write(summary, lines)
            print(f"Summary -> {summary}")
            return 1
        lines.append("")
        lines.extend(item_lines(item, include_body=True))
        lines.append("")
        lines.append(result_line("show", items, extra=f"id={item.item_id}"))
        _write(summary, lines)
        print(f"id={item.item_id} status={item.status}")
        print(f"Summary -> {summary}")
        return 0

    if action == "add":
        fields, ferr = note_fields(args, root)
        if ferr or fields is None:
            lines += ["", f"RESULT action=add error={ferr or 'need-title-cluster'}"]
            _write(summary, lines)
            print(f"Summary -> {summary}")
            return 1
        if next_id > 999:
            lines += ["", "RESULT action=add error=id-overflow"]
            _write(summary, lines)
            print(f"Summary -> {summary}")
            return 1
        title, cluster, files, body = fields
        item = Item(
            f"opt-{next_id:03d}",
            "pending",
            title,
            cluster,
            files,
            body,
        )
        new_items = items + [item]
        save(next_id + 1, new_items)
        lines.append("")
        lines.extend(item_lines(item, include_body=True))
        lines.append("")
        lines.append(result_line("add", new_items, extra=f"changed=1 id={item.item_id}"))
        _write(summary, lines)
        print(f"added={item.item_id}")
        print(f"Summary -> {summary}")
        return 0

    if action == "replace":
        item_id = norm_id(args.replace or "")
        if item_id is None:
            lines += ["", "RESULT action=replace error=bad-id"]
            _write(summary, lines)
            print(f"Summary -> {summary}")
            return 1
        item = find_item(items, item_id)
        if item is None:
            lines.append("ids=" + ", ".join(it.item_id for it in items))
            lines += ["", f"RESULT action=replace error=not-found id={item_id}"]
            _write(summary, lines)
            print(f"Summary -> {summary}")
            return 1
        fields, ferr = note_fields(args, root)
        if ferr or fields is None:
            lines += ["", f"RESULT action=replace error={ferr or 'need-title-cluster'}"]
            _write(summary, lines)
            print(f"Summary -> {summary}")
            return 1
        title, cluster, files, body = fields
        item.title = title
        item.cluster = cluster
        item.files = files
        item.suggestion = body
        save(next_id, items)
        lines.append("")
        lines.extend(item_lines(item, include_body=True))
        lines.append("")
        lines.append(result_line("replace", items, extra=f"changed=1 id={item.item_id}"))
        _write(summary, lines)
        print(f"replaced={item.item_id}")
        print(f"Summary -> {summary}")
        return 0

    if action == "status":
        raw = args.status or ""
        if "=" not in raw:
            lines += ["", "RESULT action=status error=bad-status"]
            _write(summary, lines)
            print(f"Summary -> {summary}")
            return 1
        id_raw, status_raw = raw.split("=", 1)
        item_id = norm_id(id_raw)
        status = status_raw.strip().lower()
        if item_id is None or status not in STATUSES:
            lines += ["", "RESULT action=status error=bad-status"]
            _write(summary, lines)
            print(f"Summary -> {summary}")
            return 1
        item = find_item(items, item_id)
        if item is None:
            lines.append("ids=" + ", ".join(it.item_id for it in items))
            lines += ["", f"RESULT action=status error=not-found id={item_id}"]
            _write(summary, lines)
            print(f"Summary -> {summary}")
            return 1
        item.status = status
        save(next_id, items)
        lines.append("")
        lines.extend(item_lines(item, include_body=True))
        lines.append("")
        lines.append(result_line("status", items, extra=f"changed=1 id={item.item_id}"))
        _write(summary, lines)
        print(f"id={item.item_id} status={item.status}")
        print(f"Summary -> {summary}")
        return 0

    item_id = norm_id(args.remove or "")
    if item_id is None:
        lines += ["", "RESULT action=remove error=bad-id"]
        _write(summary, lines)
        print(f"Summary -> {summary}")
        return 1
    item = find_item(items, item_id)
    if item is None:
        lines.append("ids=" + ", ".join(it.item_id for it in items))
        lines += ["", f"RESULT action=remove error=not-found id={item_id}"]
        _write(summary, lines)
        print(f"Summary -> {summary}")
        return 1
    new_items = [it for it in items if it.item_id != item_id]
    save(next_id, new_items)
    lines.append("")
    lines.extend(item_lines(item, include_body=False))
    lines.append("")
    lines.append(result_line("remove", new_items, extra=f"changed=1 id={item.item_id}"))
    _write(summary, lines)
    print(f"removed={item.item_id}")
    print(f"Summary -> {summary}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
