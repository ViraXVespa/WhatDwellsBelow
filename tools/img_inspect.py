#!/usr/bin/env python3
"""Programmatic eyes for images: compact text facts plus optional annotated PNGs (imglib.look).

  describe IMG                 size, alpha coverage, content box, margins, palette
  layout IMG [--box ...]       element boxes (segmented, or given with --box X,Y,W,H from node rects) and layout checks:
                               off-screen, clipped, overlap, alignment, gaps, safe area
  contrast IMG --box X,Y,W,H   WCAG text-vs-background ratio per box (repeatable; --large for 3:1)
  grid IMG --png OUT           labeled coordinate grid     zoom IMG --box X,Y,W,H --png OUT   crop + zoom
  diff BEFORE AFTER            pixel diff: score, changed regions, heatmap (--png)
  montage IMG IMG ... --png OUT   labeled side-by-side (labels = file names)
  find SHOT TEMPLATE           where a sprite or crop appears (needs OpenCV)
  halo IMG [--png OUT]         colour bleed on a keyed picture's rim and leftover plate colour
  rimclean IMG OUT --refs ...  re-key the rim of a keyed picture against given plate colours (scratch copy)
  motion F1 F2 ...             changed-pixel % between consecutive frames
  selftest                     imglib checks on small synthetic images (about 2 s)

Every command ends with a RESULT line (FAIL when its check fails: contrast below the ratio, halo CHECK,
layout problems, diff over --max-ratio). Image deps: tools/requirements.txt.
"""
from __future__ import annotations

import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
from agent_log import rel

COMMANDS = ("selftest", "describe", "layout", "contrast", "grid", "zoom", "diff", "montage", "find", "halo", "rimclean", "motion")


def _box(text: str) -> tuple[int, int, int, int]:
    try:
        x, y, w, h = (int(v) for v in text.replace(" ", "").split(","))
    except ValueError:
        agent_log.fail(f"bad box {text!r}: want X,Y,W,H in pixels (example 40,20,200,48)")
    return x, y, x + w, y + h


def _need(args, n: int, what: str) -> list[str]:
    if len(args.paths) < n:
        agent_log.fail(f"{args.cmd} needs {what}")
    return args.paths


def _save(im, path: str, dry: bool) -> str | None:
    if not path or dry:
        return None
    from imglib import imgio
    imgio.save(im, path)
    return Path(path).as_posix()


def run(args) -> tuple[str, list[str], dict]:
    from imglib import compare, imgio, key, look
    cmd, paths = args.cmd, args.paths
    status, lines, kv = "PASS", [], {}
    if cmd == "selftest":
        from imglib import selftest
        res = selftest.run()
        lines += [("ok   " if ok else "FAIL ") + name + " - " + detail for name, ok, detail in res]
        kv.update(checks=len(res), failing=sum(not ok for _n, ok, _d in res))
        status = "FAIL" if kv["failing"] else "PASS"
    elif cmd == "describe":
        im = imgio.load(_need(args, 1, "IMG")[0])
        d = look.describe(im)
        lines.append(look.fmt_describe(d))
        status = "INFO"
    elif cmd == "layout":
        im = imgio.load(_need(args, 1, "IMG")[0])
        boxes = [_box(b) for b in args.box] or look.regions(im, merge=args.merge, min_area=args.min_area)
        res = look.layout(boxes, im.size, safe=args.safe, tol=args.tol)
        lines.append(look.fmt_layout(boxes, res))
        bad = len(res["offscreen"]) + len(res["clipped"]) + len(res["overlaps"])
        kv.update(elements=len(boxes), offscreen=len(res["offscreen"]), clipped=len(res["clipped"]), overlaps=len(res["overlaps"]), outside_safe=len(res["outside_safe"]))
        status = "FAIL" if bad else "PASS"
        out = _save(look.annotate(im, boxes, res), args.png, args.dry_run)
        out and lines.append(f"annotated {out}")
    elif cmd == "contrast":
        im = imgio.load(_need(args, 1, "IMG")[0])
        if not args.box:
            agent_log.fail("contrast needs at least one --box X,Y,W,H")
        fails = 0
        for b in args.box:
            c = look.contrast(im, _box(b), large=args.large)
            lines.append(look.fmt_contrast(c))
            fails += not c["pass"]
        kv.update(boxes=len(args.box), failing=fails)
        status = "FAIL" if fails else "PASS"
    elif cmd in ("grid", "zoom"):
        im = imgio.load(_need(args, 1, "IMG")[0])
        out_im = look.grid_overlay(im, args.step) if cmd == "grid" else look.zoom(im, _box_corners(args), args.factor)
        out = _save(out_im, args.png, args.dry_run)
        lines.append(f"{cmd} {out_im.size[0]}x{out_im.size[1]}" + (f" -> {out}" if out else " (give --png OUT to write it)"))
        status = "INFO"
    elif cmd == "diff":
        a, b = _need(args, 2, "BEFORE AFTER")[:2]
        ia, ib = imgio.load(a), imgio.load(b)
        ign = [_box(m) for m in args.mask]
        d = compare.diff(ia, ib, args.tol_px, ign)
        lines.append(f"{d['status']} score {d.get('score')} changed_px {d['changed_px']} ratio {d['ratio']} max_delta {d.get('max_delta')} bbox {d.get('bbox')}")
        for r in d.get("regions", []):
            lines.append(f"  region x{r[0]} y{r[1]} {r[2] - r[0]}x{r[3] - r[1]}")
        kv.update(changed_px=d["changed_px"], ratio=d["ratio"], score=d.get("score"))
        status = "PASS" if d["status"] == "same" else "FAIL" if d["status"] == "size" or (args.max_ratio is not None and d["ratio"] > args.max_ratio) else "INFO"
        out = _save(compare.heatmap(ia, ib, args.tol_px, ign, boxes_on=True), args.png, args.dry_run) if d["status"] == "changed" else None
        out and lines.append(f"heatmap {out}")
    elif cmd == "montage":
        ims = [imgio.load(p) for p in _need(args, 1, "IMG ...")]
        out = _save(compare.montage(ims, [Path(p).name for p in paths], cols=args.cols or None), args.png, args.dry_run)
        lines.append(f"montage of {len(ims)}" + (f" -> {out}" if out else " (give --png OUT to write it)"))
        status = "INFO"
    elif cmd == "find":
        a, b = _need(args, 2, "SHOT TEMPLATE")[:2]
        hits = look.find(imgio.load(a), imgio.load(b), args.threshold)
        lines += [f"match x{h[0]} y{h[1]} {h[2]}x{h[3]} score {h[4]}" for h in hits] or ["no match above threshold"]
        kv.update(matches=len(hits))
        status = "PASS" if hits else "FAIL"
    elif cmd == "halo":
        im = imgio.load(_need(args, 1, "IMG")[0])
        h = look.halo(im)
        lines.append(look.fmt_halo(h))
        kv.update(halo_pct=h["halo_pct"], leftover=h["plate_like_px"])
        status = "PASS" if look.fmt_halo(h).endswith("CLEAN") else "FAIL"
        if args.png and not args.dry_run:
            import numpy as np
            vis = im.convert("RGBA").copy()
            arr = np.array(vis)
            arr[h["mask"]] = (0, 255, 255, 255)
            lines.append(f"annotated {_save(imgio.from_np(arr), args.png, False)} (cyan = tinted rim)")
    elif cmd == "rimclean":
        src, dest = _need(args, 2, "IMG OUT")[:2]
        refs = [tuple(int(v) for v in r.replace("#", "").replace(" ", "").split(",")) if "," in r else tuple(int(r.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)) for r in args.refs]
        if not refs:
            agent_log.fail("rimclean needs --refs R,G,B (or RRGGBB), one per plate shade")
        im = imgio.load(src)
        out_im = key.key_to_alpha(im, refs=refs)
        before, after = look.halo(im), look.halo(out_im)
        lines += ["before " + look.fmt_halo(before), "after  " + look.fmt_halo(after)]
        out = _save(out_im, dest, args.dry_run)
        lines.append(f"wrote {out}" if out else "dry run: nothing written")
        status = "INFO"
    elif cmd == "motion":
        from imglib.imgio import load
        frames = [load(p) for p in _need(args, 2, "F1 F2 ...")]
        m = look.motion(frames, args.tol_px if args.tol_px else 8)
        lines.append(look.fmt_motion(m))
        kv.update(frames=m["frames"], static=m["static"], max_pct=m["max_pct"])
        status = "INFO"
    return status, lines, kv


def _box_corners(args):
    if not args.box:
        agent_log.fail("zoom needs --box X,Y,W,H")
    return _box(args.box[0])


def main(argv: list[str] | None = None) -> int:
    p = agent_log.std_parser(__doc__.split("\n\n")[0], writes=True, json_out=True)
    p.add_argument("cmd", choices=COMMANDS, help="what to inspect (see the list above)")
    p.add_argument("paths", nargs="*", help="image paths (meaning depends on the command)")
    p.add_argument("--png", default="", help="write the annotated / zoomed / montage PNG here")
    p.add_argument("--box", action="append", default=[], metavar="X,Y,W,H", help="a region in pixels (repeatable for contrast)")
    p.add_argument("--mask", action="append", default=[], metavar="X,Y,W,H", help="diff: ignore this rectangle (repeatable)")
    p.add_argument("--merge", type=int, default=6, help="layout: merge elements closer than this many px")
    p.add_argument("--min-area", type=int, default=12, help="layout: ignore specks under this many px")
    p.add_argument("--safe", type=float, default=0.05, help="layout: safe-area margin as a fraction of the screen")
    p.add_argument("--tol", type=int, default=3, help="layout: edges this close (1..N px) count as near-aligned")
    p.add_argument("--tol-px", type=int, default=0, help="diff / motion: channel delta that still counts as unchanged")
    p.add_argument("--max-ratio", type=float, default=None, help="diff: FAIL above this changed-pixel fraction")
    p.add_argument("--large", action="store_true", help="contrast: large text, need 3:1 instead of 4.5:1")
    p.add_argument("--step", type=int, default=100, help="grid: line spacing in px")
    p.add_argument("--factor", type=int, default=4, help="zoom: integer magnification")
    p.add_argument("--cols", type=int, default=0, help="montage: columns (default: one row)")
    p.add_argument("--threshold", type=float, default=0.9, help="find: minimum match score 0-1")
    p.add_argument("--refs", action="append", default=[], metavar="R,G,B", help="rimclean: plate colour (repeatable)")
    args = p.parse_args(argv)
    root = agent_log.resolve_root(args)
    status, lines, kv = run(args)
    res = agent_log.write_run_file(root, root / "_logs" / "img-inspect", "img-inspect", "\n".join(lines), status,
                                   write=not args.dry_run, cmd=args.cmd, **kv)
    if args.json:
        agent_log.print_json({"status": status, "cmd": args.cmd, "lines": lines, **kv})
    else:
        print("\n".join(lines + [res]))
    return agent_log.exit_code(status)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
