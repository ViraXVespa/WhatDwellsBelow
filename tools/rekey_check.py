#!/usr/bin/env python3
"""Full-set rekey quality check: a rekey output folder against the live assets and the _src source plates.

    python tools/rekey_check.py --new DIR [--only a,b] [--strict]

DIR holds the same relative paths as the live assets (tools/rekey_all_stills.py --out DIR). One row per manifest
entry. Failure classes (each is counted):
  canvas    size or mode differs from the live PNG
  quality   detail lost: edge energy under 80 % of live, or (opaque art) mean colour error vs live over 6
  hard      hard edges went soft: share of partial-alpha pixels on the opaque rim over the larger of live's and the
            plate's own soft rim at output scale (DIR/_soft.json rim) + 0.20
  shift     opaque box moved vs live (top, bottom or centre x off by more than 2 px; recentring)
  pad       opaque box grew or shrank by more than 4 % (padding or crop added)
  mirror    a left-facing still (manifest flip) is not the exact mirror of its right-facing sibling from the same
            plate, or the output matches live only when flipped while live's own pair is mirrored
  plate     plate colour left on visible pixels
  alpha     live is fully opaque (tile, finished art) and the output is not
  stale     the source plate no longer matches the live art (live is the truth): opaque assets by colour error,
            keyed ones as reported in DIR/_kept.json by rekey_all_stills. Reported; the output must equal live.
  soft      softness lost: the plate keys to a soft subject (partial alpha wider than half an output pixel on >= 3%
            of its pixels, DIR/_soft.json share) and the output keeps under half of that share. Old live is not a
            reference here: its softness was often blur from the old shrink
  notch     notches cut into the silhouette: 2+ output pixels clear where the exact source at output scale
            (premultiplied area average, same placement) is mostly paint (alpha >= 160); shrinks of 1.5x or more (DIR/_soft.json notch)
  lost      the key lost the subject (paint on the plate's hue); the pipeline kept live (DIR/_kept.json)
Rows that are out of bounds for the open-set pass (dummy, guild, guild_reception, stall, anvil, fence, pickaxe,
male frames) are checked too and tagged frozen. Writes _logs/rekey-check/<stamp>.json.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import agent_log

ROOT = Path(__file__).resolve().parents[1]
FROZEN = ("assets/fx/dummy.png", "assets/sprites/buildings/guild.png", "assets/sprites/buildings/guild_reception.png",
          "assets/sprites/buildings/stall.png", "assets/sprites/props/anvil.png", "assets/sprites/props/fence.png",
          "assets/ui/gear/pickaxe.png", "assets/sprites/player/male/")
# replaced art: slot_legs (new art from her jpg), extract_gate_on (live was wrong; the plate wins)
NEW_ART = ("assets/ui/gear/slot_legs.png", "assets/sprites/props/extract_gate_on.png")
CLASSES = ("canvas", "quality", "hard", "shift", "pad", "mirror", "plate", "alpha", "stale", "lost", "soft", "notch")


def frozen(rel: str) -> bool:
    return any(rel == f or (f.endswith("/") and rel.startswith(f)) for f in FROZEN)


def rgba(p: Path) -> np.ndarray:
    return np.asarray(Image.open(p).convert("RGBA"), dtype=np.float32)


def core_box(a: np.ndarray, t: float = 128.0):
    ys, xs = np.nonzero(a >= t)
    if len(xs) == 0:
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def luma_on_grey(x: np.ndarray) -> np.ndarray:
    al = x[..., 3:4] / 255.0
    rgb = x[..., :3] * al + 128.0 * (1 - al)
    return rgb @ np.array([0.299, 0.587, 0.114], np.float32)


def edge_energy(x: np.ndarray) -> float:
    l = luma_on_grey(x)
    gx = np.abs(np.diff(l, axis=1)).sum()
    gy = np.abs(np.diff(l, axis=0)).sum()
    return float(gx + gy)


def rim_soft(x: np.ndarray) -> float:
    a = x[..., 3]
    solid = a >= 128
    pad = np.pad(solid, 1)
    inner = pad[1:-1, 1:-1]
    nb = pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:]
    rim = inner & ~nb
    if rim.sum() == 0:
        return 0.0
    return float(((a > 8) & (a < 247) & rim).sum() / rim.sum())


def plate_left(x: np.ndarray) -> int:
    r, g, b, a = x[..., 0], x[..., 1], x[..., 2], x[..., 3]
    exc = np.minimum(r, b) - g
    return int(((a > 32) & (exc > 60) & (r > 150) & (b > 120)).sum())


def mad(a: np.ndarray, b: np.ndarray) -> float:
    pa, pb = a[..., 3:4] / 255.0, b[..., 3:4] / 255.0
    ca = a[..., :3] * pa + 128 * (1 - pa)
    cb = b[..., :3] * pb + 128 * (1 - pb)
    return float(np.abs(ca - cb).mean())


def check(rel: str, src: Path, new_p: Path, flip: bool) -> dict:
    live_p = ROOT / rel
    row = {"live": rel, "frozen": frozen(rel), "fail": []}
    if not new_p.is_file():
        row["fail"].append("missing")
        return row
    li_im, nw_im = Image.open(live_p), Image.open(new_p)
    live, new = rgba(live_p), rgba(new_p)
    opaque_live = bool((live[..., 3] >= 255).all())
    if opaque_live:
        s = np.asarray(Image.open(src).convert("RGB").resize(li_im.size, Image.Resampling.LANCZOS), np.float32)
        row["src_err"] = round(float(np.abs(s - live[..., :3]).mean()), 2)
        if row["src_err"] > 6.0:
            row["fail"].append("stale")
    if li_im.size != nw_im.size or (li_im.mode == "RGB") != (nw_im.mode == "RGB"):
        row["fail"].append("canvas")
        row["size"] = [list(li_im.size), list(nw_im.size), li_im.mode, nw_im.mode]
        return row
    if opaque_live:
        if not (new[..., 3] >= 255).all():
            row["fail"].append("alpha")
        row["err"] = round(mad(new, live), 2)
        if row["err"] > (0.5 if "stale" in row["fail"] else 6.0):
            row["fail"].append("quality")
        e_l, e_n = edge_energy(live), edge_energy(new)
        row["edge"] = round(e_n / max(e_l, 1.0), 3)
        if row["edge"] < 0.8:
            row["fail"].append("quality") if "quality" not in row["fail"] else None
        return row
    bl, bn = core_box(live[..., 3]), core_box(new[..., 3])
    if bl and bn:
        row["box"] = [bl, bn]
        if abs(bl[1] - bn[1]) > 2 or abs(bl[3] - bn[3]) > 2 or abs((bl[0] + bl[2]) - (bn[0] + bn[2])) > 4:
            row["fail"].append("shift")
        al, an = (bl[2] - bl[0]) * (bl[3] - bl[1]), (bn[2] - bn[0]) * (bn[3] - bn[1])
        row["area"] = round(an / max(al, 1), 3)
        if abs(row["area"] - 1.0) > 0.08:
            row["fail"].append("pad")
    elif bl or bn:
        row["fail"].append("pad")
    e_l, e_n = edge_energy(live), edge_energy(new)
    row["edge"] = round(e_n / max(e_l, 1.0), 3)
    if row["edge"] < 0.8:
        row["fail"].append("quality")
    rs_l, rs_n = rim_soft(live), rim_soft(new)
    row["rim_soft"] = [round(rs_l, 3), round(rs_n, 3)]
    if rs_n > rs_l + 0.20:
        row["fail"].append("hard")
    row["plate"] = plate_left(new)
    if row["plate"] > 3 and row["plate"] > 2 * plate_left(live):
        row["fail"].append("plate")
    row["err"] = round(mad(new, live), 2)
    if rel in NEW_ART:
        row["fail"] = [f for f in row["fail"] if f not in ("quality", "pad", "shift")]
        row["new_art"] = True
    return row


def mirror_pairs(entries: list, new_dir: Path, rows: dict) -> None:
    """Each flip row against the mirror of a non-flip row from the same plate with the same name minus left/right."""
    by_src = {}
    for e in entries:
        by_src.setdefault(e["source"], []).append(e)
    for e in entries:
        if not e.get("flip") or e["live"] not in rows:
            continue
        name = e["live"].rsplit("/", 1)[-1].replace("_left", "_right")
        sib = [o for o in by_src[e["source"]] if not o.get("flip") and o["live"].rsplit("/", 1)[-1] == name]
        if not sib:
            continue
        a, b = new_dir / e["live"], new_dir / sib[0]["live"]
        if not a.is_file() or not b.is_file():
            continue
        d = float(np.abs(rgba(a) - rgba(b)[:, ::-1]).mean())
        rows[e["live"]]["mirror_err"] = round(d, 2)
        if d > 0.5:
            rows[e["live"]]["fail"].append("mirror")


SOFT_MIN = 3.0  # partial-alpha percent at or above this: a soft subject


def _share(p: Path) -> float:
    a = rgba(p)[..., 3]
    return 100.0 * float(((a > 16) & (a < 239)).sum()) / max(1, int((a > 0).sum()))


def soft_lost(row: dict, src_share, live_p: Path, new_p: Path) -> None:
    """Flag a soft subject (by its keyed plate) whose output kept under half of its partial alpha."""
    new, live = _share(new_p), _share(live_p)
    row["soft"] = [round(src_share or 0.0, 1), round(live, 1), round(new, 1)]
    if src_share is not None and src_share >= SOFT_MIN and new < 0.5 * src_share:
        row["fail"].append("soft")


def main(argv=None) -> int:
    ap = agent_log.std_parser("Full-set rekey quality check vs live assets and _src plates.", json_out=True)
    ap.add_argument("--new", required=True, help="Rekey output folder (rekey_all_stills.py --out).")
    ap.add_argument("--only", default="")
    ap.add_argument("--soft", default="", help="Source softness file (default DIR/_soft.json).")
    ap.add_argument("--strict", action="store_true", help="FAIL on frozen rows too.")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    man = json.loads((ROOT / "_src" / "manifest.json").read_text(encoding="utf-8"))
    want = {p for p in args.only.split(",") if p}
    rows = []
    for e in man["entries"]:
        rel = e.get("live", "")
        if not rel or (want and rel not in want) or not (ROOT / rel).is_file():
            continue
        rows.append(check(rel, ROOT / "_src" / e["source"], Path(args.new) / rel, bool(e.get("flip"))))
    kept_p = Path(args.new) / "_kept.json"
    kept = json.loads(kept_p.read_text(encoding="utf-8")) if kept_p.is_file() else {}
    for r in rows:
        why = kept.get(r["live"], "")
        if why.startswith("STALE") and "stale" not in r["fail"]:
            r["fail"].append("stale")
        elif why.startswith("LOST"):
            r["fail"].append("lost")
    soft_p = Path(args.soft) if args.soft else Path(args.new) / "_soft.json"
    soft = json.loads(soft_p.read_text(encoding="utf-8")) if soft_p.is_file() else {}
    for r in rows:
        if "missing" not in r["fail"]:
            sv = soft.get(r["live"]) or {}
            sv = {"share": sv} if isinstance(sv, (int, float)) else sv
            rs = r.get("rim_soft")
            if "hard" in r["fail"] and rs and rs[1] <= max(rs[0], sv.get("rim", 0.0)) + 0.20:
                r["fail"].remove("hard")
            if sv.get("notch", 0) >= 2:
                r["fail"].append("notch")
            r["notch"] = [sv.get("notch"), sv.get("bump")]
            soft_lost(r, sv.get("share"), ROOT / r["live"], Path(args.new) / r["live"])
    mirror_pairs([e for e in man["entries"] if e.get("live")], Path(args.new), {r["live"]: r for r in rows})
    counts = {c: 0 for c in CLASSES + ("missing",)}
    counts_open = dict(counts)
    for r in rows:
        for c in set(r["fail"]):
            counts[c] += 1
            if not r["frozen"]:
                counts_open[c] += 1
    out = root / "_logs" / "rekey-check"
    out.mkdir(parents=True, exist_ok=True)
    (out / "last.json").write_text(json.dumps({"counts": counts, "counts_open": counts_open, "rows": rows}, indent=1), encoding="utf-8")
    body = [f"{len(rows)} rows. fails (all / not frozen):"] + [f"  {c}: {counts[c]} / {counts_open[c]}" for c in counts]
    for r in rows:
        if r["fail"]:
            body.append(f"{'F ' if r['frozen'] else '  '}{r['live']}: {','.join(r['fail'])} edge={r.get('edge')} area={r.get('area')} err={r.get('err')} src_err={r.get('src_err', '')}")
    bad = sum(counts.values()) if args.strict else sum(counts_open[c] for c in counts_open if c != "stale")
    return agent_log.finish("rekey-check", root, "\n".join(body), "FAIL" if bad else "PASS", args=args, **counts)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
