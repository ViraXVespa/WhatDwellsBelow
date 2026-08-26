"""Tiny placeholder wavs for Phase 2 combat (Section 14 placeholder policy)."""
from __future__ import annotations

import math
import struct
import wave
from pathlib import Path

OUT = Path("assets/audio")
OUT.mkdir(parents=True, exist_ok=True)
SR = 22050


def write(name: str, samples: list[float]) -> None:
    path = OUT / f"p2_{name}.wav"
    with wave.open(str(path), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32000)) for s in samples)
        w.writeframes(frames)
    print("sfx", path)


def tone(freq: float, dur: float, vol: float = 0.35, decay: bool = True) -> list[float]:
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        env = (1.0 - t / dur) if decay else 1.0
        out.append(vol * env * math.sin(2 * math.pi * freq * t))
    return out


def noise(dur: float, vol: float = 0.2) -> list[float]:
    n = int(SR * dur)
    x = 0.0
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


if __name__ == "__main__":
    write("hit", mix(tone(180, 0.08, 0.4), noise(0.09, 0.25)))
    write("crit", mix(tone(520, 0.12, 0.35), tone(780, 0.12, 0.25)))
    write("slam", mix(tone(70, 0.22, 0.5), noise(0.2, 0.35)))
    write("dash", tone(240, 0.14, 0.25))
    write("warcry", mix(tone(220, 0.28, 0.35), tone(330, 0.28, 0.2)))
    write("bolt", mix(tone(880, 0.16, 0.3), noise(0.16, 0.2)))
    write("bow", tone(420, 0.07, 0.28))
    loop = tone(90, 0.4, 0.12, False) + tone(110, 0.4, 0.1, False)
    write("adrenaline_loop", mix(loop, noise(0.8, 0.05)))
