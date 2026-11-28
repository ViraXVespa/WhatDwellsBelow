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
                code, _ = _call(base, "POST", f"/api/studio/subjects/{sid}/sections/body", {"data": {"measures": ["head"]}})
                if code != 200:
                    bad.append(f"{tag}: save section")
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
                    code, out = _call(base, "POST", "/api/studio/jobs", {"cmd": "reference", "subject": sid})
                    if code != 501 or not out.get("not_wired"):
                        bad.append(f"real: reference ingest should be not wired ({code})")
                    continue
                if (tmp / "data/pipeline/wip/index.json").read_text(encoding="utf-8").count('"id"') != 1:
                    bad.append("sim: a simulated subject reached the real store")
                jobs = [("review", {"image": "x.png", "role": "mannequin-front"}), ("tune", {"image": "x.png", "role": "mannequin-front", "workflow": "w.json", "turns": 2}),
                        ("frame", {"image": "x.png", "out": "f.png"}), ("proportion", {"image": "x.png"}), ("mesh", {"glb": "x.glb"}),
                        ("smooth", {}), ("body", {}), ("edit", {"text": "four fingers"}), ("reference", {}), ("correct", {"role": "mannequin-front", "workflow": "w.json", "image": "x.png"})]
                for cmd, args in jobs:
                    code, job = _call(base, "POST", "/api/studio/jobs", {"cmd": cmd, "subject": sid, "args": args, "ack_soft": True})
                    if code != 200:
                        bad.append(f"sim: {cmd} start {code} {job.get('error')}")
                        continue
                    done = _wait(base, job["id"])
                    if done.get("status") not in ("done", "failed") or not done.get("result", {}).get("simulated"):
                        bad.append(f"sim: {cmd} ended {done.get('status')} {done.get('error')}")
                code, shown = _call(base, "GET", f"/api/studio/subjects/{sid}")
                stills = [s for s in shown.get("stills", []) if s["kind"] == "still"]
                meshes = [s for s in shown.get("stills", []) if s["kind"] == "mesh"]
                if not stills or not meshes or not shown.get("reviews"):
                    bad.append(f"sim: show lists stills={len(stills)} meshes={len(meshes)} reviews={len(shown.get('reviews', []))}")
                elif _call(base, "POST", f"/api/studio/subjects/{sid}/stills", {"path": stills[0]["path"], "state": "approved"})[0] != 200:
                    bad.append("sim: approve")
                _call(base, "POST", f"/api/studio/subjects/{sid}/mark", {"reason": "locked-front"})
                code, out = _call(base, "POST", "/api/studio/jobs", {"cmd": "export", "subject": sid, "args": {}})
                if code != 409 or out.get("hard") != ["locked-front"]:
                    bad.append(f"sim: hard-dirty export not held ({code})")
                code, job = _call(base, "POST", "/api/studio/jobs", {"cmd": "export", "subject": sid, "args": {"bypass": True}})
                if code != 200 or _wait(base, job["id"]).get("status") != "done":
                    bad.append("sim: bypass export")
                if (tmp / "data/pipeline/export/index.json").read_text(encoding="utf-8").count('"id"'):
                    bad.append("sim: export reached the real export index")
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
