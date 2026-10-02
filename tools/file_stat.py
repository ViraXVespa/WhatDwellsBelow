#!/usr/bin/env python3
"""Filesystem stats for one path or a small glob. No file-body dump."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Length, newline, BOM, and indent stats without reading into chat."
    )
    parser.add_argument("--root", default=".")
    parser.add_argument("--path", action="append", default=[], help="File or directory")
    parser.add_argument("--glob", default="", help="Only under a directory --path")
    parser.add_argument("--max", type=int, default=40)
    return parser.parse_args(argv)


def probe(path: Path) -> dict[str, object]:
    row: dict[str, object] = {
        "path": str(path),
        "exists": path.exists(),
        "is_file": path.is_file(),
        "bytes": 0,
        "lines": 0,
        "lf": 0,
        "crlf": 0,
        "tabs": 0,
        "space_indent": 0,
        "bom": 0,
        "missing": 0,
    }
    if not path.is_file():
        row["missing"] = 0 if path.exists() else 1
        return row
    data = path.read_bytes()
    row["bytes"] = len(data)
    if data.startswith(b"\xef\xbb\xbf"):
        row["bom"] = 1
        data = data[3:]
    row["crlf"] = data.count(b"\r\n")
    row["lf"] = data.count(b"\n") - int(row["crlf"])
    row["tabs"] = data.count(b"\t")
    text = data.decode("utf-8", errors="replace")
    lines = text.splitlines()
    row["lines"] = len(lines)
    row["space_indent"] = sum(
        1 for line in lines if line.startswith(" ") and line.strip()
    )
    return row


def collect(root: Path, paths: list[str], glob: str, cap: int) -> list[dict[str, object]]:
    hits: list[Path] = []
    raw = paths or ["."]
    for item in raw:
        target = Path(item)
        if not target.is_absolute():
            target = (root / target).resolve()
        else:
            target = target.resolve()
        if target.is_file():
            hits.append(target)
            continue
        if target.is_dir():
            if glob:
                hits.extend(sorted(p for p in target.glob(glob) if p.is_file()))
            else:
                hits.append(target)
    return [probe(path) for path in hits[: max(1, cap)]]


def render(rows: list[dict[str, object]], root: Path) -> str:
    lines = [
        "file-stat",
        "root=.",
        f"count={len(rows)}",
        "path\tbytes\tlines\tlf\tcrlf\ttabs\tspace_indent\tbom\texists",
    ]
    for row in rows:
        rel = str(row["path"])
        try:
            rel = str(Path(rel).resolve().relative_to(root))
        except ValueError:
            pass
        lines.append(
            f"{rel}\t{row['bytes']}\t{row['lines']}\t{row['lf']}\t{row['crlf']}\t"
            f"{row['tabs']}\t{row['space_indent']}\t{row['bom']}\t{int(bool(row['exists']))}"
        )
    lines.append(f"RESULT count={len(rows)}")
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    root = Path(args.root).expanduser().resolve()
    rows = collect(root, list(args.path), args.glob, int(args.max))
    body = render(rows, root)
    out_dir = agent_log.ensure_agent_log_dir("file-stat", root)
    summary = out_dir / "summary.txt"
    summary.write_text(body, encoding="utf-8")
    sys.stdout.write(body)
    print(f"summary={summary.relative_to(root).as_posix()}")
    return 0


if __name__ == "__main__":
    sys.exit(int(main()))
