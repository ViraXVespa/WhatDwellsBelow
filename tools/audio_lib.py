#!/usr/bin/env python3
"""Shared synth + WAV helpers for the placeholder audio tools (make_*).

Import-only. Mono 22.05 kHz 16-bit. Outputs must stay byte-identical to the
committed assets: change a helper here only with a regenerate-and-diff proof.
"""
from __future__ import annotations

import math
import struct
import wave
from pathlib import Path

SR = 22050


def write_wav(path: Path, samples: list[float], scale: int = 32000) -> None:
    """Clip to +-1.0 then scale (the p2/p9 sfx writer)."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * scale)) for s in samples))


def write_pcm(path: Path, samples: list[float]) -> None:
    """Scale by 32767 then clamp (the music/placeholder writer)."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples))


def sine(freq: float, dur: float, vol: float = 0.35, decay: bool = True, power: float = 1.0) -> list[float]:
    """Sine with envelope (1 - t/dur) ** power. power 1.0 is the p2 linear fade, 0.7 the p9 one."""
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        env = (1.0 - t / dur) ** power if decay else 1.0
        out.append(vol * env * math.sin(2 * math.pi * freq * t))
    return out


def noise(dur: float, vol: float = 0.2, seed: float = 1) -> list[float]:
    """LCG noise with a linear fade. seed 0.0 (float) reproduces the p2 stream, ints the p9 one."""
    n = int(SR * dur)
    x = seed
    out = []
    for i in range(n):
        x = (x * 1103515245 + 12345) % 2**31
        out.append(vol * (1.0 - i / n) * ((x / 2**30) - 1.0))
    return out


def mix(*parts: list[float]) -> list[float]:
    n = max(len(p) for p in parts)
    out = [0.0] * n
    for p in parts:
        for i, s in enumerate(p):
            out[i] += s
    return out


def mix_norm(*parts: list[float]) -> list[float]:
    """mix, then scale down when the peak passes 0.95 (placeholder music)."""
    out = mix(*parts)
    peak = max(0.001, max(abs(s) for s in out))
    return [s * 0.95 / peak for s in out] if peak > 0.95 else out
