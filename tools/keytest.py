#!/usr/bin/env python3
"""Keying regression: key every plate in assets/keytest and check the numbers.

    python tools/keytest.py                      key assets/keytest, check tools/keytest_expect.json, write sheets
    python tools/keytest.py --only wisp,hp_orb   a subset (names are file stems)
    python tools/keytest.py --src DIR --out DIR  any folder of plates; generic checks only
    python tools/keytest.py --update             rewrite the expected foreground share from this run

Checks per picture (limits in keytest_expect.json, "default" plus per-name overrides):
  plate_left    visible pixels still plate coloured (share of foreground)
  magenta_left  visible pixels with magenta excess min(R,B)-G > 40 within 14 degrees of the plate hue, R and B at
                least half the plate's, within 4 px of transparency (residue sits at the cut; interior paint is the art's) (share of foreground)
  green_specks  soft pixels the despill turned green (G above R and B by 30, source not green, no green paint within 4 px)
  plate_tint    95th percentile, over semi-transparent pixels, of alpha x plate-direction chroma (YCrCb) above
                the nearby art's, where the hue is pulled toward the plate (within 30 deg, or 90 deg on the violet side): the magenta/violet cast a glow shows over dark or light backgrounds
  rise, corr    round glows ("radial": true), by radius beyond the hard edge in 2 px steps, per 10 deg sector:
                the glow's intensity over black must not dip and climb again (rise: 90th pct of the largest
                climb above the running minimum; two rings fail it) and the alpha must follow the source's
                glow strength (corr); rough = largest 2nd difference of the 1 px alpha profile (kinks), noise =
                std of high-pass alpha in the glow (blotches), tail = alpha's 2% extent / the source glow's
  plate_hue_px  visible plate-touched pixels still magenta or lavender (within 30 deg of the plate hue, up to
                60 deg on its violet side, saturated, bright), anywhere incl. enclosed pockets
  halo          share of the foreground that is soft and more than 4 px beyond the solid art (glow kept)
  interior      share of paint pixels (more than 3 px from transparency and from any plate-tinted source
                pixel, magenta excess > 12) that are opaque (minimum). Edges and glows outside the hard edge are partial by design; `solid` (opaque share
                of the foreground) is reported for information
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
    # interior: more than 3 px from transparency and from any source pixel tinted by the plate (magenta
    # excess > 12: plate, glow or mix). What is left is paint and must stay opaque.
    src_ex = np.minimum(s[..., 0], s[..., 2]) - s[..., 1]
    inner = ~_near((a == 0) | (src_ex > 12), 3)
    # plate residue is bright like the plate; dark purple paint (a robe) is the art's own colour
    bright = np.minimum(k[..., 0], k[..., 2]) >= 0.5 * min(int(plate[0]), int(plate[2]))
    src_green = s[..., 1] - np.maximum(s[..., 0], s[..., 2])
    out_green = k[..., 1] - np.maximum(k[..., 0], k[..., 2])
    solid_green = (a == 255) & (out_green > 10)  # green paint nearby makes a green edge legitimate
    # plate tint: in a semi-transparent pixel, chroma along the plate's chroma direction (YCrCb) beyond what
    # the opaque art within 40 px carries, times alpha = what shows over a dark or light background.
    import cv2
    m = np.array([[0.5, -0.4187, -0.0813], [-0.1687, -0.3313, 0.5]], np.float32)
    pc = m @ plate.astype(np.float32)
    u = pc / max(float(np.linalg.norm(pc)), 1e-3)
    col = k[..., :3].astype(np.float32)
    opaque = (a == 255).astype(np.float32)
    art = cv2.blur(col * opaque[..., None], (81, 81)) / np.maximum(cv2.blur(opaque, (81, 81))[..., None], 1e-3)
    tint = (a / 255.0) * ((col @ m.T) @ u - np.maximum((art @ m.T) @ u, 0.0))
    # only where the pixel's hue sits closer to the plate hue than the art's does (pulled toward the plate)
    def _hd(rgb):
        h = cv2.cvtColor(np.clip(rgb, 0, 255).astype(np.uint8), cv2.COLOR_RGB2HSV_FULL)[..., 0].astype(np.int32)
        return np.abs((h - int(ph) + 128) % 256 - 128)
    hc = cv2.cvtColor(np.clip(col, 0, 255).astype(np.uint8), cv2.COLOR_RGB2HSV_FULL)[..., 0].astype(np.int32)
    side = (hc - int(ph) + 128) % 256 - 128  # < 0: the violet/blue side of the plate
    zone = (np.abs(side) <= 21) | ((side < 0) & (side >= -64))  # 30 deg either way, 90 deg toward blue
    tint = np.where((_hd(col) + 7 < _hd(art)) & zone, tint, 0.0)
    tint_p95 = float(np.percentile(tint[soft], 95)) if soft.any() else 0.0
    halo = soft & ~_near(a == 255, 4)
    # plate hue left anywhere (incl. enclosed pockets): visible, plate-touched source pixels whose colour is
    # within 30 deg of the plate hue or up to 60 deg on its violet side, saturated and bright (magenta,
    # lavender); the art's own blues and purples outside that window or dark do not count
    hsv = cv2.cvtColor(np.clip(col, 0, 255).astype(np.uint8), cv2.COLOR_RGB2HSV_FULL).astype(np.int32)
    hue_left = vis & (src_ex > 6) & (_hd(col) + 14 < _hd(art)) & ((np.abs(side) <= 21) | ((side < 0) & (side >= -43))) & (hsv[..., 1] >= 50) & (hsv[..., 2] >= 90)
    return {
        "plate_tint": round(tint_p95, 1),
        "plate_hue_px": int(hue_left.sum()),
        "halo": round(float(halo.sum()) / fg, 4),
        "plate_left": round(float((vis & near_plate).sum()) / fg, 5),
        "magenta_left": round(float((vis & (ex > 40) & on_hue & bright & _near(~vis, 4)).sum()) / fg, 5),
        "green_specks": int((soft & (out_green > 30) & (src_green <= 0) & ~_near(solid_green, 4)).sum()),
        "solid": round(float((a == 255).sum()) / fg, 4),
        "interior": round(float((inner & (a == 255)).sum()) / max(1, int(inner.sum())), 4),
        "fg": round(fg / a.size, 4),
        "partial": int(soft.sum()),
    }


def radial(src: Image.Image, keyed: Image.Image, plate: np.ndarray, span: int = 60, sectors: int = 36):
    import cv2
    """Round glows (orbs): profiles by radius beyond the opaque art, per angular sector.

    Returns rise, corr, rough, noise, tail (see the module docstring). rise = 90th percentile over sectors of the largest climb, above the running
    minimum, of the glow's premultiplied intensity seen over black (a dark gap then a brighter band = two
    rings); corr = correlation of the mean alpha profile with the source's glow strength (the source pixel's
    position on the plate -> rim-colour line)."""
    s = np.array(src.convert("RGB")).astype(np.float32)
    k = np.array(keyed).astype(np.float32)
    a = k[..., 3] / 255.0
    ys, xs = np.nonzero(a >= 1.0)
    cy, cx = np.median(ys), np.median(xs)
    yy, xx = np.mgrid[:a.shape[0], :a.shape[1]]
    r = np.sqrt((yy - cy) ** 2 + (xx - cx) ** 2)
    th = ((np.arctan2(yy - cy, xx - cx) + np.pi) / (2 * np.pi) * sectors).astype(int) % sectors
    # hard edge per sector: the outermost opaque radius (ignoring stray sparkles: 98th percentile)
    rises, A, S = [], [], []
    rim_r = np.zeros(sectors)
    for q in range(sectors):
        m = (a >= 1.0) & (th == q)
        rim_r[q] = np.percentile(r[m], 98) if m.any() else np.nan
    g_m = (a >= 1.0) & (r > rim_r[th] - 6)
    g = np.median(s[g_m], axis=0) - plate
    st = np.clip(((s - plate) * g).sum(-1) / max(float((g * g).sum()), 1.0), 0.0, 1.0)
    rel = r - rim_r[th]
    # sparkles and specks drawn in the glow are art of their own, not the glow
    rel = np.where(_near((a >= 1.0) & (rel > 2), 4), -1e9, rel)
    for q in range(sectors):
        pa, ps = [], []
        for b0 in range(0, span, 2):
            m = (th == q) & (rel >= b0) & (rel < b0 + 2)
            if m.any():
                pa.append(float(a[m].mean()))
                ps.append(float(st[m].mean()))
        if len(pa) > 1:
            pa_, ps_ = np.array(pa), np.array(ps)
            # climbs the source does not have (sparkles climb in both)
            ca = np.maximum(pa_[1:] - np.minimum.accumulate(pa_)[:-1], 0.0)
            cs = np.maximum(ps_[1:] - np.minimum.accumulate(ps_)[:-1], 0.0)
            rises.append(float(np.max(ca - cs)))
    for b0 in range(0, span, 2):
        m = (rel >= b0) & (rel < b0 + 2)
        A.append(float(a[m].mean()))
        S.append(float(st[m].mean()))
    # 1 px profile out to 90 px: roughness (largest second difference: kinks, plateaus) and tail extent (where
    # the alpha falls below 2% of its rim value vs where the source glow falls below 2% above its far level)
    A1 = np.array([a[(rel >= b) & (rel < b + 1)].mean() for b in range(90)])
    S1 = np.array([st[(rel >= b) & (rel < b + 1)].mean() for b in range(90)])
    rough = float(np.abs(A1[2:] - 2 * A1[1:-1] + A1[:-2]).max())
    base = float(np.median(S1[70:]))
    sn = (S1 - base) / max(float(S1[0]) - base, 1e-3)
    ta, ts = int(np.argmax(A1 < 0.02 * A1[0])), int(np.argmax(sn < 0.02))
    # blotchiness: high-pass (minus a 2 px Gaussian) alpha in the glow
    glow = (rel > 0) & (rel < span) & (a > 0.02) & (a < 0.98)
    noise = float((a - cv2.GaussianBlur(a, (0, 0), 2.0))[glow].std()) if glow.any() else 0.0
    return {"rise": round(float(np.percentile(rises, 90)), 4), "corr": round(float(np.corrcoef(A, S)[0, 1]), 4),
            "rough": round(rough, 4), "noise": round(noise, 4), "tail": round(ta / max(ts, 1), 2)}


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
    if m["interior"] < lim.get("interior", 0.995):
        bad.append(f"interior {m['interior']} < {lim.get('interior', 0.995)}")
    if name in recorded and abs(m["fg"] - recorded[name]) > lim.get("fg_tol", 0.01):
        bad.append(f"fg {m['fg']} vs recorded {recorded[name]} (+-{lim.get('fg_tol', 0.01)})")
    if m["plate_hue_px"] > lim.get("plate_hue_px", 20):
        bad.append(f"plate_hue_px {m['plate_hue_px']} > {lim.get('plate_hue_px', 20)} (magenta/lavender left)")
    if "rough" in m:
        for key, lo, hi, txt in (("rough", None, 0.035, "radial alpha kinks"), ("noise", None, 0.012, "blotchy glow"),
                                 ("tail", 0.7, None, "glow cut short of the source's")):
            lim_k = lim.get(key + ("_min" if lo is not None else "_max"), lo if lo is not None else hi)
            if (lo is not None and m[key] < lim_k) or (hi is not None and m[key] > lim_k):
                bad.append(f"{key} {m[key]} vs {lim_k} ({txt})")
    if m["plate_tint"] > lim.get("plate_tint", 6.0):
        bad.append(f"plate_tint {m['plate_tint']} > {lim.get('plate_tint', 6.0)}")
    if "rise" in m and m["rise"] > lim.get("rise_max", 0.02):
        bad.append(f"rise {m['rise']} > {lim.get('rise_max', 0.02)} (radial glow alpha steps back up: rings)")
    if "corr" in m and m["corr"] < lim.get("corr_min", 0.97):
        bad.append(f"corr {m['corr']} < {lim.get('corr_min', 0.97)} (glow alpha does not follow the source glow)")
    if m["halo"] < lim.get("halo_min", 0.0):
        bad.append(f"halo {m['halo']} < {lim['halo_min']} (glow beyond the solid rim)")
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
        if in_repo and exp.get(name, {}).get("radial"):
            pl = np.array([int(stats["plate"][i:i + 2], 16) for i in (1, 3, 5)], np.float32)
            m.update(radial(src, keyed, pl))
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
