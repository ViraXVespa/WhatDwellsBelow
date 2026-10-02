#!/usr/bin/env python3
from __future__ import annotations

import hmac
import json
import os
import subprocess
import threading
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse
import sys

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

import agent_log

HOST = "127.0.0.1"
PORT = 10536
TIMEOUT_SEC = 3600
CREATE_NO_WINDOW = 0x08000000
TOKEN_HEADER = "X-WDB-Scratch-Token"
TOKEN = ""

JOBS: dict[str, dict] = {}
JOBS_LOCK = threading.Lock()


ROOT: Path | None = None
SCRATCH: Path | None = None


def configure(root: Path, token: str) -> None:
    """Bind the repo root, scratch file, and token (called from main so --help never needs them)."""
    global ROOT, SCRATCH, TOKEN
    if not token or token == "REPLACE_WITH_A_LONG_RANDOM_TOKEN":
        agent_log.fail("set a real token in env WDB_SCRATCH_TOKEN")
    TOKEN = token
    ROOT = root
    SCRATCH = ROOT / "tools" / "_scratch.py"
    SCRATCH.parent.mkdir(parents=True, exist_ok=True)


def job_snapshot(job: dict) -> dict:
    return {
        "ok": True,
        "job_id": job["id"],
        "done": job["done"],
        "passed": job["passed"],
        "exit_code": job["exit_code"],
        "output": job["output"],
        "error": job["error"],
    }


def run_job(job_id: str, code: str) -> None:
    with JOBS_LOCK:
        job = JOBS[job_id]
    try:
        SCRATCH.write_text(code.replace("\r\n", "\n"), encoding="utf-8")
    except OSError as exc:
        with JOBS_LOCK:
            job["done"] = True
            job["passed"] = False
            job["exit_code"] = -1
            job["error"] = f"write failed: {exc}"
        return

    env = os.environ.copy()
    env["PYTHONUNBUFFERED"] = "1"
    env["PYTHONIOENCODING"] = "utf-8"
    kwargs = {
        "cwd": str(ROOT),
        "stdout": subprocess.PIPE,
        "stderr": subprocess.STDOUT,
        "env": env,
        "bufsize": 0,
    }
    if os.name == "nt":
        kwargs["creationflags"] = CREATE_NO_WINDOW

    try:
        proc = subprocess.Popen(["python", "-u", r"tools\_scratch.py"], **kwargs)
    except Exception as exc:
        with JOBS_LOCK:
            job["done"] = True
            job["passed"] = False
            job["exit_code"] = -1
            job["error"] = str(exc)
        return

    deadline = None if not TIMEOUT_SEC else time.monotonic() + TIMEOUT_SEC
    fd = proc.stdout.fileno()
    try:
        while True:
            if deadline is not None and time.monotonic() >= deadline:
                proc.kill()
                try:
                    proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    pass
                with JOBS_LOCK:
                    job["done"] = True
                    job["passed"] = False
                    job["exit_code"] = -1
                    job["error"] = f"Timed out after {TIMEOUT_SEC}s."
                return

            if proc.poll() is not None:
                leftover = proc.stdout.read() or b""
                if leftover:
                    with JOBS_LOCK:
                        job["output"] += leftover.decode("utf-8", "replace")
                with JOBS_LOCK:
                    job["done"] = True
                    job["passed"] = proc.returncode == 0
                    job["exit_code"] = proc.returncode
                return

            try:
                raw = os.read(fd, 4096)
            except OSError:
                raw = b""
            if not raw:
                time.sleep(0.02)
                continue
            with JOBS_LOCK:
                job["output"] += raw.decode("utf-8", "replace")
    except Exception as exc:
        try:
            proc.kill()
        except Exception:
            pass
        with JOBS_LOCK:
            job["done"] = True
            job["passed"] = False
            job["exit_code"] = -1
            job["error"] = str(exc)


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        return

    def _json(self, status: int, payload: dict):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(body)

    def _authorized(self) -> bool:
        offered = self.headers.get(TOKEN_HEADER) or ""
        return hmac.compare_digest(offered.encode("utf-8"), TOKEN.encode("utf-8"))

    def do_OPTIONS(self):
        self.send_response(403)
        self.end_headers()

    def do_GET(self):
        if not self._authorized():
            self._json(401, {"ok": False, "error": "unauthorized"})
            return
        parsed = urlparse(self.path)
        if parsed.path.rstrip("/") != "/run-scratch":
            self._json(404, {"ok": False, "error": "not found"})
            return
        job_id = (parse_qs(parsed.query).get("job") or [""])[0]
        with JOBS_LOCK:
            job = JOBS.get(job_id)
            snap = job_snapshot(job) if job else None
        if not snap:
            self._json(404, {"ok": False, "error": "unknown job"})
            return
        self._json(200, snap)

    def do_POST(self):
        if urlparse(self.path).path.rstrip("/") != "/run-scratch":
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
        try:
            data = json.loads(self.rfile.read(length).decode("utf-8"))
            code = data.get("code", "")
            if not isinstance(code, str) or not code.strip():
                raise ValueError("missing code")
        except Exception as exc:
            self._json(400, {"ok": False, "error": str(exc)})
            return

        job_id = uuid.uuid4().hex
        job = {
            "id": job_id,
            "done": False,
            "passed": False,
            "exit_code": None,
            "output": "",
            "error": None,
            "started": time.time(),
        }
        with JOBS_LOCK:
            JOBS[job_id] = job
        threading.Thread(target=run_job, args=(job_id, code), daemon=True).start()
        self._json(200, {"ok": True, "job_id": job_id, "done": False, "output": ""})


def main(argv: list[str] | None = None) -> int:
    global HOST, PORT
    ap = agent_log.std_parser("Token-protected local HTTP runner for web scratch files (needs WDB_SCRATCH_TOKEN; WDB_ROOT is the --root default).")
    ap.add_argument("--host", default=HOST)
    ap.add_argument("--port", type=int, default=PORT)
    args = ap.parse_args(argv)
    HOST, PORT = args.host, args.port
    hint = args.root or os.environ.get("WDB_ROOT") or None
    configure(agent_log.repo_root(hint), os.environ.get("WDB_SCRATCH_TOKEN", ""))
    print(f"WDB scratch server on http://{HOST}:{PORT}")
    print(f"scratch file: {agent_log.rel(ROOT, SCRATCH)}")
    agent_log.emit_result("INFO", status="listening", host=HOST, port=PORT)
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
