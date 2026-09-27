#!/usr/bin/env python3
"""Local companion for the WDB scratch Tampermonkey button.

Listens on 127.0.0.1:10536 only. Requires X-WDB-Scratch-Token.
"""

from __future__ import annotations

import hmac
import json
import os
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HOST = "127.0.0.1"
PORT = 10536
TIMEOUT_SEC = 60
CREATE_NO_WINDOW = 0x08000000
TOKEN_HEADER = "X-WDB-Scratch-Token"

# Same value as TOKEN in the Tampermonkey script.
# Override with env WDB_SCRATCH_TOKEN if you prefer not to hardcode it.
TOKEN = os.environ.get("WDB_SCRATCH_TOKEN") or "REPLACE_WITH_A_LONG_RANDOM_TOKEN"


def fail(msg: str) -> None:
    print(msg, file=sys.stderr)
    sys.exit(1)


if not TOKEN or TOKEN == "REPLACE_WITH_A_LONG_RANDOM_TOKEN":
    fail("Set a real token in TOKEN or env WDB_SCRATCH_TOKEN.")

WDB_ROOT = os.environ.get("WDB_ROOT")
if not WDB_ROOT:
    fail("WDB_ROOT is not set in the environment.")

ROOT = Path(WDB_ROOT).expanduser().resolve()
if not ROOT.is_dir():
    fail(f"WDB_ROOT is not a directory: {ROOT}")

SCRATCH = ROOT / "tools" / "_scratch.py"
SCRATCH.parent.mkdir(parents=True, exist_ok=True)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        return

    def _json(self, status: int, payload: dict):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _authorized(self) -> bool:
        offered = self.headers.get(TOKEN_HEADER) or ""
        return hmac.compare_digest(offered.encode("utf-8"), TOKEN.encode("utf-8"))

    def do_OPTIONS(self):
        # No CORS. Browser page JS should fail preflight.
        self.send_response(403)
        self.end_headers()

    def do_GET(self):
        self._json(405, {"ok": False, "error": "POST only"})

    def do_POST(self):
        if self.path.rstrip("/") != "/run-scratch":
            self._json(404, {"ok": False, "error": "not found"})
            return

        if not self._authorized():
            self._json(401, {"ok": False, "error": "unauthorized"})
            return

        ctype = (self.headers.get("Content-Type") or "").split(";")[0].strip().lower()
        if ctype != "application/json":
            self._json(415, {"ok": False, "error": "application/json required"})
            return

        length = int(self.headers.get("Content-Length") or 0)
        if length <= 0 or length > 2_000_000:
            self._json(400, {"ok": False, "error": "invalid body length"})
            return

        raw = self.rfile.read(length)
        try:
            data = json.loads(raw.decode("utf-8"))
            code = data.get("code", "")
            if not isinstance(code, str) or not code.strip():
                raise ValueError("missing code")
        except Exception as exc:
            self._json(400, {"ok": False, "error": str(exc)})
            return

        try:
            SCRATCH.write_text(code.replace("\r\n", "\n"), encoding="utf-8")
        except OSError as exc:
            self._json(500, {"ok": False, "error": f"write failed: {exc}"})
            return

        kwargs = {
            "cwd": str(ROOT),
            "capture_output": True,
            "text": True,
            "encoding": "utf-8",
            "errors": "replace",
            "timeout": TIMEOUT_SEC,
        }
        if os.name == "nt":
            kwargs["creationflags"] = CREATE_NO_WINDOW

        try:
            proc = subprocess.run(["python", r"tools\_scratch.py"], **kwargs)
            output = "".join([proc.stdout or "", proc.stderr or ""])
            self._json(
                200,
                {
                    "ok": True,
                    "exit_code": proc.returncode,
                    "passed": proc.returncode == 0,
                    "output": output,
                },
            )
        except subprocess.TimeoutExpired:
            self._json(
                200,
                {
                    "ok": True,
                    "exit_code": -1,
                    "passed": False,
                    "output": f"Timed out after {TIMEOUT_SEC}s.",
                },
            )
        except Exception as exc:
            self._json(500, {"ok": False, "error": str(exc)})


if __name__ == "__main__":
    print(f"WDB scratch server on http://{HOST}:{PORT}")
    print(f"scratch file: {SCRATCH}")
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()