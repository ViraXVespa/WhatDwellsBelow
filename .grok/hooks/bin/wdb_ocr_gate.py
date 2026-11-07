"""Tesseract before LLM OCR: part of wdb-pretool.py (kept apart so it can be reverted alone).

LLM OCR/vision-read tools, and `shots.py review` whose --question asks about text, are denied in the game repo
unless `python tools/shots.py ocr` read the same PNG set in the last 30 min (marker _logs/ocr/.tried-<sha1>,
written by tools/lib/shots/ocr_lib.py; same key), or the review passes --ocr or --why "...".
"""
from __future__ import annotations

import hashlib
import re
import shlex
import time
from pathlib import Path

OCR_TOOLS = {"ocr", "OCR", "image_ocr", "ImageOcr", "vision_ocr", "VisionOcr", "read_image_text", "ReadImageText"}
REVIEW = re.compile(r"\bshots\.py\s+review\b", re.I)
TEXTY = re.compile(r"read|text|label|ocr", re.I)
DENY = ("Run python tools/shots.py ocr PNG first; use LLM OCR only if it rates weak/fail or you need meaning, "
        "not text. (Or shots.py review --ocr, or --why \"reason\".)")
MAX_AGE_S = 1800

def marker(repo: Path, pngs: list[Path]) -> Path:
    key = "\n".join(sorted(str(p.resolve()) for p in pngs))
    return repo / "_logs" / "ocr" / (".tried-" + hashlib.sha1(key.encode()).hexdigest())

def tried(repo: Path, pngs: list[Path], now: float | None = None) -> bool:
    m = marker(repo, pngs)
    return m.is_file() and (now or time.time()) - m.stat().st_mtime <= MAX_AGE_S

def _pngs(tokens: list[str], base: Path) -> list[Path]:
    out = []
    for t in tokens:
        if t.lower().endswith((".png", ".jpg", ".jpeg", ".webp")):
            p = Path(t)
            out.append(p if p.is_absolute() else base / p)
    return out

def review_reason(cmd: str, repo: Path, cwd: Path | None) -> str:
    m = REVIEW.search(cmd)
    if not m:
        return ""
    try:
        tokens = shlex.split(cmd[m.end():].split("&&")[0].split(";")[0], posix=True)
    except ValueError:
        tokens = cmd[m.end():].split()
    question = ""
    for i, t in enumerate(tokens):
        if t in ("--ocr",) or t.startswith("--why"):
            return ""
        if t == "--question" and i + 1 < len(tokens):
            question = tokens[i + 1]
        elif t.startswith("--question="):
            question = t.split("=", 1)[1]
    if not TEXTY.search(question):
        return ""
    pngs = _pngs(tokens, cwd or repo)
    return "" if pngs and tried(repo, pngs) else DENY

def tool_reason(name: str, paths: list[str], repo: Path, cwd: Path | None) -> str:
    if name not in OCR_TOOLS:
        return ""
    pngs = _pngs(paths, cwd or repo)
    return "" if pngs and tried(repo, pngs) else DENY
