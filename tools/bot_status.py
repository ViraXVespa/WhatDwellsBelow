#!/usr/bin/env python3
"""Bot punch list (reuse brief, open opt tasks); `--prove` adds the Bot checks, diff drift and textsize --gate when UI scripts changed. Bot/CI only; elsewhere it prints "not run".

Stable entry for CI (bot-gate.yml, bot-wake.yml) and BOT.md. The work lives in tools/lib/checks/bot_punch_list.py.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import boot  # noqa: E402

MODULE = "checks/bot_punch_list"

if __name__ == "__main__":
    raise SystemExit(boot.forward(__file__, MODULE))
