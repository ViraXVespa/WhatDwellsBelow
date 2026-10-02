#!/usr/bin/env python3
"""Match a keyed source region against a live sprite, and sort local sources.

The scan keys each candidate with a flat chroma mask (not a pixel-by-pixel
read) and looks for a window that agrees with the live image. A hit has to
cover a real area: the live opaque box must be at least --min-side pixels on
its short side, and most of that box has to agree.

  python tools/match_keyed_region.py LIVE SRC
  python tools/match_keyed_region.py LIVE SRC --pipeline
  python tools/match_keyed_region.py --report
  python tools/match_keyed_region.py --organize
  python tools/match_keyed_region.py --fill-missing
  python tools/match_keyed_region.py --fill-missing --what-if

--pipeline runs plate_remap + key_to_alpha on one pair. The library scan uses
the flat mask so it can cover every session still and _src frame.

--organize copies or moves the winning sources into _src/sources, mirroring
the live asset path, and writes _src/manifest.json. Media that matches nothing
goes to _old. Live files under assets/ stay where they are. Isolated-media
cache files are copied, not moved. A source that already passed the gate is
copied to every matching live path, not kept only for the closest live.

--fill-missing reads _src/manifest.json, scores _old plus already placed
_src/sources files against unmatched lives, and copies hits to
_src/sources/<live path>. It never moves _old. --what-if prints that plan.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SESS_ROOT = (
    Path.home()
    / ".grok"
    / "sessions"
    / "C%3A%5CUsers%5CVira%5Csource%5Crepos%5CWhatDwellsBelow"
)
SRC_ROOT = ROOT / "_src"
TOOLS_SRC = ROOT / "tools" / "_src"
OLD_ROOT = ROOT / "_old"
SESSION_MARK = "C%3A%5CUsers%5CVira%5Csource%5Crepos%5CWhatDwellsBelow"

GRID = 32
MAX_SIDE = 192
AGREE_TOL = 28.0
MIN_SIDE = 24
FIGURE_MAD = 22.0
FIGURE_AGREE = 0.70
FIGURE_OVERLAP = 0.88
CELL_MAD = 16.0
CELL_AGREE = 0.86
CROP_MAD = 24.0
CROP_AGREE = 0.85
CROP_OVERLAP = 0.88
GLYPH_MAD = 48.0
GLYPH_AGREE = 0.70
GLYPH_OVERLAP = 0.88
GLYPH_MIN_SIDE = 8
MAG = np.array([255.0, 0.0, 255.0], dtype=np.float32)

IMAGE_EXT = {".png", ".jpg", ".jpeg", ".webp"}
VIDEO_EXT = {".mp4"}
CELL_NAMES = (
    "cell_up_left",
    "cell_up",
    "cell_up_right",
    "cell_left",
    "cell_face",
    "cell_right",
    "cell_down_left",
    "cell_down",
    "cell_down_right",
)
FIGURE_BASES = {"full", "center", "mid"}
OLD_SKIP = {"sidecars", "src_notes"}


def _posix(path: Path) -> str:
    try:
        rel = path.resolve().relative_to(ROOT.resolve())
        return rel.as_posix()
    except ValueError:
        return path.resolve().as_posix()


def _under(path: Path, root: Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except ValueError:
        return False


def is_glyph(live: str) -> bool:
    text = live.replace("\\", "/")
    return text.startswith("assets/ui/prompts/") or "/ui/prompts/" in text


def is_player(live: str) -> bool:
    text = live.replace("\\", "/")
    return text.startswith("assets/sprites/player/") or "/sprites/player/" in text


def load_rgba(path: Path, max_side: int = MAX_SIDE) -> tuple[np.ndarray, int, int]:
    """Return a capped RGBA array, opaque short side, and opaque pixel count."""
    im = Image.open(path)
    im.load()
    im = im.convert("RGBA")
    full = np.asarray(im)
    side = opaque_side(full)
    pixels = int((full[:, :, 3] >= 16).sum())
    w, h = im.size
    m = max(w, h)
    if m > max_side:
        scale = max_side / m
        im = im.resize(
            (max(1, int(round(w * scale))), max(1, int(round(h * scale)))),
            Image.Resampling.BOX,
        )
        full = np.asarray(im)
    return full, side, pixels


def looks_finished_sprite(path: Path) -> bool:
    """Small transparent outputs are already keyed sprites, not remap inputs."""
    name = path.name.lower()
    if "_probe" in name or name.endswith("_key.png"):
        return True
    parts = {p.lower() for p in path.parts}
    if "_probe" in parts:
        return True
    try:
        im = Image.open(path)
        w, h = im.size
        if max(w, h) > 320 or im.mode != "RGBA":
            im.close()
            return False
        alpha = np.asarray(im.getchannel("A"))
        im.close()
    except OSError:
        return False
    return float((alpha < 16).mean()) > 0.12


def key_flat(arr: np.ndarray) -> np.ndarray:
    """Knock out an existing matte, near-magenta, and a flat border plate."""
    rgb = arr[:, :, :3].astype(np.float32)
    alpha = arr[:, :, 3]
    border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]], axis=0)
    med = np.median(border, axis=0)
    std = float(border.std(axis=0).mean())
    dist_mag = np.sqrt(((rgb - MAG) ** 2).sum(axis=-1))
    dist_med = np.sqrt(((rgb - med) ** 2).sum(axis=-1))
    med_mag = float(np.sqrt(((med - MAG) ** 2).sum()))
    flat = std < 18.0 and (med_mag < 90.0 or float(med.max()) > 200.0 or float(med.min()) < 30.0)
    plate = alpha < 16
    plate |= dist_mag <= 70.0
    if flat:
        plate |= dist_med <= 42.0
    out = arr.copy()
    out[plate, 3] = 0
    return out


def key_pipeline(path: Path) -> np.ndarray:
    sys.path.insert(0, str(ROOT / "tools"))
    import plate_remap as pr  # noqa: E402
    import sprite_pipeline as sp  # noqa: E402

    im = Image.open(path).convert("RGBA")
    remapped, _vis, _info = pr.remap(im)
    keyed = sp.key_to_alpha(remapped, spill_flood=False)
    w, h = keyed.size
    m = max(w, h)
    if m > MAX_SIDE:
        scale = MAX_SIDE / m
        keyed = keyed.resize(
            (max(1, int(round(w * scale))), max(1, int(round(h * scale)))),
            Image.Resampling.BOX,
        )
    return np.asarray(keyed)


def opaque_crop(arr: np.ndarray) -> np.ndarray:
    mask = arr[:, :, 3] >= 16
    ys, xs = np.where(mask)
    if xs.size == 0:
        return arr[:1, :1]
    return arr[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]


def opaque_side(arr: np.ndarray) -> int:
    mask = arr[:, :, 3] >= 16
    ys, xs = np.where(mask)
    if xs.size == 0:
        return 0
    return int(min(xs.max() - xs.min() + 1, ys.max() - ys.min() + 1))


def to_grid(arr: np.ndarray, side: int = GRID) -> tuple[np.ndarray, np.ndarray]:
    if arr.size == 0 or arr.shape[0] < 1 or arr.shape[1] < 1:
        rgb = np.zeros((side, side, 3), dtype=np.float32)
        mask = np.zeros((side, side), dtype=bool)
        return rgb, mask
    im = Image.fromarray(arr, "RGBA").resize((side, side), Image.Resampling.BOX)
    grid = np.asarray(im)
    return grid[:, :, :3].astype(np.float32), grid[:, :, 3] >= 16


def inner_crop(arr: np.ndarray, frac: float = 0.72) -> np.ndarray:
    h, w = arr.shape[:2]
    margin = (1.0 - frac) / 2.0
    x0, y0 = int(w * margin), int(h * margin)
    x1, y1 = max(x0 + 1, int(w * (1.0 - margin))), max(y0 + 1, int(h * (1.0 - margin)))
    return arr[y0:y1, x0:x1]


def _windows(arr: np.ndarray) -> list[tuple[str, np.ndarray]]:
    h, w = arr.shape[:2]
    specs: list[tuple[str, np.ndarray]] = [("full", arr)]
    boxes = {
        "center": (0.15, 0.15, 0.85, 0.85),
        "mid": (0.25, 0.25, 0.75, 0.75),
        "tl": (0.0, 0.0, 0.5, 0.5),
        "tr": (0.5, 0.0, 1.0, 0.5),
        "bl": (0.0, 0.5, 0.5, 1.0),
        "br": (0.5, 0.5, 1.0, 1.0),
    }
    for name, (x0, y0, x1, y1) in boxes.items():
        xa, ya = int(w * x0), int(h * y0)
        xb, yb = max(xa + 1, int(w * x1)), max(ya + 1, int(h * y1))
        specs.append((name, arr[ya:yb, xa:xb]))
    if min(h, w) >= 96 and abs(w - h) / max(w, h) < 0.08:
        cw, ch = w // 3, h // 3
        if cw >= 8 and ch >= 8:
            for i, name in enumerate(CELL_NAMES):
                row, col = divmod(i, 3)
                specs.append((name, arr[row * ch : (row + 1) * ch, col * cw : (col + 1) * cw]))
    return specs


def candidate_grids(arr: np.ndarray) -> list[tuple[str, np.ndarray, np.ndarray, str]]:
    keyed = key_flat(arr)
    opaque = float((keyed[:, :, 3] >= 16).mean())
    windows = _windows(keyed)
    # A character on a plate only needs the whole figure and sheet cells.
    # Quadrant search is for full-bleed tiles and prompt stills.
    if opaque < 0.45:
        windows = [item for item in windows if item[0] == "full" or item[0].startswith("cell_")]
    return _grids_from_parts(windows)


def score_batch(
    live_rgb: np.ndarray,
    live_mask: np.ndarray,
    src_rgb: np.ndarray,
    src_mask: np.ndarray,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    both = live_mask & src_mask
    count = both.sum(axis=(1, 2)).astype(np.float32)
    live_n = live_mask.sum(axis=(1, 2)).astype(np.float32)
    diff = np.abs(live_rgb - src_rgb).sum(axis=-1) / 3.0
    mad = (diff * both).sum(axis=(1, 2)) / np.maximum(count, 1.0)
    agree = ((diff <= AGREE_TOL) & both).sum(axis=(1, 2)).astype(np.float32) / np.maximum(live_n, 1.0)
    overlap = count / np.maximum(live_n, 1.0)
    mad = np.where(count > 0, mad, 999.0)
    return mad, agree, overlap


def area_ok(agree: float, pixels: int, agree_min: float, min_side: int = MIN_SIDE) -> bool:
    """Agreeing area must cover min_side squared, or most of a small sprite."""
    if agree < agree_min:
        return False
    floor = min_side * min_side
    if pixels >= floor:
        return agree * pixels >= float(floor)
    small_floor = 40 if min_side < MIN_SIDE else 160
    return pixels >= small_floor


def loose_windows_ok(live: str) -> bool:
    text = live.replace("\\", "/")
    return "/tiles/" in text or "/ui/" in text


def accept_score(
    kind: str,
    window: str,
    mad: float,
    agree: float,
    overlap: float,
    pixels: int,
    live: str,
) -> bool:
    base = window.split("/")[0]
    # generated prompt glyphs are not match sources
    if is_glyph(live):
        return False
    if base.startswith("cell_"):
        if not (is_player(live) or loose_windows_ok(live)):
            return False
        if not area_ok(agree, pixels, CELL_AGREE):
            return False
        return mad <= CELL_MAD and agree >= CELL_AGREE and overlap >= FIGURE_OVERLAP
    if kind == "crop":
        if not area_ok(agree, pixels, CROP_AGREE):
            return False
        return loose_windows_ok(live) and mad <= CROP_MAD and agree >= CROP_AGREE and overlap >= CROP_OVERLAP
    if not area_ok(agree, pixels, FIGURE_AGREE):
        return False
    if base != "full" and not loose_windows_ok(live):
        return False
    return mad <= FIGURE_MAD and agree >= FIGURE_AGREE and overlap >= FIGURE_OVERLAP


def _grids_from_keyed(arr: np.ndarray) -> list[tuple[str, np.ndarray, np.ndarray, str]]:
    return _grids_from_parts(_windows(arr))


def _grids_from_parts(parts: list[tuple[str, np.ndarray]]) -> list[tuple[str, np.ndarray, np.ndarray, str]]:
    out: list[tuple[str, np.ndarray, np.ndarray, str]] = []
    for name, crop in parts:
        kind = "figure" if name in FIGURE_BASES or name.startswith("cell_") else "crop"
        rgb, mask = to_grid(opaque_crop(crop) if kind == "figure" else crop)
        if int(mask.sum()) < 16:
            continue
        out.append((name, rgb, mask, kind))
        out.append((name + "/flip", np.flip(rgb, axis=1).copy(), np.flip(mask, axis=1).copy(), kind))
    return out


def score_pair(live: Path, src: Path, pipeline: bool = False) -> dict:
    live_arr, side, pixels = load_rgba(live, 160)
    figure = opaque_crop(live_arr)
    fig_rgb, fig_mask = to_grid(figure)
    inn_rgb, inn_mask = to_grid(opaque_crop(inner_crop(figure)))
    if pipeline:
        grids = _grids_from_keyed(key_pipeline(src))
    else:
        grids = candidate_grids(load_rgba(src)[0])
    best: dict | None = None
    for name, rgb, mask, kind in grids:
        use_rgb, use_mask = (inn_rgb, inn_mask) if kind == "crop" else (fig_rgb, fig_mask)
        mad_a, agree_a, overlap_a = score_batch(use_rgb[None], use_mask[None], rgb, mask)
        row = {
            "mad": round(float(mad_a[0]), 2),
            "agree": round(float(agree_a[0]), 3),
            "overlap": round(float(overlap_a[0]), 3),
            "window": name,
            "flip": name.endswith("/flip"),
            "kind": kind,
            "opaque_side": side,
            "opaque_pixels": pixels,
            "accept": accept_score(
                kind,
                name,
                float(mad_a[0]),
                float(agree_a[0]),
                float(overlap_a[0]),
                pixels,
                str(live),
            ),
        }
        if best is None or row["mad"] < best["mad"]:
            best = row
    return best or {"mad": 999.0, "agree": 0.0, "overlap": 0.0, "window": "", "accept": False, "opaque_side": side}


def _iso_roots() -> list[Path]:
    roots: list[Path] = []
    sessions = Path.home() / ".grok" / "sessions"
    if sessions.is_dir():
        for child in sessions.iterdir():
            if "wdb-iso" in child.name.lower():
                roots.append(child)
    temp = Path(os.environ.get("TEMP", ""))
    if temp.is_dir():
        for child in temp.iterdir():
            if child.is_dir() and child.name.lower().startswith("wdb-iso"):
                roots.append(child)
    return roots


def _is_copy_only(path: Path) -> bool:
    text = str(path).lower()
    if "wdb-iso" in text or _under(path, OLD_ROOT):
        return True
    try:
        path.resolve().relative_to((ROOT / "assets").resolve())
        return True
    except ValueError:
        return False


def _skip_old_meta(path: Path) -> bool:
    if not _under(path, OLD_ROOT):
        return False
    rel = path.resolve().relative_to(OLD_ROOT.resolve())
    return bool(rel.parts) and rel.parts[0] in OLD_SKIP


def iter_files(root: Path, exts: set[str]) -> list[Path]:
    if not root.exists():
        return []
    found: list[Path] = []
    for path in root.rglob("*"):
        if path.is_file() and path.suffix.lower() in exts and not _skip_old_meta(path):
            found.append(path)
    return found


def collect_inputs() -> tuple[list[Path], list[Path]]:
    images: list[Path] = []
    videos: list[Path] = []
    roots = [SRC_ROOT, TOOLS_SRC, OLD_ROOT, SESS_ROOT, *(_iso_roots())]
    sheets = [
        ROOT / "assets" / "sprites" / "player" / "bible_locked_male.png",
        ROOT / "assets" / "sprites" / "player" / "bible_locked_female.png",
        ROOT / "assets" / "sprites" / "player" / "gdd_reference_bible.jpg",
    ]
    seen: set[Path] = set()
    for root in roots:
        for path in iter_files(root, IMAGE_EXT | VIDEO_EXT):
            key = path.resolve()
            if key in seen:
                continue
            seen.add(key)
            if path.suffix.lower() in VIDEO_EXT:
                videos.append(path)
            else:
                images.append(path)
    for sheet in sheets:
        if sheet.is_file() and sheet.resolve() not in seen:
            images.append(sheet)
    return images, videos


def collect_lives() -> list[Path]:
    lives: list[Path] = []
    assets = ROOT / "assets"
    for path in iter_files(assets, IMAGE_EXT):
        if path.name.endswith(".import"):
            continue
        rel = path.resolve().relative_to(ROOT.resolve()).as_posix()
        if is_glyph(rel):
            continue
        lives.append(path)
    return lives


def _window_rank(window: str) -> tuple[int, int]:
    flip = 1 if window.endswith("/flip") else 0
    base = window.split("/")[0]
    if base == "full":
        rank = 0
    elif base == "center":
        rank = 1
    elif base == "mid":
        rank = 2
    elif base.startswith("cell_"):
        rank = 3
    else:
        rank = 4
    return rank, flip


def _better(new: dict, old: dict) -> bool:
    if new["mad"] + 1.5 < old["mad"]:
        return True
    if old["mad"] + 1.5 < new["mad"]:
        return False
    return _window_rank(new["window"]) < _window_rank(old["window"])


def _origin_rank(path: Path) -> int:
    text = str(path)
    if "wdb-iso" in text.lower():
        return 3
    if _under(path, OLD_ROOT):
        return 0
    try:
        path.resolve().relative_to(TOOLS_SRC.resolve())
        return 2
    except ValueError:
        pass
    try:
        path.resolve().relative_to((ROOT / "assets").resolve())
        return 1
    except ValueError:
        return 0


def prepare_lives(paths: list[Path]) -> dict:
    rels: list[str] = []
    fig_rgb = []
    fig_mask = []
    inn_rgb = []
    inn_mask = []
    sides = []
    pix = []
    crop_ok = []
    glyph = []
    player = []
    for path in paths:
        arr, side, pixels = load_rgba(path, 160)
        figure = opaque_crop(arr)
        rgb, mask = to_grid(figure)
        irgb, imask = to_grid(opaque_crop(inner_crop(figure)))
        rel = path.resolve().relative_to(ROOT.resolve()).as_posix()
        rels.append(rel)
        fig_rgb.append(rgb)
        fig_mask.append(mask)
        inn_rgb.append(irgb)
        inn_mask.append(imask)
        sides.append(side)
        pix.append(pixels)
        crop_ok.append(rel.startswith("assets/tiles/") or rel.startswith("assets/ui/"))
        glyph.append(is_glyph(rel))
        player.append(is_player(rel))
    return {
        "paths": paths,
        "rels": rels,
        "fig_rgb": np.stack(fig_rgb),
        "fig_mask": np.stack(fig_mask),
        "inn_rgb": np.stack(inn_rgb),
        "inn_mask": np.stack(inn_mask),
        "sides": np.asarray(sides, dtype=np.int32),
        "pixels": np.asarray(pix, dtype=np.int32),
        "crop_ok": np.asarray(crop_ok, dtype=bool),
        "glyph": np.asarray(glyph, dtype=bool),
        "player": np.asarray(player, dtype=bool),
    }


def scan_with_near(images: list[Path], lives: dict) -> tuple[list[dict | None], list[dict | None]]:
    count = len(lives["rels"])
    best: list[dict | None] = [None] * count
    near_mad = np.full(count, 999.0, dtype=np.float32)
    near_agree = np.zeros(count, dtype=np.float32)
    near_overlap = np.zeros(count, dtype=np.float32)
    near_origin = np.full(count, -1, dtype=np.int32)
    near_window = [""] * count
    near_kind = [""] * count
    n = len(images)
    for index, path in enumerate(images):
        if index % 400 == 0:
            print(f"scored {index}/{n}", flush=True)
        recoverable = _under(path, OLD_ROOT) or _under(path, SRC_ROOT / "sources")
        if looks_finished_sprite(path) and not recoverable:
            continue
        try:
            arr, _side, _pixels = load_rgba(path)
            grids = candidate_grids(arr)
        except OSError as exc:
            print(f"skip {path}: {exc}", flush=True)
            continue
        rank = _origin_rank(path)
        for name, rgb, mask, kind in grids:
            base = name.split("/")[0]
            if kind == "crop":
                mad, agree, overlap = score_batch(lives["inn_rgb"], lives["inn_mask"], rgb, mask)
                mad_max = np.where(lives["glyph"], GLYPH_MAD, CROP_MAD)
                agree_min = np.where(lives["glyph"], GLYPH_AGREE, CROP_AGREE)
                overlap_min = np.where(lives["glyph"], GLYPH_OVERLAP, CROP_OVERLAP)
                allowed = lives["crop_ok"] | lives["glyph"]
            elif base.startswith("cell_"):
                mad, agree, overlap = score_batch(lives["fig_rgb"], lives["fig_mask"], rgb, mask)
                mad_max = np.where(lives["glyph"], GLYPH_MAD, CELL_MAD)
                agree_min = np.where(lives["glyph"], GLYPH_AGREE, CELL_AGREE)
                overlap_min = np.where(lives["glyph"], GLYPH_OVERLAP, FIGURE_OVERLAP)
                allowed = lives["player"] | lives["crop_ok"] | lives["glyph"]
            else:
                mad, agree, overlap = score_batch(lives["fig_rgb"], lives["fig_mask"], rgb, mask)
                mad_max = np.where(lives["glyph"], GLYPH_MAD, FIGURE_MAD)
                agree_min = np.where(lives["glyph"], GLYPH_AGREE, FIGURE_AGREE)
                overlap_min = np.where(lives["glyph"], GLYPH_OVERLAP, FIGURE_OVERLAP)
                allowed = np.ones(count, dtype=bool)
            closer = mad < near_mad
            if closer.any():
                near_mad[closer] = mad[closer]
                near_agree[closer] = agree[closer]
                near_overlap[closer] = overlap[closer]
                near_origin[closer] = index
                for hit in np.flatnonzero(closer):
                    near_window[hit] = name
                    near_kind[hit] = kind
            rough = allowed & (mad <= mad_max) & (agree >= agree_min) & (overlap >= overlap_min)
            for hit in np.flatnonzero(rough):
                if not accept_score(
                    kind,
                    name,
                    float(mad[hit]),
                    float(agree[hit]),
                    float(overlap[hit]),
                    int(lives["pixels"][hit]),
                    lives["rels"][hit],
                ):
                    continue
                row = {
                    "mad": float(mad[hit]),
                    "agree": float(agree[hit]),
                    "overlap": float(overlap[hit]),
                    "window": name,
                    "kind": kind,
                    "origin": path,
                    "rank": rank,
                }
                current = best[hit]
                take = current is None or _better(row, current)
                if not take and current is not None and abs(row["mad"] - current["mad"]) <= 1.5:
                    take = rank < current["rank"] and _window_rank(name) <= _window_rank(current["window"])
                if take:
                    best[hit] = row
    near: list[dict | None] = [None] * count
    for hit in np.flatnonzero(near_origin >= 0):
        origin_index = int(near_origin[hit])
        near[hit] = {
            "mad": float(near_mad[hit]),
            "agree": float(agree[hit]),
            "overlap": float(overlap[hit]),
            "window": near_window[hit],
            "kind": near_kind[hit],
            "origin": images[origin_index],
            "rank": _origin_rank(images[origin_index]),
        }
    print(f"scored {n}/{n}", flush=True)
    return best, near


def related_videos(origins: list[Path], videos: list[Path]) -> list[Path]:
    harvest_dirs: set[str] = set()
    oneshot_keys: set[str] = set()
    for origin in origins:
        parts = origin.parts
        if "walk_harvest" in parts:
            i = parts.index("walk_harvest")
            if i + 1 < len(parts):
                harvest_dirs.add(parts[i + 1])
        if "oneshot_harvest" in parts:
            i = parts.index("oneshot_harvest")
            rest = parts[i + 1 : -1]
            if len(rest) >= 3:
                oneshot_keys.add("_".join(rest[:3]))
    kept: list[Path] = []
    seen: set[Path] = set()
    for video in videos:
        key = video.resolve()
        if key in seen:
            continue
        take = False
        if video.parent.name == "walk_final" and video.stem in harvest_dirs:
            take = True
        elif video.parent.name == "oneshot" and video.stem in oneshot_keys:
            take = True
        if take:
            seen.add(key)
            kept.append(video)
    return kept


def _primary(rows: list[dict]) -> dict:
    def sort_key(row: dict) -> tuple:
        return (row["flip"], row["mad"], len(row["live"]), row["live"])

    return sorted(rows, key=sort_key)[0]


def _dest_for(origin: Path, live: str) -> str:
    return (Path("sources") / Path(live).with_suffix(origin.suffix)).as_posix()


def build_plan(lives: dict, best: list[dict | None], near: list[dict | None], videos: list[Path]) -> dict:
    by_origin: dict[Path, list[dict]] = {}
    unmatched = []
    for i, rel in enumerate(lives["rels"]):
        row = best[i]
        if row is None:
            miss = near[i]
            item = {"live": rel, "opaque_side": int(lives["sides"][i])}
            if miss is not None:
                item.update(
                    {
                        "best_mad": round(miss["mad"], 2),
                        "best_agree": round(miss["agree"], 3),
                        "best_window": miss["window"],
                        "best_origin": _posix(miss["origin"]),
                    }
                )
            unmatched.append(item)
            continue
        entry = {
            "live": rel,
            "mad": round(row["mad"], 2),
            "agree": round(row["agree"], 3),
            "overlap": round(row["overlap"], 3),
            "window": row["window"],
            "flip": row["window"].endswith("/flip"),
            "kind": row["kind"],
            "loose": row["mad"] > 18.0,
            "opaque_side": int(lives["sides"][i]),
            "origin_path": row["origin"],
        }
        by_origin.setdefault(row["origin"].resolve(), []).append(entry)

    sources = []
    for origin, rows in by_origin.items():
        # Every row already passed accept_score. Fan out; do not drop a live
        # because the same still matches another asset more closely.
        copy = _is_copy_only(origin) or len(rows) > 1
        for row in rows:
            base = row["window"].split("/")[0]
            cell = base[len("cell_") :] if base.startswith("cell_") else ""
            sources.append(
                {
                    "origin": origin,
                    "dest": _dest_for(origin, row["live"]),
                    "copy": copy,
                    "cell": cell,
                    "lives": [row],
                }
            )

    video_paths = related_videos([item["origin"] for item in sources], videos)
    video_plan = []
    for video in video_paths:
        try:
            rel = video.resolve().relative_to(SRC_ROOT.resolve())
            dest = Path("sources") / "clips" / rel
        except ValueError:
            dest = Path("sources") / "clips" / "other" / video.name
        video_plan.append({"origin": video, "dest": dest.as_posix(), "copy": _is_copy_only(video)})

    return {"sources": sources, "videos": video_plan, "unmatched": unmatched}


def archive_candidates(origin: str) -> list[Path]:
    """Paths where a moved non-match, or an already-archived origin, can sit."""
    text = origin.replace("\\", "/")
    out: list[Path] = []
    if not text:
        return out
    if text.startswith("_old/"):
        out.append(ROOT / text)
    if text.startswith("_src/"):
        out.append(OLD_ROOT / "src" / text[len("_src/") :])
        out.append(SRC_ROOT / text[len("_src/") :])
    if text.startswith("tools/_src/"):
        out.append(OLD_ROOT / "tools_src" / text[len("tools/_src/") :])
    if SESSION_MARK in text:
        rest = text.split(SESSION_MARK, 1)[1].lstrip("/")
        out.append(OLD_ROOT / "sessions" / rest)
    try:
        sess = SESS_ROOT.as_posix()
        if text.startswith(sess):
            out.append(OLD_ROOT / "sessions" / text[len(sess) :].lstrip("/"))
    except ValueError:
        pass
    name = Path(text).name
    if name:
        out.append(OLD_ROOT / "other" / name)
    return out


def resolve_origin(origin: str) -> Path | None:
    for cand in archive_candidates(origin):
        if cand.is_file():
            return cand
    return None


def archived_posix(origin: str) -> str | None:
    """Where a moved non-match landed under _old, if it is still there."""
    found = resolve_origin(origin)
    if found is None or not _under(found, OLD_ROOT):
        return None
    return found.resolve().relative_to(ROOT.resolve()).as_posix()


def _archive_rel(path: Path) -> Path:
    resolved = path.resolve()
    for root, bucket in (
        (SRC_ROOT, "src"),
        (TOOLS_SRC, "tools_src"),
        (SESS_ROOT, "sessions"),
    ):
        try:
            return Path(bucket) / resolved.relative_to(root.resolve())
        except ValueError:
            continue
    return Path("other") / path.name


def _move_file(src: Path, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists():
        raise SystemExit(f"refusing to overwrite {dest}")
    shutil.move(str(src), str(dest))


def _copy_file(src: Path, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists():
        raise SystemExit(f"refusing to overwrite {dest}")
    shutil.copy2(src, dest)


def _sidecar(path: Path) -> Path | None:
    side = Path(str(path) + ".import")
    if side.is_file():
        return side
    return None


def _manifest_entries(plan: dict) -> list[dict]:
    entries = []
    for item in plan["sources"]:
        for live in item["lives"]:
            base = live["window"].split("/")[0]
            entries.append(
                {
                    "live": live["live"],
                    "source": item["dest"],
                    "origin": _posix(item["origin"]),
                    "mad": live["mad"],
                    "agree": live["agree"],
                    "overlap": live["overlap"],
                    "flip": live["flip"],
                    "window": live["window"],
                    "kind": live["kind"],
                    "loose": live["loose"],
                    "opaque_side": live["opaque_side"],
                    "cell": base[len("cell_") :] if base.startswith("cell_") else "",
                }
            )
    return entries


def organize(plan: dict) -> dict:
    kept_images = {item["origin"].resolve() for item in plan["sources"]}
    kept_videos = {item["origin"].resolve() for item in plan["videos"]}
    placed: dict[Path, str] = {}

    for item in plan["sources"]:
        dest = SRC_ROOT / item["dest"]
        origin = item["origin"]
        if origin.resolve() == dest.resolve():
            placed[origin.resolve()] = item["dest"]
            continue
        if item["copy"] or dest.exists():
            if not dest.exists():
                _copy_file(origin, dest)
        else:
            _move_file(origin, dest)
            side = _sidecar(origin)
            if side is not None:
                _move_file(side, OLD_ROOT / "sidecars" / side.name)
        placed[origin.resolve()] = item["dest"]

    for item in plan["videos"]:
        dest = SRC_ROOT / item["dest"]
        origin = item["origin"]
        if origin.resolve() == dest.resolve():
            continue
        if item["copy"]:
            if not dest.exists():
                _copy_file(origin, dest)
        else:
            _move_file(origin, dest)

    archived = 0
    for root in (SRC_ROOT, TOOLS_SRC, SESS_ROOT):
        for path in list(iter_files(root, IMAGE_EXT | VIDEO_EXT)):
            resolved = path.resolve()
            if resolved in placed or resolved in kept_images or resolved in kept_videos:
                continue
            if _under(path, SRC_ROOT / "sources"):
                continue
            dest = OLD_ROOT / _archive_rel(path)
            if dest.exists():
                dest = dest.with_name(dest.stem + "_dup" + dest.suffix)
            _move_file(path, dest)
            side = _sidecar(path)
            if side is not None and side.is_file():
                _move_file(side, OLD_ROOT / "sidecars" / side.name)
            archived += 1

    notes = 0
    if SRC_ROOT.is_dir():
        for path in list(SRC_ROOT.rglob("*")):
            if not path.is_file():
                continue
            rel = path.relative_to(SRC_ROOT)
            if not rel.parts or rel.parts[0] == "sources":
                continue
            if path.name in {".gdignore", "manifest.json"}:
                continue
            if path.suffix.lower() in IMAGE_EXT | VIDEO_EXT:
                continue
            _move_file(path, OLD_ROOT / "src_notes" / rel)
            notes += 1
        for path in sorted(SRC_ROOT.rglob("*"), reverse=True):
            if path.is_dir() and path != SRC_ROOT and not any(path.iterdir()):
                path.rmdir()
    if TOOLS_SRC.is_dir():
        for path in sorted(TOOLS_SRC.rglob("*"), reverse=True):
            if path.is_dir() and not any(path.iterdir()):
                path.rmdir()

    entries = _manifest_entries(plan)
    manifest = {
        "min_side": MIN_SIDE,
        "grid": GRID,
        "agree_tol": AGREE_TOL,
        "figure": {"mad": FIGURE_MAD, "agree": FIGURE_AGREE, "overlap": FIGURE_OVERLAP},
        "crop": {"mad": CROP_MAD, "agree": CROP_AGREE, "overlap": CROP_OVERLAP},
        "glyph": {"mad": GLYPH_MAD, "agree": GLYPH_AGREE, "overlap": GLYPH_OVERLAP},
        "entries": entries,
        "videos": [{"source": item["dest"], "origin": _posix(item["origin"])} for item in plan["videos"]],
        "unmatched_live": [
            item | ({"archived": archived} if (archived := archived_posix(str(item.get("best_origin", "")))) else {})
            for item in plan["unmatched"]
        ],
    }
    (SRC_ROOT / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    gdignore = SRC_ROOT / ".gdignore"
    if not gdignore.exists():
        gdignore.write_text("", encoding="utf-8")
    return {"archived": archived, "notes": notes, "entries": len(entries)}



def live_stem(rel: str) -> str:
    return Path(rel).stem.lower()


def placed_by_stem(stem: str) -> list[Path]:
    root = SRC_ROOT / "sources"
    if not root.is_dir():
        return []
    found: list[Path] = []
    for path in root.rglob("*"):
        if path.is_file() and path.suffix.lower() in IMAGE_EXT and path.stem.lower() == stem:
            found.append(path)
    return found


def candidates_for_unmatched(item: dict) -> list[Path]:
    """Archived _old file for this live, plus a placed source with the same stem."""
    found: list[Path] = []
    seen: set[Path] = set()

    def add(path: Path | None) -> None:
        if path is None or not path.is_file():
            return
        key = path.resolve()
        if key in seen:
            return
        seen.add(key)
        found.append(path)

    archived = str(item.get("archived") or "")
    if archived:
        add(ROOT / archived)
    origin = str(item.get("best_origin") or "")
    resolved = resolve_origin(origin)
    if resolved is not None and _under(resolved, OLD_ROOT):
        add(resolved)
    for path in placed_by_stem(live_stem(str(item.get("live", "")))):
        add(path)
    return found


def _fill_entry(live: str, origin: Path, dest: str, row: dict, opaque_side: int) -> dict:
    base = str(row.get("window", "")).split("/")[0]
    return {
        "live": live,
        "source": dest,
        "origin": _posix(origin),
        "mad": row["mad"],
        "agree": row["agree"],
        "overlap": row["overlap"],
        "flip": row["flip"],
        "window": row["window"],
        "kind": row["kind"],
        "loose": row["mad"] > 18.0,
        "opaque_side": opaque_side,
        "cell": base[len("cell_") :] if base.startswith("cell_") else "",
    }


def fill_missing(what_if: bool) -> dict:
    """Copy this live's archived _old file, or a same-stem placed source. Never move."""
    manifest_path = SRC_ROOT / "manifest.json"
    if not manifest_path.is_file():
        print("no manifest, nothing to fill")
        return {"filled": 0, "unmatched": 0}
    data = json.loads(manifest_path.read_text(encoding="utf-8"))
    known = {entry["live"] for entry in data.get("entries", [])}
    pending = [
        item for item in data.get("unmatched_live", [])
        if item.get("live") not in known and not is_glyph(str(item.get("live", "")))
    ]
    new_entries: list[dict] = []
    still: list[dict] = []
    filled_rels: set[str] = set()
    for item in pending:
        rel = str(item["live"])
        live_path = ROOT / rel
        if not live_path.is_file():
            print(f"missing live {rel}")
            still.append(item)
            continue
        cands = candidates_for_unmatched(item)
        best: dict | None = None
        best_path: Path | None = None
        for cand in cands:
            row = score_pair(live_path, cand, pipeline=False)
            if not row.get("accept"):
                continue
            dest = SRC_ROOT / _dest_for(cand, rel)
            if dest.resolve() == cand.resolve():
                continue
            if best is None or float(row["mad"]) < float(best["mad"]):
                best = row
                best_path = cand
        if best is None or best_path is None:
            origin = str(item.get("best_origin", ""))
            archived = archived_posix(origin)
            if archived:
                item = item | {"archived": archived}
            still.append(item)
            continue
        dest_rel = _dest_for(best_path, rel)
        dest = SRC_ROOT / dest_rel
        filled_rels.add(rel)
        new_entries.append(_fill_entry(rel, best_path, dest_rel, best, int(item.get("opaque_side", 0))))
        if what_if:
            print(
                f"would copy {_posix(best_path)} -> {dest_rel} {rel} "
                f"mad={best['mad']} agree={best['agree']}"
            )
            continue
        if dest.exists():
            print(f"keep {dest_rel}")
            continue
        _copy_file(best_path, dest)
        print(f"copied {_posix(best_path)} -> {dest_rel}")
    if not what_if:
        data.setdefault("glyph", {"mad": GLYPH_MAD, "agree": GLYPH_AGREE, "overlap": GLYPH_OVERLAP})
        data.setdefault("entries", []).extend(new_entries)
        data["unmatched_live"] = still
        manifest_path.write_text(json.dumps(data, indent=2), encoding="utf-8")
    print(f"fill {'plan' if what_if else 'wrote'} {len(filled_rels)} left {len(still)}")
    return {"filled": len(filled_rels), "unmatched": len(still)}


def summarize(plan: dict) -> str:
    lines = []
    matched = sum(len(item["lives"]) for item in plan["sources"])
    loose = sum(1 for item in plan["sources"] for live in item["lives"] if live["loose"])
    lines.append(f"matched_lives {matched}")
    lines.append(f"source_files {len(plan['sources'])}")
    lines.append(f"videos {len(plan['videos'])}")
    lines.append(f"unmatched_lives {len(plan['unmatched'])}")
    lines.append(f"loose {loose}")
    folders: dict[str, int] = {}
    for item in plan["unmatched"]:
        parts = item["live"].split("/")
        key = "/".join(parts[:3]) if len(parts) >= 3 else item["live"]
        folders[key] = folders.get(key, 0) + 1
    lines.append("unmatched_folders")
    for key, count in sorted(folders.items(), key=lambda kv: (-kv[1], kv[0])):
        lines.append(f"  {count} {key}")
    lines.append("loose_samples")
    shown = 0
    for item in plan["sources"]:
        for live in item["lives"]:
            if not live["loose"]:
                continue
            lines.append(f"  {live['mad']} {live['live']} <= {_posix(item['origin'])} {live['window']}")
            shown += 1
            if shown >= 25:
                break
        if shown >= 25:
            break
    return "\n".join(lines)


def self_test() -> None:
    axe = ROOT / "assets" / "ui" / "gear" / "head.png"
    src = SRC_ROOT / "gear" / "head.jpg"
    manifest = SRC_ROOT / "manifest.json"
    if not src.is_file() and manifest.is_file():
        data = json.loads(manifest.read_text(encoding="utf-8"))
        for entry in data["entries"]:
            if entry["live"].endswith("ui/gear/head.png"):
                src = SRC_ROOT / entry["source"]
                break
    if not axe.is_file() or not src.is_file():
        raise SystemExit("self-test needs the head icon and its source")
    good = score_pair(axe, src, pipeline=False)
    bad = score_pair(ROOT / "assets" / "sprites" / "player" / "male" / "walk_down_0.png", src, pipeline=False)
    print(json.dumps({"good": good, "bad": bad}, indent=2))
    if not good["accept"]:
        raise SystemExit("self-test: head icon did not match its source")
    if bad["accept"]:
        raise SystemExit("self-test: head icon matched a walk frame")
    print("self-test ok")


def main() -> None:
    parser = argparse.ArgumentParser(description="Match keyed source regions to live assets.")
    parser.add_argument("live", nargs="?", type=Path)
    parser.add_argument("src", nargs="?", type=Path)
    parser.add_argument("--pipeline", action="store_true", help="Key one pair with plate_remap + key_to_alpha")
    parser.add_argument("--report", action="store_true", help="Scan and print a summary. Do not move files.")
    parser.add_argument("--organize", action="store_true", help="Put matching sources in _src and the rest in _old.")
    parser.add_argument("--fill-missing", action="store_true", help="Copy _old and placed sources onto unmatched lives.")
    parser.add_argument("--what-if", action="store_true", help="With --fill-missing, print copies and do not write.")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        self_test()
        return
    if args.live and args.src:
        result = score_pair(args.live, args.src, pipeline=args.pipeline)
        print(json.dumps(result, indent=2))
        return
    if args.fill_missing:
        fill_missing(args.what_if)
        return
    if not args.report and not args.organize:
        parser.error("pass LIVE SRC, --report, --organize, or --fill-missing")
    if args.organize and (SRC_ROOT / "manifest.json").exists():
        raise SystemExit("_src/manifest.json already exists; use --fill-missing to add unmatched lives")

    images, videos = collect_inputs()
    live_paths = collect_lives()
    print(f"images {len(images)} videos {len(videos)} lives {len(live_paths)}", flush=True)
    lives = prepare_lives(live_paths)
    best, near = scan_with_near(images, lives)
    plan = build_plan(lives, best, near, videos)
    print(summarize(plan), flush=True)
    if args.report and not args.organize:
        report = {
            "sources": [
                {
                    "origin": _posix(item["origin"]),
                    "dest": item["dest"],
                    "copy": item["copy"],
                    "cell": item["cell"],
                    "lives": [{k: v for k, v in live.items() if k != "origin_path"} | {"origin": _posix(item["origin"])} for live in item["lives"]],
                }
                for item in plan["sources"]
            ],
            "videos": [{"origin": _posix(item["origin"]), "dest": item["dest"]} for item in plan["videos"]],
            "unmatched": plan["unmatched"],
        }
        out = Path(os.environ.get("TEMP", ".")) / "wdb_src_match_report.json"
        out.write_text(json.dumps(report, indent=2), encoding="utf-8")
        print(f"report {out}", flush=True)
        return
    if matched_count(plan) < 250:
        raise SystemExit("too few matches to organize; inspect the summary first")
    stats = organize(plan)
    print(f"organized archived={stats['archived']} notes={stats['notes']} entries={stats['entries']}", flush=True)


def matched_count(plan: dict) -> int:
    return sum(len(item["lives"]) for item in plan["sources"])


if __name__ == "__main__":
    main()
