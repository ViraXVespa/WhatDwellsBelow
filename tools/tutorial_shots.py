#!/usr/bin/env python3
"""How-to-Play screenshots from shot flows (receptionist Ask? pages).

  python tools/tutorial_shots.py            check the manifest (no Godot): flows exist, shots exist, ids unique
  python tools/tutorial_shots.py --run      shoot each named flow (needs a display) and stage _out/tutorial/<id>.png
                                            plus _out/tutorial/tutorial_shots.json (sha256 per file)

Manifest: tools/tutorial_shots.json (topic id -> {flow, shot}). Tooling never writes under assets/: Grok Build
copies the staged PNGs to the manifest's dest. Re-run after a UI change to refresh every page at once.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "tools" / "tutorial_shots.json"
FLOWS = ROOT / "tools" / "shot-flows"
ID_RE = re.compile(r"^[a-z][a-z0-9_]*$")


def load() -> dict:
    return json.loads(MANIFEST.read_text(encoding="utf-8"))


def check(man: dict) -> list[str]:
    bad: list[str] = []
    if not str(man.get("dest", "")).startswith("assets/ui/tutorial"):
        bad.append("dest must be under assets/ui/tutorial")
    for tid, row in man.get("topics", {}).items():
        if not ID_RE.match(tid):
            bad.append(f"{tid}: id must be lower_snake")
        flow = FLOWS / f"{row.get('flow', '')}.json"
        if not flow.is_file():
            bad.append(f"{tid}: no flow {row.get('flow')}")
            continue
        shots = [s.get("name") for s in json.loads(flow.read_text(encoding="utf-8")).get("steps", []) if s.get("op") == "shot"]
        if row.get("shot") not in shots:
            bad.append(f"{tid}: flow {row['flow']} has no shot {row.get('shot')} (has {shots})")
    return bad


def run(man: dict, out: Path) -> list[str]:
    bad: list[str] = []
    flows = sorted({r["flow"] for r in man["topics"].values()})
    r = subprocess.run([sys.executable, str(ROOT / "tools" / "run_shot_flow.py"), "--no-dedupe", "--flow", ",".join(flows)], cwd=ROOT)
    if r.returncode != 0:
        return [f"run_shot_flow failed ({r.returncode})"]
    out.mkdir(parents=True, exist_ok=True)
    rows = {}
    for tid, row in sorted(man["topics"].items()):
        frames_dir = ROOT / "_logs" / "shot-flow" / row["flow"]
        frames = json.loads((frames_dir / "flow.json").read_text(encoding="utf-8")).get("frames", [])
        hit = [f for f in frames if f.get("name") == row["shot"] and f.get("file")]
        if not hit:
            bad.append(f"{tid}: frame {row['shot']} not shot in {row['flow']}")
            continue
        src = frames_dir / hit[-1]["file"]
        shutil.copyfile(src, out / f"{tid}.png")
        rows[tid] = {"file": f"{tid}.png", "flow": row["flow"], "shot": row["shot"],
                     "sha256": hashlib.sha256(src.read_bytes()).hexdigest()}
    (out / "tutorial_shots.json").write_text(json.dumps({"dest": man["dest"], "topics": rows}, indent=2) + "\n", encoding="utf-8")
    return bad


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--run", action="store_true", help="shoot the flows and stage PNGs in --out")
    ap.add_argument("--out", default="_out/tutorial", help="staging dir (never under assets/)")
    a = ap.parse_args(argv)
    man = load()
    bad = check(man)
    out = (ROOT / a.out).resolve()
    if (ROOT / "assets").resolve() in [out, *out.parents]:
        bad.append("refusing to write under assets/ (Grok Build places tutorial images)")
    if a.run and not bad:
        bad += run(man, out)
    for b in bad:
        print("problem", b)
    n = len(man.get("topics", {}))
    staged = f" staged={a.out} dest={man.get('dest')}" if a.run and not bad else ""
    print(f"RESULT {'FAIL' if bad else 'PASS'} topics={n} problems={len(bad)}{staged}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
