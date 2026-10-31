"""Self-test for imglib on small synthetic images (about 2 s). `python tools/shots.py inspect selftest`.

Each check is (name, ok, detail). A change to key.py / compare.py / look.py runs this once; it is not a
substitute for the before/after pixel diff of the tool that adopts the change (design/prove.md).
"""
from __future__ import annotations

import io

import numpy as np
from PIL import Image

from . import HAVE_CV2, compare, geom, key, look

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
    lip = np.zeros((80, 80, 4), np.uint8)
    lip[:, :] = (255, 0, 255, 255)
    lip[20:60, 20:60] = (40, 90, 50, 255)
    lip[59, 20:60] = (150, 40, 70, 255)
    lip[60, 20:60] = (240, 200, 220, 255)
    keyed = np.array(key.key_to_alpha(Image.fromarray(lip)))
    # Body stays as drawn. The maroon edge row stays opaque paint with its hue. The light-pink row is a
    # plate mix: partial alpha, and its magenta excess min(R,B)-G is despilled away.
    plate_ok = int(keyed[0, 0, 3]) == 0 and int(keyed[0, 0].sum()) == 0
    body = keyed[40, 40]
    cloth = keyed[59, 30]
    lip_px = keyed[60, 30]
    ex = int(min(int(lip_px[0]), int(lip_px[2])) - int(lip_px[1]))
    body_ok = tuple(int(v) for v in body[:3]) == (40, 90, 50) and int(body[3]) == 255
    cloth_ok = int(cloth[3]) > 200 and int(cloth[0]) > int(cloth[1]) and int(cloth[0]) > int(cloth[2]) - 10
    lip_partial = 0 < int(lip_px[3]) < 255 and ex <= 4
    out.append(("key light-pink lip", plate_ok and body_ok and cloth_ok and lip_partial, f"body {body.tolist()} cloth {cloth.tolist()} lip {lip_px.tolist()}"))
    wood = np.zeros((30, 40, 4), np.uint8)
    wood[:, :] = (0, 0, 0, 255)
    wood[8:22, 8:32] = (120, 80, 40, 255)
    wood_k = np.array(key.key_to_alpha(Image.fromarray(wood)))
    wood_ok = int((wood_k == wood).sum()) == wood.size
    out.append(("key ignores non-plate", wood_ok, f"changed px {int((wood_k != wood).any(axis=2).sum())}"))
    drift, truth = _on_plate(sp, [(255, 0, 192), (252, 0, 237), (248, 0, 158), (234, 0, 183)], True)
    drifted = np.array(key.key_to_alpha(drift))
    # A soft rim may keep partial alpha. Opaque means the plate is still solid.
    k = drifted[..., 3] > 200
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
    # pixel art: 6 px cells of random colour, opaque disc. shrink_art keeps interior cells exact (no averaging);
    # detect_grid finds the 6 px grid, and a blurred copy scores 0 confidence.
    rs = np.random.RandomState(3)
    cells = rs.randint(0, 255, (64, 64, 3)).astype(np.uint8).repeat(6, 0).repeat(6, 1)
    yy, xx = np.mgrid[:384, :384]
    art = np.dstack([cells, np.where((yy - 192) ** 2 + (xx - 192) ** 2 < 170 ** 2, 255, 0).astype(np.uint8)])
    im = Image.fromarray(art, "RGBA")
    small = np.array(geom.shrink_art(im, (64, 64)))
    inner = small[24:40, 24:40, :3].astype(int) - cells[::6, ::6][24:40, 24:40]
    out.append(("shrink_art exact interior", int(np.abs(inner).max()) == 0, f"max diff {int(np.abs(inner).max())}"))
    g = geom.detect_grid(im.convert("RGB"), alpha=art[..., 3])
    import cv2
    blur = Image.fromarray(cv2.GaussianBlur(cells, (0, 0), 3))
    gb = geom.detect_grid(blur, alpha=art[..., 3])
    out.append(("detect_grid", abs(g[0] - 6) < 0.1 and g[3] >= 0.5 and gb[3] < 0.5, f"pitch {g[0]:.2f} conf {g[3]:.2f}, blurred {gb[3]:.2f}"))
    # pixelate: 4 px cells, binary alpha, cells uniform, palette caps the colour count.
    px = np.array(key.pixelate(sp, 4.0, palette=3))
    cells_ok = all(len(np.unique(px[y:y + 4, x:x + 4].reshape(-1, 4), axis=0)) == 1 for y in range(0, 80, 4) for x in range(0, 60, 4))
    alpha_bin = set(np.unique(px[..., 3]).tolist()) <= {0, 255}
    ncol = len(np.unique(px[px[..., 3] > 0][:, :3], axis=0))
    out.append(("pixelate grid+alpha+palette", px.shape == (80, 60, 4) and cells_ok and alpha_bin and ncol <= 3, f"cells {cells_ok} binary {alpha_bin} colours {ncol}"))
    # pixelate detail: a 1-cell dark band (4 px wide on a 4 px cell, off the cell phase) survives as dark cells.
    band = np.full((32, 32, 4), 220, np.uint8)
    band[:, 14:18, :3] = 30
    pd, pb = (np.array(key.pixelate(Image.fromarray(band, "RGBA"), 4.0, crisp=c))[..., 0].min() for c in (True, False))
    out.append(("pixelate keeps 1-cell dark band", pd < 60 and pb > pd, f"detail min {pd}, box min {pb}"))
    return out
