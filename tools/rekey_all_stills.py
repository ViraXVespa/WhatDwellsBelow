#!/usr/bin/env python3
"""Bulk rekey every still listed in _src/manifest.json.

    python tools/rekey_all_stills.py
    python tools/rekey_all_stills.py --dry-run
    python tools/rekey_all_stills.py --only assets/fx/arrow.png,assets/ui/gear/hatchet.png

    python tools/rekey_all_stills.py --out DIR --jobs 8      (review copy; live assets untouched)
    python tools/rekey_all_stills.py --check --jobs 8        (approved rows only: each must reproduce live byte for byte)
    python tools/rekey_all_stills.py --record-fit REV        (store each still's fit geometry from live at REV)

Reads the manifest, resolves each source under _src/sources, keys it (imglib.matte), mirrors manifest flip rows, and
places it exactly like the live still it replaces (geom.fit_like: canvas, body size, bottom edge, centre x). Live
art with no alpha (tiles, finished pictures) and the out-of-bounds stills are kept; a stale source is reported.
The placement reference is the manifest `fit` field ([W, H, x0, y0, x1, y1]: canvas and solid body box of the live
still before any rekey), never the current live file, so a re-run reproduces its own output. Rows marked
`approved` are stills Vira accepted: they stay as live (--rekey-approved shows what the current key would make), and
--check fails if a run would change one. DIR/_soft.json records each keyed row's partial-alpha share at source scale.
Check the result with python tools/rekey_check.py --new DIR.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
import match_keyed_region as matcher
from imglib import geom, imgio, key

ROOT = Path(__file__).resolve().parents[1]
SRC_ROOT = ROOT / "_src"
MANIFEST = SRC_ROOT / "manifest.json"


FROZEN = ("assets/fx/dummy.png", "assets/sprites/buildings/guild.png", "assets/sprites/buildings/guild_reception.png",
          "assets/sprites/buildings/stall.png", "assets/sprites/props/anvil.png", "assets/sprites/props/fence.png",
          "assets/ui/gear/pickaxe.png", "assets/sprites/player/male/")


# live is wrong here (Vira, 2026-10-13): the plate wins even though it is other art than live
SOURCE_WINS = ("assets/sprites/props/extract_gate_on.png",)


def _on_grey(im):
    from PIL import Image
    bg = Image.new("RGBA", im.size, (128, 128, 128, 255))
    bg.alpha_composite(im.convert("RGBA"))
    return bg.convert("RGB")


def frozen(rel: str) -> bool:
    return any(rel == f or (f.endswith("/") and rel.startswith(f)) for f in FROZEN)


def _fit_ref(fit, flip: bool):
    """Recorded geometry -> ((W, H), box); a flip row places against the mirrored box."""
    W, H, x0, y0, x1, y1 = fit
    return ((W, H), (W - x1, y0, W - x0, y1) if flip else (x0, y0, x1, y1))


def _partial_share(im, k: float = 1.0) -> float:
    """Percent of the subject's pixels in partial alpha (17..238) that a shrink by k can keep: partial runs wider than
    half an output pixel (a glow, a translucent rim). A one- or two-pixel antialiased or JPEG fringe on hard pixel
    art is eroded away, so it does not read as a soft subject."""
    import numpy as np
    from PIL import Image, ImageFilter
    a = np.asarray(im.convert("RGBA"))[..., 3]
    part = ((a > 16) & (a < 239)).astype(np.uint8) * 255
    r = int(k // 4)
    if r >= 1:
        part = np.asarray(Image.fromarray(part).filter(ImageFilter.MinFilter(2 * r + 1)))
    return 100.0 * float((part > 0).sum()) / max(1, int((a > 0).sum()))


def _rim_band_soft(keyed, k: float) -> float:
    """Share of the band around the body's edge (one output pixel wide each side, k source px) that is partial
    alpha at source scale: what a faithful shrink can keep as soft rim. Pixel art scores low, glows high."""
    import numpy as np
    from PIL import ImageFilter
    a = keyed.convert("RGBA").getchannel("A")
    solid = a.point(lambda v: 255 if v >= 128 else 0)
    r = max(1, int(round(k / 2.0))) * 2 + 1
    band = np.asarray(solid.filter(ImageFilter.MaxFilter(r))) > 0
    band &= ~(np.asarray(solid.filter(ImageFilter.MinFilter(r))) > 0)
    av = np.asarray(a)
    return float(((av > 8) & (av < 247) & band).sum()) / max(1, int(band.sum()))


def _one(live_rel: str, dry: bool, out: Path | None = None, flip: bool = False, include_frozen: bool = False,
         fit=None, approved: bool = False, rekey_approved: bool = False) -> str:
    """Key one still from its plate and place it like the live still (geom.fit_like): same canvas, body size,
    bottom edge and centre. Live art with no alpha (tiles, finished pictures) has nothing to key: it is kept as is,
    and a source that no longer matches it is reported STALE (the live file is the truth). Out-of-bounds stills
    (FROZEN) are kept unless include_frozen."""
    live = ROOT / live_rel
    dest = (out / live_rel) if out else live
    src = matcher.resolve_source(live)
    if src is None or not src.is_file():
        return f"SKIP {live_rel} (no source)"
    try:
        ref = imgio.load(live) if live.is_file() else None
        keep = ref is not None and (ref.mode == "RGB" or ref.convert("RGBA").getextrema()[3][0] == 255)
        why = ""
        if keep:
            import numpy as np
            s = np.asarray(imgio.load(src).convert("RGB").resize(ref.size), np.float32)
            err = float(np.abs(s - np.asarray(ref.convert("RGB"), np.float32)).mean())
            why = f"STALE source (err {err:.1f})" if err > 6.0 else "opaque, nothing to key"
        elif ref is not None and frozen(live_rel) and not include_frozen:
            keep, why = True, "out of bounds"
        if keep:
            if not dry and dest != live:
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(live.read_bytes())
            return f"KEPT {live_rel} ({why})"
        if approved and not rekey_approved and ref is not None:
            if not dry and dest != live:
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(live.read_bytes())
            return f"KEPT {live_rel} (approved)"
        raw = imgio.load(src).convert("RGBA")
        keyed = key.key_to_alpha(raw)
        # a left-facing still is placed like the mirrored live still, then mirrored: exactly its right sibling's mirror
        if fit:
            fitted = geom.fit_like(keyed, _fit_ref(fit, flip))
        elif ref is not None:
            fitted = geom.fit_like(keyed, geom.flip(ref) if flip else ref)
        else:
            fitted = geom.fit_box(keyed, 128, 8)
        if flip:
            fitted = geom.flip(fitted)
        # never trade live art for a key that lost the subject (paint on the plate's own hue, such as pink lettering
        # on a pink plate): keep live and report it
        if ref is not None:
            import numpy as np
            body_live = int((np.asarray(ref.convert("RGBA"))[..., 3] >= 128).sum())
            body_new = int((np.asarray(fitted)[..., 3] >= 128).sum())
            diff = float(np.abs(np.asarray(_on_grey(fitted), np.float32) - np.asarray(_on_grey(ref), np.float32)).mean())
            if diff > 40.0 and live_rel not in SOURCE_WINS:
                if not dry and dest != live:
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    dest.write_bytes(live.read_bytes())
                return f"KEPT {live_rel} (STALE source: other art than live, err {diff:.1f})"
            if body_live and body_new < 0.6 * body_live:
                if not dry and dest != live:
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    dest.write_bytes(live.read_bytes())
                return f"KEPT {live_rel} (LOST subject: key kept {body_new} of {body_live} solid px)"
        kb, fb = geom.core_box(keyed), geom.core_box(fitted)
        k = (kb[3] - kb[1]) / max(1, fb[3] - fb[1]) if kb and fb else 1.0
        rim = _rim_band_soft(keyed, k)
        soft = _partial_share(keyed, k)
        if not dry:
            dest.parent.mkdir(parents=True, exist_ok=True)
            fitted.save(dest)
        return f"WROTE {live_rel} {fitted.size[0]}x{fitted.size[1]} from {src.relative_to(SRC_ROOT).as_posix()}{' flipped' if flip else ''} soft={soft:.2f} rim={rim:.3f}"
    except Exception as exc:
        return f"FAIL {live_rel} ({exc})"


def _record_fit(root, args, data) -> int:
    import io
    import subprocess
    from PIL import Image
    n = 0
    for e in data.get("entries", []):
        r = subprocess.run(["git", "show", f"{args.record_fit}:{e.get('live', '')}"], cwd=ROOT, capture_output=True)
        if r.returncode:
            continue
        im = Image.open(io.BytesIO(r.stdout))
        box = geom.core_box(im.convert("RGBA"), 128)
        if im.mode == "RGB" or not box:
            continue
        e["fit"] = [im.width, im.height, *box]
        n += 1
    if not args.dry_run:
        import re
        text = json.dumps(data, indent=2) + "\n"
        text = re.sub(r'"fit": \[\s*([^\]]*?)\s*\]', lambda m: '"fit": [' + ", ".join(x.strip() for x in m.group(1).split(",")) + "]", text)
        MANIFEST.write_text(text, encoding="utf-8")
    return agent_log.finish("rekey-all-stills", root, f"recorded fit for {n} rows from {args.record_fit}", "PASS",
                            args=args, recorded=n)


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Bulk rekey stills from the manifest. Overwrites live PNGs.", writes=True)
    ap.add_argument("--out", default="", help="Write under this folder (same relative paths) instead of live assets/.")
    ap.add_argument("--jobs", type=int, default=1, help="Worker processes.")
    ap.add_argument("--include-frozen", action="store_true", help="Also rekey the out-of-bounds stills (FROZEN).")
    ap.add_argument("--check", action="store_true", help="Run into a temp folder; fail if an approved still differs from live.")
    ap.add_argument("--record-fit", default="", metavar="REV", help="Record each row's fit geometry from live at git REV into the manifest, then stop.")
    ap.add_argument("--rekey-approved", action="store_true", help="Also rekey approved rows (default: they stay as live).")
    ap.add_argument("--only", default="", help="Comma-separated live paths to limit the run.")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    if not MANIFEST.is_file():
        agent_log.fail(f"no manifest at {MANIFEST}")
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    entries = data.get("entries", [])
    if args.record_fit:
        return _record_fit(root, args, data)
    wanted = {p.strip() for p in args.only.split(",") if p.strip()}
    lines = ["Bulk rekey from manifest. Live PNGs are overwritten unless --dry-run."]
    wrote = skipped = failed = 0
    rows = [e for e in entries if e.get("live") and (not wanted or e["live"] in wanted)]
    if args.check and not wanted:
        rows = [e for e in rows if e.get("approved")]
    todo = [e["live"] for e in rows]
    flips = [bool(e.get("flip")) for e in rows]
    incl = [bool(args.include_frozen)] * len(todo)
    fits = [e.get("fit") for e in rows]
    apprs = [bool(e.get("approved")) for e in rows]
    reap = [bool(args.rekey_approved)] * len(rows)
    tmp = None
    if args.check:
        import tempfile
        tmp = tempfile.TemporaryDirectory()
        args.out = tmp.name
    out = Path(args.out).resolve() if args.out else None
    if args.jobs > 1:
        from concurrent.futures import ProcessPoolExecutor
        with ProcessPoolExecutor(args.jobs) as ex:
            results = list(ex.map(_one, todo, [args.dry_run] * len(todo), [out] * len(todo), flips, incl, fits, apprs, reap, chunksize=4))
    else:
        results = [_one(t, args.dry_run, out, f, i, g, a, r) for t, f, i, g, a, r in zip(todo, flips, incl, fits, apprs, reap)]
    kept, soft = {}, {}
    for line in results:
        if line.startswith("WROTE") and " soft=" in line:
            tail = line.rsplit(" soft=", 1)[1].split(" rim=")
            soft[line.split()[1]] = {"share": float(tail[0]), "rim": float(tail[1])}
        lines.append(line)
        if line.startswith("KEPT "):
            rel, why = line[5:].split(" (", 1)
            kept[rel] = why[:-1]
        if line.startswith("WROTE"):
            wrote += 1
        elif line.startswith(("SKIP", "KEPT")):
            skipped += 1
        else:
            failed += 1
    if out and not args.dry_run:
        out.mkdir(parents=True, exist_ok=True)
        (out / "_kept.json").write_text(json.dumps(kept, indent=1), encoding="utf-8")
        (out / "_soft.json").write_text(json.dumps(soft, indent=1), encoding="utf-8")
    drift = 0
    if args.check:
        appr = [e["live"] for e in rows if e.get("approved")]
        for rel in appr:
            a, b = out / rel, ROOT / rel
            if not (a.is_file() and b.is_file() and a.read_bytes() == b.read_bytes()):
                drift += 1
                lines.append(f"DRIFT {rel} (a re-run would change this approved still)")
        lines.append(f"check approved={len(appr)} drift={drift}")
        failed += drift
        tmp.cleanup()
    lines.append(f"done wrote={wrote} skipped={skipped} failed={failed}")
    status = "FAIL" if failed else "PASS"
    return agent_log.finish("rekey-all-stills", root, "\n".join(lines), status, args=args, wrote=wrote, skipped=skipped, failed=failed)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
