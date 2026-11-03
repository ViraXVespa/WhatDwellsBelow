#!/usr/bin/env python3
"""Local playtester trainer and recommend-only balance tuner.

Default run trains from recorded decisions and writes a report. It does not launch Godot.
--live measures headless speed and runs the short tuner. --selftest needs no Godot and no torch.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import boot  # noqa: E402

MODULE = "tuner/run_tuner"

if __name__ == "__main__":
    raise SystemExit(boot.forward(__file__, MODULE))
