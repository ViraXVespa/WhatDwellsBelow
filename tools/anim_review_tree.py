#!/usr/bin/env python3
"""Build a wiped I2V test tree for every Regenerate clip in review.json.

Each folder contains:
  1. source.png — bible cell processed like i2v_seeds.py --cell (player only)
  2. prompt.txt — full current i2v_seeds.build_prompt text (player only)
  3. notes.txt — browser note when the User typed one

Enemy clips get warning.txt (and notes.txt when present) until that pipeline exists.
"""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

from PIL import Image

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
import anim_review_lib as lib
import i2v_seeds
import sprite_pipeline as sp


def _cell_for(gender: str, facing: str) -> Image.Image | None:
    bible = lib.BIBLE.get(gender)
    if bible is None or not bible.is_file():
        return None
    raw = Image.open(bible).convert("RGBA")
    cells = dict(zip(sp.CELL_NAMES, sp.split_equal_3x3(raw)))
    key = facing if facing in cells else "down"
    im = cells.get(key)
    if im is None:
        return None
    return i2v_seeds.pad_chroma(i2v_seeds.scale_nn(im, i2v_seeds.SCALE), i2v_seeds.PAD_FRAC)


def _wipe(dest: lib.Path) -> None:
    if dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True, exist_ok=True)


def _write_player(folder: lib.Path, row: dict) -> str:
    folder.mkdir(parents=True, exist_ok=True)
    facing = row["facing"] if row["facing"] != "idle_none" else "down"
    seed = _cell_for(row["gender"] or "male", facing)
    if seed is None:
        lib.write_text(folder / "warning.txt", "missing locked bible cell for this facing")
        status = "missing-bible"
    else:
        seed.save(folder / "source.png")
        status = "ok"
    prompt = i2v_seeds.build_prompt(
        facing,
        row["i2v_action"],
        [],
        test=False,
        gender=row["gender"] or "male",
    )
    lib.write_text(folder / "prompt.txt", prompt)
    note = row["note"].strip()
    if note:
        lib.write_text(folder / "notes.txt", note)
    return status


def _write_enemy(folder: lib.Path, row: dict) -> str:
    folder.mkdir(parents=True, exist_ok=True)
    lib.write_text(
        folder / "warning.txt",
        "enemy I2V pipeline is not configured; source.png and prompt.txt omitted",
    )
    note = row["note"].strip()
    if note:
        lib.write_text(folder / "notes.txt", note)
    return "enemy-warning"


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser(__doc__, writes=True)
    ap.add_argument("--dest", type=Path, default=None, help="Output tree (default tools/anim_review/regen_tree). It is wiped first.")
    args = lib.brief_args(ap, None, argv)
    dest = args.dest or lib.REVIEW_DIR / "regen_tree"
    if args.dry_run:
        n = len([r for r in lib.clip_rows(lib.load_review(args.review)) if r["state"] == "regenerate"])
        return agent_log.emit_result("INFO", dest=agent_log.rel(lib.ROOT, dest), regenerate=n, dry_run=True)
    args.dest = dest
    _wipe(args.dest)
    if not args.review.is_file():
        lib.write_text(args.dest / "warning.txt", f"no review file at {agent_log.rel(lib.ROOT, args.review)}")
        return agent_log.emit_result("INFO", dest=agent_log.rel(lib.ROOT, dest), regenerate=0, error="no-review-json")

    regen = [r for r in lib.clip_rows(lib.load_review(args.review)) if r["state"] == "regenerate"]
    counts = {"ok": 0, "missing-bible": 0, "enemy-warning": 0}
    for row in regen:
        folder = args.dest / row["model"] / row["facing"] / row["anim"]
        if row["player"]:
            status = _write_player(folder, row)
        else:
            status = _write_enemy(folder, row)
        counts[status] = counts.get(status, 0) + 1
    return agent_log.emit_result("PASS", dest=agent_log.rel(lib.ROOT, dest), regenerate=len(regen), ok=counts["ok"],
                                 missing_bible=counts["missing-bible"], enemy=counts["enemy-warning"])


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
