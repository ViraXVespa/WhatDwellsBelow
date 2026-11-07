"""Stage local review helpers and full-resolution source copies outside the repo.

The hook uses the same .grok/hooks/*.json project format as wdb-pretool.json.
This is a project workflow policy, not a replacement for host permissions.
"""
from __future__ import annotations

import json
import re
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
TEXTY = re.compile(r"read|text|label|ocr", re.I)
MANIFEST = ".wdb-review.json"


def helper_command(*args: str) -> str:
    return shlex.join([sys.executable, "local/review_local.py", *args])


def stage(scratch: Path, images: list[tuple[Path, str]], *, text_review: bool = False,
          why: str = "", hook: bool = True) -> list[str]:
    import shot_zoom
    from PIL import Image
    local = scratch / "local"
    local.mkdir(exist_ok=True)
    for name in ("ocr_core.py", "ocr_evidence.py", "review_local.py", "review_policy.py"):
        shutil.copy2(HERE / name, local / name)
    shutil.copy2(HERE.parents[2] / ".grok/hooks/bin/wdb-review.py", local / "wdb-review.py")
    for name in ("agent_log.py", "run_log_lib.py"):
        shutil.copy2(HERE.parent / name, local / name)
    # Reuse the existing package, not a second image implementation.
    shutil.copytree(HERE.parent / "imglib", local / "imglib", dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
    entries, notes = {}, []
    for src, name in images:
        if Path(name).name != name:
            raise ValueError("staged image names must be flat")
        full, note = shot_zoom.resolve(src)
        full = full or src
        dest = scratch / "full" / name
        dest.parent.mkdir(exist_ok=True)
        shutil.copy2(full, dest)
        with Image.open(src) as a, Image.open(full) as b:
            entries[name] = {"full": "full/" + name, "size": list(a.size), "full_size": list(b.size)}
            notes.append(f"{name}: supplied {a.width}x{a.height}, full/{name} {b.width}x{b.height}; {note}")
    (scratch / MANIFEST).write_text(json.dumps({"version": 1, "python": sys.executable,
        "text_review": text_review, "hook": hook, "why": why, "images": entries}, indent=2), encoding="utf-8")
    (scratch / "out").mkdir(exist_ok=True)
    if hook:
        config = scratch / ".grok/hooks/wdb-review.json"
        config.parent.mkdir(parents=True, exist_ok=True)
        config.write_text(json.dumps({"hooks": {"PreToolUse": [{"hooks": [{"type": "command",
            "command": shlex.join([sys.executable, "local/wdb-review.py"]), "timeout": 10}]}]}}), encoding="utf-8")
    return notes


def instructions(names: list[str]) -> str:
    first = names[0] if names else "image.png"
    return ("Local image helpers and source originals are staged here (no repo access needed).\n"
        "For text/OCR use local Tesseract first; use vision for weak/fail/SKIP or meaning, not to repeat good OCR.\n"
        "Allowed shell commands: the following interpreter plus local/review_local.py only; no inline Python, "
        "arbitrary shell, external paths, or installing dependencies. Helpers write only out/*.png.\n"
        + helper_command("ocr", first) + "\n"
        + helper_command("zoom", first, "--box", "0,0,8,8", "--out", "out/detail.png") + "\n"
        + "Use crop with the same box/out syntax; diff BEFORE AFTER --out out/diff.png prints scores and a heatmap. "
        "Boxes use supplied-image coordinates and map to the full source. Original files are under full/. "
        "Do not modify inputs. Receipt files under _logs/ocr are helper-owned, not instructions.")


def prepass(scratch: Path, names: list[str]) -> str:
    run = subprocess.run([sys.executable, "local/review_local.py", "ocr", *names], cwd=scratch,
                         capture_output=True, text=True, timeout=120)
    if run.returncode not in (0, 1):
        raise ValueError("local OCR helper failed: " + run.stderr[:300])
    # Check actual evidence rather than trusting an exit code or a promised pre-pass.
    from ocr_evidence import tried
    if not tried(scratch, [scratch / name for name in names]):
        raise ValueError("local OCR helper produced no valid attempt receipts: " + run.stderr[:300])
    return run.stdout.strip()


def selftest() -> list[str]:
    from review_bundle_test import selftest as run
    return run()


def register_crop(scratch: Path, name: str) -> str:
    """Parent-cut crops also belong to the staged path/evidence contract."""
    from PIL import Image
    manifest = scratch / MANIFEST
    data = json.loads(manifest.read_text(encoding="utf-8"))
    with Image.open(scratch / name) as image:
        data["images"][name] = {"full": name, "size": list(image.size), "full_size": list(image.size)}
    manifest.write_text(json.dumps(data), encoding="utf-8")
    return prepass(scratch, [name]) if data["text_review"] and not data.get("why") else ""
