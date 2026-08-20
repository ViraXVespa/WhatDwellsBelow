"""Write tiny placeholder WAV loops and one-shot SFX. Final music is by Vira."""
from __future__ import annotations

import math
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "audio"
OUT.mkdir(parents=True, exist_ok=True)
SR = 22050


def write_wav(path: Path, samples: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = b"".join(
            struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples
        )
        w.writeframes(frames)
    print(f"wrote {path} ({len(samples) / SR:.2f}s)")


def env(i: int, n: int, attack: float = 0.01, release: float = 0.08) -> float:
    t = i / SR
    dur = n / SR
    a = min(1.0, t / attack) if attack > 0 else 1.0
    r = 1.0
    if t > dur - release and release > 0:
        r = max(0.0, (dur - t) / release)
    return a * r


def tone(freq: float, dur: float, amp: float = 0.18, kind: str = "tri") -> list[float]:
    n = int(SR * dur)
    out = []
    for i in range(n):
        ph = (i * freq / SR) % 1.0
        if kind == "sq":
            v = 1.0 if ph < 0.5 else -1.0
        elif kind == "noise":
            v = ((i * 1103515245 + 12345) % 32768) / 16384.0 - 1.0
        else:
            v = 4.0 * abs(ph - 0.5) - 1.0
        out.append(v * amp * env(i, n))
    return out


def mix(*parts: list[float]) -> list[float]:
    n = max(len(p) for p in parts)
    out = [0.0] * n
    for p in parts:
        for i, s in enumerate(p):
            out[i] += s
    peak = max(0.001, max(abs(s) for s in out))
    if peak > 0.95:
        out = [s * 0.95 / peak for s in out]
    return out


def pad(samples: list[float], dur: float) -> list[float]:
    n = int(SR * dur)
    if len(samples) >= n:
        return samples[:n]
    return samples + [0.0] * (n - len(samples))


def note(freq: float, start: float, dur: float, amp: float, kind: str = "tri") -> list[float]:
    head = [0.0] * int(SR * start)
    return pad(head + tone(freq, dur, amp, kind), start + dur + 0.02)


def loop_hub() -> None:
    # Slow, slightly warm fifths. 4 seconds, loops.
    bars = mix(
        note(196.0, 0.00, 0.70, 0.10),
        note(247.0, 0.00, 0.70, 0.07),
        note(220.0, 1.00, 0.70, 0.10),
        note(277.0, 1.00, 0.70, 0.06),
        note(196.0, 2.00, 0.70, 0.10),
        note(294.0, 2.00, 0.55, 0.07),
        note(175.0, 3.00, 0.90, 0.11),
        note(220.0, 3.00, 0.90, 0.06),
    )
    write_wav(OUT / "music_hub.wav", pad(bars, 4.0))


def loop_dungeon() -> None:
    bars = mix(
        note(110.0, 0.00, 0.90, 0.12, "sq"),
        note(146.8, 0.50, 0.40, 0.06),
        note(98.0, 1.20, 0.80, 0.11, "sq"),
        note(130.8, 1.70, 0.35, 0.05),
        note(110.0, 2.40, 0.70, 0.12, "sq"),
        note(164.8, 2.80, 0.30, 0.05),
        note(82.4, 3.30, 0.65, 0.13, "sq"),
    )
    write_wav(OUT / "music_dungeon.wav", pad(bars, 4.0))


def sfx() -> None:
    write_wav(OUT / "sfx_hit.wav", mix(tone(420, 0.07, 0.22, "sq"), tone(180, 0.09, 0.12, "noise")))
    write_wav(OUT / "sfx_slam.wav", mix(tone(90, 0.18, 0.28, "sq"), tone(50, 0.22, 0.18, "noise")))
    write_wav(OUT / "sfx_dash.wav", tone(640, 0.10, 0.14, "tri"))
    write_wav(OUT / "sfx_mine.wav", mix(tone(210, 0.08, 0.16, "noise"), tone(140, 0.10, 0.10, "sq")))
    write_wav(OUT / "sfx_smash.wav", mix(tone(300, 0.09, 0.2, "noise"), tone(90, 0.12, 0.14, "sq")))
    write_wav(OUT / "sfx_pickup.wav", mix(tone(660, 0.08, 0.14), tone(880, 0.10, 0.10)))
    write_wav(OUT / "sfx_ui.wav", tone(520, 0.05, 0.10, "tri"))
    write_wav(OUT / "sfx_level.wav", mix(tone(392, 0.12, 0.14), note(523, 0.10, 0.16, 0.12), note(659, 0.22, 0.20, 0.12)))
    write_wav(OUT / "sfx_hurt.wav", mix(tone(180, 0.11, 0.2, "sq"), tone(90, 0.14, 0.12, "noise")))


if __name__ == "__main__":
    loop_hub()
    loop_dungeon()
    sfx()
