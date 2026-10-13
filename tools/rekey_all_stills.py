#!/usr/bin/env python3
"""Bulk rekey every still listed in _src/manifest.json.

    python tools/rekey_all_stills.py
    python tools/rekey_all_stills.py --dry-run
    python tools/rekey_all_stills.py --only assets/fx/arrow.png,assets/ui/gear/hatchet.png

    python tools/rekey_all_stills.py --out DIR --jobs 8      (review copy; live assets untouched)

Reads the manifest, resolves each source under _src/sources, keys it (imglib.matte), mirrors manifest flip rows, and
places it exactly like the live still it replaces (geom.fit_like: canvas, body size, bottom edge, centre x). Live
art with no alpha (tiles, finished pictures) and the out-of-bounds stills are kept; a stale source is reported.
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


def _one(live_rel: str, dry: bool, out: Path | None = None, flip: bool = False, include_frozen: bool = False) -> str:
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
        raw = imgio.load(src).convert("RGBA")
        keyed = key.key_to_alpha(raw)
        # a left-facing still is placed like the mirrored live still, then mirrored: exactly its right sibling's mirror
        if ref is not None:
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
        if not dry:
            dest.parent.mkdir(parents=True, exist_ok=True)
            fitted.save(dest)
        return f"WROTE {live_rel} {fitted.size[0]}x{fitted.size[1]} from {src.relative_to(SRC_ROOT).as_posix()}{' flipped' if flip else ''}"
    except Exception as exc:
        return f"FAIL {live_rel} ({exc})"


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Bulk rekey stills from the manifest. Overwrites live PNGs.", writes=True)
    ap.add_argument("--out", default="", help="Write under this folder (same relative paths) instead of live assets/.")
    ap.add_argument("--jobs", type=int, default=1, help="Worker processes.")
    ap.add_argument("--include-frozen", action="store_true", help="Also rekey the out-of-bounds stills (FROZEN).")
    ap.add_argument("--only", default="", help="Comma-separated live paths to limit the run.")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    if not MANIFEST.is_file():
        agent_log.fail(f"no manifest at {MANIFEST}")
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    entries = data.get("entries", [])
    wanted = {p.strip() for p in args.only.split(",") if p.strip()}
    lines = ["Bulk rekey from manifest. Live PNGs are overwritten unless --dry-run."]
    wrote = skipped = failed = 0
    rows = [e for e in entries if e.get("live") and (not wanted or e["live"] in wanted)]
    todo = [e["live"] for e in rows]
    flips = [bool(e.get("flip")) for e in rows]
    incl = [bool(args.include_frozen)] * len(todo)
    out = Path(args.out).resolve() if args.out else None
    if args.jobs > 1:
        from concurrent.futures import ProcessPoolExecutor
        with ProcessPoolExecutor(args.jobs) as ex:
            results = list(ex.map(_one, todo, [args.dry_run] * len(todo), [out] * len(todo), flips, incl, chunksize=4))
    else:
        results = [_one(t, args.dry_run, out, f, i) for t, f, i in zip(todo, flips, incl)]
    kept = {}
    for line in results:
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
    lines.append(f"done wrote={wrote} skipped={skipped} failed={failed}")
    status = "FAIL" if failed else "PASS"
    return agent_log.finish("rekey-all-stills", root, "\n".join(lines), status, args=args, wrote=wrote, skipped=skipped, failed=failed)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
