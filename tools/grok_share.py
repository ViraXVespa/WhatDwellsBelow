#!/usr/bin/env python3
"""Pull conversation text and images from a Grok share link.

Requires: pip install playwright && playwright install chromium

Images are tagged by turn index (0-based) and attachment index within that turn
so you can save specific ones to different destinations.

Examples:
  python tools/grok_share.py URL --print-convo
  python tools/grok_share.py URL --list-images
  python tools/grok_share.py URL --save-images design/refs/hub-vendor-stall --turn 1 --index 0,1,2
  python tools/grok_share.py URL --save-images _src/sprites/npcs --turn 3 --index 0 --prefix receptionist
"""
from __future__ import annotations

import argparse
import re
import sys
import urllib.request
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log

try:
    from playwright.sync_api import sync_playwright
except ImportError:
    print("error: playwright not installed. Run: pip install playwright && playwright install chromium", file=sys.stderr)
    raise SystemExit(2)


def _clean(text: str) -> str:
    return re.sub(r"\n{3,}", "\n\n", text).strip()


def extract(url: str, timeout: int = 60000) -> tuple[list[dict], list[dict]]:
    """Return (turns, images).

    turns: [{"role": "user"|"grok", "text": str, "turn": int}, ...]
    images: [{"url": str, "turn": int, "index": int, "name": str}, ...]
    """
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()
        page.goto(url, wait_until="networkidle", timeout=timeout)
        page.wait_for_timeout(2000)

        turns: list[dict] = []
        images: list[dict] = []
        turn_idx = 0

        # Walk message containers. User bubbles are typically .bg-secondary;
        # Grok responses sit in the following content blocks.
        containers = page.locator("div.bg-secondary, div[class*='space-y-4'], div.flex.flex-col").all()
        for cont in containers:
            cls = cont.get_attribute("class") or ""
            raw = cont.inner_text().strip()
            if not raw or len(raw) < 8:
                continue
            role = "user" if "bg-secondary" in cls else "grok"
            # Only start a new turn on substantial content
            if len(raw) > 20:
                turns.append({"role": role, "text": _clean(raw), "turn": turn_idx})
                # Images inside this container belong to this turn
                imgs = cont.locator("img").all()
                for i, img in enumerate(imgs):
                    src = img.get_attribute("src") or ""
                    if not src:
                        continue
                    if "grok-img-share" not in src and "session_source" not in src and not src.startswith("http"):
                        continue
                    if src.startswith("./") or src.startswith("/"):
                        src = page.url.rsplit("/", 1)[0] + "/" + src.lstrip("./")
                    name = f"t{turn_idx}-i{i}.jpg"
                    alt = img.get_attribute("alt") or ""
                    if alt and 3 < len(alt) < 40:
                        name = re.sub(r"[^a-zA-Z0-9_-]", "-", alt)[:28] + ".jpg"
                    images.append({"url": src, "turn": turn_idx, "index": i, "name": name})
                turn_idx += 1

        browser.close()
    return turns, images


def save_images(images: list[dict], dest: Path, prefix: str, turn: int | None, indexes: set[int] | None) -> int:
    dest.mkdir(parents=True, exist_ok=True)
    saved = 0
    for img in images:
        if turn is not None and img["turn"] != turn:
            continue
        if indexes is not None and img["index"] not in indexes:
            continue
        fname = f"{prefix}-{img['name']}" if prefix else img["name"]
        path = dest / fname
        try:
            urllib.request.urlretrieve(img["url"], path)
            print(f"saved {path}  (turn={img['turn']} index={img['index']})")
            saved += 1
        except Exception as e:
            print(f"fail {img['url']}: {e}", file=sys.stderr)
    return saved


def main(argv: list[str] | None = None) -> int:
    parser = agent_log.std_parser(
        "Pull conversation + images from a Grok share URL (Playwright).",
        json_out=True,
    )
    parser.add_argument("url", help="Grok share URL (https://x.com/i/grok/share/...)")
    parser.add_argument("--print-convo", action="store_true", help="Print the full conversation")
    parser.add_argument("--list-images", action="store_true", help="List images with turn/index")
    parser.add_argument("--save-images", type=Path, metavar="DEST", help="Download matching images into DEST")
    parser.add_argument("--prefix", default="", help="Filename prefix")
    parser.add_argument("--turn", type=int, default=None, help="Only this turn index (0-based)")
    parser.add_argument("--index", default=None, help="Comma-separated attachment indexes within the turn")
    parser.add_argument("--timeout", type=int, default=60000)
    args = parser.parse_args(sys.argv[1:] if argv is None else argv)

    root = agent_log.resolve_root(args)
    indexes: set[int] | None = None
    if args.index:
        indexes = {int(x.strip()) for x in args.index.split(",") if x.strip()}

    turns, images = extract(args.url, args.timeout)

    lines: list[str] = []
    if args.print_convo or not (args.list_images or args.save_images):
        for t in turns:
            lines.append(f"## {t['role'].title()} (turn {t['turn']})\n\n{t['text']}\n")
        lines.append("--- end convo ---")

    if args.list_images or args.save_images:
        lines.append(f"images: {len(images)}")
        for img in images:
            lines.append(f"  turn={img['turn']} index={img['index']}  {img['name']}  {img['url']}")

    saved = 0
    if args.save_images:
        saved = save_images(images, args.save_images, args.prefix, args.turn, indexes)
        lines.append(f"saved={saved}")

    body = "\n".join(lines)
    print(body)
    status = "PASS"
    return agent_log.emit_result(status, summary="grok-share", turns=len(turns), images=len(images), saved=saved)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
