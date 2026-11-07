"""Tesseract-first for the real shots.py review command and staged review policy.

There is no separate verified LLM OCR API in this runner. Do not invent OCR tool
aliases or globally block image-capable read_file: visual review is not OCR.
"""
from __future__ import annotations

import re
import shlex
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools/lib/shots"))
from ocr_evidence import marker_path, tried, record  # noqa: E402

REVIEW = re.compile(r"\bshots\.py\s+review\b", re.I)
TEXTY = re.compile(r"read|text|label|ocr", re.I)
DENY = ("Run python tools/shots.py ocr PNG first; use LLM OCR only if it rates weak/fail or you need meaning, "
        "not text. (Or shots.py review --ocr, or --why \"reason\".)")


def marker(repo: Path, pngs: list[Path]) -> Path:
    return marker_path(pngs, repo)


def isolated_decision(event: dict, cwd: Path | None):
    if cwd is None:
        return None
    for root in (cwd.resolve(), *cwd.resolve().parents):
        if (root / ".wdb-review.json").is_file():
            import json
            if not json.loads((root / ".wdb-review.json").read_text(encoding="utf-8")).get("hook"):
                return None
            from review_policy import decide
            try:
                return decide(event, root)
            except (OSError, ValueError, KeyError, TypeError):
                return "deny", "Invalid staged review configuration"
    return None


def review_reason(cmd: str, repo: Path, cwd: Path | None) -> str:
    m = REVIEW.search(cmd)
    if not m:
        return ""
    try:
        tokens = shlex.split(cmd[m.end():], posix=True)
    except ValueError:
        return DENY
    question, why, prepass = "", "", False
    for i, t in enumerate(tokens):
        if t == "--ocr":
            prepass = True
        if t in ("--question", "--why") and i + 1 < len(tokens):
            if t == "--question":
                question = tokens[i + 1]
            else:
                why = tokens[i + 1].strip()
        elif t.startswith("--question="):
            question = t.split("=", 1)[1]
        elif t.startswith("--why="):
            why = t.split("=", 1)[1].strip()
    if prepass or why or not TEXTY.search(question):
        return ""
    pngs = [(cwd or repo) / t for t in tokens if t.lower().endswith((".png", ".jpg", ".jpeg", ".webp"))]
    return "" if tried(repo, pngs) else DENY
