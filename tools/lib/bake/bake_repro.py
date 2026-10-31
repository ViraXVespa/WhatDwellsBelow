"""Hub bake reproduce check (tools/bake.py check --rebake; bot_status --prove row bake_repro).

Rebakes hub_light.png from the committed sources (tools/bake.py camp), compares the fresh stamp with HUB_BAKE_STAMP,
then restores every file the bake wrote. FAILs when the committed png is not what its committed sources produce (a
png committed without its source, a source change recorded with --record, a lost lamp), or the bake lost its lamps.
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

WRITES = ["assets/baked/hub_light.png", "assets/baked/ground_wear.png", "scripts/graphics/light_rt/hub_bake.gd",
          "tools/data/hub_bake_inputs.json", "tools/data/hub_bake_feet.json"]

def problems(root: Path, want: str) -> list[str]:
    keep = {rel: (root / rel).read_bytes() for rel in WRITES if (root / rel).is_file()}
    try:
        r = subprocess.run([sys.executable, str(root / "tools/bake.py"), "camp", "--root", str(root), "--json"],
                           capture_output=True, text=True, timeout=400)
    finally:
        for rel, data in keep.items():
            (root / rel).write_bytes(data)
    res = {}
    for ln in reversed(r.stdout.strip().splitlines()):
        if ln.startswith("{"):
            res = json.loads(ln)
            break
    got, lamp = str(res.get("stamp", "none")), int(res.get("lamp_px", 0) or 0)
    if lamp == 0:
        return [f"FAIL bake repro: fresh bake has lamp_px=0 (no hub_lamp nodes: lantern flames and pools lost); status={res.get('status')}"]
    if got != want:
        return [f"FAIL bake repro: committed hub_light.png (stamp {want}) is not what the committed sources bake (stamp {got}): "
                "rebake with tools/bake.py camp and commit the png with its source"]
    return []
