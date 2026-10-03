#!/usr/bin/env python3
"""Generate placeholder SFX wavs from tools/sfx-cues.json (one entry per cue; replaces the per-phase make_pN_sfx scripts).

    python3 tools/make_sfx.py --list
    python3 tools/make_sfx.py [--only p9_wood ...] [--prefix p2_] [--dry-run]
    python3 tools/make_sfx.py --check        # render to temp, FAIL if a committed wav differs (proof for the old cues)

Writes assets/audio/<name>.wav; a new file there is a Build access confirm (design audio-visual-sfx door).
"""
from __future__ import annotations

import json
import sys
import tempfile
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
import audio_lib as al


def render(node: list) -> list[float]:
    kind = node[0]
    if kind == "sine":
        return al.sine(node[1], node[2], node[3], node[4], node[5])
    if kind == "noise":
        return al.noise(node[1], node[2], node[3])
    if kind == "mix":
        return al.mix(*[render(n) for n in node[1:]])
    if kind == "cat":
        out: list[float] = []
        for n in node[1:]:
            out += render(n)
        return out
    raise ValueError(f"unknown node {kind!r}")


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Generate placeholder SFX wavs from tools/sfx-cues.json.", writes=True)
    ap.add_argument("--spec", default="tools/sfx-cues.json", help="Cue spec (repo-relative).")
    ap.add_argument("--only", nargs="*", default=[], help="Cue names (comma or space separated).")
    ap.add_argument("--prefix", default="", help="Only cues whose name starts with this (p2_, p9_).")
    ap.add_argument("--list", action="store_true", help="List cue names and exit.")
    ap.add_argument("--check", action="store_true", help="Render to a temp dir and compare with assets/audio; write nothing.")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    spec = json.loads((root / args.spec).read_text(encoding="utf-8-sig"))
    cues = spec["cues"]
    only = agent_log.split_list(args.only)
    cues = [c for c in cues if (not only or c["name"] in only) and c["name"].startswith(args.prefix)]
    missing = [n for n in only if n not in {c["name"] for c in spec["cues"]}]
    if missing:
        print(f"error: unknown cue(s): {', '.join(missing)}", file=sys.stderr)
        return 2
    if args.list:
        for c in cues:
            print(c["name"])
        return agent_log.emit_result("INFO", cues=len(cues))
    out_dir = root / "assets" / "audio"
    if args.check:
        bad = []
        with tempfile.TemporaryDirectory() as tmp:
            for c in cues:
                p = Path(tmp) / f"{c['name']}.wav"
                al.write_wav(p, render(c["graph"]), c["scale"])
                real = out_dir / p.name
                if not real.is_file() or real.read_bytes() != p.read_bytes():
                    bad.append(p.name)
        for n in bad:
            print(f"differs {n}")
        return agent_log.emit_result("FAIL" if bad else "PASS", checked=len(cues), differ=len(bad))
    for c in cues:
        path = out_dir / f"{c['name']}.wav"
        if not args.dry_run:
            al.write_wav(path, render(c["graph"]), c["scale"])
        print("sfx", agent_log.rel(root, path) + (" (dry-run)" if args.dry_run else ""))
    return agent_log.emit_result("PASS", written=0 if args.dry_run else len(cues), dir="assets/audio")


if __name__ == "__main__":
    raise SystemExit(main())
