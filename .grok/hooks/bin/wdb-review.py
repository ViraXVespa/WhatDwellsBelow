#!/usr/bin/env python3
"""JSON-protocol staged review hook entry; copied with its policy library."""
import sys
from pathlib import Path

here = Path(__file__).resolve().parent
library = here if (here / "review_policy.py").is_file() else here.parents[2] / "tools/lib/shots"
sys.path.insert(0, str(library))
from review_policy import main

if __name__ == "__main__":
    raise SystemExit(main())
