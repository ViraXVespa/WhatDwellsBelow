#!/usr/bin/env python3
"""Pull conversation text and images from a Grok share link.

Requires: pip install playwright && playwright install chromium

Examples:
  python tools/grok_share.py URL --list-images
  python tools/grok_share.py URL --channel msedge --user-data-dir "%LOCALAPPDATA%\\Microsoft\\Edge\\User Data" --list-images
"""
from __future__ import annotations

import argparse
import os
import re
import sys
import urllib.request
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log

def _need_playwright():
    try:
        from playwright.sync_api import sync_playwright
        return sync_playwright
    except ImportError:
        print("error: playwright not installed. Run: pip install playwright && playwright install chromium", file=sys.stderr)
        raise SystemExit(2)


UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/120.0.0.0 Safari/537.36"
)


def _clean(text: str) -> str:
    return re.sub(r"\n{3,}", "\n\n", text).strip()


def extract(page, url: str, timeout: int = 120000, debug: bool = False) -> tuple[list[dict], list[dict], str]:
    page.add_init_script("""
        Object.defineProperty(navigator, 'webdriver', {get: () => undefined});
        Object.defineProperty(navigator, 'plugins', {get: () => [1, 2, 3]});
        Object.defineProperty(navigator, 'languages', {get: () => ['en-US', 'en']});
        window.chrome = { runtime: {} };
    """)
    page.goto(url, wait_until="domcontentloaded", timeout=timeout)
    page.wait_for_timeout(3000)
    try:
        page.wait_for_selector("img[src*='mediaId'], img[src*='attachment.json'], img[src*='grok-img-share']", timeout=15000)
    except Exception:
        pass
    page.wait_for_timeout(2000)

    final_url = page.url
    title = page.title()
    html = page.content()
    main_text = page.locator("main").inner_text() if page.locator("main").count() else ""

    debug_info = f"final_url={final_url!r} title={title!r} main_len={len(main_text)} html_len={len(html)}"
    if debug:
        debug_info += "\n--- html snippet ---\n" + html[:2500]

    images: list[dict] = []
    seen = set()
    for img in page.locator("img").all():
        src = img.get_attribute("src") or ""
        if not src or src in seen:
            continue
        if not ("grok-img-share" in src or "attachment.json" in src or "mediaId" in src):
            continue
        m = re.search(r"mediaId=(\d+)", src)
        if m:
            src = f"https://pbs.twimg.com/grok-img-share/{m.group(1)}.jpg"
        if src in seen:
            continue
        seen.add(src)
        images.append({"url": src, "turn": -1, "index": len(images), "name": f"img-{len(images):02d}.jpg"})

    turns: list[dict] = []
    bubbles = page.locator("div.bg-secondary, div[class*='space-y-4'], article, [data-testid*='message']").all()
    turn_idx = 0
    for cont in bubbles:
        raw = cont.inner_text().strip()
        if len(raw) < 15:
            continue
        cls = cont.get_attribute("class") or ""
        role = "user" if "bg-secondary" in cls else "grok"
        turns.append({"role": role, "text": _clean(raw), "turn": turn_idx})
        turn_idx += 1

    if not turns and main_text:
        chunks = [c.strip() for c in re.split(r"\n{2,}", main_text) if len(c.strip()) > 20]
        for i, chunk in enumerate(chunks[:15]):
            turns.append({"role": "mixed", "text": _clean(chunk), "turn": i})

    return turns, images, debug_info


def save_images(page, images: list[dict], dest: Path, prefix: str, turn: int | None, indexes: set[int] | None) -> int:
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
            resp = page.request.get(img["url"])
            if not resp.ok:
                print(f"fail {img['url']}: HTTP {resp.status}", file=sys.stderr)
                continue
            path.write_bytes(resp.body())
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
    parser.add_argument("url", help="Grok share URL")
    parser.add_argument("--print-convo", action="store_true", help="Print the conversation text.")
    parser.add_argument("--list-images", action="store_true", help="List the image URLs in the share.")
    parser.add_argument("--save-images", type=Path, metavar="DEST", help="Save the share's images into this folder.")
    parser.add_argument("--prefix", default="", help="File-name prefix for saved images.")
    parser.add_argument("--turn", type=int, default=None, help="Only this conversation turn number (as printed in the turn headers).")
    parser.add_argument("--index", default=None, help="Only these image indexes within the turn, e.g. 0,2.")
    parser.add_argument("--timeout", type=int, default=120000, help="Page-load timeout in ms (default 120000).")
    parser.add_argument("--debug", action="store_true", help="Add a DEBUG line with page diagnostics to the output.")
    parser.add_argument("--headed", action="store_true", help="Show the browser (use once to log in)")
    parser.add_argument("--channel", default="msedge", help="Browser channel (default: msedge)")
    parser.add_argument("--user-data-dir", type=Path, default=None, help="Persistent profile directory (default: %%USERPROFILE%%/.grok-edge-profile)")
    args = parser.parse_args(sys.argv[1:] if argv is None else argv)

    agent_log.resolve_root(args)
    indexes: set[int] | None = None
    if args.index:
        indexes = {int(x.strip()) for x in args.index.split(",") if x.strip()}

    with _need_playwright()() as p:
        default_profile = Path(os.path.expandvars("%USERPROFILE%")) / ".grok-edge-profile"
        udd = Path(os.path.expandvars(str(args.user_data_dir or default_profile))).resolve()
        repo = agent_log.resolve_root(args)
        if repo in udd.parents or udd == repo:
            print(f"error: --user-data-dir must be outside the repo (got {udd})", file=sys.stderr)
            return 2
        profile_empty = not udd.exists() or not any(udd.iterdir())
        if profile_empty and not args.headed:
            print(f"Profile not ready at {udd}")
            print("One-time setup:")
            print(f'  python tools/grok_share.py "{args.url}" --headed')
            print("Log in to X in the window that opens, then close it. Later runs stay headless.")
            return 2
        if profile_empty and args.headed:
            print(f"Creating profile at {udd} -- log in to X in the window, then close it.")
            udd.mkdir(parents=True, exist_ok=True)
        launch_kwargs = {
            "headless": not args.headed,
            "args": [
                "--disable-blink-features=AutomationControlled",
                "--disable-dev-shm-usage",
            ],
        }
        if args.channel:
            launch_kwargs["channel"] = args.channel
        context = p.chromium.launch_persistent_context(
            str(udd),
            **launch_kwargs,
            user_agent=UA,
            viewport={"width": 1280, "height": 900},
            locale="en-US",
        )
        page = context.pages[0] if context.pages else context.new_page()

        turns, images, debug_info = extract(page, args.url, args.timeout, args.debug)
        saved = 0
        if args.save_images:
            saved = save_images(page, images, args.save_images, args.prefix, args.turn, indexes)
        if args.headed:
            print("\nBrowser is open. Log in to X if needed, then press Enter here to close and save the profile...")
            try:
                input()
            except EOFError:
                pass

    lines: list[str] = []
    if args.debug:
        lines.append(f"DEBUG {debug_info}")
    if args.print_convo or not (args.list_images or args.save_images):
        for t in turns:
            lines.append(f"## {t['role'].title()} (turn {t['turn']})\n\n{t['text']}\n")
        lines.append("--- end convo ---")

    if args.list_images or args.save_images:
        lines.append(f"images: {len(images)}")
        for img in images:
            lines.append(f"  turn={img['turn']} index={img['index']}  {img['name']}  {img['url']}")

    if args.save_images:
        lines.append(f"saved={saved}")

    print("\n".join(lines))
    return agent_log.emit_result("PASS", summary="NONE", turns=len(turns), images=len(images), saved=saved)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
