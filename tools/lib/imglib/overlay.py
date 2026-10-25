"""Post-key overlays: pixel text drawn onto a keyed still after keying and fitting.

A manifest row may carry "overlay": {"lines": [...], "box": [x0, y0, x1, y1] (fractions of the canvas),
"fill": [r, g, b], "centre": "box" | "cloth"}; rekey_all_stills applies it as the last step, so a rekey can never drop it. process_world_pass
uses the same call. Font: gen_prompt_glyphs.FONT (5x7), drop shadow (48, 28, 16) one px down-right.
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

GLYPH_W, GLYPH_H, GLYPH_GAP, LINE_GAP = 5, 7, 2, 2
SHADOW = (48, 28, 16, 255)

def _font() -> dict:
    tools = str(Path(__file__).resolve().parents[1])
    if tools not in sys.path:
        sys.path.insert(0, tools)
    import boot  # noqa: F401  (puts tools/lib/media on sys.path)
    from gen_prompt_glyphs import FONT
    return FONT

def blit_line(im: Image.Image, text: str, x0: int, y0: int, scale: int, fill) -> None:
    """One line of 5x7 glyphs at (x0, y0), each font px a scale x scale block, shadow first."""
    font, px = _font(), im.load()
    blank = ["0" * GLYPH_W] * GLYPH_H
    W, H = im.size
    for i, ch in enumerate(text):
        bx = x0 + i * (GLYPH_W + GLYPH_GAP) * scale
        for gy, row in enumerate(font.get(ch, blank)):
            for gx, bit in enumerate(row):
                if bit != "1":
                    continue
                for oy in range(scale):
                    for ox in range(scale):
                        x, y = bx + gx * scale + ox, y0 + gy * scale + oy
                        if 0 <= x + 1 < W and 0 <= y + 1 < H:
                            px[x + 1, y + 1] = SHADOW
                        if 0 <= x < W and 0 <= y < H:
                            px[x, y] = fill

def cloth_centre_x(im: Image.Image, y0: int, y1: int):
    """Horizontal centre of the red cloth (R above G and B by 15+, R > 70, alpha > 16) in rows y0..y1, from the
    2nd..98th percentile of its columns (stray rim pixels do not shift it); None when under 80 px are found."""
    import numpy as np
    a = np.asarray(im.convert("RGBA"), np.int16)[y0:y1]
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    xs = np.nonzero((a[..., 3] > 16) & (r > g + 15) & (r > b + 15) & (r > 70))[1]
    if xs.size < 80:
        return None
    return (float(np.percentile(xs, 2)) + float(np.percentile(xs, 98)) + 1.0) / 2.0

def text_block(im: Image.Image, lines: list[str], box=(0.2, 0.4, 0.8, 0.68), fill=(236, 214, 164),
               centre: str = "box") -> Image.Image:
    """Centre the lines in box (canvas fractions, padded 8% x / 12% y) at the largest whole scale (min 2).
    centre="cloth": the block is centred horizontally on the detected red cloth instead (size and y unchanged)."""
    im = im.convert("RGBA")
    w, h = im.size
    cx0, cy0, cx1, cy1 = int(w * box[0]), int(h * box[1]), int(w * box[2]), int(h * box[3])
    pad_x, pad_y = max(8, int((cx1 - cx0) * 0.08)), max(6, int((cy1 - cy0) * 0.12))
    inner_w, inner_h = max(8, cx1 - cx0 - pad_x * 2), max(8, cy1 - cy0 - pad_y * 2)
    line_w = max(len(s) for s in lines) * (GLYPH_W + GLYPH_GAP) - GLYPH_GAP
    block_h = len(lines) * GLYPH_H + (len(lines) - 1) * LINE_GAP
    s = max(2, min(inner_w // line_w, inner_h // block_h))
    bx = cx0 + pad_x + (inner_w - line_w * s) // 2
    mid = cloth_centre_x(im, cy0, cy1) if centre == "cloth" else None
    if mid is not None:  # centre the visible ink (blank glyph columns such as the right of "!" excluded)
        probe = Image.new("RGBA", (line_w * s + 2, block_h * s + 2))
        for i, line in enumerate(lines):
            lw = (len(line) * (GLYPH_W + GLYPH_GAP) - GLYPH_GAP) * s
            blit_line(probe, line, (line_w * s - lw) // 2, i * (GLYPH_H + LINE_GAP) * s, s, (255, 255, 255, 255))
        ink = probe.getbbox() or (0, 0, line_w * s, 1)
        bx = int(round(mid - (ink[0] + ink[2] - 1) / 2.0))
    by = cy0 + pad_y + (inner_h - block_h * s) // 2
    fill = tuple(fill)[:3] + (255,)
    for i, line in enumerate(lines):
        lw = (len(line) * (GLYPH_W + GLYPH_GAP) - GLYPH_GAP) * s
        blit_line(im, line, bx + (line_w * s - lw) // 2, by + i * (GLYPH_H + LINE_GAP) * s, s, fill)
    return im

def apply(im: Image.Image, spec: dict | None) -> Image.Image:
    """Apply a manifest "overlay" spec; None returns im unchanged."""
    if not spec:
        return im
    return text_block(im, list(spec["lines"]), tuple(spec.get("box", (0.2, 0.4, 0.8, 0.68))), tuple(spec.get("fill", (236, 214, 164))),
                      spec.get("centre", "box"))
