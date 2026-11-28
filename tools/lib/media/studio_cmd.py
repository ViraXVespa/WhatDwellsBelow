#!/usr/bin/env python3
"""Pipeline studio: the phone UI for the art and content pipeline, on 0.0.0.0:8189.

    python tools/media.py studio
    WDB_PIPELINE_SIMULATE=1 python tools/media.py studio      (fake long jobs, separate store)
    python tools/media.py studio --selftest

Open http://<lan-ip>:8189 on a phone on the same network. The closed Character Studio is at /legacy/.
WDB_PIPELINE_SIM_DELAY sets the seconds per simulated stage (default 0.8).
"""
from __future__ import annotations

import json
import shutil
import socket
import sys
import tempfile
import threading
import time
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib
import boot  # noqa: E402,F401

import agent_log
from media import mobile_ui_server as server_mod


def _lan_ip() -> str:
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("10.255.255.255", 1))
        return s.getsockname()[0]
    except OSError:
        return "127.0.0.1"
    finally:
        s.close()


def _serve(root: Path, host: str, port: int) -> int:
    sim = server_mod.simulate_on()
    try:
        server = server_mod.make_server(host, port, root)
    except OSError as exc:
        print(f"error: port {port}: {exc}", file=sys.stderr)
        return 2
    mode = "SIMULATED (store data/pipeline/wip/_sim)" if sim else "real store"
    print(f"Pipeline studio on http://{_lan_ip()}:{port}  {mode}")
    print("Ctrl+C stops it.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return agent_log.emit_result("INFO", summary="stopped", port=port, simulated=int(sim))


def _call(base: str, method: str, path: str, body: dict | None = None) -> tuple[int, dict]:
    data = json.dumps(body).encode() if body is not None else None
    req = Request(base + path, data=data, method=method, headers={"Content-Type": "application/json"})
    try:
        with urlopen(req, timeout=20) as resp:
            return resp.status, json.loads(resp.read() or b"{}")
    except HTTPError as exc:
        return exc.code, json.loads(exc.read() or b"{}")


def _wait(base: str, job_id: str, limit: float = 30) -> dict:
    end = time.time() + limit
    while time.time() < end:
        _, job = _call(base, "GET", f"/api/studio/jobs/{job_id}")
        if job.get("status") not in ("queued", "running"):
            return job
        time.sleep(0.05)
    return {"status": "timeout"}


def _fixture(real: Path) -> Path:
    tmp = Path(tempfile.mkdtemp(prefix="wdb-studio-"))
    for rel in ("data/pipeline/prompts", "data/pipeline/schemas"):
        shutil.copytree(real / rel, tmp / rel)
    (tmp / "data/pipeline/export").mkdir(parents=True)
    (tmp / "data/pipeline/export/index.json").write_text('{"schema": "wdb.export.index/1", "subjects": []}\n', encoding="utf-8")
    (tmp / "assets/sprites/enemies/slime").mkdir(parents=True)
    return tmp


def _selftest(real: Path) -> int:
    """Both backends on a temp repo: store routes, a guarded command, and every simulated job."""
    import os
    bad: list[str] = []
    tmp = _fixture(real)
    os.environ["WDB_PIPELINE_SIM_DELAY"] = "0"
    try:
        for sim in (False, True):
            srv = server_mod.make_server("127.0.0.1", 0, tmp, simulate=sim)
            threading.Thread(target=srv.serve_forever, daemon=True).start()
            base = f"http://127.0.0.1:{srv.server_address[1]}"
            tag = "sim" if sim else "real"
            try:
                code, info = _call(base, "GET", "/api/studio/info")
                if code != 200 or info.get("simulated") is not sim or len(info.get("types", [])) != 14:
                    bad.append(f"{tag}: info")
                code, made = _call(base, "POST", "/api/studio/subjects", {"type": "character", "name": f"Test {tag}"})
                sid = made.get("subject", {}).get("id")
                if code != 200 or not sid:
                    bad.append(f"{tag}: create {made}")
                    continue
                code, _ = _call(base, "POST", f"/api/studio/subjects/{sid}/sections/details", {"data": {"notes": "x"}})
                if code != 409:
                    bad.append(f"{tag}: a section before Start is Done should wait ({code})")
                code, _ = _call(base, "POST", "/api/studio/jobs", {"cmd": "edit", "subject": "female", "args": {"text": "x"}})
                if code != 403:
                    bad.append(f"{tag}: female edit was not refused ({code})")
                code, cov = _call(base, "GET", "/api/studio/coverage")
                if code != 200 or "open" not in cov:
                    bad.append(f"{tag}: coverage")
                code, ref = _call(base, "POST", f"/api/studio/subjects/{sid}/reference", {"kind": "post", "value": "https://x.com/a/status/1"})
                if code != 200:
                    bad.append(f"{tag}: reference {ref}")
                if not sim:
                    code, out = _call(base, "POST", "/api/studio/jobs", {"cmd": "reference", "subject": sid, "step": "start"})
                    if code != 501 or not out.get("not_wired"):
                        bad.append(f"real: reference ingest should be not wired ({code})")
                    code, out = _call(base, "POST", "/api/studio/jobs", {"cmd": "body", "subject": sid, "step": "body", "args": {}})
                    if code != 409 or out.get("gate") != "steps":
                        bad.append(f"real: body before earlier steps should 409 gate=steps ({code} {out})")
                    for st in ("start", "details"):
                        if _call(base, "POST", f"/api/studio/subjects/{sid}/steps/{st}", {"action": "finish"})[0] != 200:
                            bad.append(f"real: finish {st}")
                    code, out = _call(base, "POST", "/api/studio/jobs", {"cmd": "body", "subject": sid, "step": "body", "args": {}})
                    if code != 409 or out.get("gate") != "approvals":
                        bad.append(f"real: body without approved plates should 409 ({code} {out})")
                    _call(base, "POST", f"/api/studio/subjects/{sid}/overrides", {"step": "body", "prompt": "taller", "settings": {"seed": 7}})
                    code, out = _call(base, "POST", "/api/studio/jobs", {"cmd": "tune", "subject": sid, "step": "body", "ack_soft": True,
                                                                         "args": {"image": "x.png", "role": "mannequin-front", "workflow": "w.json"}})
                    if code != 501 or out.get("not_wired") != "step-overrides":
                        bad.append(f"real: adjusted settings should be not wired ({code} {out})")
                    continue
                if (tmp / "data/pipeline/wip/index.json").read_text(encoding="utf-8").count('"id"') != 1:
                    bad.append("sim: a simulated subject reached the real store")
                code, info = _call(base, "GET", "/api/studio/info")
                plans = info.get("steps") or {}
                if len(plans) != 14 or any(v[0]["id"] != "start" or v[-1]["id"] != "export" for v in plans.values()):
                    bad.append("sim: every type plan is start, sections, export")

                def fin(step: str, want: int = 200) -> dict:
                    code, out = _call(base, "POST", f"/api/studio/subjects/{sid}/steps/{step}", {"action": "finish"})
                    if code != want:
                        bad.append(f"sim: finish {step} gave {code} {out.get('error')}")
                    return out

                def run(cmd: str, step: str, args: dict | None = None, want: int = 200) -> dict:
                    code, job = _call(base, "POST", "/api/studio/jobs", {"cmd": cmd, "subject": sid, "step": step, "args": args or {}, "ack_soft": True})
                    if code != want:
                        bad.append(f"sim: {cmd} on {step} gave {code} {job.get('error')}")
                        return job
                    if code != 200:
                        return job
                    done = _wait(base, job["id"])
                    if done.get("status") not in ("done", "failed") or not done.get("result", {}).get("simulated"):
                        bad.append(f"sim: {cmd} ended {done.get('status')} {done.get('error')}")
                    return done

                def step_row(step: str) -> dict:
                    return next(s for s in _call(base, "GET", f"/api/studio/subjects/{sid}")[1]["steps"] if s["id"] == step)

                def pics(step: str) -> list[dict]:
                    return [s for s in _call(base, "GET", f"/api/studio/subjects/{sid}")[1]["stills"] if s.get("step") == step]

                def judge(path: str, state: str) -> int:
                    return _call(base, "POST", f"/api/studio/subjects/{sid}/stills", {"path": path, "state": state})[0]

                # Steps run in order.
                out = run("body", "body", want=409)
                if out.get("gate") != "steps" or out.get("blocked_by") != "start":
                    bad.append(f"sim: body before Start should say finish Start first ({out})")
                code, out = _call(base, "POST", f"/api/studio/subjects/{sid}/sections/details", {"data": {"notes": "x"}})
                if code != 409:
                    bad.append(f"sim: details save before Start should 409 ({code})")
                fin("start")
                if _call(base, "POST", f"/api/studio/subjects/{sid}/sections/details", {"data": {"notes": "x"}})[0] != 200:
                    bad.append("sim: details save after Start")
                fin("details")
                if _call(base, "POST", f"/api/studio/subjects/{sid}/sections/details", {"data": {"notes": "y"}})[0] != 409:
                    bad.append("sim: a Done step should refuse changes until reopened")
                # Body step: plates gate, pictures land on the step, finishing needs every picture judged.
                out = run("body", "body", want=409)
                if out.get("gate") != "approvals" or set(out.get("missing") or []) != {"front", "side"}:
                    bad.append(f"sim: body before plates should 409 missing front+side ({out})")
                fin("body", 409)
                run("smooth", "body")
                plates = [s for s in pics("body") if s["kind"] == "still"]
                views = {s.get("view") for s in plates}
                if len(plates) != 4 or not {"front", "side", "back"} <= views:
                    bad.append(f"sim: smooth pictures on the body step {[(s.get('view'), s['path']) for s in plates]}")
                front = next((s for s in plates if s.get("view") == "front"), None)
                side = next((s for s in plates if s.get("view") == "side"), None)
                if front and side:
                    judge(front["path"], "rejected")
                    judge(side["path"], "approved")
                    out = run("body", "body", want=409)
                    if "front" not in (out.get("missing") or []):
                        bad.append(f"sim: a rejected front should not count ({out})")
                    judge(front["path"], "approved")
                    if step_row("body")["status"] != "needs_ok":
                        bad.append("sim: body step with waiting pictures should need your OK")
                    fin("body", 409)
                    for s in pics("body"):
                        if s["state"] == "pending":
                            judge(s["path"], "rejected")
                    run("body", "body")
                    run("mesh", "body", {"glb": "x.glb"})
                    meshes = [s for s in pics("body") if s["kind"] == "mesh"]
                    if not meshes:
                        bad.append("sim: the 3D body is not on the body step")
                    for s in meshes:
                        judge(s["path"], "approved")
                    fin("body")
                # Locked steps refuse changes; overrides are per step and reach the job in simulate.
                code, out = _call(base, "POST", f"/api/studio/subjects/{sid}/overrides", {"step": "portrait", "prompt": "x"})
                if code != 409 or out.get("gate") != "steps":
                    bad.append(f"sim: overrides on a later step should wait ({code} {out})")
                code, out = _call(base, "POST", f"/api/studio/subjects/{sid}/overrides", {"step": "model", "prompt": "Taller, longer legs.", "settings": {"seed": 42, "strength": 0.6}})
                if code != 200 or out.get("overrides", {}).get("model", {}).get("settings", {}).get("seed") != 42:
                    bad.append(f"sim: save overrides ({code} {out})")
                done = run("tune", "model", {"image": "x.png", "role": "mannequin-front", "workflow": "w.json", "turns": 2})
                if (done.get("result") or {}).get("adjusted", {}).get("prompt") != "Taller, longer legs.":
                    bad.append("sim: tune on model did not use the adjusted settings")
                for s in pics("model"):
                    judge(s["path"], "approved")
                fin("model")
                # Reopening an earlier step leaves later Done steps marked to look at again.
                _call(base, "POST", f"/api/studio/subjects/{sid}/steps/details", {"action": "reopen"})
                row = step_row("body")
                if not row.get("stale") or row.get("stale_because") != "Details":
                    bad.append(f"sim: body should be marked after reopening details ({row})")
                if run("mesh", "portrait", {"glb": "x.glb"}, want=409).get("gate") != "steps":
                    bad.append("sim: portrait should wait while details is open")
                fin("details")
                run("tune", "portrait", {"image": "x.png", "role": "mannequin-front", "workflow": "w.json", "turns": 2})
                for s in pics("portrait"):
                    judge(s["path"], "approved")
                for st in ("portrait", "traits", "defaults", "equipment", "animation"):
                    fin(st)
                # Export opens when every step is Done; hard flags still hold it unless bypassed.
                _call(base, "POST", f"/api/studio/subjects/{sid}/mark", {"reason": "locked-front"})
                code, out = _call(base, "POST", "/api/studio/jobs", {"cmd": "export", "subject": sid, "step": "export", "args": {}})
                if code != 409 or out.get("hard") != ["locked-front"]:
                    bad.append(f"sim: hard-dirty export not held ({code} {out})")
                done = run("export", "export", {"bypass": True})
                if done.get("status") != "done" or step_row("export")["status"] != "done":
                    bad.append(f"sim: export with bypass after every step ({done.get('status')} {done.get('error')})")
                if (tmp / "data/pipeline/export/index.json").read_text(encoding="utf-8").count('"id"'):
                    bad.append("sim: export reached the real export index")
                # Every other command still runs from a step that lists it.
                if run("reference", "start", want=409).get("gate") != "locked":
                    bad.append("sim: Start is Done; reading a reference should ask to reopen")
            finally:
                srv.shutdown()
                srv.server_close()
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    for line in bad:
        print(line)
    return agent_log.emit_result("FAIL" if bad else "PASS", summary="selftest", problems=len(bad))


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser("Pipeline studio server: phone UI and JSON API on port 8189.")
    ap.add_argument("--port", type=int, default=server_mod.UI_PORT, help="Port (default 8189).")
    ap.add_argument("--host", default="0.0.0.0", help="Bind address (default 0.0.0.0, the LAN).")
    ap.add_argument("--selftest", action="store_true", help="Run both backends against a temp store and exit.")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    if args.selftest:
        return _selftest(root)
    return _serve(root, args.host, args.port)


if __name__ == "__main__":
    raise SystemExit(main())
