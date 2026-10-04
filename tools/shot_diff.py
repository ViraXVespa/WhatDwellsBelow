#!/usr/bin/env python3
"""Before/after diff of shot PNGs (two files, or two directories paired by file name).

  python3 tools/shot_diff.py BEFORE AFTER [--tol 0] [--max-ratio 0.02] [--mask X,Y,W,H] [--out DIR] [--json]

Identical bytes short-circuit (no Pillow needed). Otherwise imglib.compare (Pillow + numpy) counts changed pixels
(any channel differs by more than --tol), the changed bounding box and the max channel delta, and
write NAME.diff.png (dimmed BEFORE with changed pixels in red) under --out. Importable:
compare(a, b, tol, out_png, masks) and compare_dirs(a, b, tol, out_dir, masks).

RESULT PASS = all identical, INFO = changed but within --max-ratio (or no limit given),
FAIL = size mismatch, a frame only on one side, or over --max-ratio.
"""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
from agent_log import rel


def _sha(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()


def parse_mask(text: str) -> tuple[int, int, int, int]:
    try:
        x, y, w, h = (int(v) for v in text.replace(" ", "").split(","))
    except ValueError:
        agent_log.fail(f"bad --mask {text!r}: want X,Y,W,H in pixels of a 1920x1080 frame (example 1040,20,260,100)")
    return x, y, w, h


def compare(a: Path, b: Path, tol: int = 0, out_png: Path | None = None, masks: list | None = None) -> dict:
    """Compare two PNGs. status: same | changed | size | missing. masks: [(x, y, w, h)] in 1920x1080 pixels, ignored
    (live-world sprites that animate between runs)."""
    if not a.is_file() or not b.is_file():
        return {"status": "missing", "name": b.name, "changed_px": 0, "ratio": 0.0}
    if _sha(a) == _sha(b):
        return {"status": "same", "name": b.name, "changed_px": 0, "ratio": 0.0}
    try:
        from imglib import compare as cmp, imgio
    except ImportError:
        agent_log.fail("shot_diff needs Pillow and numpy for non-identical PNGs (python3 -m pip install -r tools/requirements.txt)")
    ia, ib = imgio.load(a), imgio.load(b)
    if ia.size != ib.size:
        return {"status": "size", "name": b.name, "before": list(ia.size), "after": list(ib.size),
                "changed_px": 0, "ratio": 1.0}
    k = ia.size[0] / 1920.0
    ign = [(mx * k, my * k, (mx + mw) * k, (my + mh) * k) for mx, my, mw, mh in masks or []]
    d = cmp.diff(ia, ib, tol, ign)
    res = {"status": d["status"], "name": b.name, "changed_px": d["changed_px"], "ratio": d["ratio"],
           "max_delta": d["max_delta"], "bbox": d["bbox"]}
    if d["changed_px"] and out_png is not None:
        imgio.save(cmp.heatmap(ia, ib, tol, ign), out_png)
        res["diff_png"] = str(out_png)
    return res


def compare_dirs(a: Path, b: Path, tol: int = 0, out_dir: Path | None = None, masks: list | None = None) -> list[dict]:
    names = sorted({p.name for p in a.glob("*.png")} | {p.name for p in b.glob("*.png")})
    rows = []
    for nm in names:
        if not (a / nm).is_file():
            rows.append({"status": "added", "name": nm, "changed_px": 0, "ratio": 0.0})
        elif not (b / nm).is_file():
            rows.append({"status": "removed", "name": nm, "changed_px": 0, "ratio": 0.0})
        else:
            rows.append(compare(a / nm, b / nm, tol, (out_dir / (nm[:-4] + ".diff.png")) if out_dir else None, masks))
    return rows


def verdict(rows: list[dict], max_ratio: float | None) -> str:
    if any(r["status"] in ("size", "missing", "added", "removed") for r in rows):
        return "FAIL"
    if max_ratio is not None and any(r["ratio"] > max_ratio for r in rows):
        return "FAIL"
    return "PASS" if all(r["status"] == "same" for r in rows) else "INFO"


def main(argv: list[str] | None = None) -> int:
    p = agent_log.std_parser("Diff shot PNGs: before vs after (files or directories).", writes=True, json_out=True)
    p.add_argument("before", help="Before PNG (or a folder of PNGs).")
    p.add_argument("after", help="After PNG (or a folder of PNGs).")
    p.add_argument("--tol", type=int, default=0, help="per-channel delta that still counts as unchanged")
    p.add_argument("--max-ratio", type=float, default=None, help="FAIL when a frame changes more than this fraction of pixels")
    p.add_argument("--out", default="", help="diff PNG directory (default _logs/shot-diff)")
    p.add_argument("--mask", action="append", default=[], metavar="X,Y,W,H", help="Ignore this rectangle (pixels of a 1920x1080 frame; repeatable).")
    args = p.parse_args(argv)
    masks = [parse_mask(m) for m in args.mask]
    root = agent_log.resolve_root(args)
    a, b = Path(args.before), Path(args.after)
    out_dir = Path(args.out) if args.out else root / "_logs" / "shot-diff"
    if not args.dry_run:
        out_dir.mkdir(parents=True, exist_ok=True)
    if a.is_dir() != b.is_dir():
        agent_log.fail("give two files or two directories")
    if not a.exists() or not b.exists():
        agent_log.fail(f"not found: {a if not a.exists() else b}")
    sink = None if args.dry_run else out_dir
    if a.is_dir():
        rows = compare_dirs(a, b, args.tol, sink, masks)
    else:
        rows = [compare(a, b, args.tol, (out_dir / (b.stem + ".diff.png")) if sink else None, masks)]
    status = verdict(rows, args.max_ratio)
    lines = [f"shot-diff before={a} after={b} tol={args.tol}"]
    for r in rows:
        extra = f" max_delta={r.get('max_delta')} bbox={r.get('bbox')}" if r["status"] == "changed" else ""
        lines.append(f"{r['status']:8s} {r['name']} changed_px={r['changed_px']} ratio={r['ratio']}{extra}")
    res = agent_log.write_run_file(root, root / "_logs" / "shot-diff", "shot-diff", "\n".join(lines), status, write=not args.dry_run,
                                   frames=len(rows), same=sum(r["status"] == "same" for r in rows),
                                   changed=sum(r["status"] == "changed" for r in rows),
                                   bad=sum(r["status"] in ("size", "missing", "added", "removed") for r in rows))
    if args.json:
        agent_log.print_json({"status": status, "rows": rows})
    else:
        print("\n".join(lines + [res]))
    return agent_log.exit_code(status)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
