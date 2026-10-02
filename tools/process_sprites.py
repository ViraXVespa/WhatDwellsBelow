#!/usr/bin/env python3
from pathlib import Path
from PIL import Image
import math
from sprite_lib import dist  # noqa: E402
import sys

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log

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

BG = (239, 19, 106)
THRESH = 55
CANVAS = 128


def key_and_fit(src: Path, dest: Path) -> None:
    im = Image.open(src).convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if dist((r, g, b), BG) <= THRESH:
                px[x, y] = (0, 0, 0, 0)
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
    if not SESSION.exists():
        raise SystemExit("Set SESSION to a folder of raw Imagine stills (down/right/up/left jpgs).")
    for name, src in FILES.items():
        if not src.exists():
            raise SystemExit(f"missing {src}")
        key_and_fit(src, OUT / f"{name}.png")


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("process_sprites")
    ap.parse_args(argv)
    _run()
    return agent_log.emit_result("PASS", tool="process_sprites")


if __name__ == "__main__":
    raise SystemExit(main())
