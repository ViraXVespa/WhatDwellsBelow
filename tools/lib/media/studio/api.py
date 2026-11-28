"""Studio JSON routes. One function per route; the HTTP handler maps method + path here."""
from __future__ import annotations

import re
import threading
from urllib.parse import parse_qs, urlparse

from .backend import COMMANDS, GUARDED, ApiError, Backend, NotWired
from .jobs import Job, Registry
from . import steps as step_flow

PREFIX = "/api/studio"
SOFT_CMDS = {"review", "correct", "tune", "frame", "smooth", "body", "edit"}


class Api:
    def __init__(self, backend: Backend, registry: Registry) -> None:
        self.b = backend
        self.jobs = registry
        self._start_lock = threading.Lock()
        self.routes = [
            ("GET", r"/info", self.info),
            ("GET", r"/prompts", lambda q, body: self.b.prompts()),
            ("GET", r"/coverage", lambda q, body: self.b.coverage()),
            ("GET", r"/subjects", lambda q, body: {"subjects": self.b.list_subjects()}),
            ("POST", r"/subjects", lambda q, body: {"subject": self.b.create(body)}),
            ("GET", r"/subjects/(?P<sid>[a-z0-9_-]+)", lambda q, body, sid: self.show(sid)),
            ("POST", r"/subjects/(?P<sid>[a-z0-9_-]+)/steps/(?P<step>[a-z0-9_-]+)", lambda q, body, sid, step: self.b.set_step(sid, step, body)),
            ("POST", r"/subjects/(?P<sid>[a-z0-9_-]+)/overrides", lambda q, body, sid: self.b.set_overrides(sid, body)),
            ("POST", r"/subjects/(?P<sid>[a-z0-9_-]+)/sections/(?P<sec>[a-z0-9_-]+)", lambda q, body, sid, sec: self.b.save_section(sid, sec, body)),
            ("POST", r"/subjects/(?P<sid>[a-z0-9_-]+)/links", lambda q, body, sid: {"subject": self.b.link(sid, body)}),
            ("POST", r"/subjects/(?P<sid>[a-z0-9_-]+)/mark", lambda q, body, sid: {"subject": self.b.mark(sid, body)}),
            ("POST", r"/subjects/(?P<sid>[a-z0-9_-]+)/clear", lambda q, body, sid: {"subject": self.b.clear_flag(sid, body)}),
            ("POST", r"/subjects/(?P<sid>[a-z0-9_-]+)/reference", lambda q, body, sid: {"reference": self.b.set_reference(sid, body)}),
            ("POST", r"/subjects/(?P<sid>[a-z0-9_-]+)/stills", lambda q, body, sid: self.b.set_still_state(sid, body)),
            ("GET", r"/jobs", lambda q, body: {"jobs": self.jobs.rows()}),
            ("POST", r"/jobs", self.start_job),
            ("GET", r"/jobs/(?P<jid>[a-f0-9]+)", self.job),
            ("POST", r"/jobs/(?P<jid>[a-f0-9]+)/cancel", self.cancel_job),
        ]

    def handle(self, method: str, raw_path: str, body: dict) -> tuple[int, dict]:
        url = urlparse(raw_path)
        path = url.path[len(PREFIX):] or "/"
        query = {k: v[-1] for k, v in parse_qs(url.query).items()}
        for m, pattern, fn in self.routes:
            match = re.fullmatch(pattern, path)
            if match and m == method:
                try:
                    return 200, fn(query, body, **match.groupdict())
                except ApiError as exc:
                    return exc.status, {"error": exc.message, **exc.extra}
                except ValueError as exc:
                    return 400, {"error": str(exc)}
        return 404, {"error": f"no route {method} {url.path}"}

    def info(self, q: dict, body: dict) -> dict:
        busy = self.jobs.busy_gpu()
        return {**self.b.info(), "busy": busy.row() if busy else None}

    def job(self, q: dict, body: dict, jid: str) -> dict:
        job = self.jobs.get(jid)
        if job is None:
            raise ApiError(404, "no such job")
        try:
            since = int(q.get("since") or 0)
        except ValueError:
            since = 0
        return job.view(since)

    def cancel_job(self, q: dict, body: dict, jid: str) -> dict:
        job = self.jobs.get(jid)
        if job is None:
            raise ApiError(404, "no such job")
        if job.status not in ("queued", "running"):
            return job.row()
        self.b.cancel(job)
        job.emit("log", "cancel requested")
        return job.row()

    def show(self, sid: str) -> dict:
        busy = {j.step: j.id for j in self.jobs.jobs.values() if j.subject == sid and j.step and j.status in ("queued", "running")}
        return self.b.show(sid, busy)

    def start_job(self, q: dict, body: dict) -> dict:
        cmd = str(body.get("cmd") or "")
        sid = body.get("subject") or None
        args = body.get("args") or {}
        if not isinstance(args, dict):
            raise ApiError(400, "args must be an object")
        if sid and (sid, cmd) in GUARDED:
            raise ApiError(403, f"{step_flow.ACTION_LABELS.get(cmd, cmd)} does not run on this subject from the studio.")
        step = self.b.check_step_job(cmd, sid, body.get("step")) if sid and cmd in COMMANDS else None
        if step and "workflow" in {f["name"] for f in COMMANDS[cmd]["fields"]}:
            args.setdefault("workflow", f"data/pipeline/recipes/{self.b._load(sid)['type']}/{step}.json")
        self.b.precheck(cmd, sid, args)
        adjusted = self.b.check_overrides(cmd, sid, step) if sid and step else {}
        if cmd == "export":
            self.b.export_check(sid, args)
        note = None
        if sid and cmd in SOFT_CMDS:
            soft = self.b.show(sid)["subject"]["dirty"]["soft"]
            if soft and not body.get("ack_soft"):
                raise ApiError(409, "Something earlier changed. Check these pictures still fit before making more.", soft=soft)
            if soft:
                try:
                    self.b.clear_soft(sid)
                except NotWired as exc:
                    note = exc.message
        inner = self.b.body_for(cmd, sid, args)

        def run(job: Job) -> dict:
            if adjusted:
                keys = [k for k in ("prompt", "negative") if adjusted.get(k)] + sorted((adjusted.get("settings") or {}).keys())
                job.emit("log", "Using your adjusted settings: " + ", ".join(keys))
            result = inner(job)
            if adjusted and isinstance(result, dict):
                result["adjusted"] = adjusted
            return result

        spec = COMMANDS[cmd]
        with self._start_lock:
            busy = self.jobs.busy_gpu()
            if spec["gpu"] and busy is not None:
                raise ApiError(409, f"{step_flow.ACTION_LABELS.get(busy.cmd, busy.cmd)} is running. One model job runs at a time; try again when it finishes.", busy=busy.row())
            job = Job(cmd, sid, args, gpu=spec["gpu"], simulated=self.b.simulated)
            job.step = step
            job = self.jobs.start(job, run)
        out = job.row()
        if note:
            out["soft_note"] = note
        return out
