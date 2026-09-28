#!/usr/bin/env python3
"""Extract one GDScript func/const into _logs/show-func/summary.txt."""
from __future__ import annotations

import argparse
import re
from pathlib import Path

import agent_log

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = agent_log.ensure_agent_log_dir("show-func", ROOT)
SUMMARY = OUT_DIR / "summary.txt"
MAX_LINES = 80
DECL = re.compile(
    r"^(?P<indent>\t*)(?:static\s+)?(?:func|const|var|class_name|enum)\s+(?P<name>[A-Za-z_][A-Za-z0-9_]*)"
)


def main() -> int:
    p = argparse.ArgumentParser(description="Extract one GDScript declaration.")
    p.add_argument("--path", required=True, help="Repo-relative .gd path")
    p.add_argument("--name", required=True, help="func / const / var name")
    args = p.parse_args()
    rel = args.path.replace("\\", "/").lstrip("/")
    src = ROOT / rel
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    lines_out: list[str] = [
        f"show_func path={rel} name={args.name}",
        f"root={ROOT}",
    ]
    if not src.is_file():
        lines_out.append("RESULT missing")
        SUMMARY.write_text("\n".join(lines_out) + "\n", encoding="utf-8")
        print(f"Summary -> {SUMMARY}")
        return 2
    body = src.read_text(encoding="utf-8").splitlines()
    start = -1
    indent = ""
    for i, line in enumerate(body):
        m = DECL.match(line)
        if m and m.group("name") == args.name:
            start = i
            indent = m.group("indent")
            break
    if start < 0:
        lines_out.append("RESULT not_found")
        SUMMARY.write_text("\n".join(lines_out) + "\n", encoding="utf-8")
        print(f"Summary -> {SUMMARY}")
        return 1
    end = len(body)
    for j in range(start + 1, len(body)):
        m = DECL.match(body[j])
        if m and m.group("indent") == indent:
            end = j
            break
    chunk = body[start:end]
    truncated = False
    if len(chunk) > MAX_LINES:
        chunk = chunk[:MAX_LINES]
        truncated = True
    lines_out.append(f"lines={start + 1}-{start + len(chunk)} of {len(body)}")
    lines_out.append(f"truncated={truncated}")
    lines_out.append("")
    lines_out.extend(chunk)
    lines_out.append("")
    lines_out.append("RESULT ok")
    SUMMARY.write_text("\n".join(lines_out) + "\n", encoding="utf-8")
    print(f"Summary -> {SUMMARY}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
