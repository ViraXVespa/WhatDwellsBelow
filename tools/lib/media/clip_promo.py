#!/usr/bin/env python3
"""Promo before/after wipe for `media.py clip wipe|ba --style promo` (ported from the Bottie Boop prototype ba_proto.py):
one dominant label chip (big word + small subline) bottom-left that crossfades BEFORE -> AFTER while the divider crosses
the middle, a smootherstep sweep with a glowing divider and round grip, then an optional end card (last frame blurred and
darkened, title + subline fading up). Overlays are drawn once with Pillow and slid or faded by ffmpeg."""
from __future__ import annotations

import tempfile
from pathlib import Path

import clip_edit as ce

INK = (20, 18, 24, 215)
COL = ((200, 200, 205, 255), (255, 206, 92, 255))
GOLD = (255, 214, 120, 255)

def _f(path: str, size: int, weight: str = "Bold"):
    from PIL import ImageFont
    f = ImageFont.truetype(path, size) if path else ImageFont.load_default(size)
    try:
        f.set_variation_by_name(weight)
    except Exception:
        pass
    return f

def chip(text: str, sub: str, fg, font: str, h: int, path: Path) -> None:
    """Label chip: big word, small subline, dark rounded plate with an accent bar and a soft shadow."""
    from PIL import Image, ImageDraw, ImageFilter
    k = h / 720
    f1, f2 = _f(font, int(64 * k)), _f(font, int(30 * k), "Medium")
    pw = int(max(300 * k, f1.getbbox(text)[2] + 60 * k, f2.getbbox(sub)[2] + 60 * k)) if sub else int(max(300 * k, f1.getbbox(text)[2] + 60 * k))
    ph, m = int((128 if sub else 92) * k), int(12 * k)
    im = Image.new("RGBA", (pw + 2 * m, ph + 2 * m), (0, 0, 0, 0))
    sh = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle((m + 2, m + 4, pw + m + 2, ph + m + 4), int(18 * k), fill=(0, 0, 0, 150))
    im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(6 * k)))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((m, m, pw + m, ph + m), int(18 * k), fill=INK)
    d.rounded_rectangle((m, m, m + int(10 * k), ph + m), int(5 * k), fill=fg)
    d.text((m + 32 * k, m + 6 * k), text, font=f1, fill=fg)
    if sub:
        d.text((m + 34 * k, m + 84 * k), sub, font=f2, fill=(230, 225, 210, 220))
    im.save(path)

def grip(h: int, path: Path) -> int:
    """Divider: soft glow, 4 px line, round grip with arrows; returns its width."""
    from PIL import Image, ImageDraw, ImageFilter
    k = h / 720
    hw, r = int(120 * k) // 2 * 2, int(30 * k)
    im = Image.new("RGBA", (hw, h), (0, 0, 0, 0))
    g = Image.new("RGBA", (hw, h), (0, 0, 0, 0))
    ImageDraw.Draw(g).rectangle((hw // 2 - 6, 0, hw // 2 + 6, h), fill=(0, 0, 0, 140))
    im.alpha_composite(g.filter(ImageFilter.GaussianBlur(8 * k)))
    d = ImageDraw.Draw(im)
    d.rectangle((hw // 2 - 2, 0, hw // 2 + 1, h), fill=(255, 244, 214, 255))
    cy = h // 2
    d.ellipse((hw // 2 - r, cy - r, hw // 2 + r, cy + r), fill=(255, 244, 214, 255), outline=(40, 30, 20, 255), width=max(2, int(3 * k)))
    for s in (-1, 1):
        x0 = hw // 2 + s * 6 * k
        d.polygon([(x0 + s * 14 * k, cy), (x0, cy - 10 * k), (x0, cy + 10 * k)], fill=(40, 30, 20, 255))
    im.save(path)
    return hw

def card(title: str, sub: str, font: str, w: int, h: int, path: Path) -> None:
    from PIL import Image, ImageDraw, ImageFilter
    k = h / 720
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    t, s = _f(font, int(92 * k)), _f(font, int(44 * k), "Medium")
    tw, sw, y = t.getbbox(title)[2], s.getbbox(sub)[2] if sub else 0, int(270 * k)
    sh = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(sh).text(((w - tw) // 2 + 4, y + 4), title, font=t, fill=(0, 0, 0, 220))
    im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(5 * k)))
    d = ImageDraw.Draw(im)
    d.text(((w - tw) // 2, y), title, font=t, fill=GOLD)
    if sub:
        d.line(((w - 360 * k) // 2, y + 122 * k, (w + 360 * k) // 2, y + 122 * k), fill=GOLD[:3] + (180,), width=2)
        d.text(((w - sw) // 2, y + 142 * k), sub, font=s, fill=(240, 235, 220, 255))
    im.save(path)

def _ease_expr(t0: float, d: float) -> str:
    p = "clip((t-%.3f)/%.3f,0,1)" % (t0, max(d, 0.001))
    return "(%s*%s*%s*(%s*(%s*6-15)+10))" % ((p,) * 5)

def _ease(u: float) -> float:
    u = min(max(u, 0.0), 1.0)
    return u * u * u * (u * (u * 6 - 15) + 10)

def _t_at(frac: float, hold: float, sweep: float) -> float:
    lo, hi = 0.0, 1.0
    for _ in range(40):
        m = (lo + hi) / 2
        lo, hi = (m, hi) if _ease(m) < frac else (lo, m)
    return hold + sweep * lo

def wipe(before: Path, after: Path, out: Path, labels=("BEFORE", "AFTER"), subs=("", ""), hold: float = 1.2, sweep: float = 1.6,
         hold_b: float = 2.2, end: tuple[str, str] | None = None, end_sec: float = 1.8, font: str = "") -> dict:
    """One eased sweep (after revealed from the left), chip crossfade at the middle, optional end card. Returns timings."""
    a = ce.info(before)
    w, h, fps = a["w"] - a["w"] % 2, a["h"] - a["h"] % 2, round(float(a["fps"])) or 30
    font = ce._font(font)
    t1 = hold + sweep
    clip = max(t1 + hold_b, 0.5)
    total = clip + (end_sec if end else 0.0)
    x_lo, x_hi = _t_at(0.30, hold, sweep), _t_at(0.70, hold, sweep)
    fd = max(0.3, x_hi - x_lo)
    e = _ease_expr(hold, sweep)
    norm = "scale=%d:%d:flags=lanczos,setsar=1,fps=%d,tpad=stop_mode=clone:stop_duration=%.2f,trim=duration=%.3f,setpts=PTS-STARTPTS" % (w, h, fps, clip, clip)
    with tempfile.TemporaryDirectory() as td:
        T = Path(td)
        chip(labels[0], subs[0], COL[0], font, h, T / "a.png")
        chip(labels[1], subs[1], COL[1], font, h, T / "b.png")
        hw = grip(h, T / "g.png")
        pngs = [T / "g.png", T / "a.png", T / "b.png"]
        lx = int(30 * h / 720)
        fc = (f"[0:v]{norm}[a];[1:v]{norm}[b];"
              f"color=c=black:s={w}x{h}:r={fps}:d={clip:.3f}[k];color=c=white:s={w}x{h}:r={fps}:d={clip:.3f}[wt];"
              f"[k][wt]overlay=x='W*{e}-W':eval=frame,format=gray[m];[b]format=yuva420p[ba];[ba][m]alphamerge[bm];[a][bm]overlay=0:0[w0];"
              f"[2:v]fps={fps},trim=duration={clip:.3f},format=rgba,fade=t=in:st={max(hold - 0.25, 0):.3f}:d=0.25:alpha=1,"
              f"fade=t=out:st={t1:.3f}:d=0.3:alpha=1[hd];[w0][hd]overlay=x='W*{e}-{hw // 2}':y=0:eval=frame[w1];"
              f"[3:v]fps={fps},trim=duration={clip:.3f},format=rgba,fade=t=in:st=0.15:d=0.3:alpha=1,fade=t=out:st={x_lo:.3f}:d={fd:.3f}:alpha=1[la];"
              f"[4:v]fps={fps},trim=duration={clip:.3f},format=rgba,fade=t=in:st={x_lo + fd * 0.4:.3f}:d={fd * 0.6:.3f}:alpha=1"
              + (f",fade=t=out:st={clip - 0.6:.3f}:d=0.3:alpha=1" if end else "") + "[lb];"
              f"[w1][la]overlay=x='{lx}-{lx * 4 // 3}*(1-clip((t-0.15)/0.3,0,1))':y=H-h-{lx}[w2];[w2][lb]overlay=x={lx}:y=H-h-{lx}")
        if end:
            card(end[0], end[1], font, w, h, T / "e.png")
            pngs.append(T / "e.png")
            fc += (f"[cmp];[cmp]fps={fps},settb=1/{fps},split[cA][cB];[cB]trim=start={clip - 1 / fps:.3f},setpts=PTS-STARTPTS,"
                   f"tpad=stop_mode=clone:stop_duration={end_sec:.2f},trim=duration={end_sec:.3f},gblur=sigma={14 * h / 720:.1f},eq=brightness=-0.18:saturation=0.8[eb];"
                   f"[5:v]fps={fps},trim=duration={end_sec:.3f},format=rgba,fade=t=in:st=0.15:d=0.45:alpha=1[ec];[eb][ec]overlay=0:0,fps={fps},settb=1/{fps}[en];"
                   f"[cA][en]xfade=transition=fade:duration=0.4:offset={clip - 0.4:.3f}")
            total -= 0.4
        fc += ",format=yuv420p[o]"
        loops = [x for p in pngs for x in ("-loop", "1", "-framerate", str(fps), "-t", "%.2f" % (clip + end_sec), "-i", str(p))]
        ce._run(["-i", str(before), "-i", str(after), *loops, "-filter_complex", fc, "-map", "[o]", "-an", *ce.H264, "-r", str(fps), str(out)])
    return {"sec": round(total, 2), "swap": [round(x_lo, 2), round(x_lo + fd, 2)], "end": bool(end)}
