#!/usr/bin/env python3
"""Bake the ground wear sheet (assets/baked/ground_wear.png) that ground_shader.gd samples once per pixel.

    python tools/bake_ground_wear.py [--root R] [--json]

Tileable grayscale, SIZE x SIZE texels at WEAR_PX_PER_M (ground_shader.gd), so it repeats every SIZE/px metres over
hub and dungeon floors. Domain-warped multi-octave periodic value noise (smooth, no cell edges), posterized to STEPS
levels at texel size so it reads as pixel art. 0 = no wear, 255 = full wear (shader darkens by ground_wear * 0.22).
Deterministic (fixed seed): same bytes every run. Also run at the end of tools/run_bake_camp.py. Prints stamp= (first 16
hex of SHA-256 of the L8 pixels); paste it into GROUND_WEAR_STAMP (ground_shader.gd); check_hub_bake.py checks it.
"""
from __future__ import annotations

import hashlib
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log

PNG = "assets/baked/ground_wear.png"
SIZE = 512
STEPS = 4
SEED = 7

def _octave(rng, n: int, size: int):
    import numpy as np
    g = rng.random((n, n))
    t = np.arange(size) * n / size
    i0 = np.floor(t).astype(int)
    f = t - i0
    f = f * f * (3 - 2 * f)
    i1 = (i0 + 1) % n
    rows = g[i0][:, i0] * (1 - f)[None, :] + g[i0][:, i1] * f[None, :]
    rows2 = g[i1][:, i0] * (1 - f)[None, :] + g[i1][:, i1] * f[None, :]
    return rows * (1 - f)[:, None] + rows2 * f[:, None]

def _fbm(rng, size: int, base: int, octs: int):
    acc, amp, tot = 0.0, 1.0, 0.0
    for o in range(octs):
        acc = acc + _octave(rng, base << o, size) * amp
        tot += amp
        amp *= 0.5
    return acc / tot

def bake(size: int = SIZE):
    import numpy as np
    rng = np.random.default_rng(SEED)
    wx, wy = _fbm(rng, size, 4, 3), _fbm(rng, size, 4, 3)
    n = _fbm(rng, size, 6, 5)
    yy, xx = np.mgrid[0:size, 0:size]
    warp = size * 0.06
    sx = (xx + (wx - 0.5) * 2 * warp).astype(int) % size
    sy = (yy + (wy - 0.5) * 2 * warp).astype(int) % size
    v = n[sy, sx]
    lo, hi = np.percentile(v, 35), np.percentile(v, 99)
    v = np.clip((v - lo) / (hi - lo), 0, 1)
    q = np.floor(v * (STEPS - 1) + 0.5) / (STEPS - 1)
    return (q * 255).astype(np.uint8)

def stamp_of(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()[:16]

def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Bake assets/baked/ground_wear.png (tileable posterized wear noise).", json_out=True)
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    from PIL import Image
    a = bake()
    out = root / PNG
    out.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(a, "L").save(out, optimize=True)
    st = stamp_of(a.tobytes())
    print(f"ground wear: {PNG} {SIZE}x{SIZE} steps={STEPS} bytes={out.stat().st_size} stamp={st}")
    return agent_log.finish("ground-wear", root, f"{PNG} {SIZE}x{SIZE} stamp={st}", "PASS", args=args, stamp=st)

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
