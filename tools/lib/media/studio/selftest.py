"""`media.py studio --selftest`: both backends on a temp repo, every type walked start to export in simulate."""
from __future__ import annotations

import json
import os
import shutil
import tempfile
import threading
import time
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

import agent_log
from media import mobile_ui_server as server_mod

from . import gaps, registry

STAND_IN = {"still": "x.png", "role": "mannequin-front", "path": "w.json", "glb": "x.glb", "text": "x"}


def call(base: str, method: str, path: str, body: dict | None = None) -> tuple[int, dict]:
    data = json.dumps(body).encode() if body is not None else None
    req = Request(base + path, data=data, method=method, headers={"Content-Type": "application/json"})
    try:
        with urlopen(req, timeout=20) as resp:
            return resp.status, json.loads(resp.read() or b"{}")
    except HTTPError as exc:
        return exc.code, json.loads(exc.read() or b"{}")


def _fixture(real: Path) -> Path:
    tmp = Path(tempfile.mkdtemp(prefix="wdb-studio-"))
    for rel in ("data/pipeline/prompts", "data/pipeline/schemas"):
        shutil.copytree(real / rel, tmp / rel)
    (tmp / "data/pipeline/export").mkdir(parents=True)
    (tmp / "data/pipeline/export/index.json").write_text('{"schema": "wdb.export.index/1", "subjects": []}\n', encoding="utf-8")
    (tmp / "assets/sprites/enemies/slime").mkdir(parents=True)
    return tmp


def sample(fd: dict):
    """A value that satisfies one registry field."""
    kind, opts = fd["kind"], fd.get("options") or []
    if kind in ("text", "long"):
        return f"{fd['label']} sample"
    if kind == "number":
        return fd.get("default") if fd.get("default") is not None else (fd.get("min") if fd.get("min") is not None else 1)
    if kind == "choice":
        return fd.get("default") or opts[0]
    if kind == "multi":
        return sorted(set(fd.get("default") or opts[:1]) | set(fd.get("must") or []))
    if kind == "subject":
        return ""
    if kind == "bool":
        return True
    if kind == "color":
        return "#a0b0c0"
    if kind == "list":
        return ["one"]
    if kind == "table":
        return [{c["key"]: sample(c) for c in fd["columns"]}]
    if kind == "group":
        return {c["key"]: sample(c) for c in fd["fields"]}
    return "x"


class Walk:
    def __init__(self, base: str, bad: list[str], tag: str):
        self.base, self.bad, self.tag = base, bad, tag
        self.commands = call(base, "GET", "/api/studio/info")[1]["commands"]

    def miss(self, msg: str) -> None:
        self.bad.append(f"{self.tag}: {msg}")

    def subject(self, sid: str) -> dict:
        return call(self.base, "GET", f"/api/studio/subjects/{sid}")[1]

    def row(self, sid: str, step: str) -> dict:
        return next(s for s in self.subject(sid)["steps"] if s["id"] == step)

    def pics(self, sid: str, step: str) -> list[dict]:
        return [s for s in self.subject(sid)["stills"] if s.get("step") == step]

    def judge(self, sid: str, path: str, state: str, step: str | None = None) -> int:
        return call(self.base, "POST", f"/api/studio/subjects/{sid}/stills", {"path": path, "state": state, **({"step": step} if step else {})})[0]

    def finish(self, sid: str, step: str, want: int = 200) -> dict:
        code, out = call(self.base, "POST", f"/api/studio/subjects/{sid}/steps/{step}", {"action": "finish"})
        if code != want:
            self.miss(f"{sid} finish {step} gave {code} {out.get('error')} {out.get('missing') or ''}")
        return out

    def args(self, cmd: str, clip: str | None = None) -> dict:
        out = {}
        for fd in self.commands[cmd].get("fields", []):
            if fd.get("required"):
                out[fd["name"]] = clip or "walk" if fd["kind"] == "clip" else (fd.get("options") or [None])[0] or STAND_IN.get(fd["kind"], "x")
        return out

    def run(self, sid: str, cmd: str, step: str, args: dict | None = None, want: int = 200) -> dict:
        code, job = call(self.base, "POST", "/api/studio/jobs", {"cmd": cmd, "subject": sid, "step": step, "args": self.args(cmd) if args is None else args, "ack_soft": True})
        if code != want:
            self.miss(f"{sid} {cmd} on {step} gave {code} {job.get('error')}")
        if code != 200:
            return job
        end = time.time() + 30
        while time.time() < end:
            job = call(self.base, "GET", f"/api/studio/jobs/{job['id']}")[1]
            if job.get("status") not in ("queued", "running"):
                break
            time.sleep(0.05)
        if job.get("status") != "done" or not (job.get("result") or {}).get("simulated"):
            self.miss(f"{sid} {cmd} on {step} ended {job.get('status')} {job.get('error')}")
        return job

    def fill(self, sid: str, step: str) -> dict:
        data = {fd["key"]: sample(fd) for fd in registry.step_spec(self.subject(sid)["subject"]["type"], step)["fields"]}
        code, out = call(self.base, "POST", f"/api/studio/subjects/{sid}/sections/{step}", {"data": data})
        if code != 200:
            self.miss(f"{sid} save {step} gave {code} {out.get('error')}")
        return data

    def make(self, sid: str, row: dict, data: dict) -> None:
        """Produce what the step needs, approve it all, finish."""
        acts, step = row["actions"], row["id"]
        if "mesh" in row["needs"]:
            self.run(sid, "smooth", step)
        elif "pictures" in row["needs"]:
            cmd = next(a for a in ("generate", "variant", "tile", "icon", "overlay") if a in acts)
            self.run(sid, cmd, step)
        if "clips" in row["needs"]:
            for clip in data.get("clips") or []:
                self.run(sid, "animate", step, {"clip": clip})
        for s in self.pics(sid, step):
            if s["state"] == "pending":
                self.judge(sid, s["path"], "approved")
        self.finish(sid, step)

    def through(self, sid: str, order: list[str] | None = None) -> None:
        """Every step after Start, groups walked back to front, then export."""
        rows = self.subject(sid)["steps"]
        ids = order or [r["id"] for r in rows]
        seen: set[str] = set()
        for rid in ids:
            row = next(r for r in rows if r["id"] == rid)
            if rid in seen or row["status"] == "done":
                continue
            members = [r for r in rows if row.get("group") and r.get("group") == row["group"]] or [row]
            for m in reversed(members) if len(members) > 1 else members:
                seen.add(m["id"])
                if m["id"] == "export":
                    out = self.run(sid, "export", "export", {})
                    if self.row(sid, "export")["status"] != "done":
                        self.miss(f"{sid} export did not finish ({out.get('error')})")
                    continue
                data = self.fill(sid, m["id"]) if m["fields"] else {}
                self.make(sid, self.row(sid, m["id"]), data)


def _real(w: Walk, sid: str) -> None:
    base, miss = w.base, w.miss

    def post_job(cmd: str, step: str, args: dict) -> tuple[int, dict]:
        return call(base, "POST", "/api/studio/jobs", {"cmd": cmd, "subject": sid, "step": step, "args": args, "ack_soft": True})

    code, out = post_job("reference", "start", {})
    if code != 501 or out.get("not_wired") != "action:reference":
        miss(f"reference ingest should be not set up ({code} {out.get('not_wired')})")
    code, out = post_job("body", "body", {})
    if code != 409 or out.get("gate") != "steps":
        miss(f"body before earlier steps should 409 gate=steps ({code} {out})")
    w.finish(sid, "start")
    w.finish(sid, "details", 409)
    w.fill(sid, "details")
    w.finish(sid, "details")
    code, out = post_job("body", "body", {})
    if code != 409 or out.get("gate") != "approvals":
        miss(f"body without approved plates should 409 ({code} {out})")
    code, out = post_job("generate", "body", {})
    if code != 501 or out.get("not_wired") != "action:generate" or "not set up yet" not in out.get("error", ""):
        miss(f"generate should be not set up yet ({code} {out})")
    code, out = post_job("tune", "body", {"image": "x.png", "role": "mannequin-front"})
    if code != 501 or out.get("not_wired") != "recipe:character/body":
        miss(f"tune without a default recipe should be not set up yet ({code} {out})")
    call(base, "POST", f"/api/studio/subjects/{sid}/overrides", {"step": "body", "prompt": "taller", "settings": {"seed": 7}})
    code, out = post_job("smooth", "body", {})
    if code != 501 or out.get("not_wired") != "step-overrides":
        miss(f"adjusted settings should be not wired ({code} {out})")
    code, info = call(base, "GET", "/api/studio/info")
    reg = info.get("registry") or {}
    body = next((s for s in reg.get("types", {}).get("character", {}).get("steps", []) if s["id"] == "body"), {})
    gen = next((a for a in body.get("actions", []) if a["id"] == "generate"), {})
    if gen.get("ok") is not False or not reg.get("setups"):
        miss(f"registry in info should mark generate not ready ({gen})")


def _sim(w: Walk, tmp: Path, sid: str) -> None:
    base, miss = w.base, w.miss
    if (tmp / "data/pipeline/wip/index.json").read_text(encoding="utf-8").count('"id"') != 1:
        miss("a simulated subject reached the real store")
    info = call(base, "GET", "/api/studio/info")[1]
    plans = info.get("steps") or {}
    if len(plans) != 14 or any(v[0]["id"] != "start" or v[-1]["id"] != "export" for v in plans.values()):
        miss("every type plan is start, sections, export")
    plan = info["steps"]
    names = {t: {s["id"]: s["label"] for s in rows} for t, rows in plan.items()}
    if (names["resource"]["recipes"], names["building"]["interior"], names["vfx"]["attach"]) != ("Gather node", "Interior", "Attach points"):
        miss(f"plain step names for the renamed steps ({names['resource']}, {names['building']}, {names['vfx']})")
    reg = info["registry"]["types"]
    skills = next(fd for s in reg["equipment"]["steps"] if s["id"] == "skills" for fd in s["fields"] if fd["key"] == "xp")
    if skills["labels"].get("axe") != "Great Axe" or skills["labels"].get("hp") != "Hitpoints" or set(skills["labels"]) != set(skills["options"]):
        miss("every skill id needs its display name")
    if any(s["open"] for t in reg.values() for s in t["steps"]):
        miss("no step should still be an open question")
    gather = next(s for s in reg["resource"]["steps"] if s["id"] == "recipes")
    if {"tool", "hits", "chance", "rewards", "after_break", "per_floor", "rooms", "hit_vfx", "sounds"} - {fd["key"] for fd in gather["fields"]}:
        miss("gather node fields")
    interior = next(s for s in reg["building"]["steps"] if s["id"] == "interior")
    if {"tile", "variant"} - {a["id"] for a in interior["actions"]} or {"tiles", "decor"} - {fd["key"] for fd in interior["fields"]}:
        miss("interior needs tile set, decor and the tile and picture actions")
    if call(base, "POST", f"/api/studio/subjects/{sid}/prompts", {"detail": "x"})[0] != 404:
        miss("the old Prompts screen's save route should be gone")
    out = w.run(sid, "body", "body", want=409)
    if out.get("gate") != "steps" or out.get("blocked_by") != "start":
        miss(f"body before Start should say finish Start first ({out})")
    if call(base, "POST", f"/api/studio/subjects/{sid}/sections/details", {"data": {"notes": "x"}})[0] != 409:
        miss("details save before Start should 409")
    w.finish(sid, "start")
    # Empty and partly filled steps hold; a Done step refuses changes.
    out = w.finish(sid, "details", 409)
    if out.get("gate") != "finish" or out.get("reason") != "fields" or "What it is" not in out.get("error", ""):
        miss(f"details with nothing filled should say what is missing ({out})")
    w.fill(sid, "details")
    w.finish(sid, "details")
    if call(base, "POST", f"/api/studio/subjects/{sid}/sections/details", {"data": {"notes": "y"}})[0] != 409:
        miss("a Done step should refuse changes until reopened")
    # Body: plates gate, rejected pictures block until hidden, the 3D body is approved on the step.
    out = w.run(sid, "body", "body", want=409)
    if out.get("gate") != "approvals" or set(out.get("missing") or []) != {"front", "side"}:
        miss(f"body before plates should 409 missing front+side ({out})")
    w.fill(sid, "body")
    w.run(sid, "smooth", "body")
    plates = [s for s in w.pics(sid, "body") if s["kind"] == "still"]
    if len(plates) != 4 or not {"front", "side", "back"} <= {s.get("view") for s in plates}:
        miss(f"smooth pictures on the body step {[(s.get('view'), s['path']) for s in plates]}")
    for s in w.pics(sid, "body"):
        w.judge(sid, s["path"], "approved")
    w.judge(sid, plates[-1]["path"], "rejected")
    if w.finish(sid, "body", 409).get("reason") != "rejected":
        miss("a rejected picture should hold the step")
    w.judge(sid, plates[-1]["path"], "hidden")
    w.finish(sid, "body")
    # Auto-tune is a per-step toggle; Make pictures works with it off or on.
    w.fill(sid, "model")
    plain = w.run(sid, "generate", "model", {"count": 1})
    if (plain.get("result") or {}).get("tuned"):
        miss("generate with auto-tune off should not tune")
    code, out = call(base, "POST", f"/api/studio/subjects/{sid}/steps/model", {"action": "autotune", "on": True})
    if code != 200 or not next(s for s in out.get("steps", []) if s["id"] == "model").get("autotune"):
        miss(f"auto-tune toggle ({code} {out.get('error')})")
    if not (w.run(sid, "generate", "model", {"count": 1}).get("result") or {}).get("tuned"):
        miss("generate with auto-tune on should tune")
    code, out = call(base, "POST", f"/api/studio/subjects/{sid}/overrides", {"step": "model", "prompt": "Taller, longer legs.", "settings": {"seed": 42, "strength": 0.6}})
    if code != 200 or out.get("overrides", {}).get("model", {}).get("settings", {}).get("seed") != 42:
        miss(f"save overrides ({code} {out})")
    done = w.run(sid, "tune", "model", {"image": "x.png", "role": "mannequin-front", "turns": 2})
    if (done.get("result") or {}).get("adjusted", {}).get("prompt") != "Taller, longer legs.":
        miss("tune on model did not use the adjusted settings")
    if w.finish(sid, "model", 409).get("reason") not in ("pending", "no_mesh"):
        miss("model needs an approved 3D model")
    w.make(sid, w.row(sid, "model"), {})
    # Loose pictures land on a step by file name or view.
    from media.studio import backend as be
    if be.auto_step("character", "x/portrait-closeup.png", "still", "front") != "portrait" or be.auto_step("character", "x/hunyuan-a.glb", "mesh", None) != "body" or be.auto_step("enemy", "x/a.png", "still", "side") != "description":
        miss("loose pictures should be placed by name, then by view")
    # Reopening keeps later Done steps Done and marks them to look at again.
    call(base, "POST", f"/api/studio/subjects/{sid}/steps/details", {"action": "reopen"})
    row = w.row(sid, "body")
    if row["status"] != "done" or not row.get("stale") or row.get("stale_because") != "Details":
        miss(f"body should stay Done and be marked after reopening details ({row})")
    if w.run(sid, "generate", "portrait", want=409).get("gate") != "steps":
        miss("portrait should wait while details is open")
    w.finish(sid, "details")
    # Animation needs an approved clip for every listed clip, and an 8-direction walk.
    w.through(sid, ["portrait", "traits", "defaults", "equipment"])
    code, _ = call(base, "POST", f"/api/studio/subjects/{sid}/sections/animation", {"data": {"clips": ["idle"], "dirs": 8}})
    if w.finish(sid, "animation", 409).get("reason") != "fields":
        miss("animation without a walk should hold")
    data = w.fill(sid, "animation")
    w.run(sid, "animate", "animation", {"clip": data["clips"][0]})
    for s in w.pics(sid, "animation"):
        w.judge(sid, s["path"], "approved")
    out = w.finish(sid, "animation", 409)
    if out.get("reason") != "no_clips":
        miss(f"animation with clips missing should hold ({out.get('reason')})")
    w.make(sid, w.row(sid, "animation"), data)
    # Export: hard flags hold it unless bypassed; nothing reaches the real export index.
    call(base, "POST", f"/api/studio/subjects/{sid}/mark", {"reason": "locked-front"})
    out = w.run(sid, "export", "export", {}, want=409)
    if out.get("hard") != ["locked-front"]:
        miss(f"hard-dirty export not held ({out})")
    w.run(sid, "export", "export", {"bypass": True})
    if w.row(sid, "export")["status"] != "done":
        miss("export with bypass after every step")
    if (tmp / "data/pipeline/export/index.json").read_text(encoding="utf-8").count('"id"'):
        miss("export reached the real export index")
    if w.run(sid, "reference", "start", want=409).get("gate") != "locked":
        miss("Start is Done; reading a reference should ask to reopen")
    # Every other type, start to export, with every action its steps list.
    for t in registry.TYPES:
        if t == "character":
            continue
        code, made = call(base, "POST", "/api/studio/subjects", {"type": t, "name": f"Walk {t}"})
        tid = made.get("subject", {}).get("id")
        if code != 200 or not tid:
            miss(f"create {t}")
            continue
        w.finish(tid, "start")
        w.through(tid)
        for row in w.subject(tid)["steps"]:
            if row["status"] != "done":
                miss(f"{t}/{row['id']} ended {row['status']}")
    # Every action runs in simulate from a step that lists it.
    ran = set()
    for t, spec in registry.TYPES.items():
        for st in spec["steps"]:
            for a in registry.step_spec(t, st)["actions"]:
                ran.add(a)
    missing = set(registry.ACTIONS) - ran - {"export", "preview", "reference"}
    if missing:
        miss(f"actions no step lists: {sorted(missing)}")


def run(real: Path) -> int:
    bad: list[str] = [f"registry: {p}" for p in registry.check()]
    bad += [f"stale: {p} (run media.py studio --gaps)" for p in gaps.write(real, check=True)]
    tmp = _fixture(real)
    os.environ["WDB_PIPELINE_SIM_DELAY"] = "0"
    try:
        for sim in (False, True):
            srv = server_mod.make_server("127.0.0.1", 0, tmp, simulate=sim)
            threading.Thread(target=srv.serve_forever, daemon=True).start()
            base = f"http://127.0.0.1:{srv.server_address[1]}"
            tag = "sim" if sim else "real"
            try:
                code, info = call(base, "GET", "/api/studio/info")
                if code != 200 or info.get("simulated") is not sim or len(info.get("types", [])) != 14:
                    bad.append(f"{tag}: info")
                code, made = call(base, "POST", "/api/studio/subjects", {"type": "character", "name": f"Test {tag}"})
                sid = made.get("subject", {}).get("id")
                if code != 200 or not sid:
                    bad.append(f"{tag}: create {made}")
                    continue
                code, _ = call(base, "POST", "/api/studio/jobs", {"cmd": "edit", "subject": "female", "args": {"text": "x"}})
                if code != 403:
                    bad.append(f"{tag}: female edit was not refused ({code})")
                if call(base, "GET", "/api/studio/coverage")[0] != 200:
                    bad.append(f"{tag}: coverage")
                if call(base, "POST", f"/api/studio/subjects/{sid}/reference", {"kind": "post", "value": "https://x.com/a/status/1"})[0] != 200:
                    bad.append(f"{tag}: reference")
                w = Walk(base, bad, tag)
                _real(w, sid) if not sim else _sim(w, tmp, sid)
            finally:
                srv.shutdown()
                srv.server_close()
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    for line in bad:
        print(line)
    return agent_log.emit_result("FAIL" if bad else "PASS", summary="selftest", problems=len(bad))
