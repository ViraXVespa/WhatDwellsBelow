"""Portable Tesseract measurements shared with isolated image-review helpers."""
from __future__ import annotations

import csv
import difflib
import io
import os
import shutil
import statistics
import subprocess
from pathlib import Path

OK_CONF, OK_XH, OK_CONTRAST, OK_MATCH = 80.0, 9.0, 4.5, 0.8

def tesseract_exe() -> str | None:
    env = os.environ.get("WDB_TESSERACT", "")
    if env and Path(env).is_file():
        return env
    return shutil.which("tesseract")

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
    try:
        p = subprocess.run([exe, "stdin", "stdout", "--psm", str(psm), "tsv"], input=buf.getvalue(), capture_output=True, timeout=60)
    except subprocess.TimeoutExpired as exc:
        raise RuntimeError("Tesseract timed out after 60s") from exc
    if p.returncode:
        raise RuntimeError(f"Tesseract exited {p.returncode}: {p.stderr.decode('utf-8', 'replace')[:300]}")
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

