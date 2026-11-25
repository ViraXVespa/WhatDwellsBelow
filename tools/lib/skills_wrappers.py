"""Functional wrappers that invoke task-ops and changelog-commit via the local Ollama API.
Matches the call style used in tools/lib/slice/gather_pick.py.
"""
import json
import urllib.error
import urllib.request
from pathlib import Path

TIMEOUT = 120
ROOT = Path(__file__).resolve().parents[2]

def _ollama_chat(messages: list[dict], model: str) -> str:
    body = {
        "model": model,
        "messages": messages,
        "stream": False,
        "options": {"temperature": 0},
    }
    req = urllib.request.Request(
        "http://127.0.0.1:11434/api/chat",
        data=json.dumps(body).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            payload = json.loads(resp.read().decode("utf-8"))
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError, OSError) as exc:
        raise RuntimeError(f"ollama call failed: {exc}") from exc
    content = (payload.get("message") or {}).get("content") or ""
    if not content:
        raise RuntimeError(f"ollama returned no content: {payload.get('done_reason')}")
    return content

def _skill_prompt(skill_name: str) -> str:
    path = ROOT / ".opencode" / "skills" / skill_name / "SKILL.md"
    return path.read_text(encoding="utf-8")

def task_ops(user_prompt: str, model: str = "gpt-oss:20b") -> str:
    """Invoke the task-ops skill via Ollama. Returns the model reply."""
    system = _skill_prompt("task-ops")
    messages = [
        {"role": "system", "content": system},
        {"role": "user", "content": user_prompt},
    ]
    return _ollama_chat(messages, model)

def changelog_commit(user_prompt: str, model: str = "gpt-oss:20b") -> str:
    """Invoke the changelog-commit skill via Ollama. Returns the model reply."""
    system = _skill_prompt("changelog-commit")
    messages = [
        {"role": "system", "content": system},
        {"role": "user", "content": user_prompt},
    ]
    return _ollama_chat(messages, model)
