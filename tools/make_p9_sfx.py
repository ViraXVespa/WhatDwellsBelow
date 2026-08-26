"""Appendix E remaining SFX + gendered VO stand-ins."""
from __future__ import annotations

import math
import struct
import wave
from pathlib import Path

OUT = Path("assets/audio")
OUT.mkdir(parents=True, exist_ok=True)
SR = 22050


def write(name: str, samples: list[float]) -> None:
    path = OUT / f"{name}.wav"
    with wave.open(str(path), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 30000)) for s in samples)
        w.writeframes(frames)
    print("sfx", path)


def tone(freq: float, dur: float, vol: float = 0.35, decay: bool = True) -> list[float]:
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        env = (1.0 - t / dur) ** 0.7 if decay else 1.0
        out.append(vol * env * math.sin(2 * math.pi * freq * t))
    return out


def noise(dur: float, vol: float = 0.2, seed: int = 1) -> list[float]:
    n = int(SR * dur)
    x = seed
    out = []
    for i in range(n):
        x = (x * 1103515245 + 12345) % 2**31
        env = 1.0 - i / n
        out.append(vol * env * ((x / 2**30) - 1.0))
    return out


def mix(*parts: list[float]) -> list[float]:
    n = max(len(p) for p in parts)
    out = [0.0] * n
    for p in parts:
        for i, s in enumerate(p):
            out[i] += s
    return out


def vo(base: float, dur: float, vol: float) -> list[float]:
    return mix(tone(base, dur, vol), tone(base * 1.5, dur, vol * 0.35), noise(dur, 0.06, int(base)))


if __name__ == "__main__":
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
