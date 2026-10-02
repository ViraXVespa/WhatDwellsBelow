"""Shared read helpers for Animation Browser review tools.

The game writes tools/anim_review/review.json from the editor.
That directory is gitignored. These tools never touch SaveStore.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import md_format_lib as md

ROOT = Path(__file__).resolve().parent.parent
REVIEW_DIR = ROOT / "tools" / "anim_review"
REVIEW_PATH = REVIEW_DIR / "review.json"
PLAYER_SPRITE = ROOT / "assets" / "sprites" / "player"
BIBLE = {
    "male": PLAYER_SPRITE / "bible_locked_male.png",
    "female": PLAYER_SPRITE / "bible_locked_female.png",
}
PLAYER_IDS = {"player_male": "male", "player_female": "female"}
I2V_ACTIONS = (
    "idle",
    "walk",
    "attack_great_axe",
    "attack_staff",
    "attack_longbow",
    "special_great_axe",
    "special_staff",
    "special_longbow",
    "gather",
    "gather_pickaxe",
    "gather_hatchet",
    "death",
    "dispel",
)
PACK_ANIMS = ("walk", "idle_to_walk", "walk_to_idle")


def load_review(path: Path = REVIEW_PATH) -> dict:
    if not path.is_file():
        return {"v": 1, "clips": {}}
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        return {"v": 1, "clips": {}}
    clips = data.get("clips", {})
    if not isinstance(clips, dict):
        clips = {}
    return {"v": int(data.get("v", 1) or 1), "clips": clips}


def parse_key(key: str) -> tuple[str, str, str]:
    parts = str(key).split("/")
    if len(parts) != 3:
        return ("", "", "")
    return parts[0], parts[1], parts[2]


def clip_rows(review: dict | None = None) -> list[dict]:
    review = review if review is not None else load_review()
    rows: list[dict] = []
    for key, raw in sorted(review.get("clips", {}).items()):
        model, facing, anim = parse_key(key)
        if not model:
            continue
        row = raw if isinstance(raw, dict) else {}
        state = str(row.get("state", "")).lower()
        if state not in ("repack", "regenerate"):
            continue
        rows.append(
            {
                "key": key,
                "model": model,
                "facing": facing,
                "anim": anim,
                "state": state,
                "note": str(row.get("note", "")),
                "player": model in PLAYER_IDS,
                "gender": PLAYER_IDS.get(model),
                "i2v_action": i2v_action(anim),
            }
        )
    return rows


def i2v_action(anim: str) -> str:
    name = str(anim).strip().lower().replace("-", "_")
    if name.startswith("atk_"):
        name = "attack_" + name[len("atk_") :]
    elif name.startswith("spc_"):
        name = "special_" + name[len("spc_") :]
    if name.startswith("idle_to_walk") or name.startswith("walk_to_idle"):
        return "walk"
    if name == "idle" or name.startswith("idle_"):
        return "idle"
    if name in I2V_ACTIONS:
        return name
    if name.startswith(("attack_", "special_", "gather_")):
        return name
    head = name.split("_", 1)[0]
    if head in I2V_ACTIONS:
        return head
    return name


def is_pack_anim(anim: str) -> bool:
    name = str(anim)
    return name in PACK_ANIMS or name.startswith("walk")


def player_dir(model: str) -> Path | None:
    gender = PLAYER_IDS.get(model)
    if not gender:
        return None
    return PLAYER_SPRITE / gender


def _seq(base: Path, prefix: str, facing: str) -> list[Path]:
    out: list[Path] = []
    i = 0
    while True:
        p = base / f"{prefix}_{facing}_{i}.png"
        if not p.is_file():
            break
        out.append(p)
        i += 1
    return out


def frame_paths(model: str, facing: str, anim: str) -> list[Path]:
    base = player_dir(model)
    if base is None:
        enemy = ROOT / "assets" / "sprites" / "enemies" / model.replace("player_", "")
        base = enemy
    single = base / f"{anim}_{facing}.png"
    if single.is_file():
        return [single]
    found = _seq(base, anim, facing)
    if found:
        return found
    # Engine attack/special prefixes differ from review clip names.
    aliases: list[str] = []
    if anim.startswith("attack_"):
        aliases.append("atk_" + anim[len("attack_") :])
    if anim.startswith("special_"):
        aliases.append("spc_" + anim[len("special_") :])
    if anim.startswith("gather_"):
        aliases.append("gather")
    if anim == "gather":
        aliases.extend(["gather_pickaxe", "gather_hatchet"])
    for prefix in aliases:
        found = _seq(base, prefix, facing)
        if found:
            return found
    return []


def write_text(path: Path, body: str) -> None:
    md.write_utf8(path, body, mkdir=True)


def brief_args(ap: argparse.ArgumentParser, stem: str) -> argparse.Namespace:
    """Add --review, --out-md, --out-json (defaults <stem>.md/.json) to the tool's std_parser and parse."""
    ap.add_argument("--review", type=Path, default=REVIEW_PATH)
    ap.add_argument("--out-md", type=Path, default=REVIEW_DIR / f"{stem}.md")
    ap.add_argument("--out-json", type=Path, default=REVIEW_DIR / f"{stem}.json")
    return ap.parse_args()


def load_with_missing(path: Path) -> tuple[dict, list[str]]:
    """(review, missing notes): an absent file gives an empty review and one note."""
    if not path.is_file():
        return {"v": 1, "clips": {}}, [f"no review file at {path}"]
    return load_review(path), []


def add_missing(lines: list[str], missing: list[str]) -> None:
    """Append the Missing review store section when there are notes."""
    if missing:
        lines.extend(["## Missing review store", ""])
        for line in missing:
            lines.append(f"- {line}")
        lines.append("")


def write_brief(args: argparse.Namespace, body: str, payload: dict) -> None:
    write_text(args.out_md, body)
    write_text(args.out_json, json.dumps(payload, indent="\t"))
    print(f"wrote {args.out_md}")
    print(f"wrote {args.out_json}")
