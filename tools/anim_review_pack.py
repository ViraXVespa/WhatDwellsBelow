#!/usr/bin/env python3
"""Build a Grok-readable pack brief from Animation Browser review.json.

Reads Repack notes plus Good locomotion clips already on disk so pack_locomotion.py
and sibling pack_*.py scripts can be tuned against both failure and success cases.
"""

from __future__ import annotations

from collections import defaultdict

import anim_review_lib as lib
import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log


def _scan_good_pack_clips() -> list[dict]:
    """Clips on disk that look like packed locomotion and are not flagged."""
    flagged = {row["key"] for row in lib.clip_rows()}
    found: list[dict] = []
    for model, gender in lib.PLAYER_IDS.items():
        base = lib.PLAYER_SPRITE / gender
        if not base.is_dir():
            continue
        for facing in (
            "up",
            "up_right",
            "right",
            "down_right",
            "down",
            "down_left",
            "left",
            "up_left",
        ):
            for anim in lib.PACK_ANIMS:
                frames = lib.frame_paths(model, facing, anim)
                if len(frames) <= 1:
                    continue
                key = f"{model}/{facing}/{anim}"
                if key in flagged:
                    continue
                found.append(
                    {
                        "key": key,
                        "model": model,
                        "facing": facing,
                        "anim": anim,
                        "state": "good",
                        "note": "",
                        "frames": [str(p.relative_to(lib.ROOT)) for p in frames],
                    }
                )
    return found


def _md(repack: list[dict], good: list[dict], missing: list[str]) -> str:
    lines = [
        "# Pack review brief",
        "",
        "Input: `tools/anim_review/review.json`.",
        "Use Repack notes as failure cases. Use Good locomotion clips as keep-behavior.",
        "Do not treat Regenerate rows as pack-script failures.",
        "",
        f"Repack clips: {len(repack)}",
        f"Good pack-family clips on disk: {len(good)}",
        "",
        "## Repack",
        "",
    ]
    if not repack:
        lines.append("None.")
        lines.append("")
    by_model = defaultdict(list)
    for row in repack:
        by_model[row["model"]].append(row)
    for model in sorted(by_model):
        lines.append(f"### {model}")
        lines.append("")
        for row in by_model[model]:
            frames = [str(p.relative_to(lib.ROOT)) for p in lib.frame_paths(row["model"], row["facing"], row["anim"])]
            lines.append(f"- `{row['key']}` frames={len(frames)}")
            if frames:
                lines.append(f"  - assets: `{frames[0]}` … `{frames[-1]}`" if len(frames) > 1 else f"  - assets: `{frames[0]}`")
            else:
                lines.append("  - assets: missing on disk")
            note = row["note"].strip()
            lines.append(f"  - note: {note if note else '(none)'}")
            if not row["player"]:
                lines.append("  - warning: enemy pack pipeline is not configured; notes only.")
            lines.append("")
    lines.extend(["## Good pack-family clips", ""])
    if not good:
        lines.append("None.")
        lines.append("")
    else:
        for row in good:
            lines.append(f"- `{row['key']}` frames={len(row['frames'])}")
        lines.append("")
    lib.add_missing(lines, missing)
    lines.extend(
        [
            "## Tuning hint",
            "",
            "Prefer changing `tools/pack_locomotion.py` (stride period, idle MAD, plant-foot rotation,",
            "torso X lock, start/stop split) only when Repack notes name those symptoms and Good clips",
            "of the same facing family should keep working.",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    args = lib.brief_args(agent_log.std_parser(__doc__), "pack_brief")
    review, missing = lib.load_with_missing(args.review)

    rows = lib.clip_rows(review)
    repack = [r for r in rows if r["state"] == "repack"]
    good = _scan_good_pack_clips()
    payload = {
        "v": 1,
        "kind": "pack_brief",
        "review": str(args.review.relative_to(lib.ROOT)) if args.review.is_file() else str(args.review),
        "repack": repack,
        "good": good,
        "missing": missing,
    }
    lib.write_brief(args, _md(repack, good, missing), payload)
    print(f"repack {len(repack)} good {len(good)}")
    return agent_log.emit_result("PASS", repack=len(repack), good=len(good), missing=len(missing))


if __name__ == "__main__":
    raise SystemExit(main())
