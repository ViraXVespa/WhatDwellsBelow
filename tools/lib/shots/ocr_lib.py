#!/usr/bin/env python3
"""Local Tesseract OCR with a readability rating, so text questions need no LLM vision read.

    python tools/shots.py ocr PNG [PNG ...] [--box X,Y,W,H] [--expect "text"] [--min-conf 70] [--psm 6|7]
Per region: words read, mean confidence, glyph x-height (px, scaled to 1080p), WCAG contrast of text vs the
ring around it, and READ ok|weak|fail (ok = conf >= 80, x-height >= 9 px at 1080p, contrast >= 4.5; weak = one
miss; fail = two or more, or nothing read). --expect adds a fuzzy match ratio (difflib) and fails under 0.8.
Writes _logs/ocr/.tried-<sha1 of the PNG path set> (repo root; key shared with .grok/hooks/bin/wdb_ocr_gate.py)
so the pretool hook lets an LLM text read follow (30 min).
Tesseract: PATH, or WDB_TESSERACT=path. Missing binary prints RESULT SKIP (exit 0).
Install: apt install tesseract-ocr; Windows UB-Mannheim build; no root: micromamba -c conda-forge tesseract.
"""
from __future__ import annotations

import csv
import difflib
import hashlib
import io
import os
import shutil
import statistics
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib; boot adds every area dir
import boot  # noqa: E402,F401
import agent_log

MARK_DIR = Path("_logs/ocr")
OK_CONF, OK_XH, OK_CONTRAST, OK_MATCH = 80.0, 9.0, 4.5, 0.8

def tesseract_exe() -> str | None:
    env = os.environ.get("WDB_TESSERACT", "")
    if env and Path(env).is_file():
        return env
    return shutil.which("tesseract")

def marker_path(pngs: list[str], root: Path | None = None) -> Path:
    key = "\n".join(sorted(str(Path(p).resolve()) for p in pngs))
    return (root or agent_log.repo_root()) / MARK_DIR / (".tried-" + hashlib.sha1(key.encode()).hexdigest())

def _lum(rgb):
    import numpy as np
    c = rgb.astype(float) / 255.0
    c = np.where(c <= 0.03928, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    return 0.2126 * c[..., 0] + 0.7152 * c[..., 1] + 0.0722 * c[..., 2]

def contrast(arr, words: list[dict]) -> float:
    """WCAG ratio: the 5th/95th luminance tail inside word boxes (whichever is further) vs the median of a 4 px ring."""
    import numpy as np
    if not words:
        return 1.0
    lum = _lum(arr[..., :3])
    h, w = lum.shape
    inner, ring = np.zeros_like(lum, bool), np.zeros_like(lum, bool)
    for wd in words:
        x0, y0, x1, y1 = wd["left"], wd["top"], wd["left"] + wd["width"], wd["top"] + wd["height"]
        ring[max(0, y0 - 4):min(h, y1 + 4), max(0, x0 - 4):min(w, x1 + 4)] = True
        inner[y0:y1, x0:x1] = True
    ring &= ~inner
    if not ring.any() or not inner.any():
        return 1.0
    bg = float(np.median(lum[ring]))
    vals = lum[inner]
    lo, hi = float(np.percentile(vals, 5)), float(np.percentile(vals, 95))
    fg = lo if abs(lo - bg) > abs(hi - bg) else hi
    a, b = max(fg, bg), min(fg, bg)
    return round((a + 0.05) / (b + 0.05), 2)

def x_height(words: list[dict], img_h: int) -> float:
    """Median x-height in px scaled to a 1080-row frame: 0.55 x word box height (0.7 for caps/digits, cap height stands in)."""
    if not words:
        return 0.0
    hs = [wd["height"] * (0.7 if wd["text"].isupper() or not any(c.isalpha() for c in wd["text"]) else 0.55) for wd in words]
    return round(statistics.median(hs) * 1080.0 / img_h, 1)

def read_region(exe: str, im, psm: int) -> list[dict]:
    """Tesseract TSV words (conf >= 0) for a PIL image; upscaled 2x when small so thin UI fonts read."""
    from PIL import Image
    scale = 2 if im.height < 200 else 1
    src = im.convert("RGB")
    if scale > 1:
        src = src.resize((src.width * scale, src.height * scale), Image.LANCZOS)
    buf = io.BytesIO()
    src.save(buf, "PNG")
    p = subprocess.run([exe, "stdin", "stdout", "--psm", str(psm), "tsv"], input=buf.getvalue(), capture_output=True, timeout=60)
    words = []
    for row in csv.DictReader(io.StringIO(p.stdout.decode("utf-8", "replace")), delimiter="\t", quoting=csv.QUOTE_NONE):
        try:
            conf = float(row.get("conf") or -1)
        except ValueError:
            continue
        text = (row.get("text") or "").strip()
        if conf < 0 or not text:
            continue
        words.append({"text": text, "conf": conf, **{k: int(int(row[k]) / scale) for k in ("left", "top", "width", "height")}})
    return words

def rate(conf: float, xh: float, con: float, n: int, match: float | None = None) -> str:
    if not n:
        return "fail"
    miss = (conf < OK_CONF) + (xh < OK_XH) + (con < OK_CONTRAST) + (2 if match is not None and match < OK_MATCH else 0)
    return "ok" if miss == 0 else "weak" if miss == 1 else "fail"

def analyse(exe: str, png: Path, box: tuple[int, int, int, int] | None, expect: str, psm: int) -> dict:
    import numpy as np
    from PIL import Image
    im = Image.open(png).convert("RGBA")
    full_h = im.height
    if box:
        x, y, w, h = box
        if x < 0 or y < 0 or x + w > im.width or y + h > im.height:
            raise ValueError(f"box {x},{y},{w},{h} is outside the {im.width}x{im.height} image")
        im = im.crop((x, y, x + w, y + h))
    words = read_region(exe, im, psm)
    arr = np.asarray(im)
    text = " ".join(w["text"] for w in words)
    conf = round(sum(w["conf"] for w in words) / len(words), 1) if words else 0.0
    xh = x_height(words, full_h)
    con = contrast(arr, words)
    match = None
    if expect:
        a, b = (expect.lower().split(), text.lower().split()) if len(expect.split()) > 1 else (expect.lower(), text.lower())
        match = round(difflib.SequenceMatcher(None, a, b).ratio(), 2)
    return {"png": str(png), "box": box, "text": text, "words": len(words), "conf": conf, "xh": xh,
            "contrast": con, "match": match, "read": rate(conf, xh, con, len(words), match)}

def fmt(r: dict) -> str:
    box = ",".join(map(str, r["box"])) if r["box"] else "full"
    m = f" match={r['match']}" if r["match"] is not None else ""
    return f"READ {r['read']} {Path(r['png']).name} box={box} conf={r['conf']} xh1080={r['xh']} contrast={r['contrast']}{m} words={r['words']} text={r['text']!r}"

def ocr(pngs: list[str], box=None, expect: str = "", psm: int = 6, min_conf: float = 70.0) -> tuple[str, list[dict]]:
    """(PASS|FAIL|SKIP, rows); writes the hook marker for this PNG set."""
    exe = tesseract_exe()
    if not exe:
        return "SKIP", []
    rows = [analyse(exe, Path(p), box, expect, psm) for p in pngs]
    m = marker_path(pngs)
    m.parent.mkdir(parents=True, exist_ok=True)
    m.write_text("\n".join(fmt(r) for r in rows) + "\n", encoding="utf-8")
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
    except ValueError as e:
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
