"""Local OCR attempt receipts, not credentials or host authorization.

Receipts bind resolved paths AND image contents, expire after 30 minutes, and are
shared by the repo review gate and the staged helper. Missing Tesseract is a
recorded SKIP attempt; an old empty .tried marker is not evidence.
"""
from __future__ import annotations

import hashlib
import json
import time
from pathlib import Path

MAX_AGE_S = 1800


def marker_path(pngs, root: Path | None = None) -> Path:
    key = "\n".join(sorted(str(Path(p).resolve()) for p in pngs))
    return (root or Path.cwd()) / "_logs/ocr" / (".tried-" + hashlib.sha1(key.encode()).hexdigest())


def fingerprint(path) -> dict:
    p = Path(path).resolve(strict=True)
    return {"path": str(p), "sha256": hashlib.sha256(p.read_bytes()).hexdigest()}


def record(pngs, root: Path, status: str, lines: list[str]) -> None:
    entries = [fingerprint(p) for p in pngs]
    payload = {"version": 1, "time": time.time(), "status": status, "files": entries, "lines": lines}
    # Singleton receipts let a subsequent request use a subset of the same images.
    for group in [list(pngs), *[[p] for p in pngs]]:
        m = marker_path(group, root)
        m.parent.mkdir(parents=True, exist_ok=True)
        m.write_text(json.dumps(payload), encoding="utf-8")


def tried(root: Path, pngs, now: float | None = None) -> bool:
    if not pngs:
        return False
    now = time.time() if now is None else now
    try:
        for path in pngs:
            row = json.loads(marker_path([path], root).read_text(encoding="utf-8"))
            if row.get("version") != 1 or row.get("status") not in ("ATTEMPT", "SKIP", "ERROR"):
                return False
            if not 0 <= now - float(row["time"]) <= MAX_AGE_S:
                return False
            if fingerprint(path) not in row["files"]:
                return False
        return True
    except (OSError, ValueError, TypeError, KeyError):
        return False
