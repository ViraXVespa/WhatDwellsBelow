#!/usr/bin/env python3
"""Agent sessions and run logs: read a job summary, dump or share a session, clean logs, one-off scripts.

`python tools/session.py` lists the subcommands; `python tools/session.py SUB --help` prints that one's flags.
The work lives in tools/lib/session/ (one module per subcommand); this file only maps names to modules.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
import boot  # noqa: E402

COMMANDS = [  # (subcommand, module under tools/lib/, what it does)
    ("summary",         "session/read_summary",           "A job's last run: index plus the newest summary (JOB)"),
    ("dump",            "session/session_dump",           "Dump a recent Grok session into one file"),
    ("share",           "session/grok_share",             "Pull a Grok share URL's conversation and images"),
    ("clean",           "session/clean_agent_logs",       "Delete raw logs under _logs/ (--new-week for the weekly clean)"),
    ("py",              "session/run_agent_py",           "Run a one-off script from _logs/agent-py/ and delete it"),
    ("scratch-server",  "session/wdb_scratch_server",     "Token-protected local HTTP runner for web/chat scratch (User setup)"),
]

if __name__ == "__main__":
    raise SystemExit(boot.dispatch(__file__, __doc__, COMMANDS))
