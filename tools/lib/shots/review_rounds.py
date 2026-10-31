"""Zoom back-and-forth for shots.py review: the isolated child asks for crops, the parent cuts them from the originals.

Protocol (child side, in report.md): instead of a VERDICT line, end with up to MAX_CROPS lines
    ZOOM N:X,Y,W,H  reason            (pixels of file N as the child saw it, i.e. the downsized shot)
    ZOOM N:norm X0,Y0,X1,Y1  reason   (0..1 fractions of file N)
The parent validates and clamps each request, cuts a 4x nearest crop from the full-size original (shot_zoom),
and resumes the same grok session (--resume <sessionId>; a fresh call carrying the prior report when no id came
back) with a follow-up job naming the new crops and any rejected lines. At most MAX_ROUNDS rounds; the last
round says no more zooms, and a report there without a VERDICT is a FAIL.
"""
from __future__ import annotations

import re
from pathlib import Path

MAX_ROUNDS = 3
MAX_CROPS = 4
FOLLOW_TURNS = 10  # per follow-up round: one read per crop + the report, min(10, 2 + 2 * crops)
MIN_SIDE = 4

ZOOM_RE = re.compile(r"^\s*ZOOM\s+(\d+)\s*:\s*(norm\s+)?([-\d.,\s]+?)(?:\s{2,}|\s+(?=[A-Za-z])|$)(.*)$", re.I)

def protocol_lines() -> list[str]:
    return ["", "If a small detail is too small to judge, do not guess: end report.md with up to "
            f"{MAX_CROPS} lines `ZOOM N:X,Y,W,H reason` (pixels of file N as you saw it) or "
            "`ZOOM N:norm X0,Y0,X1,Y1 reason` (0..1 fractions) instead of the VERDICT line. "
            "The developer cuts those areas from the full-size original, 4x enlarged, and you continue."]

def parse(body: str, sizes: list[tuple[int, int]]) -> tuple[list[tuple[int, str, str]], list[str]]:
    """ZOOM lines -> ([(file index 1-based, --box spec in that file's viewed pixels, reason)], [rejection notes])."""
    ok, bad = [], []
    for ln in body.splitlines():
        if not ln.strip().upper().startswith("ZOOM"):
            continue
        m = ZOOM_RE.match(ln)
        nums = []
        if m:
            try:
                nums = [float(x) for x in m.group(3).replace(" ", "").split(",") if x != ""]
            except ValueError:
                nums = []
        if not m or len(nums) != 4:
            bad.append(f"`{ln.strip()}`: not `ZOOM N:X,Y,W,H reason` or `ZOOM N:norm X0,Y0,X1,Y1 reason`")
            continue
        n = int(m.group(1))
        if not 1 <= n <= len(sizes):
            bad.append(f"`{ln.strip()}`: no file {n} (files 1..{len(sizes)})")
            continue
        W, H = sizes[n - 1]
        if m.group(2):
            x0, y0, x1, y1 = nums
            if not (0 <= x0 < x1 <= 1 and 0 <= y0 < y1 <= 1):
                bad.append(f"`{ln.strip()}`: norm needs 0 <= X0 < X1 <= 1 and 0 <= Y0 < Y1 <= 1")
                continue
            x, y, w, h = x0 * W, y0 * H, (x1 - x0) * W, (y1 - y0) * H
        else:
            x, y, w, h = nums
        l, t = max(0, round(x)), max(0, round(y))
        r, b = min(W, round(x + w)), min(H, round(y + h))
        if r - l < MIN_SIDE or b - t < MIN_SIDE:
            bad.append(f"`{ln.strip()}`: box is outside file {n} ({W}x{H}) or under {MIN_SIDE}px after clamping")
            continue
        if len(ok) >= MAX_CROPS:
            bad.append(f"`{ln.strip()}`: over {MAX_CROPS} crops this round")
            continue
        ok.append((n, f"{l},{t},{r - l},{b - t}", (m.group(4) or "").strip()[:120]))
    return ok, bad

def follow_job(crops: list[str], rejected: list[str], round_no: int, prior: str | None) -> str:
    last = round_no >= MAX_ROUNDS
    lines = [f"# Shot review, round {round_no} of {MAX_ROUNDS}", ""]
    if prior is not None:
        lines += ["Your previous report (this is a new session; the shots are in this directory):", "", prior, ""]
    if crops:
        lines += ["New zoomed crops (full-size original, 4x nearest). Call read_file once on each: " + "; ".join(crops)]
    if rejected:
        lines += ["Rejected zoom lines (not cut): " + "; ".join(rejected)]
    lines += ["", "Rewrite `report.md` in full with the write tool: same rules as before, using what the crops show."]
    lines += (["This is the final round: no more ZOOM lines. Last line must be the VERDICT."] if last
              else protocol_lines()[1:] + ["Otherwise last line is the VERDICT."])
    return "\n".join(lines) + "\n"

def budget_note(first: int) -> str:
    return f"turns: round 1 {first}, each follow-up <= {FOLLOW_TURNS}, <= {MAX_ROUNDS} rounds, total <= {first + FOLLOW_TURNS * (MAX_ROUNDS - 1)}"

def sizes_of(paths: list[Path]) -> list[tuple[int, int]]:
    from PIL import Image
    return [Image.open(p).size for p in paths]
