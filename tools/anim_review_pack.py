"""Build a Grok-readable pack brief from Animation Browser review.json.

Reads Repack notes plus Good locomotion clips already on disk so pack_locomotion.py
and sibling pack_*.py scripts can be tuned against both failure and success cases.
"""

from __future__ import annotations

import argparse
import json
from collections import defaultdict

import anim_review_lib as lib


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
    if missing:
        lines.extend(["## Missing review store", ""])
        for line in missing:
            lines.append(f"- {line}")
        lines.append("")
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
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--review", type=lib.Path, default=lib.REVIEW_PATH)
    ap.add_argument("--out-md", type=lib.Path, default=lib.REVIEW_DIR / "pack_brief.md")
    ap.add_argument("--out-json", type=lib.Path, default=lib.REVIEW_DIR / "pack_brief.json")
    args = ap.parse_args()

    missing: list[str] = []
    if not args.review.is_file():
        missing.append(f"no review file at {args.review}")
        review = {"v": 1, "clips": {}}
    else:
        review = lib.load_review(args.review)

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
    lib.write_text(args.out_md, _md(repack, good, missing))
    lib.write_text(args.out_json, json.dumps(payload, indent="\t"))
    print(f"wrote {args.out_md}")
    print(f"wrote {args.out_json}")
    print(f"repack {len(repack)} good {len(good)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())