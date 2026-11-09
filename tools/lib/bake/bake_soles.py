#!/usr/bin/env python3
"""Bake actor sole positions (scripts/data/actor_soles.json) through --wdb-bake-soles.

    python tools/bake.py soles [--timeout-sec 300]

Headless. Godot scans every assets/sprites/**/*.png and assets/fx/**/*.png with Soles._scan and writes the table.
Play only looks that table up. Stamp is the first 16 hex of SHA-256 over the sorted rows plus the
normalized soles.gd / soles_scan.gd / sole_bake.gd sources. The tool pastes stamp= into SOLE_BAKE_STAMP.
bake.py check fails when a png or those scripts changed since the bake.
"""
from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import boot  # noqa: E402,F401
import agent_log
import godot_lib

JSON_REL = "scripts/data/actor_soles.json"
SOLES_REL = "scripts/graphics/actor_lit/soles.gd"
BAKE_REL = "scripts/graphics/actor_lit/sole_bake.gd"
SCAN_REL = "scripts/graphics/actor_lit/soles_scan.gd"
_STAMP_RE = re.compile(r'const SOLE_BAKE_STAMP := "[0-9a-f]*"')


def _strip_stamp(src: str) -> str:
    return _STAMP_RE.sub('const SOLE_BAKE_STAMP := ""', src, count=1)


def _script_sha(path: Path) -> str:
    text = _strip_stamp(path.read_bytes().decode("utf-8"))
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def _line(path: str, packed: list) -> str:
    sha = str(packed[0])
    nums = ",".join([str(packed[1]), str(packed[2]), str(packed[3]), str(packed[4])] + [str(int(n)) for n in packed[5:11]])
    return f"{path}\t{sha}\t{nums}"


def stamp_of(root: Path, rows: dict) -> str:
    lines = [_line(path, rows[path]) for path in sorted(rows)]
    lines.append("soles:" + _script_sha(root / SOLES_REL))
    lines.append("scan:" + _script_sha(root / SCAN_REL))
    lines.append("bake:" + _script_sha(root / BAKE_REL))
    lines.append("soles-v1")
    return hashlib.sha256("\n".join(lines).encode("utf-8")).hexdigest()[:16]


def problems(root: Path) -> list[str]:
    """Empty when the committed sole bake matches the sprites and the scan scripts."""
    src = root / SOLES_REL
    blob = root / JSON_REL
    text = src.read_text(encoding="utf-8") if src.is_file() else ""
    m = re.search(r'const SOLE_BAKE_STAMP := "([0-9a-f]*)"', text)
    want = m.group(1) if m else ""
    lines: list[str] = []
    if not m:
        lines.append(f"FAIL {SOLES_REL}: no `const SOLE_BAKE_STAMP := \"<hex>\"` line")
    if not blob.is_file():
        lines.append(f"FAIL {JSON_REL} is missing: the game crashes on the first mark")
        return lines
    try:
        data = json.loads(blob.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return lines + [f"FAIL {JSON_REL} is not json ({exc})"]
    rows = data.get("rows") if isinstance(data, dict) else None
    got = str(data.get("stamp", "")) if isinstance(data, dict) else ""
    if not isinstance(rows, dict) or not rows:
        lines.append(f"FAIL {JSON_REL} has no rows")
        return lines
    pngs: set[str] = set()
    for folder in ("assets/sprites", "assets/fx"):
        base = root / folder
        if not base.is_dir():
            continue
        pngs.update(f"res://{p.relative_to(root).as_posix()}" for p in base.rglob("*.png"))
    keys = set(rows)
    missing = sorted(pngs - keys)
    extra = sorted(keys - pngs)
    if missing:
        lines.append(f"FAIL {JSON_REL} missing {len(missing)} sprite(s), first {missing[0]}")
    if extra:
        lines.append(f"FAIL {JSON_REL} has {len(extra)} unknown row(s), first {extra[0]}")
    for path in sorted(pngs & keys):
        rel = path[6:] if path.startswith("res://") else path
        file_sha = hashlib.sha256((root / rel).read_bytes()).hexdigest()[:16]
        row = rows[path]
        if not isinstance(row, list) or len(row) < 11 or str(row[0]) != file_sha:
            lines.append(f"FAIL {rel} changed since the sole bake")
            break
    fresh = stamp_of(root, rows) if not lines else ""
    if fresh and fresh != got:
        lines.append(f"FAIL {JSON_REL} stamp {got} != recomputed {fresh}: rebake with tools/bake.py soles")
    if m and got != want:
        lines.append(f"FAIL {JSON_REL} stamp {got} != SOLE_BAKE_STAMP {want or '(empty)'}: rebake with tools/bake.py soles")
    return lines


def _write_stamp(root: Path, stamp: str) -> None:
    src = root / SOLES_REL
    text = src.read_bytes().decode("utf-8")
    nxt = _STAMP_RE.sub(f'const SOLE_BAKE_STAMP := "{stamp}"', text, count=1)
    if nxt == text and f'const SOLE_BAKE_STAMP := "{stamp}"' not in text:
        raise SystemExit(f"FAIL could not paste SOLE_BAKE_STAMP in {SOLES_REL}")
    src.write_bytes(nxt.encode("utf-8"))


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Bake actor_soles.json through the --wdb-bake-soles hook.", json_out=True)
    ap.add_argument("--timeout-sec", type=int, default=300, help="Godot timeout in seconds (default 300).")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    out_log = agent_log.run_path("bake-soles", root, "bake-out.log")
    err_log = agent_log.run_path("bake-soles", root, "bake-err.log")
    print("Baking actor soles (headless)...")
    gargs = godot_lib.headless_args(root, "--wdb-bake-soles")
    r = godot_lib.run_godot(root, root, gargs, out_log, err_log, args.timeout_sec, gui=False)
    hits = godot_lib.grep_logs([err_log, out_log], r"SCRIPT ERROR:|Parse Error|Compile Error|ERROR: Failed|bake_soles:")
    hard = any(godot_lib.HARD_RE.search(h) for h in hits)
    stamps = [m.group(1) for h in hits for m in [re.search(r"stamp=([0-9a-f]+)", h)] if m]
    stamp = stamps[-1] if stamps else "none"
    counts = [int(m.group(1)) for h in hits for m in [re.search(r"n=(\d+)", h)] if m]
    n = counts[-1] if counts else 0
    clean = r["status"] == "EXIT=0" and not hard and stamp != "none" and n > 0
    if clean:
        _write_stamp(root, stamp)
        bad = problems(root)
        if bad:
            clean = False
            hits = bad + hits
    status = "PASS" if clean else "FAIL"
    body = [
        "bake soles root=.",
        f"status={r['status']} ms={r['ms']} n={n} stamp={stamp} errBytes={r['err_bytes']} outBytes={r['out_bytes']}",
        "",
        "--- highlights ---",
    ] + (hits[:120] or ["(no SCRIPT ERROR / WARNING highlights)"])
    return agent_log.finish(
        "bake-soles", root, "\n".join(body), status, args=args, n=n, stamp=stamp,
    )


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))


def selftest(root: Path) -> list[str]:
    """A moved scan remains a bake input; stamp constants do not hash themselves."""
    for rel in (SOLES_REL, SCAN_REL, BAKE_REL):
        p = root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text('const SOLE_BAKE_STAMP := "1234"\n# scan fixture\n')
    rows = {"res://fixture.png": ["fixture", "0", "0", "0", "0", 0, 0, 1, 1, 1, 1]}
    original = stamp_of(root, rows)
    p = root / SCAN_REL
    p.write_text(p.read_text().replace('"1234"', '"5678"'))
    bad = [] if stamp_of(root, rows) == original else ["sole stamp must exclude embedded stamp constants"]
    p.write_text(p.read_text() + "# changed scan algorithm\n")
    if stamp_of(root, rows) == original:
        bad.append("moved sole scan helper must invalidate the bake stamp")
    return bad
