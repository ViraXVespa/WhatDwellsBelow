#!/usr/bin/env python3
"""Staged-only image review helper: OCR, crop/zoom and pixel diff. No repo imports."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from ocr_core import analyse, fmt, tesseract_exe
from ocr_evidence import record

MANIFEST = ".wdb-review.json"


def inside(root: Path, value: str) -> Path:
    p = (root / value).resolve()
    if not p.is_relative_to(root.resolve()):
        raise ValueError("path must stay inside the staged review directory")
    return p


def source(root: Path, value: str, originals: bool = False) -> Path:
    p = inside(root, value)
    data = json.loads((root / MANIFEST).read_text(encoding="utf-8"))
    allowed = {inside(root, k) for k in data["images"]}
    allowed |= {inside(root, v["full"]) for v in data["images"].values()}
    if p not in allowed and not (p.is_relative_to(root / "out") and p.suffix.lower() == ".png"):
        raise ValueError("input must be a staged image or an out/*.png helper result")
    if not p.is_file():
        raise ValueError("missing staged image: " + value)
    entry = data["images"].get(str(p.relative_to(root)))
    return inside(root, entry["full"]) if originals and entry else p


def destination(root: Path, value: str) -> Path:
    p = inside(root, value)
    if not p.is_relative_to(root / "out") or p.suffix.lower() != ".png":
        raise ValueError("output must be out/*.png (sources cannot be overwritten)")
    p.parent.mkdir(parents=True, exist_ok=True)
    return p


def parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(description=__doc__)
    sub = ap.add_subparsers(dest="op", required=True)
    oc = sub.add_parser("ocr", help="Try local Tesseract on staged full-size sources; record evidence even on SKIP")
    oc.add_argument("images", nargs="+")
    oc.add_argument("--psm", type=int, choices=(6, 7), default=6)
    oc.add_argument("--expect", default="")
    for name in ("crop", "zoom"):
        cr = sub.add_parser(name, help="Box in supplied-image pixels; crop from full source")
        cr.add_argument("image")
        cr.add_argument("--box", required=True, help="x,y,w,h in supplied-image pixels")
        cr.add_argument("--scale", type=int, choices=range(1, 9), default=4 if name == "zoom" else 1)
        cr.add_argument("--out", required=True)
    df = sub.add_parser("diff", help="Pixel difference of staged sources, with heatmap")
    df.add_argument("before")
    df.add_argument("after")
    df.add_argument("--out", required=True)
    return ap


def run(args, root: Path) -> int:
    if args.op == "ocr":
        exe = tesseract_exe()
        status, lines, files = "ATTEMPT", [], []
        failed = False
        for name in args.images:
            displayed, full = source(root, name), source(root, name, True)
            files.extend([displayed, full])
            if not exe:
                status = "SKIP"
                lines.append("READ weak " + name + " local OCR SKIP: Tesseract not installed")
            else:
                try:
                    r = analyse(exe, full, None, args.expect, args.psm)
                    lines.append(fmt(r))
                    failed |= r["read"] == "fail"
                except (RuntimeError, OSError, ValueError) as exc:
                    status, failed = "ERROR", True
                    lines.append("READ fail " + name + " local OCR error: " + str(exc))
        record(list(dict.fromkeys(files)), root, status, lines)
        print("\n".join(lines))
        print("RESULT " + ("SKIP" if status == "SKIP" else "FAIL" if failed else "PASS") + " cmd=local-ocr")
        return 1 if failed else 0
    from imglib import compare, geom, imgio
    if args.op in ("crop", "zoom"):
        a = imgio.load(source(root, args.image))
        full = imgio.load(source(root, args.image, True))
        x, y, w, h = map(int, args.box.split(","))
        if min(x, y) < 0 or min(w, h) <= 0 or x + w > a.width or y + h > a.height:
            raise ValueError("box must fit the supplied image")
        import math
        box = (math.floor(x * full.width / a.width), math.floor(y * full.height / a.height),
               math.ceil((x + w) * full.width / a.width), math.ceil((y + h) * full.height / a.height))
        result = geom.scale_nearest(geom.crop(full, box), factor=args.scale)
        imgio.save(result, destination(root, args.out))
        print(f"RESULT PASS cmd=local-{args.op} source={full.size} box={box} output={result.size}")
    else:
        a, b = imgio.load(source(root, args.before, True)), imgio.load(source(root, args.after, True))
        score = compare.diff(a, b)
        print(json.dumps(score, sort_keys=True))
        if a.size != b.size:
            print("RESULT FAIL cmd=local-diff reason=size-mismatch")
            return 1
        imgio.save(compare.heatmap(a, b), destination(root, args.out))
        print("RESULT PASS cmd=local-diff")
    return 0


def main(argv=None) -> int:
    try:
        return run(parser().parse_args(argv), Path(__file__).resolve().parents[1])
    except (ValueError, OSError, KeyError) as exc:
        print("RESULT FAIL reason=" + str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
