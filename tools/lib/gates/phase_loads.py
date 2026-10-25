"""Which smoke phases load a file, from a real run: tools/data/phase_loads.json.

`gate.py bot-smokes --record-loads` runs every phase with --wdb-dump-loaded (scripts/debug/smoke/loaded_dump.gd: the
ResourceLoader cache sampled through the run) and records, per live .gd/.tscn/.tres/.gdshader, the phases that loaded
it ("" = not seen: the main scene is freed before the dump starts, lazy loads may be missed). bot_warnscan_lib.changed_areas
picks phases from it; a "" file or one the record does not know (new since the recording) falls back to the folder map. Re-record after moving code between phases (the record names its commit).
"""
from __future__ import annotations

import json
import subprocess
from pathlib import Path

REC = "tools/data/phase_loads.json"
DIRS = ("scripts", "scenes", "tools/data", "assets/shaders")
EXT = (".gd", ".tscn", ".tres", ".gdshader")

def load(root: Path) -> dict[str, str]:
    p = root / REC
    return json.loads(p.read_text(encoding="utf-8")).get("loads", {}) if p.is_file() else {}

def candidates(root: Path) -> list[str]:
    return sorted(p.relative_to(root).as_posix() for d in DIRS if (root / d).is_dir() for p in (root / d).rglob("*") if p.suffix in EXT)

def record(root: Path, dumps: dict[int, Path]) -> tuple[Path, int]:
    """Write the record from {phase: dump file of res:// lines}; returns (path, files loaded by any phase)."""
    seen: dict[str, str] = {f: "" for f in candidates(root)}
    for ph in sorted(dumps):
        for ln in dumps[ph].read_text(encoding="utf-8").splitlines():
            rel = ln.strip().removeprefix("res://")
            if rel in seen and str(ph) not in seen[rel]:
                seen[rel] += str(ph)
    sha = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=root, capture_output=True, text=True).stdout.strip()
    out = root / REC
    out.write_text(json.dumps({"_about": __doc__.split("\n\n")[0], "commit": sha, "loads": seen}, indent=0) + "\n", encoding="utf-8")
    return out, sum(1 for v in seen.values() if v)
