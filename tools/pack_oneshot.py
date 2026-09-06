"""Pack one-shot I2V clips into engine frames.

Walk / idle_to_walk / walk_to_idle stay in pack_locomotion.py.

Drop videos at:
  _src/oneshot/{gender}_{action}_{facing}.mp4
Example:
  _src/oneshot/female_attack_great_axe_down.mp4

Attack, special, and gather default to 6 frames so every facing of that
action shares a count. Death and Dispel keep the clip length (Dispel is
allowed to run long).
"""
from __future__ import annotations

import argparse
import sys
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path

from PIL import Image

TOOLS = Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))

import i2v_seeds  # noqa: E402
import pack_locomotion as loc  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "_src" / "oneshot"
HARVEST = ROOT / "_src" / "oneshot_harvest"
OUT = ROOT / "assets" / "sprites" / "player"
KEYS = list(i2v_seeds.BODY_CELLS)

PREFIX = {
    "attack_great_axe": "atk_great_axe",
    "attack_staff": "atk_staff",
    "attack_longbow": "atk_longbow",
    "special_great_axe": "spc_great_axe",
    "special_staff": "spc_staff",
    "special_longbow": "spc_longbow",
    "gather_pickaxe": "gather_pickaxe",
    "gather_hatchet": "gather_hatchet",
    "death": "death",
    "dispel": "dispel",
}
FIXED_N = {
    "attack_great_axe": 6,
    "attack_staff": 6,
    "attack_longbow": 6,
    "special_great_axe": 6,
    "special_staff": 6,
    "special_longbow": 6,
    "gather_pickaxe": 6,
    "gather_hatchet": 6,
}


def even_pick(frames: list[Image.Image], count: int) -> list[Image.Image]:
    if count <= 0 or len(frames) <= count:
        return list(frames)
    if count == 1:
        return [frames[0]]
    last = len(frames) - 1
    idxs = [int(round(i * last / (count - 1))) for i in range(count)]
    out: list[Image.Image] = []
    seen: set[int] = set()
    for i in idxs:
        if i in seen:
            i = min(last, i + 1)
        seen.add(i)
        out.append(frames[i])
    return out


def pack_one(
    gender: str,
    facing: str,
    action: str,
    video: str,
    reuse: bool,
    rim: int,
    rim_hue: float,
    frames_n: int | None,
) -> str:
    vid = Path(video)
    raw_dir = HARVEST / gender / action / facing
    paths = loc.extract(vid, raw_dir, reuse=reuse)
    if not paths:
        return f"empty {vid}"
    raw = [Image.open(p).convert("RGBA") for p in paths]
    cleaned = [loc.clean(im, rim, rim_hue) for im in raw]
    ref = loc.bible_cell(gender, facing)
    locked = loc.lock_x(cleaned, ref) if ref is not None else cleaned
    n = frames_n
    if n is None:
        n = FIXED_N.get(action)
    picked = even_pick(locked, n) if n else locked
    dest = OUT / gender
    prefix = f"{PREFIX[action]}_{facing}"
    loc.write_seq(picked, dest, prefix)
    return f"{gender} {action} {facing} {len(picked)} -> {dest / (prefix + '_0.png')}"


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--gender", action="append", choices=("male", "female"))
    p.add_argument("--facing", action="append", choices=KEYS)
    p.add_argument("--action", action="append", choices=sorted(PREFIX))
    p.add_argument("--reuse-harvest", action="store_true")
    p.add_argument("--rim", type=int, default=2)
    p.add_argument("--rim-hue", type=float, default=26.0)
    p.add_argument(
        "--frames",
        type=int,
        default=0,
        help="Force frame count. 0 = default (6 for attack/special/gather, all frames for death/dispel).",
    )
    args = p.parse_args(argv)
    genders = args.gender or ["male", "female"]
    facings = args.facing or list(KEYS)
    actions = args.action or list(PREFIX)
    force_n = args.frames if args.frames > 0 else None
    jobs: list[tuple] = []
    for gender in genders:
        for action in actions:
            for facing in facings:
                vid = SRC / f"{gender}_{action}_{facing}.mp4"
                if not vid.is_file():
                    print("missing", vid)
                    continue
                n = force_n
                if n is None:
                    n = FIXED_N.get(action)
                jobs.append(
                    (
                        gender,
                        facing,
                        action,
                        str(vid),
                        args.reuse_harvest,
                        args.rim,
                        args.rim_hue,
                        n,
                    )
                )
    if not jobs:
        return 0
    if len(jobs) == 1:
        print(pack_one(*jobs[0]))
        return 0
    with ProcessPoolExecutor() as pool:
        futs = [pool.submit(pack_one, *job) for job in jobs]
        for fut in as_completed(futs):
            print(fut.result())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())