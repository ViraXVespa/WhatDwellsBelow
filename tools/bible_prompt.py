#!/usr/bin/env python3
"""Bible Imagine text. Print and copy.

--gender: the locked 3x3 player Character Bible prompt.
--enemy ID: the 3x3 Enemy Bible prompt filled from ENEMIES below, the one home of the
enemy prop and hand table (design/art-bible-enemy.md points here). A '?' in a hand or note
means unverified: the output marks it UNKNOWN and a warning goes to stderr.
I2V / overlay prompts stay in tools/i2v_seeds.py. Do not send Imagine from this path unless the User says to.
"""
from __future__ import annotations

import argparse
import sys

HAIR = {
    "male": "short messy dark hair",
    "female": "appropriate female hairstyle",
}

TEMPLATE = """\
Create a single clean image that is a perfect 3×3 Character Bible grid on solid pure magenta `#FF00FF` background for the {gender} player character of "What Dwells Below".

Strict cell layout (do not swap, reverse rows, reverse columns, or move any figure):

Top row:
Top-left: Up-Left full-body, complete head-to-feet, character facing Up-Left, neutral standing
Top-center: Up full-body, complete head-to-feet, character facing Up (full back view), neutral standing
Top-right: Up-Right full-body, complete head-to-feet, character facing Up-Right, neutral standing

Middle row:
Middle-left: Left full-body, complete head-to-feet, character facing Left (left profile), neutral standing
Exact center: clear head-and-shoulders face close-up of the same character
Middle-right: Right full-body, complete head-to-feet, character facing Right (right profile), neutral standing

Bottom row:
Bottom-left: Down-Left full-body, complete head-to-feet, character facing Down-Left, neutral standing
Bottom-center: Down full-body, complete head-to-feet, character facing Down (front view), neutral standing
Bottom-right: Down-Right full-body, complete head-to-feet, character facing Down-Right, neutral standing

All eight full-body figures must have identical proportions and silhouette height, feet on the same baseline. Character locked across every cell: rugged human dungeon delver, practical layered leather and metal armor, {hair}, determined expression, a short green neckband worn only around the neck, limited muted palette (grays, browns, dark greens, skin tones, metal). Crisp true pixel-art style, integer pixel edges, no anti-aliasing, no smoothing. Hands empty. No weapons, no tools. Do not swap any cells. Do not place the face close-up anywhere except the exact center. No cropping of limbs, no props, no weapons, no text, no numbers, no borders, no grid lines. Perfect even 3×3 grid.
"""

# Enemy Bible, the one home of the prop and hand table. Prop = (kind, name, side, visible piece, note, idle pose).
# kind: held (side right|left|both|each) or worn (side = where). Every prop is drawn at rest (carried, never aimed, drawn or swung)
# so it can be animated later. A '?' in side or note = unverified: the output marks it UNKNOWN. Enemies with no props: empty list.
Prop = tuple[str, str, str, str, str, str]
ENEMIES: dict[str, list[Prop]] = {
    "slime": [], "bat": [], "spider": [], "wolf": [], "beetle": [], "wisp": [],
    "goblin": [("held", "rusty knife", "right", "blade", "", "hangs low at the side, blade pointing down")],
    "orc": [("held", "two-handed battle axe", "both", "axe head", "right hand higher on the haft", "is held low in front of the hips, head resting low, never raised"),
            ("worn", "pauldron", "on the left shoulder", "", "asymmetric armour", "")],
    "skeleton": [("held", "rusted sword", "right", "blade", "", "hangs low at the side, point down"),
                 ("worn", "purple cloak", "over the left shoulder", "", "", "")],
    "archer": [("held", "longbow", "left", "bow tip", "", "hangs down at the side, string undrawn"),
               ("held", "arrow", "right", "arrow", "", "rests in the hand at the side, point down, not nocked"),
               ("worn", "back quiver", "on the back", "", "only from the back or the far-side profile", "")],
    "shaman": [("held", "bone staff with horned skull", "left", "skull head", "", "is planted upright on the ground, never raised")],
    "imp": [("held", "small flame", "each", "flame", "one in each hand, symmetric", "rest in the open palms held low, never thrown")],
}

ENEMY_TEMPLATE = """\
Create a single image: a perfect 3x3 Enemy Bible grid on solid pure magenta #FF00FF for the enemy "{enemy}" of "What Dwells Below": {body}.
Strict cell layout, never swap or reverse a figure. Top row: Up-Left, Up, Up-Right. Middle row: Left, centre = head-and-shoulders close-up, Right. Bottom row: Down-Left, Down, Down-Right.
{facing}
{props}
IDLE POSE: every prop is at rest, carried low as given above, never aimed, drawn, raised or swung, so it can be animated later. It turns with its figure (Down end-on toward the camera, Up away, Left/Right toward that edge, diagonals diagonally); same size and height in all eight.
HANDS: "right" and "left" mean the CHARACTER's own hands. Facing Down the right hand is at the image's LEFT edge side; facing Up, at the RIGHT edge side. In Right only the right side faces the camera; in Left only the left. Never mirror a figure.
All eight figures: identical proportions, palette and silhouette height, feet on one baseline, neutral standing, true pixel art, no anti-aliasing, text or grid lines.
"""

FACING = ('Facing per cell: Down "face and chest toward the viewer"; Up "back toward the viewer, no face"; '
          'Left "profile, nose and toes point toward the LEFT EDGE of the image"; Right "profile, nose and toes point toward the RIGHT EDGE of the image"; '
          'Up-Left "three-quarter back view toward the LEFT EDGE, one cheek visible"; '
          'Down-Left "three-quarter front view toward the LEFT EDGE, both eyes visible"; '
          'Up-Right "three-quarter back view toward the RIGHT EDGE, one cheek visible"; '
          'Down-Right "three-quarter front view toward the RIGHT EDGE, both eyes visible".')

NO_PROPS = "PROPS: none. No weapons, no held items, no extra limbs or props; the hands hold nothing."
UNKNOWN = " [HAND UNKNOWN: confirm from the live still before sending]"


def build_prompt(gender: str) -> str:
    return TEMPLATE.format(gender=gender, hair=HAIR[gender]).rstrip() + "\n"


def _clause(prop: Prop) -> tuple[str, bool]:
    kind, name, side, piece, note, idle = prop
    unknown = "?" in side or "?" in note
    word = side.split()[0]
    if kind == "worn":
        text = f"the {name} is worn {side}, in the same place in every cell where it shows"
    elif word == "both":
        text = f"the {name} is held in BOTH hands in every figure, including Up with the {piece} seen from behind; the grip never changes"
    elif word == "each":
        text = f"one {name} in EACH hand in every figure"
    else:
        other = "left" if word == "right" else "right"
        edge = "left" if word == "right" else "right"
        text = (f"the {name} is in its {word} hand: at the image's {edge} side in Down, {other} side in Up, near side in "
                f"{word.capitalize()}, and only the {piece} shows in {other.capitalize()}")
    if idle:
        text += f"; idle: {'they' if word == 'each' else 'it'} {idle}"
    if note:
        text += f" ({note})"
    return text[0].upper() + text[1:] + "." + (UNKNOWN if unknown else ""), unknown


def build_enemy(enemy: str, body: str = "") -> tuple[str, list[str]]:
    props = ENEMIES[enemy]
    if not props:
        line, unknown = NO_PROPS, []
    else:
        parts = [_clause(p) for p in props]
        unknown = [f"{enemy}: {p[1]} ({p[2]}{'; ' + p[4] if p[4] else ''})" for p, (_, u) in zip(props, parts) if u]
        names = "; ".join(("exactly one " + p[1]) if p[2] != "each" else ("exactly two " + p[1] + "s") for p in props)
        line = (f"PROPS: this character owns {names}. Every full-body figure shows every prop. "
                + " ".join(c for c, _ in parts) + " No other props, extra limbs or duplicated weapons.")
    text = ENEMY_TEMPLATE.format(enemy=enemy, body=body or f"{'an' if enemy[0] in 'aeiou' else 'a'} {enemy} as it looks in the live game", facing=FACING, props=line)
    return text, unknown


def main() -> None:
    parser = argparse.ArgumentParser(epilog="No --root: explicit-path tool, exempt by design (paths are arguments).",
        description="Print a locked 3x3 Bible Imagine text (player: --gender, enemy: --enemy). Copy the block. Printer only."
    )
    what = parser.add_mutually_exclusive_group(required=True)
    what.add_argument("--gender", choices=("male", "female"), help="Player Bible to print: male or female.")
    what.add_argument("--enemy", choices=sorted(ENEMIES), help="Enemy Bible to print, filled from the prop and hand table in this file.")
    what.add_argument("--list-enemies", action="store_true", help="List enemy ids with their props, hands and idle poses (a ? marks an unknown hand).")
    parser.add_argument("--body", default="", help="With --enemy: one clause describing the body (default: 'a ID as it looks in the live game').")
    args = parser.parse_args()
    if args.list_enemies:
        for eid in sorted(ENEMIES):
            sys.stdout.write(f"{eid}: " + ("; ".join(f"{p[1]} [{p[2]}{'; idle ' + p[5] if p[5] else ''}]" for p in ENEMIES[eid]) or "none") + "\n")
    elif args.enemy:
        text, unknown = build_enemy(args.enemy, args.body)
        sys.stdout.write(text)
        for u in unknown:
            sys.stderr.write(f"bible_prompt: UNKNOWN hand '?': {u}\n")
    else:
        sys.stdout.write(build_prompt(args.gender))


if __name__ == "__main__":
    main()
