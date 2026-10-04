#!/usr/bin/env python3
"""List design/*.md (not changelog/) by byte size, largest first. Read-only.

Doc signal-to-noise sweep options (one tool, no scratches):
  --boot    bytes and ~tokens of each boot chain (routes.yaml boot_max) + the skills dirs.
  --dupes   sentences (>= --min-chars) repeated across root md, design/*.md, .grok skills; each is a
            candidate for one canonical copy plus a one-line pointer.
"""

from __future__ import annotations

import re
import sys
from collections import defaultdict
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
import bot_gate_lib

_SENT = re.compile(r"(?<=[.!?:;])\s+|\n+")


def _doc_files(root: Path) -> list[Path]:
    out = sorted(root.glob("*.md")) + sorted((root / "design").glob("*.md"))
    out += sorted((root / ".grok" / "skills").glob("*/SKILL.md"))
    return [f for f in out if f.is_file()]


def boot_report(root: Path) -> tuple[list[str], int]:
    from load_routes import boot_max, load_routes

    lines = ["", "boot chains (bytes, ~tokens = bytes/4):"]
    worst = 0
    for name, paths in boot_max(load_routes(root)).items():
        sizes = [(p, (root / p).stat().st_size) for p in paths if (root / p).is_file()]
        total = sum(n for _, n in sizes)
        worst = max(worst, total)
        lines.append(f"  {name}: {total} bytes ~{total // 4} tokens  " + " ".join(f"{p}={n}" for p, n in sizes))
    return lines, worst


def dupe_report(root: Path, min_chars: int) -> tuple[list[str], int]:
    seen: dict[str, set[str]] = defaultdict(set)
    for f in _doc_files(root):
        text = f.read_text(encoding="utf-8", errors="replace")
        for s in _SENT.split(text):
            s = re.sub(r"[^a-z0-9]+", " ", s.lower()).strip()
            if len(s) >= min_chars:
                seen[s].add(f.relative_to(root).as_posix())
    hits = sorted(((s, sorted(fs)) for s, fs in seen.items() if len(fs) > 1), key=lambda x: -len(x[0]))
    lines = ["", f"repeated sentences (>= {min_chars} chars, 2+ files):"]
    lines += [f"  [{len(s)}] {', '.join(fs)} :: {s[:90]}" for s, fs in hits]
    return lines, len(hits)


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("List design/*.md by os.path.getsize; OVER marks files at or over --over-kb. --boot / --dupes: doc SNR sweep.", json_out=True)
    bot_gate_lib.add_flag(ap)
    ap.add_argument("--over-kb", "-OverKb", type=float, default=8.0, help="limit = round(kb * 1000) bytes")
    ap.add_argument("--boot", action="store_true", help="print bytes per boot chain (routes.yaml boot_max)")
    ap.add_argument("--dupes", action="store_true", help="print sentences repeated across docs")
    ap.add_argument("--min-chars", type=int, default=60, help="--dupes minimum normalized sentence length (default 60)")
    ap.add_argument("--all", action="store_true", help="list every doc (default: only OVER-limit docs)")
    args = ap.parse_args(sys.argv[1:] if argv is None else argv)
    if not bot_gate_lib.enabled(args):
        agent_log.resolve_root(args)
        return bot_gate_lib.not_run("doc size listing")
    root = agent_log.resolve_root(args)
    limit = round(args.over_kb * 1000)
    files = sorted((f for f in (root / "design").glob("*.md")), key=lambda f: -f.stat().st_size)
    lines = [f"root=. over_kb={args.over_kb} limit_bytes={limit}", ""]
    over = 0
    for f in files:
        n = f.stat().st_size
        hit = n >= limit
        over += hit
        if hit or args.all:
            lines.append(f"{'OVER ' if hit else ''}{f.relative_to(root).as_posix()} bytes={n}")
    extra: dict[str, int] = {}
    if args.boot:
        more, extra["boot_worst"] = boot_report(root)
        lines += more
    if args.dupes:
        more, extra["dupes"] = dupe_report(root, args.min_chars)
        lines += more
    return agent_log.finish("oversize-docs", root, "\n".join(lines), "INFO", args=args, legacy=False, over=over, files=len(files), **extra)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
