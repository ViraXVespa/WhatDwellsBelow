"""Queue one workflow on the local ComfyUI and fetch its first saved image.

The server is the one already running on 127.0.0.1:8188. This does not start
or stop that server. Stop it with stop_comfyui.
"""
from __future__ import annotations

import json
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

SERVER = "http://127.0.0.1:8188"


def run(server: str, workflow: dict, dest: Path, timeout: float = 1200) -> Path:
    prompt_id = queue(server, workflow)
    item = wait(server, prompt_id, timeout)
    return save_first(server, item, dest)


def queue(server: str, workflow: dict) -> str:
    body = _request(server, "/prompt", {"prompt": workflow})
    if body.get("node_errors") or body.get("error"):
        detail = json.dumps(
            {"error": body.get("error"), "node_errors": body.get("node_errors")},
            ensure_ascii=True,
        )[:500]
        raise ValueError(f"Comfy rejected the workflow: {detail}")
    prompt_id = body.get("prompt_id")
    if not isinstance(prompt_id, str) or not prompt_id:
        raise ValueError("Comfy did not return a prompt id")
    return prompt_id


def wait(server: str, prompt_id: str, timeout: float) -> dict:
    deadline = time.time() + timeout
    while time.time() < deadline:
        history = _request(server, f"/history/{prompt_id}", timeout=60)
        item = history.get(prompt_id)
        if isinstance(item, dict):
            status = item.get("status") or {}
            if status.get("status_str") == "error":
                detail = json.dumps(status.get("messages") or [], ensure_ascii=True)[:500]
                raise ValueError(f"Comfy run {prompt_id} failed: {detail}")
            if status.get("completed"):
                return item
        time.sleep(5)
    raise ValueError(f"Comfy run {prompt_id} did not finish")


def save_first(server: str, item: dict, dest: Path) -> Path:
    info = None
    for node_out in (item.get("outputs") or {}).values():
        images = node_out.get("images") if isinstance(node_out, dict) else None
        if images:
            info = images[0]
            break
    if not isinstance(info, dict) or not info.get("filename"):
        raise ValueError("Comfy saved no image")
    query = urllib.parse.urlencode({
        "filename": info["filename"],
        "subfolder": info.get("subfolder", ""),
        "type": info.get("type", "output"),
    })
    try:
        with urllib.request.urlopen(server.rstrip("/") + "/view?" + query, timeout=120) as resp:
            raw = resp.read()
    except urllib.error.URLError as exc:
        raise ValueError(f"Comfy image fetch failed ({exc})") from exc
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(raw)
    return dest


def upload_image(server: str, path: Path) -> str:
    """Put one plate in the local Comfy input folder. Returns the name LoadImage uses."""
    boundary = "----wdbpipeline"
    raw = path.read_bytes()
    head = (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="image"; filename="{path.name}"\r\n'
        "Content-Type: image/png\r\n\r\n"
    ).encode("utf-8")
    tail = (
        f"\r\n--{boundary}\r\n"
        'Content-Disposition: form-data; name="overwrite"\r\n\r\n'
        "true\r\n"
        f"--{boundary}\r\n"
        'Content-Disposition: form-data; name="type"\r\n\r\n'
        "input\r\n"
        f"--{boundary}--\r\n"
    ).encode("utf-8")
    req = urllib.request.Request(
        server.rstrip("/") + "/upload/image",
        data=head + raw + tail,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            parsed = json.loads(resp.read())
    except urllib.error.URLError as exc:
        raise ValueError(f"Comfy image upload failed ({exc})") from exc
    name = parsed.get("name") if isinstance(parsed, dict) else None
    if not isinstance(name, str) or not name:
        raise ValueError(f"Comfy did not name {path.name}")
    return name


def upload_file(server: str, path: Path, *, subfolder: str = "") -> str:
    """Put one file in the local Comfy input folder. Returns the name Load3D uses."""
    boundary = "----wdbpipeline"
    raw = path.read_bytes()
    head = (
        f"--{boundary}\r\n"
        f'Content-Disposition: form-data; name="image"; filename="{path.name}"\r\n'
        "Content-Type: application/octet-stream\r\n\r\n"
    ).encode("utf-8")
    tail = (
        f"\r\n--{boundary}\r\n"
        'Content-Disposition: form-data; name="subfolder"\r\n\r\n'
        f"{subfolder}\r\n"
        f"--{boundary}\r\n"
        'Content-Disposition: form-data; name="overwrite"\r\n\r\n'
        "true\r\n"
        f"--{boundary}\r\n"
        'Content-Disposition: form-data; name="type"\r\n\r\n'
        "input\r\n"
        f"--{boundary}--\r\n"
    ).encode("utf-8")
    req = urllib.request.Request(
        server.rstrip("/") + "/upload/image",
        data=head + raw + tail,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
    )
    try:
        with urllib.request.urlopen(req, timeout=180) as resp:
            parsed = json.loads(resp.read())
    except urllib.error.URLError as exc:
        raise ValueError(f"Comfy file upload failed ({exc})") from exc
    name = parsed.get("name") if isinstance(parsed, dict) else None
    if not isinstance(name, str) or not name:
        raise ValueError(f"Comfy did not name {path.name}")
    folder = str(parsed.get("subfolder") or "").replace("\\", "/").strip("/")
    named = name.replace("\\", "/")
    if folder and not named.startswith(folder + "/"):
        named = f"{folder}/{named}"
    return named


def save_3d(server: str, item: dict, dest: Path) -> Path:
    """Fetch the first saved glb. SaveGLB records it under the history key `3d`."""
    info = None
    for node_out in (item.get("outputs") or {}).values():
        models = node_out.get("3d") if isinstance(node_out, dict) else None
        if models:
            info = models[0]
            break
    if not isinstance(info, dict) or not info.get("filename"):
        raise ValueError("Comfy saved no mesh")
    query = urllib.parse.urlencode({
        "filename": info["filename"],
        "subfolder": info.get("subfolder", ""),
        "type": info.get("type", "output"),
    })
    try:
        with urllib.request.urlopen(server.rstrip("/") + "/view?" + query, timeout=180) as resp:
            raw = resp.read()
    except urllib.error.URLError as exc:
        raise ValueError(f"Comfy mesh fetch failed ({exc})") from exc
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(raw)
    return dest


def free(server: str) -> None:
    """Unload Comfy weights so the vision model can fit. A stopped server counts as already free."""
    try:
        _request(server, "/free", {"unload_models": True, "free_memory": True}, timeout=60)
    except ValueError as exc:
        if "not answering" in str(exc):
            return
        raise


def _request(server: str, path: str, payload: dict | None = None, timeout: float = 180) -> dict:
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        server.rstrip("/") + path,
        data=data,
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read()
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")[:400]
        raise ValueError(f"Comfy {path} failed: {detail}") from exc
    except urllib.error.URLError as exc:
        raise ValueError(f"Comfy is not answering at {server} ({exc.reason})") from exc
    if not raw:
        return {}
    parsed = json.loads(raw)
    if not isinstance(parsed, dict):
        raise ValueError(f"Comfy {path} did not return an object")
    return parsed
