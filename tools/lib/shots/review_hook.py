#!/usr/bin/env python3
"""JSON staged-hook entry, bundled beside its policy; no repository hook edits."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
try:
    from review_policy import main
except ImportError:
    sys.stdout.write(json.dumps({"decision": "deny", "reason": "Staged review policy unavailable"}) + "\n")
    raise SystemExit(2)

if __name__ == "__main__":
    raise SystemExit(main())
