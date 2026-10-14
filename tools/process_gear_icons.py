#!/usr/bin/env python3
# Key _src/sources/assets/ui/gear/*.(jpg|png) through the live still pipeline into assets/ui/gear/*.png
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image
from imglib import imgio  # noqa: E402
from imglib.geom import fit_box  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import sprite_pipeline as sp  # noqa: E402

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log

SRC = ROOT / "_src" / "sources" / "assets" / "ui" / "gear"
_LEGACY_GEAR = ROOT / "_src" / "gear"
if not SRC.is_dir() and _LEGACY_GEAR.is_dir():
    SRC = _LEGACY_GEAR
DEST = ROOT / "assets" / "ui" / "gear"
CANVAS = 64
PAD = 2

EXPECTED = (
    "slot_head",
    "slot_body",
    "slot_legs",
    "slot_potion",
    "slot_food",
    "great_axe",
    "staff",
    "longbow",
    "moldy_bread",
    "pickaxe",
    "hatchet",
    "head",
    "body",
    "legs",
    "ration",
    "stew",
    "trail_bread",
    "potion",
    "snack",
    "cinder_ember",
    "cinder_coil",
    "tide_pearl",
    "tide_scale",
    "root_knot",
    "root_charm",
    "root_seed",
    "ash_mask",
    "ash_bell",
    "ash_cloak",
    "spark_lens",
    "spark_wire",
    "bone_ring",
    "bone_splint",
    "bone_tooth",
    "veil_shard",
    "veil_thread",
    "veil_coin",
    "veil_hush",
    "iron_seal",
    "iron_nail",
    "iron_link",
    "iron_plate",
    "iron_heart",
)


def key_still(src: Path) -> Image.Image:
    raw = imgio.load(src)
    return sp.key_to_alpha(raw)


def fit_icon(keyed: Image.Image, canvas: int = CANVAS) -> Image.Image:
    return fit_box(keyed, canvas, PAD)


def sources() -> list[Path]:
    found: list[Path] = []
    for path in sorted(SRC.iterdir()) if SRC.is_dir() else []:
        if path.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp"}:
            found.append(path)
    return found


def _check() -> None:
    missing: list[str] = []
    plates = list(SRC.glob("*")) if SRC.is_dir() else []
    for name in EXPECTED:
        found = [p for p in plates if p.stem == name and p.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp"}]
        if not found:
            missing.append(name + " source")
        if not (DEST / (name + ".png")).is_file():
            missing.append(name + " live")
    if missing:
        print("missing " + ", ".join(missing))
        raise SystemExit(1)
    print(f"gear sources ok names={len(EXPECTED)}")


def _run(args) -> None:
    if args.check:
        _check()
        return
    if not SRC.is_dir():
        raise SystemExit(f"missing source dir {SRC}")
    DEST.mkdir(parents=True, exist_ok=True)
    seen: set[str] = set()
    for src in sources():
        dest = DEST / (src.stem + ".png")
        out = fit_icon(key_still(src))
        out.save(dest)
        seen.add(src.stem)
        print(f"wrote {dest.relative_to(ROOT)} {out.size}", flush=True)
    missing = [name for name in EXPECTED if name not in seen]
    if missing:
        print("missing sources: " + ", ".join(missing), flush=True)
    extra = sorted(seen.difference(EXPECTED))
    if extra:
        print("extra sources: " + ", ".join(extra), flush=True)


def _args(ap) -> None:
    ap.add_argument("--check", action="store_true", help="Fail if an expected gear icon has no _src plate or live png. Writes nothing.")


def main(argv: list[str] | None = None) -> int:
    return agent_log.run_writer(
        "process_gear_icons",
        "Key _src/sources/assets/ui/gear source plates through the live still pipeline into assets/ui/gear/*.png.",
        _run,
        argv,
        globals(),
        add_args=_args,
    )


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
