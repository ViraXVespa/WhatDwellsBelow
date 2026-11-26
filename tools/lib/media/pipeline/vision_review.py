"""Pass/fail review of one pipeline image with local Qwen3-VL.

Ollama `qwen3-vl:8b` fits this PC only after Comfy is freed. The caller frees
Comfy first. This module does not start Comfy and does not call the game.

The role checklist stays. When the caller also passes the prompt that was sent,
each positive sentence must be visible and each comma-separated negative tag
must be absent. Those clauses are whatever that prompt said. This module does
not add a body part the prompt did not name. qwen3-vl:8b drops ids on a long
list, so every ask is at most BATCH checks. A miss is restated for the tune
loop. A restatement is not a new check.

    python tools/media.py pipeline review --image path.png --role mannequin-front
    python tools/media.py pipeline review --cycle data/pipeline/wip/review/cycle.json
"""
from __future__ import annotations

import base64
import hashlib
import json
import re
import urllib.error
import urllib.request
from pathlib import Path

CHECKS = Path("data/pipeline/prompts/vision-checks.json")
MODEL = "qwen3-vl:8b"
HOST = "http://127.0.0.1:11434"
# qwen3-vl:8b stops answering once the checklist is long. Four is one reply.
BATCH = 4
_SENTENCE = re.compile(r"(?<=[.!?])\s+")
_SKIP = ("required and clearly visible:", "do not include ")


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


def spec_for(doc: dict, role: str, extra_ids: list[str] | None = None) -> dict:
    """Copy a role and append the optional checks this asset asked for. Unknown ids fail."""
    spec = role_spec(doc, role)
    if not extra_ids:
        return spec
    optional = doc.get("optional") or {}
    rows = optional.get(role) if isinstance(optional, dict) else None
    if not isinstance(rows, list):
        raise ValueError(f"role {role} has no optional checks")
    pool: dict[str, dict] = {}
    for row in rows:
        if not isinstance(row, dict) or not isinstance(row.get("id"), str) or not row["id"]:
            raise ValueError(f"role {role} optional check needs an id")
        pool[row["id"]] = row
    seen = {row["id"] for row in spec["checks"]}
    added = []
    for cid in extra_ids:
        if cid in seen:
            raise ValueError(f"check {cid} is already on {role}")
        row = pool.get(cid)
        if row is None:
            raise ValueError(f"role {role} has no optional check {cid}")
        added.append(row)
        seen.add(cid)
    out = dict(spec)
    out["checks"] = list(spec["checks"]) + added
    return out


def prompt_for(spec: dict) -> str:
    lines = [
        "Review this one image for a game art pipeline.",
        "Reply with one JSON object and no markdown.",
        'Schema: {"verdict":"pass"|"fail","checks":[{"id":"...","pass":true|false,"reason":"..."}]}',
        "Include every check id exactly once. Do not stop before the last id.",
        'Set verdict to "fail" if any check has pass false.',
        "If you are unsure, set pass to false and say what you cannot see.",
        "Judge only the checks listed below.",
        spec.get("about", ""),
        spec.get("allow", ""),
        "Checks:",
    ]
    for row in spec["checks"]:
        lines.append(f"- {row['id']}: Fail if: {row['fail_if']}")
    return "\n".join(line for line in lines if line)


def _kept(text: str) -> bool:
    lowered = text.lower()
    if not any(ch.isalpha() for ch in text):
        return False
    return not any(lowered.startswith(prefix) for prefix in _SKIP)


def _sentences(prompt: str) -> list[str]:
    text = " ".join(prompt.split())
    if not text:
        return []
    return [part.strip() for part in _SENTENCE.split(text) if _kept(part.strip())]


def _tags(negative: str) -> list[str]:
    out = []
    for part in negative.split(","):
        part = " ".join(part.split())
        if _kept(part):
            out.append(part)
    return out


def _clause_id(kind: str, text: str) -> str:
    norm = " ".join(text.lower().split())
    digest = hashlib.sha256(norm.encode("utf-8")).hexdigest()[:8]
    return ("p-" if kind == "present" else "n-") + digest


def clauses_from(prompt: str, negative: str) -> list[dict]:
    """Positive sentences must show. Negative tags must not. Repeats collapse."""
    rows: list[dict] = []
    seen: set[str] = set()
    for kind, texts in (("present", _sentences(prompt)), ("absent", _tags(negative))):
        for text in texts:
            cid = _clause_id(kind, text)
            if cid in seen:
                continue
            seen.add(cid)
            rows.append({"id": cid, "kind": kind, "text": text})
    return rows


def batches_of(rows: list, size: int) -> list[list]:
    if size < 1:
        raise ValueError("batch size must be at least 1")
    if not rows:
        return []
    return [rows[i:i + size] for i in range(0, len(rows), size)]


def clause_checks(rows: list[dict]) -> list[dict]:
    out = []
    for row in rows:
        text = row["text"]
        if row["kind"] == "present":
            fail_if = f"This is missing or not clearly visible: {text}"
        elif row["kind"] == "absent":
            fail_if = f"This is visible: {text}"
        else:
            raise ValueError(f"clause kind must be present or absent, not {row['kind']!r}")
        out.append({"id": row["id"], "fail_if": fail_if})
    return out


def prompts_from(workflow: dict) -> tuple[str, str]:
    """The prompt and negative that TextEncodeQwenImage21 sent. No encoder means none."""
    found = []
    for node in workflow.values():
        if not isinstance(node, dict) or node.get("class_type") != "TextEncodeQwenImage21":
            continue
        inputs = node.get("inputs") or {}
        found.append((str(inputs.get("prompt") or ""), str(inputs.get("negative_prompt") or "")))
    if not found:
        return "", ""
    if len(found) > 1:
        raise ValueError("workflow has more than one TextEncodeQwenImage21")
    return found[0]


def _emphasize(row: dict) -> tuple[str, str]:
    if not isinstance(row, dict):
        raise ValueError("prompt clause must be an object")
    text = row.get("text")
    if not isinstance(text, str) or not text.strip():
        raise ValueError("prompt clause needs text")
    text = " ".join(text.split())
    kind = row.get("kind")
    if kind == "present":
        return (f"Required and clearly visible: {text}", "")
    if kind == "absent":
        return (f"Do not include {text.rstrip('.')}.", text)
    raise ValueError(f"clause kind must be present or absent, not {kind!r}")


def _merge_parts(parts: list[dict]) -> dict:
    checks: list[dict] = []
    failed: list[str] = []
    seen: set[str] = set()
    for part in parts:
        checks.extend(part.get("checks") or [])
        for cid in part.get("failed") or []:
            if cid not in seen:
                failed.append(cid)
                seen.add(cid)
    return {"verdict": "fail" if failed else "pass", "checks": checks, "failed": failed}


def assemble(role_parsed: dict, clauses: list[dict], parts: list[dict]) -> dict:
    """Join the role batches and the prompt batches. A shared id is an error."""
    role_ids = [row["id"] for row in role_parsed.get("checks") or []]
    overlap = [row["id"] for row in clauses if row["id"] in role_ids]
    if overlap:
        raise ValueError(f"prompt clause ids collide with role checks: {overlap}")
    merged = _merge_parts([role_parsed, *parts])
    merged["clauses"] = {row["id"]: {"kind": row["kind"], "text": row["text"]} for row in clauses}
    return merged


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


def _review_spec(host: str, model: str, image: Path, spec: dict, timeout: float, label: str) -> dict:
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
            print(f"{label} reply unusable, retry {attempt}: {exc}", flush=True)
    if parsed is None:
        raise ValueError(f"{label} reply unusable ({last_error})") from last_error
    return parsed


def review_image(
    root: Path,
    image: Path,
    role: str,
    *,
    extra: list[str] | None = None,
    prompt: str | None = None,
    negative: str | None = None,
    host: str = HOST,
    model: str = MODEL,
    timeout: float = 480,
) -> dict:
    if not image.is_file():
        raise ValueError(f"no image {image}")
    doc = load_checks(root)
    spec = spec_for(doc, role, extra)
    role_parts = []
    groups = batches_of(spec["checks"], BATCH)
    for index, group in enumerate(groups, start=1):
        label = "review" if len(groups) == 1 else f"check batch {index}/{len(groups)}"
        if len(groups) > 1:
            print(label, flush=True)
        part = dict(spec)
        part["checks"] = group
        role_parts.append(_review_spec(host, model, image, part, timeout, label))
    clauses = clauses_from(prompt or "", negative or "") if (prompt or negative) else []
    prompt_parts = []
    prompt_groups = batches_of(clauses, BATCH)
    for index, group in enumerate(prompt_groups, start=1):
        label = f"prompt batch {index}/{len(prompt_groups)}"
        print(label, flush=True)
        batch_spec = {
            "about": spec.get("about", ""),
            "allow": spec.get("allow", ""),
            "checks": clause_checks(group),
        }
        prompt_parts.append(_review_spec(host, model, image, batch_spec, timeout, label))
    parsed = assemble(_merge_parts(role_parts), clauses, prompt_parts)
    parsed["image"] = str(image)
    parsed["role"] = role
    parsed["model"] = model
    return parsed


def correction_plan(doc: dict, spec: dict, failed: list[str], clauses: dict | None = None) -> dict:
    """Decide how a failed locked-image review is fixed. No fix means hold, not a user handoff."""
    library = doc.get("fix_library") or {}
    flow = spec.get("flow")
    if flow not in ("prompt", "rebuild"):
        raise ValueError(f"role flow must be prompt or rebuild, not {flow!r}")
    if not failed:
        return {"action": "pass", "adds": [], "negatives": [], "failed": []}
    if flow == "rebuild":
        return {"action": "rebuild", "adds": [], "negatives": [], "failed": list(failed)}
    known = clauses or {}
    missing = [cid for cid in failed if cid not in library and cid not in known]
    if missing:
        return {"action": "hold", "adds": [], "negatives": [], "failed": list(failed), "unfixed": missing}
    adds = []
    negatives = []
    for cid in failed:
        if cid in known:
            add, neg = _emphasize(known[cid])
        else:
            fix = library[cid]
            add = fix.get("add") or ""
            neg = fix.get("negative") or ""
        if add and add not in adds:
            adds.append(add)
        if neg and neg not in negatives:
            negatives.append(neg)
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
    sample_doc = {
        "roles": {"sample": {"flow": "prompt", "checks": [{"id": "feet", "fail_if": "blocks"}]}},
        "optional": {"sample": [{"id": "mark", "fail_if": "missing mark"}]},
    }
    added = spec_for(sample_doc, "sample", ["mark"])
    if [row["id"] for row in added["checks"]] != ["feet", "mark"]:
        bad.append("an optional check was not added")
    plain = spec_for(sample_doc, "sample", None)
    if [row["id"] for row in plain["checks"]] != ["feet"]:
        bad.append("a role gained a check it was not given")
    try:
        spec_for(sample_doc, "sample", ["nope"])
        bad.append("an unknown optional check was accepted")
    except ValueError:
        pass
    gate = "A stone gatehouse with a tall door."
    roof = "The roof is a single slope."
    sent = f"{gate} {roof} Required and clearly visible: {gate}"
    banned = "glass curtain wall, neon sign, Do not include neon sign"
    rows = clauses_from(sent, banned)
    texts = [(row["kind"], row["text"]) for row in rows]
    expect = [
        ("present", gate),
        ("present", roof),
        ("absent", "glass curtain wall"),
        ("absent", "neon sign"),
    ]
    if texts != expect:
        bad.append(f"prompt clauses drifted: {texts}")
    if any(word in row["text"].lower() for row in rows for word in ("head", "thigh", "female", "hourglass")):
        bad.append("a building prompt grew a body check")
    if len(batches_of(rows, 2)) != 2 or len(batches_of(rows, BATCH)) != 1:
        bad.append("clauses did not batch")
    if [row["id"] for row in clauses_from(sent, banned)] != [row["id"] for row in rows]:
        bad.append("clause ids changed between calls")
    if len(clauses_from(f"{gate} {gate}", "")) != 1:
        bad.append("a repeated sentence was checked twice")
    if clauses_from("", ""):
        bad.append("an empty prompt grew a check")
    bare = clauses_from("one claim without a stop", "pixel art")
    if [row["kind"] for row in bare] != ["present", "absent"]:
        bad.append("a prompt without a period was dropped")
    try:
        batches_of(rows, 0)
        bad.append("a zero batch size was accepted")
    except ValueError:
        pass
    graph = {"4": {"class_type": "TextEncodeQwenImage21", "inputs": {"prompt": sent, "negative_prompt": banned}}}
    if prompts_from(graph) != (sent, banned):
        bad.append("the sent prompt was not read")
    if prompts_from({"1": {"class_type": "KSampler", "inputs": {}}}) != ("", ""):
        bad.append("a mesh graph invented a prompt")
    try:
        prompts_from({
            "4": {"class_type": "TextEncodeQwenImage21", "inputs": {"prompt": "A.", "negative_prompt": ""}},
            "5": {"class_type": "TextEncodeQwenImage21", "inputs": {"prompt": "B.", "negative_prompt": ""}},
        })
        bad.append("two prompts were accepted")
    except ValueError:
        pass
    clause_plan = correction_plan(
        {"fix_library": {}}, {"flow": "prompt"}, [rows[0]["id"]],
        clauses={rows[0]["id"]: {"kind": "present", "text": gate}},
    )
    if clause_plan["action"] != "prompt" or clause_plan["adds"] != [f"Required and clearly visible: {gate}"]:
        bad.append("a missing prompt clause was not sent back")
    if correction_plan({"fix_library": {}}, {"flow": "prompt"}, ["no_nose"])["action"] != "hold":
        bad.append("a role check with no fix was not held")
    absent = correction_plan(
        {"fix_library": {}}, {"flow": "prompt"}, [rows[2]["id"]],
        clauses={rows[2]["id"]: rows[2]},
    )
    if absent["action"] != "prompt" or "glass curtain wall" not in absent["negatives"]:
        bad.append("a visible negative was not banned again")
    if not absent["adds"] or not absent["adds"][0].lower().startswith("do not include "):
        bad.append("a visible negative was not restated")
    role_ok = {"verdict": "pass", "failed": [], "checks": [{"id": "feet", "pass": True, "reason": ""}]}
    part = {
        "verdict": "fail",
        "failed": [rows[0]["id"]],
        "checks": [{"id": rows[0]["id"], "pass": False, "reason": "no door"}],
    }
    merged = assemble(role_ok, rows[:1], [part])
    if merged["verdict"] != "fail" or merged["failed"] != [rows[0]["id"]]:
        bad.append("a prompt miss did not fail the review")
    if rows[0]["id"] not in merged.get("clauses", {}):
        bad.append("the review dropped the clause map")
    try:
        assemble(
            {"checks": [{"id": rows[0]["id"], "pass": True}], "failed": []},
            rows[:1],
            [],
        )
        bad.append("a colliding clause id was accepted")
    except ValueError:
        pass
    wide = batches_of([{"id": f"c{i}"} for i in range(5)], BATCH)
    if [len(group) for group in wide] != [4, 1]:
        bad.append("a long checklist was not split")
    return bad
