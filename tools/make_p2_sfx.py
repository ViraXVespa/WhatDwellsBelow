#!/usr/bin/env python3
"""Tiny placeholder wavs for Phase 2 combat (Section 14 placeholder policy)."""
from __future__ import annotations

import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
import audio_lib as al

OUT: Path = Path("assets/audio")
WRITTEN: list[str] = []


def write(name: str, samples: list[float]) -> None:
    path = OUT / f"p2_{name}.wav"
    al.write_wav(path, samples, 32000)
    WRITTEN.append(path.name)
    print("sfx", agent_log.rel(ROOT, path))


def tone(freq: float, dur: float, vol: float = 0.35, decay: bool = True) -> list[float]:
    return al.sine(freq, dur, vol, decay, 1.0)


def noise(dur: float, vol: float = 0.2) -> list[float]:
    return al.noise(dur, vol, 0.0)


mix = al.mix
ROOT: Path = Path(".")


def main(argv: list[str] | None = None) -> int:
    global OUT, ROOT
    ap = agent_log.std_parser("Tiny placeholder wavs for Phase 2 combat (Section 14 placeholder policy).")
    args = ap.parse_args(argv)
    ROOT = agent_log.resolve_root(args)
    OUT = ROOT / "assets" / "audio"
    write("hit", mix(tone(180, 0.08, 0.4), noise(0.09, 0.25)))
    write("crit", mix(tone(520, 0.12, 0.35), tone(780, 0.12, 0.25)))
    write("slam", mix(tone(70, 0.22, 0.5), noise(0.2, 0.35)))
    write("dash", tone(240, 0.14, 0.25))
    write("warcry", mix(tone(220, 0.28, 0.35), tone(330, 0.28, 0.2)))
    write("bolt", mix(tone(880, 0.16, 0.3), noise(0.16, 0.2)))
    write("bow", tone(420, 0.07, 0.28))
    loop = tone(90, 0.4, 0.12, False) + tone(110, 0.4, 0.1, False)
    write("adrenaline_loop", mix(loop, noise(0.8, 0.05)))
    return agent_log.emit_result("PASS", written=len(WRITTEN), dir="assets/audio")


if __name__ == "__main__":
    raise SystemExit(main())
