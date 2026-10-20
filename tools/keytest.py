#!/usr/bin/env python3
"""Golden-set keying regression: truth mattes under _src/truth, keyed again from hard synthetic plates.

    python tools/keytest.py                  every golden picture: errors against its truth matte, sheets
    python tools/keytest.py --only nail,wisp a subset (golden names)
    python tools/keytest.py --make-truth     rewrite the truth mattes from the current key of the real plates

Each truth matte (_src/truth/<name>.png, RGBA at source size) is composited over a synthetic Imagine-style plate
(magenta drifting across the picture, B 153..243, a luma gradient, pixel noise, JPEG q80) and keyed again
(imglib.matte). Checks (limits in keytest_expect.json, "default" plus per-name overrides):
  sad      mean |alpha - truth| over the truth's edge band (pixels within 4 px of partial or clear), full size
  area     the same at output scale: both shrunk by the premultiplied box to the live still's size, mean over edge px
  edge     mean sub-pixel edge position error at output scale, px (rekey_all_stills.metrics)
  halo     visible partial pixels still plate-coloured at output scale (share)
  inner_mad     mean |RGB| inside the edge band after the fit shrink (geom.shrink_art) vs nearest-sampled truth
  inner_detail  Laplacian energy there over truth's, a minimum (an averaging shrink reads about 0.6)
  real     mean |alpha - truth| of the key of the real plate (drift since the truth was made)
  repeat   keying twice gives identical bytes
The truth mattes come from the keyer and were reviewed by eye once; they pin behaviour on hard plates, they are
not hand-painted ground truth. Writes _logs/keytest/<name>.png sheets (plate | keyed on checker | on black | alpha
error, red = too opaque, blue = too clear) and _logs/keytest/last.json.
"""
from __future__ import annotations

import io
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
import rekey_all_stills as ras
from imglib import geom, matte

ROOT = _TOOLS.parent
TRUTH = ROOT / "_src" / "truth"
EXPECT = _TOOLS / "keytest_expect.json"
GOLDEN = {  # name: (live still, source plate under _src)
    "nail": ("assets/ui/gear/iron_nail.png", "sources/assets/ui/gear/iron_nail.png"),
    "crack": ("assets/fx/crack.png", "sources/assets/fx/crack.jpg"),
    "lightning": ("assets/fx/lightning.png", "sources/assets/fx/lightning.jpg"),
    "tree": ("assets/sprites/props/tree.png", "sources/assets/sprites/props/tree.jpg"),
    "longbow": ("assets/ui/gear/longbow.png", "sources/assets/ui/gear/longbow.jpg"),
    "wisp": ("assets/sprites/enemies/wisp/idle_down.png", "sources/assets/sprites/enemies/wisp/idle_up.jpg"),
    "female": ("assets/sprites/player/female/idle_down.png", "sources/assets/sprites/player/female/idle_down.png"),
}

def synthetic(truth: Image.Image, seed: int = 7) -> Image.Image:
    """truth over a drifting, noisy magenta plate, then a JPEG q80 round trip."""
    t = np.asarray(truth, np.float32)
    h, w = t.shape[:2]
    y, x = np.mgrid[:h, :w].astype(np.float32)
    u, v = x / max(1, w - 1), y / max(1, h - 1)
    plate = np.dstack([235 - 25 * v, 10 + 20 * u * v, 153 + 90 * u])  # B 153..243, R and G drift too
    plate += np.random.default_rng(seed).normal(0, 3.0, plate.shape)
    a = t[..., 3:] / 255.0
    comp = np.clip(t[..., :3] * a + plate * (1 - a), 0, 255).astype(np.uint8)
    buf = io.BytesIO()
    Image.fromarray(comp).save(buf, "JPEG", quality=80)
    return Image.open(io.BytesIO(buf.getvalue())).convert("RGB")

def _band(ta: np.ndarray) -> np.ndarray:
    import cv2
    soft = (ta < 255).astype(np.uint8) & (cv2.dilate((ta > 0).astype(np.uint8), np.ones((9, 9), np.uint8)))
    return cv2.dilate(soft, np.ones((9, 9), np.uint8)).astype(bool) & cv2.dilate((ta > 0).astype(np.uint8), np.ones((9, 9), np.uint8)).astype(bool)

def _small(im: Image.Image, truth: Image.Image, live: Path) -> Image.Image:
    """Truth's crop and the live still's scale for both (the same footprints, so placement cannot differ)."""
    ref = Image.open(live).convert("RGBA")
    rb, sb, box = geom.core_box(ref, 128), geom.core_box(truth, 128), truth.getbbox()
    k = float(np.sqrt((rb[2] - rb[0]) / max(1, sb[2] - sb[0]) * (rb[3] - rb[1]) / max(1, sb[3] - sb[1])))
    c = im.crop(box)
    return geom.resize_rgba(c, (max(1, round(c.width * k)), max(1, round(c.height * k))))

def _interior(keyed: Image.Image, truth: Image.Image, live: Path) -> dict:
    """Interior detail after the fit shrink (geom.shrink_art): inside the edge band the keyed pixels must be the
    nearest source pixels, not an average. inner_mad: mean |RGB| vs nearest-sampled truth inside the band;
    inner_detail: Laplacian energy there over truth's (an averaging shrink reads about 0.6)."""
    import cv2
    from imglib import band
    ref = Image.open(live).convert("RGBA")
    rb, sb, box = geom.core_box(ref, 128), geom.core_box(truth, 128), truth.getbbox()
    k = float(np.sqrt((rb[2] - rb[0]) / max(1, sb[2] - sb[0]) * (rb[3] - rb[1]) / max(1, sb[3] - sb[1])))
    size = (max(1, round((box[2] - box[0]) * k)), max(1, round((box[3] - box[1]) * k)))
    sk = np.asarray(geom.shrink_art(keyed.crop(box), size), np.float32)
    nt = np.asarray(truth.crop(box).resize(size, Image.Resampling.NEAREST), np.float32)
    inner, _ = band.band_info(sk[..., 3].astype(np.uint8), sk[..., :3])
    inner &= nt[..., 3] == 255
    if int(inner.sum()) < 16:
        return {"inner_mad": 0.0, "inner_detail": 1.0}
    lap = lambda a: float(np.abs(cv2.Laplacian(cv2.cvtColor(a[..., :3].astype(np.uint8), cv2.COLOR_RGB2GRAY).astype(np.float32), cv2.CV_32F))[inner].mean())
    return {"inner_mad": round(float(np.abs(sk[..., :3] - nt[..., :3])[inner].mean()), 2),
            "inner_detail": round(lap(sk) / max(lap(nt), 1e-6), 3)}

def run_one(name: str, out: Path) -> dict:
    live, src = GOLDEN[name]
    truth = Image.open(TRUTH / f"{name}.png").convert("RGBA")
    ta = np.asarray(truth)[..., 3].astype(np.float32)
    plate = synthetic(truth)
    keyed, _ = matte.key(plate)
    again, _ = matte.key(plate)
    ka = np.asarray(keyed)[..., 3].astype(np.float32)
    band = _band(ta)
    r = {"sad": round(float(np.abs(ka - ta)[band].mean() / 255.0), 4)}
    st, sk = _small(truth, truth, ROOT / live), _small(keyed, truth, ROOT / live)
    m = ras.metrics(sk, st)
    r.update(area=m["area"], edge=m["edge"], halo=ras.metrics(sk, sk)["halo"])
    r.update(_interior(keyed, truth, ROOT / live))
    real, _ = matte.key(Image.open(ROOT / "_src" / src))
    r["real"] = round(float(np.abs(np.asarray(real)[..., 3].astype(np.float32) - ta)[band].mean() / 255.0), 4)
    r["repeat"] = np.asarray(keyed).tobytes() == np.asarray(again).tobytes()
    d = ka - ta
    heat = np.zeros(ta.shape + (3,), np.uint8)
    heat[..., :] = (ta * 0.3).astype(np.uint8)[..., None]
    heat[d > 24] = (255, 60, 60)
    heat[d < -24] = (60, 120, 255)
    cells = [plate.convert("RGBA")]
    for bg in ((150, 150, 150, 255), (0, 0, 0, 255)):
        c = Image.new("RGBA", keyed.size, bg)
        c.alpha_composite(keyed)
        cells.append(c)
    cells.append(Image.fromarray(heat).convert("RGBA"))
    s = 360 / max(keyed.size)
    cw, ch = round(keyed.width * s), round(keyed.height * s)
    sheet = Image.new("RGB", (cw * 4, ch), (48, 48, 48))
    for i, c in enumerate(cells):
        sheet.paste(c.convert("RGB").resize((cw, ch), Image.Resampling.NEAREST), (i * cw, 0))
    sheet.save(out / f"{name}.png")
    return r

def main(argv=None) -> int:
    ap = agent_log.std_parser("Golden-set keying regression against truth mattes.", writes=True)
    ap.add_argument("--only", default="", help="Comma-separated golden names.")
    ap.add_argument("--make-truth", action="store_true", help="Rewrite _src/truth from the current key of the real plates.")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    names = [n for n in (args.only.split(",") if args.only else GOLDEN) if n]
    bad = [n for n in names if n not in GOLDEN]
    if bad:
        agent_log.fail(f"unknown golden names: {', '.join(bad)} (have {', '.join(GOLDEN)})")
    if args.make_truth:
        TRUTH.mkdir(parents=True, exist_ok=True)
        for n in names:
            matte.key(Image.open(ROOT / "_src" / GOLDEN[n][1]))[0].save(TRUTH / f"{n}.png")
        return agent_log.finish("keytest", root, f"wrote {len(names)} truth mattes to {TRUTH}", "PASS", args=args)
    exp = json.loads(EXPECT.read_text(encoding="utf-8"))
    out = root / "_logs" / "keytest"
    out.mkdir(parents=True, exist_ok=True)
    lines, fails, res = [], 0, {}
    for n in names:
        r = run_one(n, out)
        lim = {**exp["default"], **exp.get(n, {})}
        f = [k for k in ("sad", "area", "edge", "halo", "real", "inner_mad") if r[k] > lim[k]]
        f += ([] if r["inner_detail"] >= lim["inner_detail"] else ["inner_detail"]) + ([] if r["repeat"] else ["repeat"])
        fails += bool(f)
        res[n] = {**r, "fail": f}
        lines.append(f"{'FAIL' if f else 'ok  '} {n}: " + " ".join(f"{k}={v}" for k, v in r.items()) + (f"  ({','.join(f)})" if f else ""))
    (out / "last.json").write_text(json.dumps(res, indent=1), encoding="utf-8")
    return agent_log.finish("keytest", root, "\n".join(lines), "FAIL" if fails else "PASS", args=args, fails=fails)

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
