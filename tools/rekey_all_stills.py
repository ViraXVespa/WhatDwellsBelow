#!/usr/bin/env python3
"""Bulk rekey every still listed in _src/manifest.json.

    python tools/rekey_all_stills.py
    python tools/rekey_all_stills.py --dry-run
    python tools/rekey_all_stills.py --only assets/fx/arrow.png,assets/ui/gear/hatchet.png

    python tools/rekey_all_stills.py --out DIR --jobs 8      (review copy; live assets untouched)
    python tools/rekey_all_stills.py --check --jobs 8        (determinism: two runs into temp folders, byte-identical)
    python tools/rekey_all_stills.py --record-fit REV        (store each still's fit geometry from live at REV)

Reads the manifest, resolves each source under _src/sources, keys it (imglib.matte), mirrors manifest flip rows, and
places it exactly like the live still it replaces (geom.fit_like: canvas, body size, bottom edge, centre x; one
premultiplied box shrink, on a detected pixel grid when there is one), then applies the row's alpha policy once
(manifest `alpha`: soft, crisp or hard; default soft for fx, crisp otherwise). Live
art with no alpha (tiles, finished pictures) is kept and a stale source reported; a key that lost the subject keeps live
(SOURCE_WINS rows are exempt from that guard). Every other still is rekeyed on every run.
The placement reference is the manifest `fit` field ([W, H, x0, y0, x1, y1]: canvas and solid body box of the live
still before any rekey), never the current live file, so a re-run reproduces its own output. DIR/_metrics.json records each keyed row's area/edge/halo/notch metrics
against the exact area average of the same key.
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

# live is wrong here (Vira, 2026-10-13): the plate wins even though it is other art than live
SOURCE_WINS = ("assets/sprites/props/extract_gate_on.png",)

def _on_grey(im):
    from PIL import Image
    bg = Image.new("RGBA", im.size, (128, 128, 128, 255))
    bg.alpha_composite(im.convert("RGBA"))
    return bg.convert("RGB")

def _fit_ref(fit, flip: bool):
    """Recorded geometry -> ((W, H), box); a flip row places against the mirrored box."""
    W, H, x0, y0, x1, y1 = fit
    return ((W, H), (W - x1, y0, W - x0, y1) if flip else (x0, y0, x1, y1))

GRID_CONF = 0.5  # detect_grid confidence for a real pixel grid
EDGE_CAP = 2.0  # px: one edge position error counts at most this (a speck or a lost branch is one fault, not a run)

def policy_for(rel: str, row: dict) -> str:
    """Alpha policy: the manifest row's `alpha`, else soft for fx (glows, energy), else crisp."""
    return row.get("alpha") or ("soft" if rel.startswith("assets/fx/") else "crisp")

def _edges(a, axis: int):
    """Sub-pixel x of the half-coverage crossings along each row (axis 1) or column (axis 0): first and last."""
    import numpy as np
    a = (a if axis == 1 else a.T).astype(np.float32) / 255.0
    pos = []
    for r in a:
        idx = np.nonzero(r >= 0.5)[0]
        if len(idx) == 0:
            pos.append((np.nan, np.nan))
            continue
        i, j = idx[0], idx[-1]
        left = i - (r[i] - 0.5) / max(r[i] - r[i - 1], 1e-3) if i > 0 else float(i)
        right = j + (r[j] - 0.5) / max(r[j] - r[j + 1], 1e-3) if j < len(r) - 1 else float(j)
        pos.append((left, right))
    return np.array(pos)

def metrics(out, exact) -> dict:
    """The output against the exact area average of the same key at output scale (same placement):
    area   mean and max |alpha difference| /255 over edge pixels (partial in either)
    edge   mean |sub-pixel half-coverage edge position| difference in px (each capped at EDGE_CAP) over rows and columns
    halo   share of visible partial pixels still plate-coloured (magenta excess over 24)
    notch  output clear (< 128) where the exact footprint is mostly paint (>= 160); bump the reverse (< 96)"""
    import numpy as np
    o = np.asarray(out.convert("RGBA")).astype(np.int32)
    e = np.asarray(exact.convert("RGBA")).astype(np.int32)
    oa, ea = o[..., 3], e[..., 3]
    band = ((oa > 0) & (oa < 255)) | ((ea > 0) & (ea < 255))
    d = np.abs(oa - ea)[band] / 255.0
    errs = []
    for ax in (0, 1):
        x, y = _edges(oa, ax), _edges(ea, ax)
        m = ~np.isnan(x) & ~np.isnan(y)
        errs.append(np.minimum(np.abs(x - y)[m], EDGE_CAP))
    err = np.concatenate(errs)
    part = (oa > 16) & (oa < 240)
    ex = np.minimum(o[..., 0], o[..., 2]) - o[..., 1]
    return {"area": round(float(d.mean()) if d.size else 0.0, 4), "area_max": round(float(d.max()) if d.size else 0.0, 3),
            "edge": round(float(err.mean()) if err.size else 0.0, 3),
            "halo": round(float((part & (ex > 24)).sum()) / max(1, int(part.sum())), 4),
            "notch": int(((ea >= 160) & (oa < 128)).sum()), "bump": int(((ea < 96) & (oa >= 128)).sum())}

def _one(live_rel: str, dry: bool, out: Path | None = None, flip: bool = False, fit=None, policy: str = "crisp") -> str:
    """Key one still from its plate and place it like the live still (geom.fit_like): same canvas, body size,
    bottom edge and centre. Live art with no alpha (tiles, finished pictures) has nothing to key: it is kept as is,
    and a source that no longer matches it is reported STALE (the live file is the truth)."""
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
        if keep:
            if not dry and dest != live:
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(live.read_bytes())
            return f"KEPT {live_rel} ({why})"
        raw = imgio.load(src).convert("RGBA")
        keyed = key.key_to_alpha(raw)
        pitch, gx, gy, conf = geom.detect_grid(raw)
        grid = (pitch, gx, gy) if conf >= GRID_CONF else None
        # a left-facing still is placed like the mirrored live still, then mirrored: exactly its right sibling's mirror
        place = _fit_ref(fit, flip) if fit else (geom.flip(ref) if flip else ref) if ref is not None else None
        exact = geom.fit_like(keyed, place, grid=grid) if place is not None else geom.fit_box(keyed, 128, 8)
        fitted = geom.alpha_policy(exact, policy)
        if flip:
            fitted, exact = geom.flip(fitted), geom.flip(exact)
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
            if body_live and (body_new < 0.6 * body_live or (diff > 20.0 and body_new < 0.9 * body_live)):
                if not dry and dest != live:
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    dest.write_bytes(live.read_bytes())
                return f"KEPT {live_rel} (LOST subject: key kept {body_new} of {body_live} solid px)"
        m = metrics(fitted, exact)
        if not dry:
            dest.parent.mkdir(parents=True, exist_ok=True)
            fitted.save(dest)
        kv = " ".join(f"{k}={v}" for k, v in m.items())
        g = f" grid={pitch:.2f}" if grid else ""
        return f"WROTE {live_rel} {fitted.size[0]}x{fitted.size[1]} from {src.relative_to(SRC_ROOT).as_posix()}{' flipped' if flip else ''} policy={policy}{g} {kv}"
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
    ap.add_argument("--check", action="store_true", help="Run twice into temp folders; fail unless the two runs are byte-identical.")
    ap.add_argument("--record-fit", default="", metavar="REV", help="Record each row's fit geometry from live at git REV into the manifest, then stop.")
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
    todo = [e["live"] for e in rows]
    flips = [bool(e.get("flip")) for e in rows]
    fits = [e.get("fit") for e in rows]
    pols = [policy_for(e["live"], e) for e in rows]
    def run(out):
        if args.jobs > 1:
            from concurrent.futures import ProcessPoolExecutor
            with ProcessPoolExecutor(args.jobs) as ex:
                return list(ex.map(_one, todo, [args.dry_run] * len(todo), [out] * len(todo), flips, fits, pols, chunksize=4))
        return [_one(t, args.dry_run, out, f, g, p) for t, f, g, p in zip(todo, flips, fits, pols)]
    if args.check:
        import tempfile
        with tempfile.TemporaryDirectory() as a, tempfile.TemporaryDirectory() as b:
            ra, rb = run(Path(a)), run(Path(b))
            diff = [t for t in todo if (Path(a) / t).is_file() != (Path(b) / t).is_file()
                    or ((Path(a) / t).is_file() and (Path(a) / t).read_bytes() != (Path(b) / t).read_bytes())]
        bad = [r for r in ra if r.startswith("FAIL")] + [f"DIFF {t} (two runs differ)" for t in diff]
        body = bad + [f"check rows={len(todo)} differ={len(diff)} failed={len(bad) - len(diff)}"]
        return agent_log.finish("rekey-all-stills", root, "\n".join(body), "FAIL" if bad or ra != rb else "PASS", args=args,
                                rows=len(todo), differ=len(diff))
    out = Path(args.out).resolve() if args.out else None
    results = run(out)
    kept, met = {}, {}
    for line in results:
        if line.startswith("WROTE") and " area=" in line:
            kv = dict(t.split("=", 1) for t in line.split() if "=" in t)
            met[line.split()[1]] = {k: (v if k == "policy" else float(v)) for k, v in kv.items()}
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
        (out / "_metrics.json").write_text(json.dumps(met, indent=1), encoding="utf-8")
    lines.append(f"done wrote={wrote} skipped={skipped} failed={failed}")
    status = "FAIL" if failed else "PASS"
    return agent_log.finish("rekey-all-stills", root, "\n".join(lines), status, args=args, wrote=wrote, skipped=skipped, failed=failed)

if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
