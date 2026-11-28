"""Job registry for the studio. Jobs run in threads; the page polls events by sequence number.

The registry is kept in memory and mirrored to one JSON file so a reload (or a server restart)
still lists finished jobs. A job that was running when the server stopped comes back as `lost`.
"""
from __future__ import annotations

import json
import threading
import time
import uuid
from pathlib import Path
from typing import Callable

ACTIVE = ("queued", "running")
KEEP = 60  # finished jobs kept in the file


class Cancelled(Exception):
    """Raised inside a job body when the page asked to cancel."""


class Job:
    def __init__(self, cmd: str, subject: str | None, args: dict, *, gpu: bool, simulated: bool) -> None:
        self.id = uuid.uuid4().hex[:12]
        self.cmd = cmd
        self.subject = subject
        self.args = args
        self.gpu = gpu
        self.simulated = simulated
        self.status = "queued"
        self.stage = ""
        self.pct = 0.0
        self.events: list[dict] = []
        self.result: dict | None = None
        self.error: str | None = None
        self.created = time.time()
        self.finished: float | None = None
        self.cancel_requested = False
        self.cancel_hook: Callable[[], None] | None = None
        self.step: str | None = None
        self._lock = threading.Lock()

    # Called from the job body.
    def emit(self, kind: str, msg: str = "", pct: float | None = None, **extra: object) -> None:
        with self._lock:
            if pct is not None:
                self.pct = max(0.0, min(100.0, float(pct)))
            if kind == "stage":
                self.stage = msg
            self.events.append({"seq": len(self.events) + 1, "t": round(time.time(), 3), "kind": kind,
                                "msg": msg, "pct": round(self.pct, 1), **extra})
            if len(self.events) > 2000:
                self.events = self.events[-2000:]

    def check_cancel(self) -> None:
        if self.cancel_requested:
            raise Cancelled()

    def sleep(self, seconds: float) -> None:
        end = time.time() + seconds
        while time.time() < end:
            self.check_cancel()
            time.sleep(min(0.05, max(0.0, end - time.time())))
        self.check_cancel()

    def view(self, since: int = 0) -> dict:
        with self._lock:
            return {
                "id": self.id, "cmd": self.cmd, "subject": self.subject, "args": self.args,
                "status": self.status, "stage": self.stage, "pct": round(self.pct, 1),
                "simulated": self.simulated, "gpu": self.gpu, "step": self.step,
                "created": self.created, "finished": self.finished,
                "result": self.result, "error": self.error,
                "events": [e for e in self.events if e["seq"] > since],
                "last_seq": self.events[-1]["seq"] if self.events else 0,
            }

    def row(self) -> dict:
        v = self.view(10 ** 9)
        v.pop("events")
        return v


class Registry:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.jobs: dict[str, Job] = {}
        self._lock = threading.Lock()
        self._load()

    def _load(self) -> None:
        if not self.path.is_file():
            return
        try:
            rows = json.loads(self.path.read_text(encoding="utf-8")).get("jobs") or []
        except (OSError, ValueError):
            return
        for row in rows:
            job = Job(row.get("cmd", "?"), row.get("subject"), row.get("args") or {},
                      gpu=bool(row.get("gpu")), simulated=bool(row.get("simulated")))
            job.id = row.get("id", job.id)
            job.status = row.get("status", "lost")
            if job.status in ACTIVE:
                job.status = "lost"
                job.error = "The studio server stopped while this job ran."
            job.stage = row.get("stage", "")
            job.step = row.get("step")
            job.pct = float(row.get("pct") or 0)
            job.result = row.get("result")
            job.error = job.error or row.get("error")
            job.created = float(row.get("created") or 0)
            job.finished = row.get("finished")
            job.events = list(row.get("events") or [])
            self.jobs[job.id] = job

    def save(self) -> None:
        with self._lock:
            jobs = sorted(self.jobs.values(), key=lambda j: j.created)
            done = [j for j in jobs if j.status not in ACTIVE][-KEEP:]
            keep = [j for j in jobs if j.status in ACTIVE or j in done]
            rows = []
            for j in keep:
                v = j.view(0)
                v["events"] = v["events"][-200:]
                rows.append(v)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.path.with_suffix(".tmp")
        tmp.write_text(json.dumps({"schema": "wdb.studio.jobs/1", "jobs": rows}, indent=1) + "\n", encoding="utf-8")
        tmp.replace(self.path)

    def busy_gpu(self) -> Job | None:
        with self._lock:
            for j in self.jobs.values():
                if j.gpu and j.status in ACTIVE:
                    return j
        return None

    def get(self, job_id: str) -> Job | None:
        return self.jobs.get(job_id)

    def rows(self) -> list[dict]:
        return [j.row() for j in sorted(self.jobs.values(), key=lambda j: -j.created)]

    def start(self, job: Job, body: Callable[[Job], dict]) -> Job:
        with self._lock:
            self.jobs[job.id] = job
        self.save()

        def run() -> None:
            job.status = "running"
            job.emit("stage", "Starting", 0)
            try:
                job.result = body(job) or {}
                job.status = "done" if job.result.get("ok", True) else "failed"
                job.emit("stage", "Done" if job.status == "done" else "Finished with a fail", 100)
            except Cancelled:
                job.status = "cancelled"
                job.emit("stage", "Cancelled")
            except Exception as exc:  # the page shows the message; the log keeps the detail
                job.status = "error"
                job.error = str(exc) or exc.__class__.__name__
                job.emit("log", f"error: {job.error}")
            finally:
                job.finished = time.time()
                self.save()

        threading.Thread(target=run, name=f"studio-job-{job.id}", daemon=True).start()
        return job
