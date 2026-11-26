"""Review, correct, and regenerate a locked still until it passes or the turn limit hits.

Each generation is one turn. The starting image is turn 0 and costs no generation.
A repeated miss drops a bible reference, then lowers sampler guidance. The seed
changes every turn. At the limit, the report keeps every in-between image.
A mesh checklist stays a rebuild. This module does not call Ollama or Comfy.
"""
from __future__ import annotations

import json
import shutil
import tempfile
from pathlib import Path

from media.pipeline import vision_review

DEFAULT_TURNS = 4


def prepare_attempt(workflow: dict, adds: list[str], negatives: list[str], *, turn: int, stage: int) -> tuple[dict, dict]:
    """Copy the still workflow for one generation. Stage 0 patches the prompt. Stage 1 also drops a bible reference. Stage 2 also lowers guidance."""
    patched = vision_review.patch_workflow(workflow, adds, negatives)
    dropped = False
    cfg = None
    if stage >= 1:
        patched, dropped = _drop_bible_refs(patched)
    if stage >= 2:
        patched, cfg = _lower_cfg(patched)
    patched, seed = _bump_seed(patched, turn)
    _mark_prefix(patched, turn)
    return patched, {"seed": seed, "dropped_bible": dropped, "cfg": cfg, "stage": stage}


def run_tune(
    root: Path,
    image: Path,
    role: str,
    workflow: dict,
    dest: Path,
    review,
    generate,
    *,
    turns: int = DEFAULT_TURNS,
    first_review: dict | None = None,
) -> dict:
    """Drive review and generate until pass, hold, rebuild, error, or the turn limit."""
    if turns < 1:
        raise ValueError("turns must be at least 1")
    if not image.is_file():
        raise ValueError(f"no image {image}")
    doc = vision_review.load_checks(root)
    spec = vision_review.role_spec(doc, role)
    dest.mkdir(parents=True, exist_ok=True)
    current = dest / "turn-0.png"
    shutil.copy2(image, current)
    report: dict = {
        "schema": "wdb.pipeline.tune/1",
        "role": role,
        "status": "error",
        "turns": 0,
        "limit": turns,
        "image": "turn-0.png",
        "steps": [],
    }
    adds: list[str] = []
    negatives: list[str] = []
    stage = 0
    previous: list[str] | None = None
    made = 0
    while True:
        reviewed = first_review if first_review is not None and not report["steps"] else review(current)
        first_review = None
        failed = reviewed.get("failed")
        if not isinstance(failed, list):
            raise ValueError("review has no failed list")
        step = _step(len(report["steps"]), current.name, reviewed)
        report["steps"].append(step)
        report["image"] = current.name
        plan = vision_review.correction_plan(doc, spec, failed)
        step["action"] = plan["action"]
        if plan["action"] == "pass":
            report["status"] = "pass"
            report["turns"] = made
            break
        if plan["action"] != "prompt":
            step["note"] = _stop_note(plan)
            report["status"] = plan["action"]
            report["turns"] = made
            break
        if made >= turns:
            step["action"] = "limit"
            step["note"] = "Turn limit. No further generation."
            report["status"] = "limit"
            report["turns"] = made
            break
        if previous is not None and set(failed) == set(previous):
            stage = min(stage + 1, 2)
        previous = list(failed)
        for line in plan["adds"]:
            if line not in adds:
                adds.append(line)
        for bit in plan["negatives"]:
            if bit not in negatives:
                negatives.append(bit)
        made += 1
        target = dest / f"turn-{made}.png"
        try:
            patched, note = prepare_attempt(workflow, adds, negatives, turn=made, stage=stage)
            step["note"] = _attempt_note(note)
            current = generate(patched, made, target)
        except ValueError as exc:
            step["action"] = "error"
            step["note"] = str(exc)
            report["status"] = "error"
            report["turns"] = made - 1
            break
        if not isinstance(current, Path):
            current = Path(current)
        if current.resolve() != target.resolve():
            shutil.copy2(current, target)
        current = target
    _write_report(dest, report)
    return report


def _step(turn: int, image: str, reviewed: dict) -> dict:
    reasons = {}
    for row in reviewed.get("checks") or []:
        if isinstance(row, dict) and row.get("pass") is False:
            reasons[str(row.get("id", ""))] = str(row.get("reason") or "")
    failed = [str(item) for item in reviewed.get("failed") or []]
    verdict = "pass" if not failed else "fail"
    return {"turn": turn, "image": image, "verdict": verdict, "failed": failed, "reasons": reasons, "action": "", "note": ""}


def _stop_note(plan: dict) -> str:
    if plan["action"] == "rebuild":
        return "Rebuild the mesh from a checklist-passing still. Do not present this render."
    if plan["action"] == "hold":
        missing = ", ".join(plan.get("unfixed") or [])
        return f"No automatic fix for {missing}."
    return ""


def _attempt_note(note: dict) -> str:
    bits = ["Patched the still prompt."]
    if note.get("dropped_bible"):
        bits.append("Dropped the bible reference.")
    if note.get("cfg") is not None:
        bits.append(f"Guidance {note['cfg']}.")
    if note.get("seed") is not None:
        bits.append(f"Seed {note['seed']}.")
    return " ".join(bits)


def _drop_bible_refs(workflow: dict) -> tuple[dict, bool]:
    bible: list[str] = []
    other: list[str] = []
    for nid, node in workflow.items():
        if not isinstance(node, dict) or node.get("class_type") != "LoadImage":
            continue
        name = str((node.get("inputs") or {}).get("image", ""))
        if "bible" in name.lower():
            bible.append(nid)
        else:
            other.append(nid)
    if not bible or not other:
        return workflow, False
    replacement = other[0]
    changed = False
    for node in workflow.values():
        inputs = node.get("inputs") if isinstance(node, dict) else None
        if not isinstance(inputs, dict):
            continue
        for key, val in inputs.items():
            if isinstance(val, list) and len(val) >= 2 and val[0] in bible:
                inputs[key] = [replacement, val[1]]
                changed = True
    return workflow, changed


def _lower_cfg(workflow: dict) -> tuple[dict, float | None]:
    seen = None
    for node in workflow.values():
        if not isinstance(node, dict) or node.get("class_type") != "KSampler":
            continue
        inputs = node.setdefault("inputs", {})
        value = max(1.0, round(float(inputs.get("cfg", 1.0)) - 0.5, 2))
        inputs["cfg"] = value
        if seen is None:
            seen = value
    return workflow, seen


def _bump_seed(workflow: dict, turn: int) -> tuple[dict, int]:
    seed = None
    for node in workflow.values():
        if not isinstance(node, dict) or node.get("class_type") != "KSampler":
            continue
        inputs = node.setdefault("inputs", {})
        inputs["seed"] = int(inputs.get("seed", 0)) + turn
        if seed is None:
            seed = inputs["seed"]
    if seed is None:
        raise ValueError("workflow has no KSampler seed")
    return workflow, seed


def _mark_prefix(workflow: dict, turn: int) -> None:
    for node in workflow.values():
        if not isinstance(node, dict) or node.get("class_type") != "SaveImage":
            continue
        inputs = node.setdefault("inputs", {})
        prefix = str(inputs.get("filename_prefix") or "wdb-gen/tune")
        inputs["filename_prefix"] = f"{prefix}-t{turn}"


def _write_report(dest: Path, report: dict) -> None:
    (dest / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    status = report["status"]
    lines = []
    if status == "limit":
        lines.append("# Tune stopped at the turn limit")
        lines.append("")
        lines.append(f"Role `{report['role']}` used {report['turns']} of {report['limit']} generations and the checklist still fails.")
        lines.append("The images below are the in-between steps. They are not for approval.")
    elif status == "pass":
        lines.append("# Tune passed")
        lines.append("")
        lines.append(f"Role `{report['role']}` passed on turn {report['steps'][-1]['turn']}.")
    else:
        lines.append(f"# Tune stopped: {status}")
        lines.append("")
        lines.append(f"Role `{report['role']}`. The checklist did not pass.")
    lines.append("")
    for step in report["steps"]:
        lines.append(f"## Turn {step['turn']}")
        lines.append("")
        lines.append(f"![]({step['image']})")
        lines.append("")
        failed = ", ".join(step["failed"]) or "none"
        lines.append(f"{step['verdict'].upper()} failed={failed}")
        for cid, reason in (step.get("reasons") or {}).items():
            if reason:
                lines.append(f"- {cid}: {reason}")
        action = step.get("action") or ""
        note = step.get("note") or ""
        if action or note:
            lines.append(f"Action: {action}. {note}".rstrip())
        lines.append("")
    (dest / "report.md").write_text("\n".join(lines), encoding="utf-8")


def _checks(flow: str) -> dict:
    return {
        "schema": "wdb.pipeline.vision-checks/1",
        "roles": {
            "side": {
                "flow": flow,
                "checks": [{"id": "no_nose", "fail_if": "A nose sticks out."}],
            }
        },
        "fix_library": {"no_nose": {"add": "No nose. The nose is a later piece.", "negative": "nose"}},
    }


def _fake_review(failed: list[str]) -> dict:
    return {
        "verdict": "fail" if failed else "pass",
        "failed": list(failed),
        "checks": [{"id": "no_nose", "pass": not failed, "reason": "nose" if failed else ""}],
    }


def selftest() -> list[str]:
    """Turn limit, escalation, and the report. Does not call Ollama or Comfy."""
    bad: list[str] = []
    workflow = {
        "4": {"class_type": "TextEncodeQwenImage21", "inputs": {
            "prompt": "Body.", "negative_prompt": "blur",
            "images.image_1": ["8", 0], "images.image_2": ["9", 0],
        }},
        "5": {"class_type": "KSampler", "inputs": {"seed": 11, "cfg": 2.5}},
        "7": {"class_type": "SaveImage", "inputs": {"filename_prefix": "wdb-gen/side"}},
        "8": {"class_type": "LoadImage", "inputs": {"image": "female-bible-left.png"}},
        "9": {"class_type": "LoadImage", "inputs": {"image": "female-mannequin-bare.png"}},
    }
    sentence = "No nose. The nose is a later piece."
    first, _note = prepare_attempt(workflow, [sentence], ["nose"], turn=1, stage=0)
    if first["5"]["inputs"]["seed"] != 12 or workflow["5"]["inputs"]["seed"] != 11:
        bad.append("seed did not advance from a copy")
    if first["4"]["inputs"]["images.image_1"] != ["8", 0]:
        bad.append("first try dropped the bible view")
    if first["4"]["inputs"]["prompt"].count(sentence) != 1:
        bad.append("prompt fix was missing")
    if not str(first["7"]["inputs"]["filename_prefix"]).endswith("-t1"):
        bad.append("save prefix did not gain the turn")
    second, second_note = prepare_attempt(workflow, [sentence], ["nose"], turn=2, stage=1)
    if second["4"]["inputs"]["images.image_1"] != ["9", 0] or not second_note["dropped_bible"]:
        bad.append("a repeated miss kept the bible view")
    if not str(second["7"]["inputs"]["filename_prefix"]).endswith("-t2"):
        bad.append("save prefix stacked turns")
    third, _third_note = prepare_attempt(workflow, [sentence], ["nose"], turn=3, stage=2)
    if third["5"]["inputs"]["cfg"] != 2.0:
        bad.append("guidance did not step down")
    with tempfile.TemporaryDirectory(prefix="wdb-tune-") as tmp:
        root = Path(tmp)
        checks = root / "data" / "pipeline" / "prompts"
        checks.mkdir(parents=True)
        (checks / "vision-checks.json").write_text(json.dumps(_checks("prompt")), encoding="utf-8")
        image = root / "start.png"
        image.write_bytes(b"start")
        made = {"n": 0}

        def generate(patched: dict, turn: int, dest: Path) -> Path:
            made["n"] += 1
            dest.write_bytes(f"turn{turn}".encode("ascii"))
            return dest

        seen = {"n": 0}

        def always_fail(path: Path) -> dict:
            seen["n"] += 1
            return _fake_review(["no_nose"])

        limited = run_tune(root, image, "side", workflow, root / "limit", always_fail, generate, turns=2)
        text = (root / "limit" / "report.md").read_text(encoding="utf-8")
        if limited["status"] != "limit" or limited["turns"] != 2 or made["n"] != 2:
            bad.append("the turn limit did not stop after two generations")
        if any(name not in text for name in ("turn-0.png", "turn-1.png", "turn-2.png", "turn limit")):
            bad.append("the limit report dropped an in-between image")
        for name in ("turn-0.png", "turn-1.png", "turn-2.png"):
            if not (root / "limit" / name).is_file():
                bad.append(f"missing {name}")
        made["n"] = 0
        reviews = [_fake_review(["no_nose"]), _fake_review([])]

        def then_pass(path: Path) -> dict:
            return reviews.pop(0)

        passed = run_tune(root, image, "side", workflow, root / "pass", then_pass, generate, turns=4)
        passed_text = (root / "pass" / "report.md").read_text(encoding="utf-8")
        if passed["status"] != "pass" or passed["turns"] != 1 or "turn limit" in passed_text:
            bad.append("a later pass was treated as the turn limit")
        seen["n"] = 0
        skipped = run_tune(
            root, image, "side", workflow, root / "skip", always_fail, generate,
            turns=1, first_review=_fake_review(["no_nose"]),
        )
        if seen["n"] != 1 or skipped["turns"] != 1:
            bad.append("a saved first review was sent to the model again")
        (checks / "vision-checks.json").write_text(json.dumps(_checks("rebuild")), encoding="utf-8")
        made["n"] = 0
        rebuilt = run_tune(root, image, "side", workflow, root / "mesh", always_fail, generate, turns=4)
        if rebuilt["status"] != "rebuild" or made["n"] != 0:
            bad.append("a mesh fail was regenerated")
    return bad
