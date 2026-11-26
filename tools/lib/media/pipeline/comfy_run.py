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
        raise ValueError("Comfy rejected the workflow")
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
                raise ValueError(f"Comfy run {prompt_id} failed")
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
