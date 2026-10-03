#!/usr/bin/env python3
"""Build a Grok-readable regen brief from Animation Browser review.json.

Use Regenerate notes to tune tools/i2v_seeds.py prompts. Enemy rows are listed
with a warning until that I2V pipeline exists.
"""

from __future__ import annotations

from collections import defaultdict

import anim_review_lib as lib
import i2v_seeds
import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log


def _prompt_for(row: dict) -> str:
    if not row["player"]:
        return ""
    facing = row["facing"]
    if facing == "idle_none":
        facing = "down"
    return i2v_seeds.build_prompt(
        facing,
        row["i2v_action"],
        [],
        test=False,
        gender=row["gender"] or "male",
    )


def _md(regen: list[dict], prompts: dict[str, str], missing: list[str]) -> str:
    lines = [
        "# Regen review brief",
        "",
        "Input: `tools/anim_review/review.json`.",
        "Use these notes when changing `tools/i2v_seeds.py` MOTION / IDENTITY_LOCK / FACING_LOCK.",
        "Accepted clips are everything not listed here; do not break those prompts without cause.",
        "",
        f"Regenerate clips: {len(regen)}",
        "",
        "## Regenerate",
        "",
    ]
    if not regen:
        lines.append("None.")
        lines.append("")
    by_model = defaultdict(list)
    for row in regen:
        by_model[row["model"]].append(row)
    for model in sorted(by_model):
        lines.append(f"### {model}")
        lines.append("")
        for row in by_model[model]:
            lines.append(f"- `{row['key']}` i2v_action=`{row['i2v_action']}`")
            note = row["note"].strip()
            lines.append(f"  - note: {note if note else '(none)'}")
            if not row["player"]:
                lines.append("  - warning: enemy I2V pipeline is not configured; notes only.")
            else:
                prompt = prompts.get(row["key"], "").strip()
                if prompt:
                    lines.append("  - current prompt:")
                    lines.append("")
                    for ln in prompt.splitlines():
                        lines.append(f"    {ln}")
                    lines.append("")
            lines.append("")
    lib.add_missing(lines, missing)
    lines.extend(
        [
            "## Tuning hint",
            "",
            "Change one motion or identity sentence at a time. Re-check every facing that is not",
            "in this list before widening a prompt change.",
            "",
        ]
    )
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    args = lib.brief_args(agent_log.std_parser(__doc__, writes=True), "regen_brief", argv)
    review, missing = lib.load_with_missing(args.review)

    regen = [r for r in lib.clip_rows(review) if r["state"] == "regenerate"]
    prompts = {row["key"]: _prompt_for(row) for row in regen}
    payload = {
        "v": 1,
        "kind": "regen_brief",
        "review": agent_log.rel(lib.ROOT, args.review),
        "regenerate": [{**row, "prompt": prompts.get(row["key"], "")} for row in regen],
        "missing": missing,
    }
    lib.write_brief(args, _md(regen, prompts, missing), payload)
    return agent_log.emit_result("PASS", regenerate=len(regen), missing=len(missing))


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
