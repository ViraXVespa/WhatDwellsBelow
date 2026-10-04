#!/usr/bin/env python3
"""Posed-camera postcard tool. Not a numbered P1-P9 smoke.

Modes:
  web   full-res PNG + Windows clipboard (paste into chat)
  build scaled PNG under the session shots dir
  user  full-res PNG and open it

Scripted flows (open a menu, press pad buttons, shoot every page, assert state): --steps FILE
(a tools/shot-flows/*.json; see design/shot-flows.md). Whole flows, diffs and publishing: run_shot_flow.py.
Whole floor in one image: --full-map [--floor N --seed S --max-px 8192] sweeps the dungeon floor in overlapping play-camera
tiles (flow op "sweep") and stitches them (needs Pillow). Numbers live here, not in a prompt.
"""
from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
import godot_lib
import run_log_lib
import shot_clip_lib
from agent_log import rel

JOB = "shots"
BUILD_SCALE_PCT = 50
SETTLE_MS = 1000
TIMEOUT_SEC = 180
WARN_BYTES = 2048
RENDER_DRIVER = "opengl3"
RENDER_METHOD = "gl_compatibility"
SCREENS = ("title", "splash", "fs_gate")  # menu screens the worker can boot (scripts/debug/shot_tool/tool_args.gd)
# Flow-file header keys that fill an unset CLI default (scene, hud, zoom, ...).
FLOW_KEYS = ("scene", "hud", "zoom", "settle_ms", "seed", "floor", "px", "pz", "width", "height", "fixed_fps")


def _load_recipe(root: Path, name: str) -> dict:
    path = root / "tools" / "shot-recipes.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    rec = data.get(name)
    if not isinstance(rec, dict) or not rec.get("frames"):
        raise SystemExit("FAIL unknown shot recipe " + name)
    return rec


def _recipe_poses(rec: dict) -> str:
    bits: list[str] = []
    for fr in rec.get("frames") or []:
        kind = str(fr.get("kind") or "play")
        look = fr.get("look") or [16.5, 15.0]
        off = fr.get("offset") or [0.0, 0.0]
        zoom = fr.get("zoom")
        if zoom is None:
            zoom = rec.get("zoom", 1.0)
        px = fr.get("px", rec.get("px", look[0]))
        pz = fr.get("pz", rec.get("pz", look[1]))
        face = fr.get("face", "down")
        bits.append("%s,%s,%s,%s,%s,%s,%s,%s,%s" % (kind, look[0], look[1], off[0], off[1], zoom, px, pz, face))
    return ";".join(bits)


def _out_dir(root: Path) -> Path:
    try:
        return agent_log.ensure_agent_log_dir(JOB, root)
    except FileNotFoundError:
        fallback = root / "_logs" / JOB
        fallback.mkdir(parents=True, exist_ok=True)
        return fallback


def _extra_flags(args: argparse.Namespace) -> list[str]:
    extra = [
        f"--wdb-shot-hud={1 if args.hud else 0}",
        f"--wdb-shot-zoom={args.zoom}",
        f"--wdb-shot-cx={args.cx}",
        f"--wdb-shot-cz={args.cz}",
        "--wdb-shot-scene=camp" if args.scene in ("camp", "hub") else (f"--wdb-shot-scene={args.scene}" if args.scene in SCREENS else "--wdb-shot-scene=dungeon"),
    ]
    if args.width > 0:
        extra.append(f"--wdb-shot-width={args.width}")
    if args.height > 0:
        extra.append(f"--wdb-shot-height={args.height}")
    if args.px != "":
        extra.append(f"--wdb-shot-px={args.px}")
    if args.pz != "":
        extra.append(f"--wdb-shot-pz={args.pz}")
    if args.steps:
        extra.append(f"--wdb-shot-steps={Path(args.steps).resolve()}")
    if args.frames_dir:
        extra.append(f"--wdb-shot-frames={Path(args.frames_dir).resolve()}")
    if args.no_pixels:
        extra.append("--wdb-shot-nopix=1")
    return extra


def _godot_args(root: Path, png: Path, args: argparse.Namespace, scale_pct: int, poses: str) -> list[str]:
    head = (["--headless", "--display-driver", "headless", "--audio-driver", "Dummy"] if args.no_pixels else
            ["--audio-driver", "Dummy", "--rendering-method", RENDER_METHOD, "--rendering-driver", RENDER_DRIVER])
    if args.fixed_fps > 0:
        head = head + ["--fixed-fps", str(args.fixed_fps)]  # fixed frame delta: repeatable animation and AI
    godot_args = head + [
        "--path", str(root),
        "--",
        "--wdb-shot",
        f"--wdb-shot-seed={max(1, args.seed)}",
        f"--wdb-shot-show={1 if args.show else 0}",
        f"--wdb-shot-floor={max(1, args.floor)}",
        f"--wdb-shot-out={png}",
        f"--wdb-shot-scale={scale_pct}",
        f"--wdb-shot-settle-ms={max(0, args.settle_ms)}",
    ] + _extra_flags(args)
    if poses:
        godot_args.append("--wdb-shot-poses=" + poses)
    return godot_args


def _log_lines(logs: list[Path], keep) -> list[str]:
    hits: list[str] = []
    for path in logs:
        if path.is_file():
            hits += [ln for ln in path.read_text(encoding="utf-8", errors="replace").splitlines() if keep(ln)]
    return hits


def _shot_lines(logs: list[Path]) -> list[str]:
    return _log_lines(logs, lambda ln: ln.startswith("SHOT:"))


def _error_lines(logs: list[Path]) -> list[str]:
    needles = ("SCRIPT ERROR:", "Parse Error", "Compile Error", "ERROR: Failed to")
    return _log_lines(logs, lambda ln: any(n in ln for n in needles))


def _png_info(png: Path) -> tuple[int, int, int]:
    if not png.is_file():
        return 0, 0, 0
    data = png.read_bytes()
    width = height = 0
    if len(data) >= 24 and data[:8] == b"\x89PNG\r\n\x1a\n":
        width = int.from_bytes(data[16:20], "big")
        height = int.from_bytes(data[20:24], "big")
    return len(data), width, height


def _band(ok: bool, nbytes: int, width: int, height: int) -> str:
    if not ok or nbytes <= 0 or width <= 0 or height <= 0:
        return "fail"
    if nbytes < WARN_BYTES:
        return "warn"
    return "good"


def apply_flow_header(args: argparse.Namespace, header: dict, given: set[str]) -> None:
    """Fill CLI values the user left at default from a flow file header."""
    for key in FLOW_KEYS:
        if key in header and key not in given:
            setattr(args, key, str(header[key]) if key in ("px", "pz") else type(getattr(args, key))(header[key]))


def stitch_full_map(tiles_dir: Path, png: Path, max_px: int, keep: bool) -> dict:
    """Stitch the sweep.json tiles into png. The camera never yaws, so a tile is the same picture shifted: exact integer offsets, no blending."""
    from PIL import Image
    import shutil
    from imglib import compare

    Image.MAX_IMAGE_PIXELS = None
    d = json.loads((tiles_dir / "sweep.json").read_text(encoding="utf-8"))
    ppu, sp, tw, th, mx, my = d["ppu"], d["sinp"], d["tile_w"], d["tile_h"], d["crop_x"], d["crop_y"]
    cw, ch = int(-(-d["w"] * ppu // 1)), int(-(-d["h"] * sp * ppu // 1))
    f = 1
    while max_px > 0 and max(cw, ch) // f > max_px:
        f *= 2  # exact box average: every tile piece starts on a multiple of f
    canvas = Image.new("RGB", (-(-cw // f), -(-ch // f)), (10, 10, 10))
    place: dict[tuple[int, int], tuple[int, int, Path]] = {}
    resid = 0.0
    for t in d["tiles"]:
        fx, fy = (t["px"] - d["x0"]) * ppu - t["ux"], (t["pz"] - d["z0"]) * sp * ppu - t["uy"]
        resid = max(resid, abs(fx - round(fx)), abs(fy - round(fy)))
        ox, oy = round(fx), round(fy)
        place[(t["r"], t["c"])] = (ox, oy, tiles_dir / "tiles" / t["file"])
        left, right = (0 if t["c"] == 0 else mx), (tw if t["c"] == d["cols"] - 1 else tw - mx)
        top, bot = (0 if t["r"] == 0 else my), (th if t["r"] == d["rows"] - 1 else th - my)
        with Image.open(tiles_dir / "tiles" / t["file"]) as im:
            piece = im.crop((left, top, right, bot))
            canvas.paste(piece.reduce(f) if f > 1 else piece, ((ox + left) // f, (oy + top) // f))
    # Seam check: the same world pixels as seen from the two tiles either side of each cut (a 32 px band each side).
    means, bad_px = [], 0
    for (r, c), (ox, oy, fa) in place.items():
        for dr, dc in ((0, 1), (1, 0)):
            nb = place.get((r + dr, c + dc))
            if nb is None:
                continue
            x0, y0, x1, y1 = max(ox, nb[0]), max(oy, nb[1]), min(ox, nb[0]) + tw, min(oy, nb[1]) + th
            if dc:
                x0, x1 = max(x0, ox + tw - mx - 32), min(x1, ox + tw - mx + 32)
            else:
                y0, y1 = max(y0, oy + th - my - 32), min(y1, oy + th - my + 32)
            if x1 <= x0 or y1 <= y0:
                continue
            with Image.open(fa) as ia, Image.open(nb[2]) as ib:
                diff = compare.delta_map(ia.convert("RGB").crop((x0 - ox, y0 - oy, x1 - ox, y1 - oy)),
                                         ib.convert("RGB").crop((x0 - nb[0], y0 - nb[1], x1 - nb[0], y1 - nb[1])))
            means.append(float(diff.mean()))
            bad_px += int((diff > 24).sum())
    full = (cw, ch)
    png.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(png, optimize=False, compress_level=6)
    if not keep:
        shutil.rmtree(tiles_dir, ignore_errors=True)
    return {"tiles": len(d["tiles"]), "full": full, "out": canvas.size, "ppu": ppu, "reduce": f, "offset_resid": round(resid, 3),
            "seam_pairs": len(means), "seam_mean_diff": round(sum(means) / max(1, len(means)), 3),
            "seam_worst_pair": round(max(means, default=0.0), 3), "seam_pairs_over_4": sum(m > 4 for m in means), "seam_bad_px": bad_px}


def build_parser() -> argparse.ArgumentParser:
    p = agent_log.std_parser("Capture a play-camera postcard, or run a scripted shot flow (--steps).",
                             writes=True, json_out=True)
    p.add_argument("--mode", choices=("web", "build", "user"), default="user", help="web copies the PNG to the clipboard, user opens it, build does neither and scales down (default user).")
    p.add_argument("--seed", type=int, default=42, help="Dungeon seed (default 42).")
    p.add_argument("--scene", choices=("dungeon", "camp", "hub", *SCREENS), default="dungeon", help="Scene to shoot: dungeon, camp or hub (default dungeon), or a menu screen: title, splash, fs_gate (isolated save).")
    p.add_argument("--floor", type=int, default=1, help="Dungeon floor (default 1).")
    p.add_argument("--scale", type=int, default=0, help="PNG scale percent; 0 picks mode default")
    p.add_argument("--settle-ms", type=int, default=SETTLE_MS, help="Milliseconds to wait before the capture.")
    p.add_argument("--timeout-sec", type=int, default=TIMEOUT_SEC, help="Godot timeout in seconds.")
    p.add_argument("--out", default="", help="PNG path override (with --steps: the last frame)")
    p.add_argument("--show", action="store_true", help="leave the Godot window visible")
    p.add_argument("--hud", type=int, default=-1, help="1=HUD on, 0=HUD off; -1 uses recipe")
    p.add_argument("--width", type=int, default=0, help="window width px (0 keeps the project size)")
    p.add_argument("--height", type=int, default=0, help="window height px (0 keeps the project size)")
    p.add_argument("--zoom", type=float, default=1.0, help="Camera zoom (default 1.0).")
    p.add_argument("--px", default="", help="player world X; empty keeps spawn")
    p.add_argument("--pz", default="", help="player world Z; empty keeps spawn")
    p.add_argument("--cx", type=float, default=0.0, help="camera look offset X")
    p.add_argument("--cz", type=float, default=0.0, help="camera look offset Z")
    p.add_argument("--recipe", default="", help="tools/shot-recipes.json key; empty is the play camera")
    p.add_argument("--steps", default="", help="shot flow JSON (tools/shot-flows/*.json): scripted input, state and shots")
    p.add_argument("--frames-dir", default="", help="with --steps: where numbered frames and flow.json go (default: the PNG dir)")
    p.add_argument("--no-pixels", action="store_true",
                   help="with --steps: headless run, steps and asserts only, no PNGs (works without a display)")
    p.add_argument("--fixed-fps", type=int, default=0, help="engine fixed frame delta (e.g. 60) so animation and AI repeat; 0 = real time. Flow key: fixed_fps.")
    p.add_argument("--full-map", action="store_true", help="photograph the whole dungeon floor in overlapping tiles and stitch one PNG (seed 42 floor 1 unless --seed/--floor) at the real game scale (64 px per cell)")
    p.add_argument("--max-px", type=int, default=8192, help="with --full-map: longest side of the output PNG, 0 = native size (about 27000 px wide on a 432-cell floor); reduced by exact 2x steps")
    p.add_argument("--keep-tiles", action="store_true", help="with --full-map: keep the raw tiles and sweep.json next to the PNG")
    p.add_argument("--taskbar", type=int, default=0, help=argparse.SUPPRESS)
    return p


def setup_full_map(args: argparse.Namespace, root: Path) -> None:
    """--full-map: write the one-op sweep flow and point --steps, --frames-dir and --out at it."""
    args.scene, args.hud, args.no_pixels = "dungeon", 0, False
    args.zoom = 1.0  # the real game scale: lights depend on the distance to the player, so the kept centre of each tile is what play shows
    args.fixed_fps = args.fixed_fps or 60
    args.scale = 100
    out_dir = _out_dir(root)
    stem = f"fullmap-s{max(1, args.seed)}-f{max(1, args.floor)}"
    if not args.out:
        args.out = str(out_dir / (stem + ".png"))
    tiles = Path(args.out).parent / (stem + "-tiles")
    flow = {"name": "full-map", "scene": "dungeon", "seed": max(1, args.seed), "floor": max(1, args.floor), "zoom": args.zoom,
            "hud": 0, "settle_ms": 0, "fixed_fps": args.fixed_fps, "steps": [{"op": "sweep"}]}
    tiles.mkdir(parents=True, exist_ok=True)
    (tiles / "full-map-flow.json").write_text(json.dumps(flow, indent=1), encoding="utf-8")
    args.steps, args.frames_dir = str(tiles / "full-map-flow.json"), str(tiles)
    args.timeout_sec = max(args.timeout_sec, 900)


def capture(args: argparse.Namespace, root: Path, given: set[str] | None = None) -> dict:
    """Run one worker boot and return the result dict (band, png, frames, flow, lines). Writes the summary."""
    given = given or set()
    poses = ""
    if args.full_map:
        setup_full_map(args, root)
    if args.steps:
        steps_path = Path(args.steps)
        if not steps_path.is_file():
            agent_log.fail(f"steps file not found: {args.steps}")
        data = json.loads(steps_path.read_text(encoding="utf-8"))
        if isinstance(data, dict):
            apply_flow_header(args, data, given)
    if args.recipe:
        rec = _load_recipe(root, args.recipe)
        poses = _recipe_poses(rec)
        if rec.get("scene"):
            args.scene = str(rec.get("scene"))
        if "hud" in rec:
            args.hud = 0 if int(rec.get("hud", 1)) == 0 else 1
        if rec.get("zoom") is not None:
            args.zoom = float(rec.get("zoom"))
        for key in ("px", "pz"):
            if rec.get(key) not in (None, ""):
                setattr(args, key, str(rec.get(key)))
    if args.hud < 0:
        args.hud = 1
    out_dir = _out_dir(root)
    scale_pct = max(1, min(100, args.scale if args.scale > 0 else (BUILD_SCALE_PCT if args.mode == "build" else 100)))
    png = Path(args.out) if args.out else (out_dir / f"shot-s{args.seed}-f{args.floor}.png")
    png.parent.mkdir(parents=True, exist_ok=True)
    if args.steps and not args.frames_dir:
        args.frames_dir = str(png.parent)
    if args.frames_dir:
        Path(args.frames_dir).mkdir(parents=True, exist_ok=True)
    godot_args = _godot_args(root, png, args, scale_pct, poses)
    res = {"png": png, "scale": scale_pct, "out_dir": out_dir, "godot_args": godot_args,
           "frames_dir": Path(args.frames_dir) if args.frames_dir else None}
    if args.dry_run:
        res.update(band="dry", status="DRY", lines=[], ok=True)
        return res
    out_log, err_log = run_log_lib.run_path(out_dir, JOB, "out.log"), run_log_lib.run_path(out_dir, JOB, "err.log")
    try:
        run = godot_lib.run_godot(root, root, godot_args, out_log, err_log, max(1, args.timeout_sec),
                                  gui=not args.no_pixels)
    except (FileNotFoundError, godot_lib.GodotBusy) as exc:
        agent_log.fail(str(exc))
    shot_hits = _shot_lines([err_log, out_log])
    err_hits = _error_lines([err_log, out_log])
    shot_ok = any("ok=true" in line for line in shot_hits)
    if args.full_map and shot_ok and (res["frames_dir"] / "sweep.json").is_file():
        st = stitch_full_map(res["frames_dir"], png, args.max_px, args.keep_tiles)
        shot_hits.append("SHOT: stitch " + " ".join(f"{k}={v}" for k, v in st.items()))
    nbytes, width, height = _png_info(png)
    flow = {}
    flow_json = (res["frames_dir"] / "flow.json") if res["frames_dir"] else None
    if args.steps and flow_json is not None and flow_json.is_file():
        flow = json.loads(flow_json.read_text(encoding="utf-8"))
    status = run["status"]
    timed = bool(run["timed_out"])
    if args.no_pixels:
        ok = (not timed) and status == "EXIT=0" and shot_ok and not err_hits
        band = "good" if ok else "fail"
    else:
        ok = (not timed) and status == "EXIT=0" and shot_ok and nbytes > 0 and not err_hits
        band = _band(ok, nbytes, width, height) if ok else "fail"
    res.update(band=band, status=status, wall_ms=run["ms"], timeout=timed, shot_ok=shot_ok, bytes=nbytes,
               w=width, h=height, lines=shot_hits, errors=err_hits, flow=flow, ok=ok)
    return res


def main(argv: list[str] | None = None) -> int:
    p = build_parser()
    argv = list(sys.argv[1:] if argv is None else argv)
    args = p.parse_args(argv)
    given = {a.lstrip("-").replace("-", "_").split("=")[0] for a in argv if a.startswith("--")}
    root = agent_log.resolve_root(args)
    res = capture(args, root, given)
    png = res["png"]
    clip = opened = "n/a"
    if res["band"] not in ("fail", "dry") and not args.no_pixels and not args.steps:
        if args.mode == "web":
            clip = shot_clip_lib.clipboard_png(png)
        elif args.mode == "user":
            opened = shot_clip_lib.open_png(png)
    flow = res.get("flow") or {}
    frames = flow.get("frames") or []
    lines = [
        f"shots {datetime.now(timezone.utc).isoformat()}",
        "root=.",
        f"mode={args.mode} seed={max(1, args.seed)} floor={max(1, args.floor)} scene={args.scene} "
        f"scale={res['scale']} settle_ms={max(0, args.settle_ms)} method={RENDER_METHOD} driver={RENDER_DRIVER}",
        f"status={res['status']} wall_ms={res.get('wall_ms', 0)} timeout={res.get('timeout', False)}",
        f"png={rel(root, png)} bytes={res.get('bytes', 0)} w={res.get('w', 0)} h={res.get('h', 0)}",
        f"clipboard={clip} open={opened} band={res['band']}",
    ]
    if args.steps:
        lines.append(f"steps={args.steps} frames={len(frames)} no_pixels={args.no_pixels} fail={flow.get('fail', '')}")
        lines += [f"  frame {f.get('n')} {f.get('name')} {f.get('file')}" for f in frames]
    lines += ["", "--- command ---" if args.dry_run else "--- SHOT lines ---"]
    if args.dry_run:
        lines.append(" ".join(str(a) for a in res["godot_args"]))
    elif res["lines"]:
        lines.extend(res["lines"])
    else:
        lines.append("(none)")
    lines += ["", "--- errors ---"]
    lines += res.get("errors", [])[:40] or ["(none)"]
    lines.append("")
    status = {"fail": "FAIL", "warn": "INFO"}.get(res["band"], "PASS")
    kv = dict(band=res["band"], shot_ok=str(res.get("shot_ok", False)).lower(), bytes=res.get("bytes", 0), clipboard=clip, open=opened)
    if args.steps:
        kv.update(frames=len(frames), steps=flow.get("steps", 0))
    if args.dry_run:
        kv = {"band": "dry"}
    result = agent_log.write_run_file(root, res["out_dir"], JOB, "\n".join(lines), status, write=not args.dry_run, **kv)
    if args.json:
        agent_log.print_json({"band": res["band"], "status": res["status"], "png": rel(root, png), "frames": frames,
                              "checks": flow.get("checks", []), "fail": flow.get("fail", ""),
                              "summary": result.rsplit("summary=", 1)[-1] if "summary=" in result else ""})
    else:
        sys.stdout.write("\n".join(lines + [result]) + "\n")
    return 0 if res["band"] != "fail" else 1


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
