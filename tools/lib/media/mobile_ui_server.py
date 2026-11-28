"""Pipeline studio server (phone UI). Run it with `python tools/media.py studio`.

- Serves the studio (tools/lib/media/mobile_ui/) on 0.0.0.0:8189 and its JSON API under /api/studio/
- WDB_PIPELINE_SIMULATE=1 swaps in the simulate backend (separate store root, fake long jobs)
- Keeps the closed Character Studio at /legacy/ with its old routes: /api/picks, /api/ledger,
  /api/cancel, /api/start-comfy, /api/build-test, /api/queue-walk, /workflow.json, /comfy/* -> 127.0.0.1:8188
"""
from __future__ import annotations

import json
import mimetypes
import os
import subprocess
import sys
import threading
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[3]
UI_DIR = Path(__file__).resolve().parent / "mobile_ui"
PICKS = ROOT / "_src" / "comfy-character" / "walk-picks.json"
LEDGER = ROOT / "_src" / "comfy-character" / "ledger.json"
WORKFLOW = ROOT / "tools" / "data" / "comfy-character-workflow.json"
UI_PORT = 8189
COMFY = "http://127.0.0.1:8188"
MEDIA = ROOT / "tools" / "media.py"
MAX_BODY = 40 * 1024 * 1024
SIM_ENV = "WDB_PIPELINE_SIMULATE"

_current_proc = None
_proc_lock = threading.Lock()
_comfy_proc = None

mimetypes.add_type("text/javascript", ".js")
mimetypes.add_type("model/gltf-binary", ".glb")
mimetypes.add_type("application/manifest+json", ".webmanifest")


def simulate_on() -> bool:
    return os.environ.get(SIM_ENV, "").strip().lower() in ("1", "true", "yes", "on")


def make_api(repo: Path, simulate: bool | None = None):
    """The studio API over the real store, or the simulate backend when the env var is on."""
    from media.studio.api import Api
    from media.studio.backend import Backend
    from media.studio.jobs import Registry
    from media.studio.sim import SimBackend

    sim = simulate_on() if simulate is None else simulate
    backend = SimBackend(repo) if sim else Backend(repo)
    registry = Registry(backend.root / "data" / "pipeline" / "wip" / "_studio" / "jobs.json")
    return Api(backend, registry)


def ui_to_api(ui: dict) -> dict:
    """Convert a ComfyUI UI graph into the API prompt format (legacy Character Studio)."""
    if not isinstance(ui, dict) or "nodes" not in ui:
        return ui
    link_map = {}
    for link in ui.get("links") or []:
        if isinstance(link, (list, tuple)) and len(link) >= 5:
            link_map[link[0]] = (str(link[1]), link[2])
    api = {}
    for node in ui.get("nodes") or []:
        class_type = node.get("type")
        if not class_type or class_type == "MarkdownNote":
            continue
        inputs = {}
        widgets = node.get("widgets_values") or []
        names = [inp.get("name") for inp in node.get("inputs") or [] if inp.get("widget")]
        for i, name in enumerate(names):
            if i < len(widgets):
                inputs[name] = widgets[i]
        for inp in node.get("inputs") or []:
            if inp.get("link") is not None and inp.get("link") in link_map:
                inputs[inp.get("name")] = list(link_map[inp["link"]])
        api[str(node.get("id"))] = {"class_type": class_type, "inputs": inputs}
    return api


class Handler(SimpleHTTPRequestHandler):
    api = None  # set by serve()

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(UI_DIR), **kwargs)

    def log_message(self, fmt: str, *args) -> None:  # quiet: the phone polls every second
        if os.environ.get("WDB_STUDIO_VERBOSE"):
            super().log_message(fmt, *args)

    def end_headers(self) -> None:
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    # ---- studio ----------------------------------------------------------------
    def _studio(self, method: str) -> None:
        body: dict = {}
        if method == "POST":
            length = int(self.headers.get("Content-Length", 0) or 0)
            if length > MAX_BODY:
                self._json(413, {"error": "request too large"})
                return
            raw = self.rfile.read(length) if length else b""
            try:
                body = json.loads(raw.decode("utf-8") or "{}")
            except (UnicodeDecodeError, json.JSONDecodeError):
                self._json(400, {"error": "body is not JSON"})
                return
            if not isinstance(body, dict):
                self._json(400, {"error": "body must be an object"})
                return
        status, payload = self.api.handle(method, self.path, body)
        self._json(status, payload)

    def _file(self) -> None:
        from media.studio.backend import ApiError
        rel = (parse_qs(urlparse(self.path).query).get("path") or [""])[-1]
        try:
            path = self.api.b.resolve_file(rel)
        except ApiError as exc:
            self._json(exc.status, {"error": exc.message})
            return
        data = path.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", mimetypes.guess_type(path.name)[0] or "application/octet-stream")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self) -> None:
        route = urlparse(self.path).path
        if route == "/api/studio/file":
            self._file()
        elif route.startswith("/api/studio/"):
            self._studio("GET")
        elif route == "/legacy":
            self.send_response(301)
            self.send_header("Location", "/legacy/")
            self.end_headers()
        elif route == "/workflow.json":
            self._serve_workflow()
        elif route == "/api/picks":
            self._serve_json(PICKS)
        elif route.startswith("/comfy/"):
            self._proxy("GET")
        else:
            super().do_GET()

    def do_POST(self) -> None:
        route = urlparse(self.path).path
        if route.startswith("/api/studio/"):
            self._studio("POST")
            return
        if route.startswith("/comfy/"):
            self._proxy("POST")
            return
        length = int(self.headers.get("Content-Length", 0) or 0)
        raw = self.rfile.read(length) if length else b""
        try:
            data = json.loads(raw.decode() or "{}")
        except json.JSONDecodeError:
            data = {}
        if route == "/api/picks":
            self._write_json(PICKS, data)
            self._json(200, {"status": "ok"})
        elif route == "/api/ledger":
            self._write_json(LEDGER, data)
            self._json(200, {"status": "ok"})
        elif route == "/api/cancel":
            self._cancel()
        elif route == "/api/start-comfy":
            self._start_comfy()
        elif route == "/api/build-test":
            self._stream_media(["comfy-character", "walk-build", "--root", str(ROOT)])
        elif route == "/api/queue-walk":
            args = ["comfy-character", "run", "--root", str(ROOT)]
            for key in ("prompt", "negative", "seed", "steps", "cfg", "strength", "name", "ref", "pose"):
                if key in data and data[key] not in (None, "", -1):
                    args += [f"--{key}", str(data[key])]
            self._stream_media(args)
        else:
            self.send_error(404)

    # ---- legacy Character Studio ---------------------------------------------------
    def _start_comfy(self) -> None:
        global _comfy_proc
        candidates = [Path.home() / "ComfyUI" / "main.py", ROOT / "ComfyUI" / "main.py", Path("/opt/ComfyUI/main.py")]
        main_py = next((p for p in candidates if p.is_file()), None)
        if not main_py:
            self._json(200, {"status": "no-install", "message": "No ComfyUI install found. Start it manually."})
            return
        if _comfy_proc and _comfy_proc.poll() is None:
            self._json(200, {"status": "already-running"})
            return
        try:
            _comfy_proc = subprocess.Popen([sys.executable, str(main_py), "--listen", "0.0.0.0", "--port", "8188"],
                                           cwd=main_py.parent, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            self._json(200, {"status": "started"})
        except Exception as e:
            self._json(200, {"status": "fail", "message": str(e)})

    def _cancel(self) -> None:
        global _current_proc
        with _proc_lock:
            proc, _current_proc = _current_proc, None
        if proc and proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=2)
            except Exception:
                proc.kill()
        self._json(200, {"status": "cancelled"})

    def _stream_media(self, args: list[str]) -> None:
        global _current_proc
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Transfer-Encoding", "chunked")
        self.end_headers()

        def send(line: str) -> None:
            raw = (line + "\n").encode("utf-8")
            self.wfile.write(f"{len(raw):X}\r\n".encode() + raw + b"\r\n")
            self.wfile.flush()

        proc = None
        try:
            proc = subprocess.Popen([sys.executable, str(MEDIA), *args], cwd=ROOT, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, text=True, bufsize=1)
            with _proc_lock:
                _current_proc = proc
            for line in proc.stdout:
                send(line.rstrip())
            proc.wait()
            send(f"EXIT {proc.returncode}")
        except Exception as e:
            send(f"ERROR {e}")
        finally:
            with _proc_lock:
                if _current_proc is proc:
                    _current_proc = None
        self.wfile.write(b"0\r\n\r\n")
        self.wfile.flush()

    def _serve_workflow(self) -> None:
        raw = b"{}"
        if WORKFLOW.is_file():
            try:
                raw = json.dumps(ui_to_api(json.loads(WORKFLOW.read_text(encoding="utf-8")))).encode("utf-8")
            except Exception:
                raw = WORKFLOW.read_bytes()
        self._raw(200, "application/json", raw)

    def _serve_json(self, path: Path) -> None:
        self._raw(200, "application/json", path.read_bytes() if path.is_file() else b"[]")

    def _proxy(self, method: str) -> None:
        length = int(self.headers.get("Content-Length", 0) or 0)
        body = self.rfile.read(length) if length else None
        req = Request(COMFY + self.path[len("/comfy"):], data=body, method=method)
        if body:
            req.add_header("Content-Type", "application/json")
        try:
            with urlopen(req, timeout=120) as resp:
                self._raw(resp.status, resp.headers.get("Content-Type", "application/json"), resp.read())
        except Exception as e:
            self._raw(502, "text/plain; charset=utf-8", str(e).encode())

    def _write_json(self, path: Path, data: dict) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")

    # ---- replies -------------------------------------------------------------------
    def _raw(self, status: int, ctype: str, data: bytes) -> None:
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _json(self, status: int, payload: dict) -> None:
        self._raw(status, "application/json", json.dumps(payload).encode("utf-8"))


def make_server(host: str = "0.0.0.0", port: int = UI_PORT, repo: Path = ROOT, simulate: bool | None = None) -> ThreadingHTTPServer:
    handler = type("StudioHandler", (Handler,), {"api": make_api(repo, simulate)})
    server = ThreadingHTTPServer((host, port), handler)
    server.daemon_threads = True
    return server


def start_background(host: str = "0.0.0.0", port: int = UI_PORT) -> threading.Thread | None:
    """Start the studio on a daemon thread (comfy-character does this). A busy port is not an error."""
    try:
        server = make_server(host, port)
    except OSError:
        return None
    t = threading.Thread(target=server.serve_forever, daemon=True)
    t.start()
    return t
