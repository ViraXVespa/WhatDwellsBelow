#!/usr/bin/env python3
from pathlib import Path
from PIL import Image
import math
from imglib import imgio  # noqa: E402
from imglib.color import dist  # noqa: E402
import sys

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
import match_keyed_region as matcher
from imglib import key as plate_key

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites" / "player"
OUT.mkdir(parents=True, exist_ok=True)

# Optional: session dump of raw Imagine stills. Override if you re-run from a new session.
SESSION = Path(r"")
FILES = {
    "down": SESSION / "1.jpg",
    "right": SESSION / "2.jpg",
    "up": SESSION / "3.jpg",
    "left": SESSION / "4.jpg",
}

CANVAS = 128


def key_and_fit(src: Path, dest: Path) -> None:
    use = matcher.resolve_source(dest, src)
    if use is None:
        raise SystemExit(f"missing source for {dest}")
    im = plate_key.punch(imgio.load(use))
    bbox = im.getbbox()
    if not bbox:
        raise SystemExit(f"empty after key: {src}")
    cropped = im.crop(bbox)
    # pad 8px then fit
    cw, ch = cropped.size
    pad = 8
    box = Image.new("RGBA", (cw + pad * 2, ch + pad * 2), (0, 0, 0, 0))
    box.paste(cropped, (pad, pad), cropped)
    scale = min(CANVAS / box.size[0], CANVAS / box.size[1])
    nw = max(1, int(box.size[0] * scale))
    nh = max(1, int(box.size[1] * scale))
    resized = box.resize((nw, nh), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    ox = (CANVAS - nw) // 2
    oy = (CANVAS - nh) // 2
    canvas.paste(resized, (ox, oy), resized)
    dest.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(dest)
    print(f"wrote {dest} from {src.name} bbox={bbox} -> {nw}x{nh}")


def _run() -> None:
    for name, src in FILES.items():
        key_and_fit(src, OUT / f"{name}.png")


def main(argv: list[str] | None = None) -> int:
    return agent_log.run_writer("process_sprites", 'Key numbered _src stills (1.jpg ...) into engine sprites.', _run, argv, globals())


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
