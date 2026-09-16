"""Beat-by-beat unarmed attack stills from a locked Bible cell.

I2V clips stay in tools/i2v_seeds.py. Do not mix the two jobs.

Print one image-edit prompt, log the roll, stop. Imagine is manual.

Authored grip is always character-left-hand high. Other handedness is
runtime flip_h plus Left/Right (and diagonal) remap. Do not generate a
second grip sheet.

Facing Down, character-left high is camera-right high. Do not write
"her left" / "his left" into the Imagine prompt; the editor reads that
as camera-left. Do not write belt or buckle; naming them redraws the
strap. Pose stack is sternum / midriff / torso centerline, not zipper.

On resume (any future web session), run this first and paste the printed
block at the top of the reply so the agent does not have to remember CLI:

  python tools/attack_keyframes.py --resume
"""
from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
LOG = TOOLS / "attack_keyframes_log.json"

# Identity lock only. Pose left/right lives in LOCKED as camera-right/left.
GRIP = {
    "female": {
        "pronoun_armor": "Same woman, same face",
    },
    "male": {
        "pronoun_armor": "Same man, same face",
    },
}

BEATS = {
    "attack_great_axe": ("idle", "coil", "mid_swing", "contact", "follow", "recover"),
    "special_great_axe": ("idle", "coil", "slam", "contact", "follow", "recover"),
    "attack_staff": ("idle", "ready", "strike", "recoil", "recover"),
    "special_staff": ("idle", "ready", "cast", "recoil", "recover"),
    "attack_longbow": ("idle", "nock", "full_draw", "loose", "recover"),
    "special_longbow": ("idle", "nock", "fan", "loose", "recover"),
}

LOCKED = {
    "coil_v22": (
        "2D pixel-art edit of this exact sprite. {pronoun_armor}, "
        "same burgundy armor, same center zipper, same green neck cloth, "
        "dark trousers, brown boots, gold earrings. Square front view locked: "
        "eyes, chest, and belt buckle face the camera. Do not change the face.\n\n"
        "Two-handed wind-up, character-left high: her left hand higher on the "
        "chest, her right hand lower on the midriff, stacked one above the other "
        "in front of the zipper. Both hands in fists. Hands empty. Hands hover "
        "off the jacket. Elbows bent and close to the ribs. Face stays on camera. "
        "Not both hands at the same height. Not arms out. Not a shrug. No pouch, "
        "glove, or extra object.\n\n"
        "Small body coil. Hair may shift a little with that coil and must stay "
        "close to the head. Keep this still's exact narrow idle feet. Do not "
        "widen the stance.\n\n"
        "Flat hot-magenta background. Same chunky pixel style. Hands stay in frame."
    ),
    "coil_v31": (
        "2D pixel-art edit of this exact sprite. {pronoun_armor}, "
        "same burgundy armor, same center zipper, same green neck cloth, "
        "dark trousers, brown boots, gold earrings. Square front view locked: "
        "eyes and chest face the camera. Do not change the face.\n\n"
        "Two-handed wind-up. The higher fist is on camera-right, on the chest. "
        "The lower fist is on camera-left, on the midriff. Both fists stacked "
        "on the sternum. One fist directly above the other on the torso "
        "centerline. Both hands in fists. Both fists square. Knuckles face the "
        "camera. Wrists straight, not tilted, not cocked. Hands empty. Hands "
        "hover off the jacket. Elbows bent and close to the ribs. Face stays "
        "on camera. Not both hands at the same height. Not arms out. Not a "
        "shrug. Not a punch. No pouch, glove, or extra object.\n\n"
        "Small body coil. Hair may shift a little with that coil and must stay "
        "close to the head. Keep this still's exact narrow idle feet. Boots "
        "stay as close together as this seed. Do not widen the stance.\n\n"
        "Flat hot-magenta background. Same chunky pixel style. Hands stay in frame."
    ),
}

BEAT_SHEET = {
    ("attack_great_axe", "coil"): "coil_v31",
}

BANNED = (
    "stomach",
    "navel",
    "C-shape",
    "fingernails",
    "thumbs on top",
    "strip of jacket between",
    "shoulder twist",
    "clearer coil",
    "clearer body coil",
    "belt",
    "buckle",
    "middle of the chest",
    "her left",
    "his left",
)


RESUME_COMMANDS = """# Attack keyframe pipeline — run these yourself
# 1. See parked beat + print the live Imagine-edit prompt:
python tools/attack_keyframes.py --resume
# 2. Same prompt without reading the log:
python tools/attack_keyframes.py --print --gender female --facing down --action attack_great_axe --beat coil
# 3. After a roll, append the log:
python tools/attack_keyframes.py --log --verdict parked --note "short note"
# verdict: keeper | fail | parked
# 4. List beats for an action:
python tools/attack_keyframes.py --beats --action attack_great_axe
# Seed: locked Bible cell only (4x NN, #FF00FF). Never edit a previous generate.
# Grip: authored character-left high = camera-right high when facing Down.
# Do not write her/his left, belt, or buckle into the Imagine prompt.
# Do not generate a male-right or female-right sheet.
"""


def _grip(gender: str) -> dict[str, str]:
    g = gender.lower().strip()
    if g not in GRIP:
        raise SystemExit(f"gender must be male or female, got {gender!r}")
    return dict(GRIP[g])


def build_still_prompt(
    *,
    gender: str,
    facing: str,
    action: str,
    beat: str,
) -> str:
    if action not in BEATS:
        raise SystemExit(f"unknown action {action!r}. keys: {sorted(BEATS)}")
    if beat == "idle":
        return "# idle is the Bible cell. Do not generate."
    if beat not in BEATS[action]:
        raise SystemExit(f"{action} beats: {BEATS[action]}")
    sheet_id = BEAT_SHEET.get((action, beat))
    if not sheet_id:
        return (
            f"# No locked sheet for {action}/{beat} yet.\n"
            f"# Open design/art-attack-keyframes.md only if that pipeline is in scope.\n"
            f"# Banned cues: {', '.join(BANNED)}"
        )
    grip = _grip(gender)
    body = LOCKED[sheet_id].format(**grip)
    facing_l = facing.lower().strip()
    preamble = (
        f"# still {gender} {facing_l} {action} {beat} sheet={sheet_id}\n"
        f"# seed = locked Bible cell only (4x NN, #FF00FF plate).\n"
        f"# grip = character-left high = camera-right high (Down).\n"
        f"# banned: {', '.join(BANNED)}\n\n"
    )
    if facing_l != "down" or gender.lower() != "female":
        preamble += (
            "# WARNING: coil_v31 was locked on female Down. Other facing/"
            "gender is untested; keep stack + fists + feet + empty hands. "
            "Camera-right/left is a Down facing map.\n\n"
        )
    return preamble + body


def load_log() -> dict:
    if not LOG.is_file():
        return {
            "status": "parked",
            "resume": {
                "gender": "female",
                "facing": "down",
                "action": "attack_great_axe",
                "beat": "coil",
                "next_id": "coil_v32",
                "seed": "seed_i2v_down_x4.png",
                "sheet": "coil_v31",
                "grip": "authored_left_high",
                "best_still": "GDNnn",
            },
            "rolls": [],
        }
    return json.loads(LOG.read_text(encoding="utf-8"))


def save_log(data: dict) -> None:
    LOG.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def print_resume() -> None:
    data = load_log()
    r = data.get("resume", {})
    print(RESUME_COMMANDS)
    print("# parked pointer")
    print(json.dumps(r, indent=2))
    print()
    print(
        build_still_prompt(
            gender=str(r.get("gender", "female")),
            facing=str(r.get("facing", "down")),
            action=str(r.get("action", "attack_great_axe")),
            beat=str(r.get("beat", "coil")),
        )
    )


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--print", action="store_true", dest="do_print")
    p.add_argument("--beats", action="store_true")
    p.add_argument("--resume", action="store_true")
    p.add_argument("--log", action="store_true", dest="do_log")
    p.add_argument("--gender", default="female")
    p.add_argument("--facing", default="down")
    p.add_argument("--action", default="attack_great_axe")
    p.add_argument("--beat", default="coil")
    p.add_argument("--note", default="")
    p.add_argument("--verdict", default="", help="keeper | fail | parked")
    args = p.parse_args()

    if args.beats:
        keys = [args.action] if args.action in BEATS else list(BEATS)
        for act in keys:
            print(f"{act}: {' '.join(BEATS[act])}")
        return

    if args.resume:
        print_resume()
        return

    if args.do_log:
        data = load_log()
        data.setdefault("rolls", []).append(
            {
                "utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                "gender": args.gender,
                "facing": args.facing,
                "action": args.action,
                "beat": args.beat,
                "verdict": args.verdict or "note",
                "note": args.note,
            }
        )
        save_log(data)
        print(f"appended {LOG}")
        return

    print(
        build_still_prompt(
            gender=args.gender,
            facing=args.facing,
            action=args.action,
            beat=args.beat,
        )
    )


if __name__ == "__main__":
    main()