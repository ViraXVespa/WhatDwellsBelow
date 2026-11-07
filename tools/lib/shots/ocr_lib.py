#!/usr/bin/env python3
"""Local Tesseract OCR with a readability rating, so text questions need no LLM vision read.

    python tools/shots.py ocr PNG [PNG ...] [--box X,Y,W,H] [--expect "text"] [--min-conf 70] [--psm 6|7]
Per region: words read, mean confidence, glyph x-height (px, scaled to 1080p), WCAG contrast of text vs the
ring around it, and READ ok|weak|fail (ok = conf >= 80, x-height >= 9 px at 1080p, contrast >= 4.5; weak = one
miss; fail = two or more, or nothing read). --expect adds a fuzzy match ratio (difflib) and fails under 0.8.
Writes _logs/ocr/.tried-<sha1 of the PNG path set> (repo root; shared content-bound contract in ocr_evidence.py)
so the pretool hook lets an LLM text read follow (30 min).
Tesseract: PATH, or WDB_TESSERACT=path. Missing binary prints RESULT SKIP (exit 0).
Install: apt install tesseract-ocr; Windows UB-Mannheim build; no root: micromamba -c conda-forge tesseract.
"""
from __future__ import annotations

import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402,F401
import agent_log

MARK_DIR = Path("_logs/ocr")
OK_CONF, OK_XH, OK_CONTRAST, OK_MATCH = 80.0, 9.0, 4.5, 0.8

from ocr_core import analyse, fmt, tesseract_exe  # shared portable implementation
from ocr_evidence import marker_path, record

def ocr(pngs: list[str], box=None, expect: str = "", psm: int = 6, min_conf: float = 70.0) -> tuple[str, list[dict]]:
    """(PASS|FAIL|SKIP, rows); writes the hook marker for this PNG set."""
    exe = tesseract_exe()
    if not exe:
        record(pngs, agent_log.repo_root(), "SKIP", ["Tesseract not installed"])
        return "SKIP", []
    try:
        rows = [analyse(exe, Path(p), box, expect, psm) for p in pngs]
    except (RuntimeError, OSError) as exc:
        record(pngs, agent_log.repo_root(), "ERROR", [str(exc)])
        raise
    record(pngs, agent_log.repo_root(), "ATTEMPT", [fmt(r) for r in rows])
    bad = [r for r in rows if r["read"] == "fail" or r["conf"] < min_conf]
    return ("FAIL" if bad else "PASS"), rows

def selftest() -> int:
    import tempfile
    from PIL import Image, ImageDraw, ImageFilter, ImageFont
    exe = tesseract_exe()
    if not exe:
        print("RESULT SKIP cmd=selftest reason=tesseract not found")
        return 0
    bad: list[str] = []
    font = None
    for f in ("DejaVuSans.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "arial.ttf"):
        try:
            font = ImageFont.truetype(f, 40)
            break
        except OSError:
            pass
    font = font or ImageFont.load_default(size=40)
    with tempfile.TemporaryDirectory() as td:
        good, weak = Path(td) / "good.png", Path(td) / "weak.png"
        im = Image.new("RGB", (900, 120), (20, 20, 30))
        ImageDraw.Draw(im).text((20, 30), "Report bug to the guild", fill=(240, 240, 240), font=font)
        im.save(good)
        lo = Image.new("RGB", (900, 120), (110, 110, 110))
        ImageDraw.Draw(lo).text((20, 30), "Report bug to the guild", fill=(140, 140, 140), font=font)
        lo.filter(ImageFilter.GaussianBlur(2.5)).save(weak)
        r = analyse(exe, good, None, "Report bug to the guild", 7)
        if r["read"] != "ok" or (r["match"] or 0) < 0.9:
            bad.append("crisp text reads ok and matches: " + fmt(r))
        r2 = analyse(exe, weak, None, "Report bug to the guild", 7)
        if r2["read"] == "ok":
            bad.append("blurred low-contrast copy must not rate ok: " + fmt(r2))
        if not analyse(exe, good, (20, 20, 300, 80), "", 7)["words"]:
            bad.append("--box crop still reads words")
        try:
            analyse(exe, good, (800, 100, 300, 300), "", 7)
            bad.append("a box outside the image must fail")
        except ValueError:
            pass
        if marker_path([str(good)]) == marker_path([str(weak)]):
            bad.append("marker key differs per PNG set")
    return agent_log.selftest_result(bad)

def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Local Tesseract OCR with a READ ok|weak|fail rating per PNG region.")
    ap.add_argument("pngs", nargs="*", help="PNG paths")
    ap.add_argument("--box", default="", metavar="X,Y,W,H", help="Region to read (image pixels)")
    ap.add_argument("--expect", default="", help="Text known to be drawn; adds match=, fails under 0.8")
    ap.add_argument("--min-conf", type=float, default=70.0, help="FAIL when mean confidence is under this (default 70)")
    ap.add_argument("--psm", type=int, default=6, choices=(6, 7), help="6 = block (default), 7 = one line")
    ap.add_argument("--selftest", action="store_true", help="Render known text with PIL; crisp reads ok, blurred low-contrast does not")
    args = ap.parse_args(argv)
    if args.selftest:
        return selftest()
    if not args.pngs:
        agent_log.fail('pass PNG paths (example: python tools/shots.py ocr _logs/shot-flow/title-menu/01-title-card.png --box 40,900,600,80 --expect "Report bug")')
    for p in args.pngs:
        if not Path(p).is_file():
            agent_log.fail(f"not a file: {p}")
    box = None
    if args.box:
        from shot_crop import parse_box
        box = parse_box(args.box)
    try:
        status, rows = ocr(args.pngs, box, args.expect, args.psm, args.min_conf)
    except (ValueError, RuntimeError, OSError) as e:
        agent_log.fail(str(e))
    if status == "SKIP":
        print("RESULT SKIP reason=tesseract not found (PATH or WDB_TESSERACT)")
        return 0
    lines = [fmt(r) for r in rows]
    print("\n".join(lines))
    log = agent_log.repo_root() / MARK_DIR / time.strftime("%Y%m%d-%H%M%S-ocr.txt")
    log.parent.mkdir(parents=True, exist_ok=True)
    log.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return agent_log.emit_result(status, str(log.relative_to(agent_log.repo_root())), regions=len(rows))

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
