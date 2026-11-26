"""Pass/fail review of one pipeline image with local Qwen3-VL.

Ollama `qwen3-vl:8b` fits this PC only after Comfy is freed. The caller frees
Comfy first. This module does not start Comfy and does not call the game.

    python tools/media.py pipeline review --image path.png --role mannequin-front
    python tools/media.py pipeline review --cycle data/pipeline/wip/review/cycle.json
"""
from __future__ import annotations

import base64
import json
import urllib.error
import urllib.request
from pathlib import Path

CHECKS = Path("data/pipeline/prompts/vision-checks.json")
MODEL = "qwen3-vl:8b"
HOST = "http://127.0.0.1:11434"


def load_checks(root: Path) -> dict:
    path = root / CHECKS
    doc = json.loads(path.read_text(encoding="utf-8"))
    if doc.get("schema") != "wdb.pipeline.vision-checks/1":
        raise ValueError(f"schema must be wdb.pipeline.vision-checks/1 ({path})")
    if not isinstance(doc.get("roles"), dict) or not doc["roles"]:
        raise ValueError("roles must be a non-empty object")
    return doc


def role_spec(doc: dict, role: str) -> dict:
    spec = doc["roles"].get(role)
    if not isinstance(spec, dict):
        known = ", ".join(sorted(doc["roles"]))
        raise ValueError(f"unknown role {role!r}. Known roles: {known}")
    checks = spec.get("checks")
    if not isinstance(checks, list) or not checks:
        raise ValueError(f"role {role} has no checks")
    ids = [row.get("id") for row in checks]
    if any(not isinstance(i, str) or not i for i in ids) or len(ids) != len(set(ids)):
        raise ValueError(f"role {role} check ids must be unique strings")
    return spec


def prompt_for(spec: dict) -> str:
    lines = [
        "Review this one image for a game art pipeline.",
        "Reply with one JSON object and no markdown.",
        'Schema: {"verdict":"pass"|"fail","checks":[{"id":"...","pass":true|false,"reason":"..."}]}',
        "Include every check id exactly once. Do not stop before the last id.",
        'Set verdict to "fail" if any check has pass false.',
        "If you are unsure, set pass to false and say what you cannot see.",
        spec.get("about", ""),
        spec.get("allow", ""),
        "Checks:",
    ]
    for row in spec["checks"]:
        lines.append(f"- {row['id']}: Fail if: {row['fail_if']}")
    return "\n".join(line for line in lines if line)


def parse_review(text: str, expected: list[str]) -> dict:
    """Turn a model reply into a verdict. A missing or extra check fails closed."""
    raw = text.strip()
    if raw.startswith("```"):
        raw = raw.strip("`")
        if raw.lower().startswith("json"):
            raw = raw[4:]
        raw = raw.strip()
    try:
        doc = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ValueError(f"review was not JSON: {exc}") from exc
    if not isinstance(doc, dict):
        raise ValueError("review JSON must be an object")
    rows = doc.get("checks")
    if not isinstance(rows, list):
        raise ValueError("review checks must be a list")
    by_id: dict[str, dict] = {}
    for row in rows:
        if not isinstance(row, dict) or not isinstance(row.get("id"), str):
            raise ValueError("each check needs a string id")
        if row["id"] in by_id:
            raise ValueError(f"duplicate check {row['id']}")
        if not isinstance(row.get("pass"), bool):
            raise ValueError(f"check {row['id']} pass must be true or false")
        reason = row.get("reason", "")
        if not isinstance(reason, str):
            raise ValueError(f"check {row['id']} reason must be a string")
        by_id[row["id"]] = {"id": row["id"], "pass": row["pass"], "reason": reason.strip()}
    missing = [cid for cid in expected if cid not in by_id]
    extra = [cid for cid in by_id if cid not in expected]
    if missing or extra:
        raise ValueError(f"check ids missing={missing} extra={extra}")
    ordered = [by_id[cid] for cid in expected]
    failed = [row["id"] for row in ordered if not row["pass"]]
    return {"verdict": "fail" if failed else "pass", "checks": ordered, "failed": failed}


def _ask(host: str, model: str, image: Path, text: str, timeout: float) -> str:
    payload = {
        "model": model,
        "stream": False,
        "format": "json",
        "messages": [{
            "role": "user",
            "content": text,
            "images": [base64.b64encode(image.read_bytes()).decode("ascii")],
        }],
        "options": {"temperature": 0, "num_predict": 2048},
    }
    raw = json.dumps(payload).encode("utf-8")
    last: Exception | None = None
    body: dict | None = None
    for attempt in (1, 2):
        req = urllib.request.Request(
            host.rstrip("/") + "/api/chat",
            data=raw,
            headers={"Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                body = json.loads(resp.read().decode("utf-8"))
            last = None
            break
        except TimeoutError as exc:
            last = exc
            print(f"review timed out, retry {attempt}", flush=True)
        except urllib.error.URLError as exc:
            if isinstance(exc.reason, TimeoutError):
                last = exc
                print(f"review timed out, retry {attempt}", flush=True)
                continue
            raise ValueError(f"Ollama at {host} did not answer ({exc}). Free Comfy before qwen3-vl:8b.") from exc
    if last is not None or body is None:
        raise ValueError(f"Ollama at {host} timed out ({last}). Free Comfy before qwen3-vl:8b.") from last
    message = body.get("message") if isinstance(body, dict) else None
    content = message.get("content") if isinstance(message, dict) else None
    if not isinstance(content, str) or not content.strip():
        raise ValueError("Ollama returned no review text")
    return content


def review_image(root: Path, image: Path, role: str, *, host: str = HOST, model: str = MODEL, timeout: float = 480) -> dict:
    if not image.is_file():
        raise ValueError(f"no image {image}")
    doc = load_checks(root)
    spec = role_spec(doc, role)
    expected = [row["id"] for row in spec["checks"]]
    parsed = None
    last_error: Exception | None = None
    for attempt in (1, 2):
        try:
            text = _ask(host, model, image, prompt_for(spec), timeout)
            parsed = parse_review(text, expected)
            break
        except ValueError as exc:
            last_error = exc
            print(f"review reply unusable, retry {attempt}: {exc}", flush=True)
    if parsed is None:
        raise ValueError(f"review reply unusable ({last_error})") from last_error
    parsed["image"] = str(image)
    parsed["role"] = role
    parsed["model"] = model
    return parsed


def correction_plan(doc: dict, spec: dict, failed: list[str]) -> dict:
    """Decide how a failed locked-image review is fixed. No fix means hold, not a user handoff."""
    library = doc.get("fix_library") or {}
    flow = spec.get("flow")
    if flow not in ("prompt", "rebuild"):
        raise ValueError(f"role flow must be prompt or rebuild, not {flow!r}")
    if not failed:
        return {"action": "pass", "adds": [], "negatives": [], "failed": []}
    if flow == "rebuild":
        return {"action": "rebuild", "adds": [], "negatives": [], "failed": list(failed)}
    missing = [cid for cid in failed if cid not in library]
    if missing:
        return {"action": "hold", "adds": [], "negatives": [], "failed": list(failed), "unfixed": missing}
    adds = []
    negatives = []
    for cid in failed:
        fix = library[cid]
        if fix.get("add") and fix["add"] not in adds:
            adds.append(fix["add"])
        if fix.get("negative") and fix["negative"] not in negatives:
            negatives.append(fix["negative"])
    return {"action": "prompt", "adds": adds, "negatives": negatives, "failed": list(failed)}


def patch_workflow(workflow: dict, adds: list[str], negatives: list[str]) -> dict:
    """Append still-prompt fixes once. Does not run Comfy."""
    out = json.loads(json.dumps(workflow))
    found = False
    for node in out.values():
        if not isinstance(node, dict) or node.get("class_type") != "TextEncodeQwenImage21":
            continue
        found = True
        inputs = node.setdefault("inputs", {})
        prompt = str(inputs.get("prompt", ""))
        negative = str(inputs.get("negative_prompt", ""))
        for line in adds:
            if line not in prompt:
                prompt = (prompt.rstrip() + " " + line).strip()
        for bit in negatives:
            if bit not in negative:
                negative = (negative.rstrip(", ") + ", " + bit).lstrip(", ")
        inputs["prompt"] = prompt
        inputs["negative_prompt"] = negative
    if not found:
        raise ValueError("workflow has no TextEncodeQwenImage21 prompt")
    return out


def selftest() -> list[str]:
    """Parser and checklist contract. Does not call Ollama."""
    bad: list[str] = []
    expected = ["no_brows", "feet"]
    try:
        ok = parse_review(
            '{"verdict":"pass","checks":[{"id":"no_brows","pass":true,"reason":"bare"},{"id":"feet","pass":true,"reason":"feet"}]}',
            expected,
        )
        if ok["verdict"] != "pass" or ok["failed"]:
            bad.append("a clean reply did not pass")
    except ValueError as exc:
        bad.append(f"clean reply raised {exc}")
    try:
        flagged = parse_review(
            '{"verdict":"pass","checks":[{"id":"no_brows","pass":false,"reason":"brows are drawn"},{"id":"feet","pass":false,"reason":"feet are blocks"}]}',
            expected,
        )
        if flagged["verdict"] != "fail" or flagged["failed"] != ["no_brows", "feet"]:
            bad.append("a failed check was trusted when the model said pass")
    except ValueError as exc:
        bad.append(f"failed check raised {exc}")
    try:
        parse_review('{"verdict":"pass","checks":[{"id":"no_brows","pass":true,"reason":""}]}', expected)
        bad.append("a missing check was accepted")
    except ValueError:
        pass
    try:
        parse_review("not json", expected)
        bad.append("non-JSON was accepted")
    except ValueError:
        pass
    sample = {
        "fix_library": {
            "no_brows": {"add": "No eyebrows.", "negative": "eyebrows"},
            "feet": {"add": "Distinct feet.", "negative": "block feet"},
        }
    }
    prompt_role = {"flow": "prompt"}
    plan = correction_plan(sample, prompt_role, ["no_brows"])
    if plan["action"] != "prompt" or plan["adds"] != ["No eyebrows."]:
        bad.append("a brow fail did not become a prompt fix")
    hold = correction_plan(sample, prompt_role, ["no_nose"])
    if hold["action"] != "hold":
        bad.append("a check with no fix was not held")
    rebuild = correction_plan(sample, {"flow": "rebuild"}, ["feet"])
    if rebuild["action"] != "rebuild":
        bad.append("a mesh fail was not a rebuild")
    patched = patch_workflow(
        {"4": {"class_type": "TextEncodeQwenImage21", "inputs": {"prompt": "Body.", "negative_prompt": "blur"}}},
        ["No eyebrows."],
        ["eyebrows"],
    )
    again = patch_workflow(patched, ["No eyebrows."], ["eyebrows"])
    text = again["4"]["inputs"]["prompt"]
    if text.count("No eyebrows.") != 1 or "eyebrows" not in again["4"]["inputs"]["negative_prompt"]:
        bad.append("prompt fix was dropped or repeated")
    return bad
