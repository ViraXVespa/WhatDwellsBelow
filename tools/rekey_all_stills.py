#!/usr/bin/env python3
"""Bulk rekey every still listed in _src/manifest.json.

    python tools/rekey_all_stills.py
    python tools/rekey_all_stills.py --dry-run
    python tools/rekey_all_stills.py --only assets/fx/arrow.png,assets/ui/gear/hatchet.png

Reads the manifest, resolves each source under _src/sources, runs the current
key_to_alpha, fits to the live canvas (or 128), and overwrites the live PNG.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
import match_keyed_region as matcher
from imglib import geom, imgio, key

ROOT = Path(__file__).resolve().parents[1]
SRC_ROOT = ROOT / "_src"
MANIFEST = SRC_ROOT / "manifest.json"


def _canvas_for(live: Path) -> tuple[int, int]:
    """Return (canvas, pad). Prefer the existing live size; default 128/8."""
    if live.is_file():
        try:
            im = imgio.load(live)
            side = max(im.size)
            im.close()
            if side <= 64:
                return 64, 2
            if side <= 48:
                return 48, 4
            return side, 8
        except OSError:
            pass
    return 128, 8


def _one(live_rel: str, dry: bool) -> str:
    live = ROOT / live_rel
    src = matcher.resolve_source(live)
    if src is None or not src.is_file():
        return f"SKIP {live_rel} (no source)"
    try:
        raw = imgio.load(src).convert("RGBA")
        keyed = key.key_to_alpha(raw)
        canvas, pad = _canvas_for(live)
        fitted = geom.fit_box(keyed, canvas, pad)
        if not dry:
            live.parent.mkdir(parents=True, exist_ok=True)
            fitted.save(live)
        return f"WROTE {live_rel} {fitted.size[0]}x{fitted.size[1]} from {src.relative_to(SRC_ROOT).as_posix()}"
    except Exception as exc:
        return f"FAIL {live_rel} ({exc})"


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Bulk rekey stills from the manifest. Overwrites live PNGs.", writes=True)
    ap.add_argument("--only", default="", help="Comma-separated live paths to limit the run.")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    if not MANIFEST.is_file():
        agent_log.fail(f"no manifest at {MANIFEST}")
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    entries = data.get("entries", [])
    wanted = {p.strip() for p in args.only.split(",") if p.strip()}
    lines = ["Bulk rekey from manifest. Live PNGs are overwritten unless --dry-run."]
    wrote = skipped = failed = 0
    for entry in entries:
        live_rel = entry.get("live")
        if not live_rel:
            continue
        if wanted and live_rel not in wanted:
            continue
        line = _one(live_rel, args.dry_run)
        lines.append(line)
        if line.startswith("WROTE"):
            wrote += 1
        elif line.startswith("SKIP"):
            skipped += 1
        else:
            failed += 1
    lines.append(f"done wrote={wrote} skipped={skipped} failed={failed}")
    status = "FAIL" if failed else "PASS"
    return agent_log.finish("rekey-all-stills", root, "\n".join(lines), status, args=args, wrote=wrote, skipped=skipped, failed=failed)


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
