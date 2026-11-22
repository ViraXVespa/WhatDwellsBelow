#!/usr/bin/env python3
"""Mobile UI server for comfy-character.

- Serves the static UI on 0.0.0.0:8189
- Proxies /comfy/* to local ComfyUI (127.0.0.1:8188)
- Serves the character workflow at /workflow.json
- Writes walk-picks.json and ledger.json
- /api/build-test and /api/queue-walk stream CLI output
- /api/cancel kills the current CLI process
- /api/start-comfy attempts a best-effort ComfyUI launch
- Starts itself in the background on import (defensive)
"""
import json
import os
import subprocess
import sys
import threading
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[3]
UI_DIR = Path(__file__).resolve().parent / "mobile_ui"
PICKS = ROOT / "_src" / "comfy-character" / "walk-picks.json"
LEDGER = ROOT / "_src" / "comfy-character" / "ledger.json"
WORKFLOW = ROOT / "tools" / "data" / "comfy-character-workflow.json"
UI_PORT = 8189
COMFY = "http://127.0.0.1:8188"
MEDIA = ROOT / "tools" / "media.py"

_current_proc = None
_proc_lock = threading.Lock()
_comfy_proc = None



def ui_to_api(ui: dict) -> dict:
    """Convert a ComfyUI UI graph into the API prompt format.

    Handles the common case used by the character workflow.
    Original file is left untouched.
    """
    if not isinstance(ui, dict) or "nodes" not in ui:
        return ui  # already API format or empty
    nodes = ui.get("nodes") or []
    links = ui.get("links") or []

    # link_id -> (from_node, from_slot)
    link_map = {}
    for link in links:
        if isinstance(link, (list, tuple)) and len(link) >= 5:
            link_id, from_node, from_slot = link[0], link[1], link[2]
            link_map[link_id] = (str(from_node), from_slot)

    api = {}
    for node in nodes:
        nid = str(node.get("id"))
        class_type = node.get("type")
        if not class_type or class_type == "MarkdownNote":
            continue
        inputs = {}
        # widget values (simple positional mapping for known nodes)
        widgets = node.get("widgets_values") or []
        widget_names = []
        for inp in node.get("inputs") or []:
            if inp.get("widget"):
                widget_names.append(inp.get("name"))
        for i, name in enumerate(widget_names):
            if i < len(widgets):
                inputs[name] = widgets[i]
        # linked inputs
        for inp in node.get("inputs") or []:
            link_id = inp.get("link")
            if link_id is not None and link_id in link_map:
                inputs[inp.get("name")] = list(link_map[link_id])
        api[nid] = {"class_type": class_type, "inputs": inputs}
    return api


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(UI_DIR), **kwargs)

    def do_GET(self) -> None:
        if self.path == "/workflow.json":
            self._serve_workflow()
        elif self.path == "/api/picks":
            self._serve_json(PICKS)
        elif self.path.startswith("/comfy/"):
            self._proxy("GET")
        else:
            super().do_GET()

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path.startswith("/comfy/"):
            self._proxy("POST")
            return

        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length) if length else b""
        try:
            data = json.loads(body.decode() or "{}")
        except json.JSONDecodeError:
            data = {}

        if parsed.path == "/api/picks":
            self._write_json(PICKS, data)
            self._ok({"status": "ok"})
        elif parsed.path == "/api/ledger":
            self._write_json(LEDGER, data)
            self._ok({"status": "ok"})
        elif parsed.path == "/api/cancel":
            self._cancel()
        elif parsed.path == "/api/start-comfy":
            self._start_comfy()
        elif parsed.path == "/api/build-test":
            self._stream_media(["comfy-character", "walk-build", "--root", str(ROOT)])
        elif parsed.path == "/api/queue-walk":
            args = ["comfy-character", "run", "--root", str(ROOT)]
            mapping = {
                "prompt": "--prompt",
                "negative": "--negative",
                "seed": "--seed",
                "steps": "--steps",
                "cfg": "--cfg",
                "strength": "--strength",
                "name": "--name",
                "ref": "--ref",
                "pose": "--pose",
            }
            for key, flag in mapping.items():
                if key in data and data[key] not in (None, "", -1):
                    args += [flag, str(data[key])]
            self._stream_media(args)
        else:
            self.send_error(404)

    def _start_comfy(self) -> None:
        global _comfy_proc
        candidates = [
            Path.home() / "ComfyUI" / "main.py",
            ROOT / "ComfyUI" / "main.py",
            Path("/opt/ComfyUI/main.py"),
        ]
        main_py = next((p for p in candidates if p.is_file()), None)
        if not main_py:
            self._ok({"status": "no-install", "message": "No ComfyUI install found. Start it manually."})
            return
        if _comfy_proc and _comfy_proc.poll() is None:
            self._ok({"status": "already-running"})
            return
        try:
            _comfy_proc = subprocess.Popen(
                [sys.executable, str(main_py), "--listen", "0.0.0.0", "--port", "8188"],
                cwd=main_py.parent,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            self._ok({"status": "started"})
        except Exception as e:
            self._ok({"status": "fail", "message": str(e)})

    def _cancel(self) -> None:
        global _current_proc
        with _proc_lock:
            proc = _current_proc
            _current_proc = None
        if proc and proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=2)
            except Exception:
                proc.kill()
        self._ok({"status": "cancelled"})

    def _stream_media(self, args: list[str]) -> None:
        global _current_proc
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Transfer-Encoding", "chunked")
        self.end_headers()

        def send(line: str) -> None:
            raw = (line + "\n").encode("utf-8")
            self.wfile.write(f"{len(raw):X}\r\n".encode())
            self.wfile.write(raw)
            self.wfile.write(b"\r\n")
            self.wfile.flush()

        try:
            proc = subprocess.Popen(
                [sys.executable, str(MEDIA), *args],
                cwd=ROOT,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
            )
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
        if WORKFLOW.is_file():
            try:
                ui = json.loads(WORKFLOW.read_text(encoding="utf-8"))
                api = ui_to_api(ui)
                raw = json.dumps(api).encode("utf-8")
            except Exception:
                raw = WORKFLOW.read_bytes()
        else:
            raw = b"{}"
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def _serve_json(self, path: Path) -> None:
        if path.is_file():
            raw = path.read_bytes()
        else:
            raw = b"[]"
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def _proxy(self, method: str) -> None:
        target = COMFY + self.path[len("/comfy"):]
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length) if length else None
        req = Request(target, data=body, method=method)
        if body:
            req.add_header("Content-Type", "application/json")
        try:
            with urlopen(req, timeout=120) as resp:
                data = resp.read()
                self.send_response(resp.status)
                self.send_header("Content-Type", resp.headers.get("Content-Type", "application/json"))
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)
        except Exception as e:
            msg = str(e).encode()
            self.send_response(502)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(msg)))
            self.end_headers()
            self.wfile.write(msg)

    def _write_json(self, path: Path, data: dict) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")

    def _ok(self, payload: dict) -> None:
        raw = json.dumps(payload).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)


def serve() -> None:
    try:
        server = ThreadingHTTPServer(("0.0.0.0", UI_PORT), Handler)
    except OSError:
        print(f"Mobile UI port {UI_PORT} already in use")
        return
    print(f"Mobile UI on http://0.0.0.0:{UI_PORT}")
    server.serve_forever()


def start_background() -> threading.Thread | None:
    t = threading.Thread(target=serve, daemon=True)
    t.start()
    return t


try:
    start_background()
except Exception:
    pass


if __name__ == "__main__":
    serve()
