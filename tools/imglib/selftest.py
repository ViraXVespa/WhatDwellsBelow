"""Self-test for imglib on small synthetic images (about 2 s). `python tools/img_inspect.py selftest`.

Each check is (name, ok, detail). A change to key.py / compare.py / look.py runs this once; it is not a
substitute for the before/after pixel diff of the tool that adopts the change (design/prove.md).
"""
from __future__ import annotations

import io

import numpy as np
from PIL import Image

from . import HAVE_CV2, compare, key, look


def _sprite() -> Image.Image:
    im = Image.new("RGBA", (60, 80), (0, 0, 0, 0))
    a = np.zeros((80, 60, 4), np.uint8)
    a[10:70, 15:45] = (40, 90, 50, 255)
    a[10:70, 15:17] = (10, 10, 10, 255)
    a[20:24, 5:55] = (120, 80, 30, 255)
    return Image.fromarray(a)


def _on_plate(sprite: Image.Image, corners, jpeg: bool) -> Image.Image:
    a = np.array(sprite)
    h, w = a.shape[:2]
    pad = 20
    canvas = np.zeros((h + 2 * pad, w + 2 * pad, 4), np.uint8)
    canvas[pad:pad + h, pad:pad + w] = a
    H, W = canvas.shape[:2]
    yy, xx = np.mgrid[0:H, 0:W]
    u, v = (xx / (W - 1))[..., None], (yy / (H - 1))[..., None]
    c = [np.array(k, np.float32) for k in corners]
    plate = c[0] * (1 - u) * (1 - v) + c[1] * u * (1 - v) + c[2] * (1 - u) * v + c[3] * u * v
    out = np.where(canvas[..., 3:4] > 0, canvas[..., :3].astype(np.float32), plate)
    rgb = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))
    if jpeg:
        b = io.BytesIO()
        rgb.save(b, "JPEG", quality=80, subsampling=2)
        b.seek(0)
        rgb = Image.open(b).convert("RGB")
    return rgb.convert("RGBA"), canvas[..., 3] > 0


def run() -> list[tuple[str, bool, str]]:
    out: list[tuple[str, bool, str]] = []
    sp = _sprite()
    exact, truth = _on_plate(sp, [(255, 0, 255)] * 4, False)
    k = np.array(key.key_to_alpha(exact))[..., 3] > 0
    out.append(("key exact plate", int((truth ^ k).sum()) == 0, f"wrong px {int((truth ^ k).sum())}"))
    drift, truth = _on_plate(sp, [(255, 0, 192), (252, 0, 237), (248, 0, 158), (234, 0, 183)], True)
    k = np.array(key.key_to_alpha(drift))[..., 3] > 0
    miss = int(((~truth) & k).sum())
    out.append(("key drifting JPEG plate", miss <= 40, f"plate left opaque {miss} px (<= 40)"))
    r = np.array(key.remap_plate(drift)[0])[..., :3]
    ex = (r[..., 0] == 255) & (r[..., 1] == 0) & (r[..., 2] == 255)
    share = float((ex & ~truth).sum()) / max(1, int((~truth).sum()))
    out.append(("remap exact #FF00FF", share >= 0.99, f"{share * 100:.1f}% of plate exact (>= 99)"))
    a = Image.new("RGBA", (100, 60), (10, 20, 30, 255))
    b = a.copy()
    b.paste((255, 0, 0, 255), (10, 10, 30, 30))
    d = compare.diff(a, b)
    out.append(("diff regions", d["changed_px"] == 400 and d["regions"] == [[10, 10, 30, 30]], f"changed {d['changed_px']} regions {d['regions']}"))
    out.append(("diff same", compare.diff(a, a)["status"] == "same", "identical images"))
    scr = Image.new("RGB", (400, 300), (20, 20, 30))
    for box in ((20, 20, 120, 60), (100, 50, 200, 90), (300, 250, 400, 300)):
        scr.paste((200, 200, 220), box)
    found = look.regions(scr)
    boxes = [(20, 20, 120, 60), (100, 50, 200, 90), (300, 250, 400, 300)]
    res = look.layout(boxes, scr.size)
    out.append(("layout overlap + clipped", len(found) == 2 and len(res["overlaps"]) == 1 and len(res["clipped"]) == 1, f"segmented {len(found)} elements; explicit boxes: overlaps {len(res['overlaps'])}, clipped {len(res['clipped'])}"))
    t = Image.new("RGB", (100, 40), (0, 0, 0))
    t.paste((255, 255, 255), (10, 10, 60, 30))
    c1 = look.contrast(t, (0, 0, 100, 40))
    t2 = Image.new("RGB", (100, 40), (120, 120, 120))
    t2.paste((140, 140, 140), (10, 10, 60, 30))
    c2 = look.contrast(t2, (0, 0, 100, 40))
    out.append(("contrast pass/fail", c1["pass"] and not c2["pass"], f"white on black {c1['ratio']}, grey on grey {c2['ratio']}"))
    pink = Image.fromarray(np.dstack([np.full((30, 30), v, np.uint8) for v in (190, 60, 140, 0)]))
    arr = np.array(pink)
    arr[5:25, 5:25] = (40, 90, 50, 255)
    arr[4, 5:25] = (190, 60, 140, 255)
    h1 = look.halo(Image.fromarray(arr))
    arr[4, 5:25] = (40, 90, 50, 255)
    h2 = look.halo(Image.fromarray(arr))
    out.append(("halo flags pink rim", h1["halo_pct"] > 10 and h2["halo_pct"] == 0, f"pink {h1['halo_pct']}%, clean {h2['halo_pct']}%"))
    m = look.motion([a, a, b])
    out.append(("motion", m["static"] == 1 and m["rows"][1]["changed_pct"] > 0, f"static {m['static']}, step 2 {m['rows'][1]['changed_pct']}%"))
    if HAVE_CV2:
        shot = np.random.RandomState(1).randint(0, 255, (120, 160, 3)).astype(np.uint8)
        tmpl = Image.fromarray(shot[40:70, 50:90])
        hits = look.find(Image.fromarray(shot), tmpl)
        out.append(("find template", bool(hits) and hits[0][:2] == (50, 40), f"hits {hits[:1]}"))
    else:
        out.append(("find template", True, "skipped: no OpenCV"))
    return out
