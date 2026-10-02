#!/usr/bin/env python3
"""Appendix E remaining SFX + gendered VO stand-ins."""
from __future__ import annotations

import sys
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log
import audio_lib as al

OUT: Path = Path("assets/audio")
ROOT: Path = Path(".")
WRITTEN: list[str] = []


def write(name: str, samples: list[float]) -> None:
    path = OUT / f"{name}.wav"
    al.write_wav(path, samples, 30000)
    WRITTEN.append(path.name)
    print("sfx", agent_log.rel(ROOT, path))


def tone(freq: float, dur: float, vol: float = 0.35, decay: bool = True) -> list[float]:
    return al.sine(freq, dur, vol, decay, 0.7)


noise = al.noise
mix = al.mix


def vo(base: float, dur: float, vol: float) -> list[float]:
    return mix(tone(base, dur, vol), tone(base * 1.5, dur, vol * 0.35), noise(dur, 0.06, int(base)))


def main(argv: list[str] | None = None) -> int:
    global OUT, ROOT
    ap = agent_log.std_parser("Appendix E remaining SFX + gendered VO stand-ins.")
    args = ap.parse_args(argv)
    ROOT = agent_log.resolve_root(args)
    OUT = ROOT / "assets" / "audio"
    write("p9_potion", mix(tone(520, 0.12, 0.28), tone(780, 0.16, 0.22)))
    write("p9_food", mix(tone(180, 0.18, 0.3), tone(240, 0.22, 0.18)))
    write("p9_wood", mix(tone(140, 0.1, 0.32), noise(0.12, 0.22, 9)))
    write("p9_thud", mix(tone(55, 0.28, 0.5), noise(0.22, 0.3, 3)))
    write("p9_enter", mix(tone(180, 0.45, 0.22, False), tone(360, 0.45, 0.12)))
    write("p9_wake", mix(tone(220, 0.55, 0.2), tone(330, 0.7, 0.12)))
    write("p9_ui_cancel", tone(220, 0.07, 0.22))
    write("p9_hurt_male", vo(140, 0.22, 0.4))
    write("p9_hurt_female", vo(210, 0.22, 0.38))
    write("p9_warcry_male", mix(vo(160, 0.38, 0.42), tone(80, 0.38, 0.2)))
    write("p9_warcry_female", mix(vo(240, 0.38, 0.4), tone(120, 0.38, 0.16)))
    write("p9_hurk_male", mix(vo(110, 0.32, 0.45), noise(0.28, 0.12, 4)))
    write("p9_hurk_female", mix(vo(175, 0.32, 0.42), noise(0.28, 0.1, 5)))
    write("p9_level", mix(tone(440, 0.18, 0.28), tone(660, 0.22, 0.2), tone(880, 0.26, 0.14)))
    return agent_log.emit_result("PASS", written=len(WRITTEN), dir="assets/audio")


if __name__ == "__main__":
    raise SystemExit(main())
