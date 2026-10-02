#!/usr/bin/env python3
"""Scan live scripts for common hostify / := pitfalls. Writes a short hit list.

Usage (from repo root):
  python tools/lint_hostify.py
  powershell -File tools/lint_hostify.ps1

Output: _logs/hostify-lint/summary.txt
See design/refactor.md (Hostify pitfalls).

Exit 0 always (advisory report). Read RESULT hits= in the summary.
"""
from __future__ import annotations

import re
import sys
from datetime import datetime
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
import gd_lib

ROOT = agent_log.repo_root()

RE_SHADOW_HOST = re.compile(r"^\s*var\s+host\s*:=")
RE_INFER_LOAD = re.compile(r"^\s*var\s+\w+\s*:=.*\bload\s*\(")
RE_INFER_FAC = re.compile(r"^\s*var\s+\w+\s*:=.*\b_fac\s*\.")
RE_INFER_HOST_GET = re.compile(r"^\s*var\s+\w+\s*:=.*\b(?:host|p|pt|ui)\.get\s*\(")
RE_INFER_ONEARG_GET = re.compile(r"""^\s*var\s+\w+\s*:=.*\.get\s*\(\s*['"][^'"]*['"]\s*\)""")
RE_MOTION = re.compile(r"(?<!\.)\bMOTION_MODE_[A-Z0-9_]+\b")
RE_STR_N_AME = re.compile(r"str\(n\)ame")
RE_HOST_TRAILING_COMMA = re.compile(r"\bhost\s*,\s*\)")
RE_EXTENDS_CB = re.compile(r"^extends\s+CharacterBody(?:2D|3D)\b", re.M)


def rel(p: Path) -> str:
    return agent_log.rel(ROOT, p)


def lint_file(path: Path) -> list[str]:
    hits: list[str] = []
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        text = path.read_text(encoding="utf-8", errors="replace")
    is_character_body = bool(RE_EXTENDS_CB.search(text))
    for i, line in enumerate(text.splitlines(), 1):
        stripped = line.lstrip()
        if stripped.startswith("#"):
            continue
        if RE_SHADOW_HOST.search(line):
            hits.append(f"{rel(path)}:{i}: SHADOW_HOST {stripped}")
        if RE_INFER_LOAD.search(line):
            hits.append(f"{rel(path)}:{i}: INFER_LOAD {stripped}")
        if RE_INFER_FAC.search(line):
            hits.append(f"{rel(path)}:{i}: INFER_FAC {stripped}")
        if RE_INFER_HOST_GET.search(line) or RE_INFER_ONEARG_GET.search(line):
            hits.append(f"{rel(path)}:{i}: INFER_GET {stripped}")
        if (not is_character_body) and RE_MOTION.search(line):
            hits.append(f"{rel(path)}:{i}: MOTION_UNQUALIFIED {stripped}")
        if RE_STR_N_AME.search(line):
            hits.append(f"{rel(path)}:{i}: CORRUPT_NAME {stripped}")
        if RE_HOST_TRAILING_COMMA.search(line):
            hits.append(f"{rel(path)}:{i}: HOST_TRAILING_COMMA {stripped}")
    return hits


def main() -> int:
    global ROOT
    ap = agent_log.std_parser("Advisory hostify / := lint over live scripts/**/*.gd (exit 0 always).", json_out=True)
    args = ap.parse_args()
    ROOT = agent_log.resolve_root(args)
    files = gd_lib.iter_gd(ROOT)
    all_hits: list[str] = []
    for p in files:
        all_hits.extend(lint_file(p))

    kinds: dict[str, int] = {}
    for h in all_hits:
        kind = h.split(":", 2)[2].strip().split()[0]
        kinds[kind] = kinds.get(kind, 0) + 1

    lines = [
        f"hostify lint {datetime.now().astimezone().isoformat()}",
        "root=.",
        f"files_scanned={len(files)} hits={len(all_hits)}",
        "kinds=" + ",".join(f"{k}:{v}" for k, v in sorted(kinds.items())),
        "",
        "--- hits ---",
    ]
    if not all_hits:
        lines.append("(none)")
    else:
        lines.extend(all_hits[:500])
        if len(all_hits) > 500:
            lines.append(f"... +{len(all_hits) - 500} more")
    head = [f"Scanned {len(files)} scripts; {len(all_hits)} hits"] + [f"  {k}: {v}" for k, v in sorted(kinds.items())]
    code = agent_log.finish("hostify-lint", ROOT, "\n".join(lines), "INFO", args=args, echo="\n".join(head), hits=len(all_hits), files=len(files))
    return code


if __name__ == "__main__":
    raise SystemExit(main())
