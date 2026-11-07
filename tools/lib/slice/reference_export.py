"""Read-only source export for Blender reference work; no modeling or generation.

Native Bible cells reuse the sprite pipeline's layout and imglib split. Walk frames
are copied, not repacked. Manifest coordinates are half-open source pixels.
"""
from __future__ import annotations
import json
import re
import shutil
from pathlib import Path

import reference_policy as policy


def export(root: Path, task: str, bible: str, walk_dir: str, out: str, dry: bool = False) -> dict:
    from imglib import imgio
    from sprite_pipeline import CELL_NAMES, split_equal_3x3
    policy.task_file(root, task)
    source = policy.reference(root, task, bible)
    dest = policy.contained(root, out or f"_logs/references/{task}", exists=False)
    dest.relative_to(root / "_logs" / "references" / task)
    if dest.exists():
        raise ValueError("export needs a fresh folder; existing references are never overwritten")
    im = imgio.load(source)
    if im.width % 3 or im.height % 3:
        raise ValueError("Bible dimensions must divide exactly into a 3x3 grid")
    records, writes = [], [(source, dest / "bible.png", None)]
    for i, (name, cell) in enumerate(zip(CELL_NAMES, split_equal_3x3(im))):
        x, y = i % 3 * cell.width, i // 3 * cell.height
        writes.append((source, dest / (name + ".png"), (cell, [x, y, x + cell.width, y + cell.height])))
    if walk_dir:
        folder = policy.contained(root, walk_dir, exists=False)
        folder.relative_to(root / "assets" / "sprites" / "player")
        frames = sorted(p for p in folder.iterdir() if re.fullmatch(r"walk_(?:up|down|left|right|up_left|up_right|down_left|down_right)_\d+\.png", p.name))
        if not frames:
            raise ValueError("no current walk frames found")
        for path in frames:
            policy.reference(root, task, str(path))
            writes.append((path, dest / "walk" / path.name, None))
    if len(writes) > 128:
        raise ValueError("select a smaller reference bundle (maximum 128 files)")
    if not dry:
        dest.mkdir(parents=True)
    for src, dst, cut in writes:
        original = im if src == source else imgio.load(src)
        crop = cut[1] if cut else [0, 0, original.width, original.height]
        image = cut[0] if cut else original
        if not dry:
            dst.parent.mkdir(exist_ok=True)
            if cut:
                imgio.save(image, dst)
            else:
                shutil.copy2(src, dst)
        records.append({"path": dst.relative_to(root).as_posix(), "source": src.relative_to(root).as_posix(),
            "source_sha256": policy.digest(src), "source_size": list(original.size), "crop": crop,
            "size": list(image.size), "scale": 1,
            "sha256": policy.digest(dst) if not dry else None})
    result = {"version": 1, "task": task, "coordinates": "source pixels, half-open x0,y0,x1,y1", "images": records}
    if not dry:
        (dest / "manifest.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    return result
