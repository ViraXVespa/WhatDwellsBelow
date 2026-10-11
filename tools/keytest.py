#!/usr/bin/env python3
"""Keying regression: key every plate in assets/keytest and check the numbers.

    python tools/keytest.py                      key assets/keytest, check tools/keytest_expect.json, write sheets
    python tools/keytest.py --only wisp,hp_orb   a subset (names are file stems)
    python tools/keytest.py --src DIR --out DIR  any folder of plates; generic checks only
    python tools/keytest.py --update             rewrite the expected foreground share from this run

Checks per picture (limits in keytest_expect.json, "default" plus per-name overrides):
  plate_left    visible pixels still plate coloured (share of foreground)
  magenta_left  visible pixels with magenta excess min(R,B)-G > 40 within 14 degrees of the plate hue (share of foreground)
  green_specks  soft pixels the despill turned green (G above R and B by 30, source not green, no green paint within 4 px)
  solid         share of the foreground that is fully opaque (minimum)
  fg            foreground share of the picture, within +-fg_tol of the recorded value (over/under keying)
  repeat        keying twice gives identical bytes
Writes _logs/keytest/<name>.png (keyed), sheets/<name>.png (source | checker | dark | light) and
sheets/overview.png, plus each stage's debug PNG under debug/ (trimap: white solid, orange ring,
blue glow; alpha; keyed). Look at the sheets; a PASS is numbers, not her yes.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
from imglib import matte

EXTS = {".png", ".jpg", ".jpeg", ".webp"}
EXPECT = _TOOLS / "keytest_expect.json"
CELL = 360


def _premul_fit(im: Image.Image, side: int) -> Image.Image:
    a = np.array(im.convert("RGBA")).astype(np.float32)
    a[..., :3] *= a[..., 3:] / 255.0
    s = min(side / im.width, side / im.height)
    size = (max(1, round(im.width * s)), max(1, round(im.height * s)))
    b = np.array(Image.fromarray(np.rint(a).astype(np.uint8), "RGBA").resize(size, Image.LANCZOS)).astype(np.float32)
    b[..., :3] = np.clip(b[..., :3] * 255.0 / np.maximum(b[..., 3:], 1.0), 0, 255)
    return Image.fromarray(np.rint(b).astype(np.uint8), "RGBA")


def _checker(size, c: int = 12) -> Image.Image:
    y, x = np.mgrid[:size[1], :size[0]]
    v = np.where(((x // c) + (y // c)) % 2, 200, 140).astype(np.uint8)
    return Image.fromarray(np.dstack([v, v, v, np.full_like(v, 255)]), "RGBA")


def sheet(src: Image.Image, keyed: Image.Image, label: str) -> Image.Image:
    from PIL import ImageDraw
    out = Image.new("RGB", (CELL * 4, CELL + 18), (48, 48, 48))
    o = src.convert("RGB")
    o.thumbnail((CELL, CELL))
    out.paste(o, (0, 18))
    k = _premul_fit(keyed, CELL)
    for i, bg in enumerate((_checker(k.size), Image.new("RGBA", k.size, (0, 0, 0, 255)), Image.new("RGBA", k.size, (235, 235, 235, 255)))):
        bg.alpha_composite(k)
        out.paste(bg.convert("RGB"), (CELL * (i + 1), 18))
    ImageDraw.Draw(out).text((4, 3), f"{label}   source | checker | dark | light", fill=(230, 230, 230))
    return out


def _near(mask: np.ndarray, r: int) -> np.ndarray:
    import cv2
    return cv2.dilate(mask.astype(np.uint8), np.ones((2 * r + 1, 2 * r + 1), np.uint8)).astype(bool)


def measure(src: Image.Image, keyed: Image.Image, stats: dict) -> dict:
    s = np.array(src.convert("RGB")).astype(np.int32)
    k = np.array(keyed).astype(np.int32)
    a = k[..., 3]
    vis = a > 0
    fg = max(1, int(vis.sum()))
    plate = np.array([int(stats["plate"][i:i + 2], 16) for i in (1, 3, 5)]) if stats.get("plate") else np.array([255, 0, 255])
    near_plate = np.abs(k[..., :3] - plate).max(-1) <= 24
    ex = np.minimum(k[..., 0], k[..., 2]) - k[..., 1]
    hsv = np.array(Image.fromarray(k[..., :3].astype(np.uint8)).convert("HSV")).astype(np.int32)
    ph = np.array(Image.fromarray(plate.astype(np.uint8).reshape(1, 1, 3)).convert("HSV"))[0, 0, 0]
    on_hue = np.abs((hsv[..., 0] - int(ph) + 128) % 256 - 128) <= 10
    soft = vis & (a < 255)
    src_green = s[..., 1] - np.maximum(s[..., 0], s[..., 2])
    out_green = k[..., 1] - np.maximum(k[..., 0], k[..., 2])
    solid_green = (a == 255) & (out_green > 10)  # green paint nearby makes a green edge legitimate
    return {
        "plate_left": round(float((vis & near_plate).sum()) / fg, 5),
        "magenta_left": round(float((vis & (ex > 40) & on_hue).sum()) / fg, 5),
        "green_specks": int((soft & (out_green > 30) & (src_green <= 0) & ~_near(solid_green, 4)).sum()),
        "solid": round(float((a == 255).sum()) / fg, 4),
        "fg": round(fg / a.size, 4),
        "partial": int(soft.sum()),
    }


def check(name: str, m: dict, exp: dict, recorded: dict) -> list[str]:
    lim = dict(exp.get("default", {}))
    lim.update(exp.get(name, {}))
    bad = []
    if m["plate_left"] > lim.get("plate_left", 0.001):
        bad.append(f"plate_left {m['plate_left']} > {lim.get('plate_left', 0.001)}")
    if m["magenta_left"] > lim.get("magenta_left", 0.002):
        bad.append(f"magenta_left {m['magenta_left']} > {lim.get('magenta_left', 0.002)}")
    if m["green_specks"] > lim.get("green_specks", 0):
        bad.append(f"green_specks {m['green_specks']} > {lim.get('green_specks', 0)}")
    if m["solid"] < lim.get("solid", 0.85):
        bad.append(f"solid {m['solid']} < {lim.get('solid', 0.85)}")
    if name in recorded and abs(m["fg"] - recorded[name]) > lim.get("fg_tol", 0.01):
        bad.append(f"fg {m['fg']} vs recorded {recorded[name]} (+-{lim.get('fg_tol', 0.01)})")
    if not m["repeat"]:
        bad.append("repeat: keying twice gave different bytes")
    return bad


def check_callers(root: Path) -> list[str]:
    """Compile every tool that calls the keyer and flag removed keywords (spill_flood, tol, refs)."""
    import ast
    bad = []
    for f in sorted((root / "tools").rglob("*.py")):
        text = f.read_text(encoding="utf-8-sig")
        if not any(w in text for w in ("key_to_alpha", "punch(", "fit_canvas", "flatten_magenta_to_alpha")):
            continue
        try:
            tree = ast.parse(text, str(f))
        except SyntaxError as exc:
            bad.append(f"{f.name}: {exc}")
            continue
        for node in ast.walk(tree):
            if isinstance(node, ast.Call):
                fn = node.func.attr if isinstance(node.func, ast.Attribute) else getattr(node.func, "id", "")
                if fn in ("key_to_alpha", "punch", "fit_canvas", "flatten_magenta_to_alpha"):
                    for kw in node.keywords:
                        if kw.arg in ("spill_flood", "tol", "refs"):
                            bad.append(f"{f.name}:{node.lineno} {fn}({kw.arg}=) was removed")
    return bad


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Key assets/keytest (or --src) and check the numbers; write review sheets.", writes=True)
    ap.add_argument("--src", default="", help="Folder of plates (default: assets/keytest).")
    ap.add_argument("--out", default="", help="Output folder (default: _logs/keytest).")
    ap.add_argument("--only", default="", help="Comma-separated file stems.")
    ap.add_argument("--update", action="store_true", help="Record this run's foreground share in keytest_expect.json.")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    src_dir = Path(args.src) if args.src else root / "assets" / "keytest"
    out = Path(args.out) if args.out else root / "_logs" / "keytest"
    in_repo = not args.src
    exp = json.loads(EXPECT.read_text(encoding="utf-8")) if EXPECT.is_file() else {}
    recorded = exp.get("recorded_fg", {}) if in_repo else {}
    wanted = {w.strip() for w in args.only.split(",") if w.strip()}
    files = sorted(p for p in src_dir.rglob("*") if p.suffix.lower() in EXTS and (not wanted or p.stem in wanted))
    if not files:
        agent_log.fail(f"no plates under {src_dir}")
    if not args.dry_run:
        (out / "sheets").mkdir(parents=True, exist_ok=True)
    lines, sheets, fails = [], [], 0
    for p in files:
        name = p.stem if in_repo else p.stem[:16]
        src = Image.open(p)
        src.load()
        keyed, stats = matte.key(src, debug=None if args.dry_run else out / "debug", name=name)
        again, _ = matte.key(src)
        m = measure(src, keyed, stats)
        m["repeat"] = np.array_equal(np.array(keyed), np.array(again))
        bad = check(name, m, exp, recorded) if in_repo else check(name, m, {"default": exp.get("default", {})}, {})
        fails += int(bool(bad))
        lines.append(f"{'FAIL' if bad else 'ok  '} {name} plate={stats.get('plate')} ring={stats.get('ring')} "
                     + " ".join(f"{k}={v}" for k, v in m.items()) + (" | " + "; ".join(bad) if bad else ""))
        if in_repo and args.update:
            exp.setdefault("recorded_fg", {})[name] = m["fg"]
        if not args.dry_run:
            keyed.save(out / f"{name}.png")
            sh = sheet(src, keyed, name)
            sh.save(out / "sheets" / f"{name}.png")
            sheets.append(sh)
    if sheets and not args.dry_run:
        ov = Image.new("RGB", (sheets[0].width, sum(s.height for s in sheets)), (48, 48, 48))
        y = 0
        for s in sheets:
            ov.paste(s, (0, y))
            y += s.height
        ov.thumbnail((CELL * 4, 6000))
        ov.save(out / "sheets" / "overview.png")
        lines.append(f"sheets: {out / 'sheets'}")
    if in_repo:
        cb = check_callers(root)
        fails += len(cb)
        lines.append("callers: " + ("ok (every tool that calls the keyer compiles, no removed keywords)" if not cb else "; ".join(cb)))
    if in_repo and args.update and not args.dry_run:
        EXPECT.write_text(json.dumps(exp, indent=2) + "\n", encoding="utf-8")
        lines.append("recorded fg updated in tools/keytest_expect.json")
    return agent_log.finish("keytest", root, "\n".join(lines), "FAIL" if fails else "PASS", args=args, checked=len(files), failing=fails)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
