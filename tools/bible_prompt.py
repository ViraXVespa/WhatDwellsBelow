"""Character Bible Imagine text. Print and copy.

This file stays the locked 3x3 Bible prompt. I2V / overlay prompts stay in
tools/i2v_seeds.py. Do not send Imagine from this path unless the User says to.
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


def build_prompt(gender: str) -> str:
    return TEMPLATE.format(gender=gender, hair=HAIR[gender]).rstrip() + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Print the locked 3x3 Character Bible Imagine text. Copy the block. Printer only."
    )
    parser.add_argument(
        "--gender",
        required=True,
        choices=("male", "female"),
        help="Player Bible to print: male or female.",
    )
    args = parser.parse_args()
    sys.stdout.write(build_prompt(args.gender))


if __name__ == "__main__":
    main()