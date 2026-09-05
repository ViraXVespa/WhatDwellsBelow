"""Shared read helpers for Animation Browser review tools.

The game writes tools/anim_review/review.json from the editor.
That directory is gitignored. These tools never touch SaveStore.
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REVIEW_DIR = ROOT / "tools" / "anim_review"
REVIEW_PATH = REVIEW_DIR / "review.json"
PLAYER_SPRITE = ROOT / "assets" / "sprites" / "player"
BIBLE = {
    "male": PLAYER_SPRITE / "bible_locked_male.png",
    "female": PLAYER_SPRITE / "bible_locked_female.png",
}
PLAYER_IDS = {"player_male": "male", "player_female": "female"}
I2V_ACTIONS = ("idle", "walk", "attack", "special", "gather", "death", "dispel")
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
    name = str(anim)
    if name.startswith("attack"):
        return "attack"
    if name.startswith("special"):
        return "special"
    if name.startswith("idle_to_walk") or name.startswith("walk_to_idle"):
        return "walk"
    if name.startswith("idle"):
        return "idle"
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


def frame_paths(model: str, facing: str, anim: str) -> list[Path]:
    base = player_dir(model)
    if base is None:
        enemy = ROOT / "assets" / "sprites" / "enemies" / model.replace("player_", "")
        base = enemy
    single = base / f"{anim}_{facing}.png"
    if single.is_file():
        return [single]
    out: list[Path] = []
    i = 0
    while True:
        p = base / f"{anim}_{facing}_{i}.png"
        if not p.is_file():
            break
        out.append(p)
        i += 1
    if out:
        return out
    # Engine attack/special prefixes differ from review clip names.
    aliases = []
    if anim.startswith("attack_"):
        aliases.append(("atk_" + anim[len("attack_") :], facing))
    if anim.startswith("special_"):
        aliases.append(("spc_" + anim[len("special_") :], facing))
    for prefix, fac in aliases:
        i = 0
        found: list[Path] = []
        while True:
            p = base / f"{prefix}_{fac}_{i}.png"
            if not p.is_file():
                break
            found.append(p)
            i += 1
        if found:
            return found
    return []


def write_text(path: Path, body: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(body if body.endswith("\n") else body + "\n", encoding="utf-8")