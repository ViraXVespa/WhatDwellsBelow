#!/usr/bin/env python3
"""WIP and export store for the art and content pipeline.

    python tools/media.py pipeline status
    python tools/media.py pipeline check
    python tools/media.py pipeline list
    python tools/media.py pipeline coverage
    python tools/media.py pipeline new --type character --name "Town Guard"
    python tools/media.py pipeline show ID
    python tools/media.py pipeline link ID --rel wears --to OTHER
    python tools/media.py pipeline mark ID --reason locked-front
    python tools/media.py pipeline export ID [--area body]
    python tools/media.py pipeline prompts
    python tools/media.py pipeline review --image path.png --role mannequin-front
    python tools/media.py pipeline review --cycle data/pipeline/wip/review/cycle.json
    python tools/media.py pipeline correct --from review.json --role mannequin-front --workflow still.json --out still-retry.json
    python tools/media.py pipeline tune --image path.png --role mannequin-side --workflow still.json --turns 4
    python tools/media.py pipeline frame --image still.png --out still-framed.png
    python tools/media.py pipeline mesh --glb coarse.glb
    python tools/media.py pipeline proportion --image still.png
    python tools/media.py pipeline body
    python tools/media.py pipeline smooth

WIP under data/pipeline/wip stays off Git. Export under data/pipeline/export is the game contract.
Qwen3-VL review runs only after Comfy is freed. It writes pass/fail JSON under data/pipeline/wip/review.
`tune` repeats that review and a local Comfy regeneration until the checklist passes or --turns is hit.
At the limit it writes report.md with each in-between image. A fail is not a handoff.
`mesh` reads a coarse glb. An empty height band fails. A pass only means shape may run.
`proportion ID` measures a still or a glb against the measures that subject lists. A missing list fails. A vision pass does not override it.
`body ID` builds a Hunyuan3D surface-net mesh from that subject's front plate. The 32-grid path is not used. A connected mesh that misses the subject's measures is not kept.
`smooth ID` tunes four T-pose stills from that subject's shape, then builds the body from the front if they pass. Idle is a later animation.
A fit failure retries one smaller octree. A fragmented mesh stops. The limit writes a progress report. A fail is not a handoff.
"""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))  # tools/lib
import boot  # noqa: E402,F401

import agent_log
from media.pipeline import body, comfy_run, mesh_check, plates, proportion, smooth, store, tune, vision_review

_PROMPTS = Path("data/pipeline/prompts/defaults.json")


def _fingerprint(root: Path) -> list[tuple[str, int, int]]:
    base = store.pipeline_root(root)
    if not base.is_dir():
        return []
    rows = []
    for path in sorted(base.rglob("*")):
        if path.is_file():
            stat = path.stat()
            rows.append((path.relative_to(base).as_posix(), stat.st_size, stat.st_mtime_ns))
    return rows


def _print_subject(doc: dict) -> None:
    print(json.dumps(doc, indent=2))


def _status(root: Path) -> int:
    wip = store.list_subjects(root)
    export_path = store.export_dir(root) / "index.json"
    exported = 0
    if export_path.is_file():
        exported = len(json.loads(export_path.read_text(encoding="utf-8")).get("subjects") or [])
    prompts = root / _PROMPTS
    print(f"schema {store.SCHEMA}")
    print(f"export {store.EXPORT_SCHEMA}")
    print(f"wip {len(wip)}")
    print(f"exported {exported}")
    print(f"prompts {'yes' if prompts.is_file() else 'missing'} { _PROMPTS.as_posix()}")
    return agent_log.emit_result("INFO", wip=len(wip), exported=exported)


def _list(root: Path) -> int:
    rows = store.list_subjects(root)
    for row in rows:
        print(f"{row['id']} {row['type']} {row['name']}")
    return agent_log.emit_result("INFO", subjects=len(rows))


def _show(root: Path, subject_id: str) -> int:
    _print_subject(store.load_subject(root, subject_id))
    return agent_log.emit_result("INFO", id=subject_id)


def _prompts(root: Path) -> int:
    path = root / _PROMPTS
    doc = json.loads(path.read_text(encoding="utf-8"))
    steps = doc.get("steps") or {}
    print(f"global {len(doc.get('global') or '')} chars")
    print(f"types {len(doc.get('types') or {})}")
    print(f"steps {len(steps)}")
    return agent_log.emit_result("INFO", steps=len(steps))


def _check(real: Path) -> int:
    before = _fingerprint(real)
    with tempfile.TemporaryDirectory(prefix="wdb-pipeline-") as tmp:
        repo = Path(tmp)
        (repo / "assets" / "sprites" / "player" / "hero").mkdir(parents=True)
        (repo / "assets" / "sprites" / "npcs").mkdir(parents=True)
        data = repo / "scripts" / "data"
        data.mkdir(parents=True)
        (data / "talk_lines.gd").write_text(
            'const LINES: Dictionary = {\n\t"vendor": [\n\t],\n}\nconst ONCE: Dictionary = {\n\t"receptionist": "x",\n}\n',
            encoding="utf-8",
        )
        (data / "catalog.gd").write_text(
            'const ARTS: Array = [\n\t{"id": "cinder_ember", "set": "cinder"},\n]\n',
            encoding="utf-8",
        )
        hero = store.create_subject(repo, "character", "Hero")
        vendor = store.create_subject(repo, "npc", "Vendor")
        store.mark_hard(repo, hero["id"], "front")
        blocked = False
        try:
            store.export_subject(repo, hero["id"])
        except ValueError as exc:
            blocked = "hard-dirty" in str(exc)
        if not blocked:
            print("error: hard-dirty export was allowed")
            return agent_log.emit_result("FAIL", summary="hard-dirty export was allowed")
        linked = store.link_subjects(repo, hero["id"], "talks", vendor["id"])
        if not any(link["id"] == vendor["id"] for link in linked["links"]):
            print("error: link was not stored")
            return agent_log.emit_result("FAIL", summary="link was not stored")
        copied = store.create_subject(repo, "character", "Hero Two", template=hero["id"])
        if copied["template_of"] != hero["id"] or copied["dirty"]["hard"]:
            print("error: template copy kept the lock or lost its source")
            return agent_log.emit_result("FAIL", summary="template copy")
        exported = store.export_subject(repo, vendor["id"])
        if exported["schema"] != store.EXPORT_SCHEMA or exported["canvas"] != store.CANVAS:
            print("error: export contract")
            return agent_log.emit_result("FAIL", summary="export contract")
        store.validate(store.load_subject(repo, hero["id"]))
        cov = store.coverage(repo)
        missing = {slot["id"] for slot in cov["missing"]}
        if cov["schema"] != "wdb.pipeline.coverage/1" or cov["slots"] != 4 or missing != {"hero", "receptionist", "cinder_ember"}:
            print(f"error: coverage slots={cov['slots']} missing={sorted(missing)}")
            return agent_log.emit_result("FAIL", summary="coverage")
        boss = store.create_subject(repo, "boss", "Gate")
        if boss["draw_scale"] != 4:
            print("error: boss draw_scale")
            return agent_log.emit_result("FAIL", summary="draw_scale")
        problems = (
            vision_review.selftest()
            + tune.selftest()
            + plates.selftest()
            + mesh_check.selftest()
            + body.selftest()
            + smooth.selftest()
            + proportion.selftest()
        )
        hero_doc = store.load_subject(repo, hero["id"])
        hero_doc["sections"]["body"]["data"] = {
            "label": "hero",
            "shape": "A broad chest.",
            "measures": [{"id": "aspect", "view": "any", "max": 1.5}],
        }
        store.save_subject(repo, hero_doc)
        recorded = store.asset_record(store.load_subject(repo, hero["id"]))
        if recorded["measures"][0]["id"] != "aspect":
            print("error: asset record dropped its measures")
            return agent_log.emit_result("FAIL", summary="asset record")
        blank = store.create_subject(repo, "enemy", "Blank")
        try:
            store.asset_record(blank)
            print("error: a subject with no measures was accepted")
            return agent_log.emit_result("FAIL", summary="missing measures")
        except ValueError:
            pass
        doc = vision_review.load_checks(real)
        library = doc.get("fix_library") or {}
        for role, spec in doc["roles"].items():
            vision_review.role_spec(doc, role)
            for row in spec["checks"]:
                if row["id"] not in library:
                    problems.append(f"{role} check {row['id']} has no fix")
        optional = doc.get("optional") or {}
        if not isinstance(optional, dict):
            problems.append("optional checks must be an object")
        else:
            for role, rows in optional.items():
                if role not in doc["roles"]:
                    problems.append(f"optional role {role} is unknown")
                if not isinstance(rows, list):
                    problems.append(f"optional {role} checks must be a list")
                    continue
                for row in rows:
                    cid = row.get("id") if isinstance(row, dict) else None
                    if cid not in library:
                        problems.append(f"{role} optional check {cid} has no fix")
        if problems:
            print("error: vision review " + "; ".join(problems))
            return agent_log.emit_result("FAIL", summary="vision review")
    after = _fingerprint(real)
    if before != after:
        print("error: check wrote the real pipeline store")
        return agent_log.emit_result("FAIL", summary="real store changed")
    print("check passed on a temp store")
    return agent_log.emit_result("PASS", summary="temp store")


def _new(root: Path, args: object, dry: bool) -> int:
    if dry:
        subject_id = args.id or store.slug(args.name)
        print(f"would create {args.type} {subject_id} {args.name}")
        return agent_log.emit_result("INFO", summary="dry-run", id=subject_id)
    doc = store.create_subject(root, args.type, args.name, args.id, args.template)
    print(f"created {doc['type']} {doc['id']}")
    return agent_log.emit_result("PASS", summary="created", id=doc["id"], type=doc["type"])


def _link(root: Path, args: object, dry: bool) -> int:
    if dry:
        print(f"would link {args.id} {args.rel} -> {args.to}")
        return agent_log.emit_result("INFO", summary="dry-run", id=args.id)
    doc = store.link_subjects(root, args.id, args.rel, args.to)
    print(f"linked {doc['id']} {args.rel} {args.to}")
    return agent_log.emit_result("PASS", summary="linked", id=doc["id"])


def _mark(root: Path, args: object, dry: bool) -> int:
    if dry:
        print(f"would mark {args.id} hard {args.reason}")
        return agent_log.emit_result("INFO", summary="dry-run", id=args.id)
    doc = store.mark_hard(root, args.id, args.reason)
    print(f"hard {doc['id']} {args.reason}")
    return agent_log.emit_result("PASS", summary="marked", id=doc["id"])


def _export(root: Path, args: object, dry: bool) -> int:
    areas = agent_log.split_list(args.area) or None
    if dry:
        print(f"would export {args.id} areas={areas or 'all'}")
        return agent_log.emit_result("INFO", summary="dry-run", id=args.id)
    doc = store.export_subject(root, args.id, areas)
    print(f"exported {doc['type']} {doc['id']} areas={len(doc['areas'])}")
    return agent_log.emit_result("PASS", summary="exported", id=doc["id"])


def _coverage(root: Path, dry: bool) -> int:
    if dry:
        print("would scan live sprite slots and write data/pipeline/wip/coverage.json")
        return agent_log.emit_result("INFO", summary="dry-run")
    doc = store.coverage(root)
    print(f"slots {doc['slots']} open {doc['open']}")
    for slot in doc["missing"][:12]:
        print(f"open {slot['type']} {slot['id']}")
    extra = len(doc["missing"]) - 12
    if extra > 0:
        print(f"... {extra} more open slots")
    return agent_log.emit_result("INFO", slots=doc["slots"], open=doc["open"])


def _record(root: Path, args: object) -> dict:
    """Load the subject's measure record. A missing id or a missing list is an error."""
    subject_id = getattr(args, "id", None)
    if not subject_id:
        agent_log.fail("id is required")
    doc = store.load_subject(root, subject_id)
    record = dict(store.asset_record(doc))
    record["id"] = doc["id"]
    return record


def _extras(root: Path, args: object) -> list[str]:
    """Optional vision checks from the subject. No id means no extra checks, and not the female list."""
    subject_id = getattr(args, "id", None)
    if not subject_id:
        return []
    record = store.asset_record(store.load_subject(root, subject_id))
    checks = record.get("checks") or []
    if not isinstance(checks, list) or any(not isinstance(item, str) or not item for item in checks):
        raise ValueError(f"{subject_id} checks must be a list of ids")
    return list(checks)


def _review(root: Path, args: object, dry: bool) -> int:
    jobs = _review_jobs(root, args)
    extra = _extras(root, args)
    if dry:
        for image, role in jobs:
            print(f"would review {image} as {role}")
        return agent_log.emit_result("INFO", summary="dry-run", images=len(jobs))
    out_dir = root / "data" / "pipeline" / "wip" / "review"
    out_dir.mkdir(parents=True, exist_ok=True)
    failed = 0
    for image, role in jobs:
        doc = vision_review.review_image(root, image, role, extra=extra or None)
        dest = out_dir / f"{image.stem}-{role}.json"
        dest.write_text(json.dumps(doc, indent=2) + "\n", encoding="utf-8")
        print(f"{image.name} {role} {doc['verdict'].upper()}")
        for row in doc["checks"]:
            mark = "PASS" if row["pass"] else "FAIL"
            reason = f" {row['reason']}" if row["reason"] else ""
            print(f"  {row['id']} {mark}{reason}")
        if doc["verdict"] != "pass":
            failed += 1
    subprocess.run(["ollama", "stop", vision_review.MODEL], check=False)
    status = "FAIL" if failed else "PASS"
    return agent_log.emit_result(status, summary=f"{failed} failed of {len(jobs)}", failed=failed, images=len(jobs))


def _review_jobs(root: Path, args: object) -> list[tuple[Path, str]]:
    if args.cycle:
        path = Path(args.cycle)
        if not path.is_file():
            path = root / args.cycle
        if not path.is_file():
            agent_log.fail(f"no cycle file {args.cycle}")
        doc = json.loads(path.read_text(encoding="utf-8"))
        rows = doc.get("images") if isinstance(doc, dict) else None
        if not isinstance(rows, list) or not rows:
            agent_log.fail("cycle file needs an images list")
        jobs = []
        for row in rows:
            if not isinstance(row, dict) or not row.get("image") or not row.get("role"):
                agent_log.fail("each cycle image needs image and role")
            image = Path(row["image"])
            if not image.is_file():
                image = root / row["image"]
            jobs.append((image, row["role"]))
        return jobs
    images = args.image or []
    if not images:
        agent_log.fail("--image or --cycle is required")
    role = _need(args.role, "--role")
    jobs = []
    for raw in images:
        image = Path(raw)
        if not image.is_file():
            image = root / raw
        jobs.append((image, role))
    return jobs


def _correct(root: Path, args: object, dry: bool) -> int:
    role = _need(args.role, "--role")
    extra = _extras(root, args)
    doc = vision_review.load_checks(root)
    spec = vision_review.spec_for(doc, role, extra or None)
    if args.review_from:
        path = Path(args.review_from)
        if not path.is_file():
            path = root / args.review_from
        review = json.loads(path.read_text(encoding="utf-8"))
        if review.get("role") not in (None, role):
            agent_log.fail(f"review role is {review.get('role')}, not {role}")
    else:
        image = _need((args.image or [None])[0], "--image")
        image_path = Path(image)
        if not image_path.is_file():
            image_path = root / image
        if dry:
            print(f"would review {image_path} as {role} and correct")
            return agent_log.emit_result("INFO", summary="dry-run")
        review = vision_review.review_image(root, image_path, role, extra=extra or None)
        subprocess.run(["ollama", "stop", vision_review.MODEL], check=False)
    failed = review.get("failed")
    if not isinstance(failed, list):
        agent_log.fail("review has no failed list")
    plan = vision_review.correction_plan(doc, spec, failed)
    print(f"{role} {plan['action'].upper()} failed={','.join(failed) or 'none'}")
    if plan["action"] in ("pass", "hold", "rebuild"):
        if plan["action"] == "hold":
            print("no automatic fix for " + ", ".join(plan.get("unfixed", [])))
        if plan["action"] == "rebuild":
            print("rebuild the mesh from a checklist-passing still. Do not present this render.")
        status = "PASS" if plan["action"] == "pass" else "FAIL"
        return agent_log.emit_result(status, summary=plan["action"], action=plan["action"])
    workflow_path = _need(args.workflow, "--workflow")
    src = Path(workflow_path)
    if not src.is_file():
        src = root / workflow_path
    workflow = json.loads(src.read_text(encoding="utf-8"))
    if dry:
        print(f"would patch {src}")
        return agent_log.emit_result("INFO", summary="dry-run")
    patched = vision_review.patch_workflow(workflow, plan["adds"], plan["negatives"])
    dest = Path(args.out) if args.out else src.with_name(src.stem + "-retry.json")
    if not dest.is_absolute():
        dest = root / dest
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(json.dumps(patched, indent=2) + "\n", encoding="utf-8")
    print(f"patched {dest}")
    return agent_log.emit_result("FAIL", summary="prompt retry", action="prompt", out=str(dest))


def _tune(root: Path, args: object, dry: bool) -> int:
    role = _need(args.role, "--role")
    image = _need((args.image or [None])[0], "--image")
    workflow_path = _need(args.workflow, "--workflow")
    turns = args.turns if args.turns is not None else tune.DEFAULT_TURNS
    if turns < 1:
        agent_log.fail("--turns must be at least 1")
    image_path = Path(image)
    if not image_path.is_file():
        image_path = root / image
    src = Path(workflow_path)
    if not src.is_file():
        src = root / workflow_path
    if dry:
        print(f"would tune {image_path} as {role} for {turns} turns from {src}")
        return agent_log.emit_result("INFO", summary="dry-run", turns=turns)
    workflow = json.loads(src.read_text(encoding="utf-8"))
    extra = _extras(root, args)
    gates = None
    if role in proportion.STILL_ROLES:
        gates = proportion.gates_for(_record(root, args))
    subprocess.run(["ollama", "stop", vision_review.MODEL], check=False)
    first = None
    if args.review_from:
        path = Path(args.review_from)
        if not path.is_file():
            path = root / args.review_from
        first = json.loads(path.read_text(encoding="utf-8"))
        if first.get("role") not in (None, role):
            agent_log.fail(f"review role is {first.get('role')}, not {role}")
    dest = root / "data" / "pipeline" / "wip" / "review" / f"{image_path.stem}-tune"
    server = args.server or comfy_run.SERVER

    def review(path: Path) -> dict:
        print(f"review {path.name}", flush=True)
        comfy_run.free(server)
        doc = vision_review.review_image(root, path, role, extra=extra or None)
        subprocess.run(["ollama", "stop", vision_review.MODEL], check=False)
        if gates is not None:
            forced = "side" if role == "mannequin-tpose-side" else "front"
            measured = proportion.with_reference(
                root, args.id, proportion.measure_image(path, gates, view=forced), gates["deltas"],
            )
            if forced == "front" and list(measured.get("failed") or []) == ["no_ears"]:
                from PIL import Image

                with Image.open(path) as plate:
                    clipped, removed = proportion.clip_ear_lobes(plate)
                if removed:
                    clipped.convert("RGB").save(path)
                    measured = proportion.with_reference(
                        root, args.id, proportion.measure_image(path, gates, view=forced), gates["deltas"],
                    )
                    print(f"clipped ear lobes {removed}px", flush=True)
            print(
                f"proportion {measured['reason']}",
                flush=True,
            )
            doc = proportion.merge_review(doc, measured)
        return doc

    def generate(patched: dict, turn: int, target: Path) -> Path:
        print(f"generate turn {turn}")
        saved = comfy_run.run(server, patched, target)
        try:
            comfy_run.free(server)
        except ValueError as exc:
            print(f"warn: Comfy did not free ({exc})")
        return saved

    report = tune.run_tune(
        root, image_path, role, workflow, dest, review, generate,
        turns=turns, first_review=first,
    )
    print(f"{role} {report['status'].upper()} turns={report['turns']}/{report['limit']}")
    for step in report["steps"]:
        failed = ",".join(step["failed"]) or "none"
        print(f"  turn {step['turn']} {step['verdict'].upper()} failed={failed} action={step['action']}")
    report_path = dest / "report.md"
    if report["status"] == "pass":
        print(f"passed {dest / report['image']}")
        return agent_log.emit_result("PASS", summary="tune passed", role=role, turns=report["turns"], image=str(dest / report["image"]))
    print(f"progress report {report_path}")
    return agent_log.emit_result("FAIL", summary=report["status"], role=role, turns=report["turns"], report=str(report_path))


def _frame(root: Path, args: object, dry: bool) -> int:
    image = _need((args.image or [None])[0], "--image")
    out = _need(args.out, "--out")
    src = Path(image)
    if not src.is_file():
        src = root / image
    dest = Path(out)
    if not dest.is_absolute():
        dest = root / dest
    if dry:
        print(f"would frame {src} -> {dest}")
        return agent_log.emit_result("INFO", summary="dry-run")
    info = plates.frame_file(src, dest)
    print(f"framed {dest} height={info['height']} canvas={info['canvas']}")
    return agent_log.emit_result("PASS", summary="framed", height=info["height"], out=str(dest))


def _mesh(root: Path, args: object, dry: bool) -> int:
    raw = _need(args.glb, "--glb")
    path = Path(raw)
    if not path.is_file():
        path = root / raw
    if dry:
        print(f"would measure {path}")
        return agent_log.emit_result("INFO", summary="dry-run")
    report = mesh_check.check_glb(path)
    print(
        f"verts={report['verts']} span={report['span']} "
        f"empty={report['empty'] or 'none'} bands={report['bands']}"
    )
    if report["ok"]:
        print("mesh is one piece. This is not a look approval.")
        return agent_log.emit_result("PASS", summary="connected", verts=report["verts"], span=report["span"])
    print(f"coarse mesh failed: {report['reason']}. Do not present it.")
    return agent_log.emit_result("FAIL", summary=report["reason"], verts=report["verts"], span=report["span"])


def _proportion(root: Path, args: object, dry: bool) -> int:
    """Print the measures this subject listed. Exit fail when the still or the mesh misses them."""
    record = _record(root, args)
    gates = proportion.gates_for(record)
    image = (args.image or [None])[0]
    if not image and not args.glb:
        agent_log.fail("proportion needs --image or --glb")
    if dry:
        target = image or args.glb
        print(f"would measure {target} for {args.id}")
        return agent_log.emit_result("INFO", summary="dry-run")
    if args.glb:
        path = Path(args.glb)
        if not path.is_file():
            path = root / args.glb
        sized = proportion.check_glb(path, gates)
        print(sized["reason"])
        if sized["ok"]:
            return agent_log.emit_result("PASS", summary="in band", glb=str(path))
        print("proportion failed. Do not present it.")
        return agent_log.emit_result("FAIL", summary=sized["reason"], glb=str(path))
    path = Path(image)
    if not path.is_file():
        path = root / image
    forced = None
    if args.role == "mannequin-tpose-side":
        forced = "side"
    elif args.role in proportion.STILL_ROLES:
        forced = "front"
    measured = proportion.measure_image(path, gates, view=forced)
    print(f"head={measured['head_ratio']} thigh={measured['thigh_ratio']} calf={measured['calf_ratio']} {measured['reason']}")
    if measured["ok"]:
        return agent_log.emit_result("PASS", summary="in band", image=str(path))
    print("proportion failed. Do not present it.")
    return agent_log.emit_result("FAIL", summary=measured["reason"], image=str(path))


def _body(root: Path, args: object, dry: bool) -> int:
    record = _record(root, args)
    gates = proportion.gates_for(record)
    plates_map = record.get("plates") if isinstance(record.get("plates"), dict) else {}
    slots = {
        "front": args.front or plates_map.get("front"),
        "left": args.left or plates_map.get("left"),
        "back": args.back or plates_map.get("back"),
        "right": args.right or plates_map.get("right"),
    }
    views: dict[str, Path] = {}
    for slot, raw in slots.items():
        if not raw:
            agent_log.fail(f"{args.id} has no {slot} plate")
        path = Path(raw)
        if not path.is_file():
            path = root / raw
        if not path.is_file():
            print(f"error: missing {slot} plate {raw}")
            return agent_log.emit_result("FAIL", summary=f"missing {slot}")
        views[slot] = path
    dest = root / "data" / "pipeline" / "wip" / "review" / f"{args.id}-hunyuan-body"
    turns = args.turns if args.turns is not None else len(body.STAGES)
    server = args.server or comfy_run.SERVER
    if dry:
        print(f"would build a surface-net body from {', '.join(views)} turns={turns}")
        return agent_log.emit_result("INFO", summary="dry-run")
    report = body.run_body(
        root, views, dest, subject_id=args.id, gates=gates, server=server, turns=turns,
    )
    print(f"body {report['status'].upper()} turns={report['turns']}/{report['limit']}")
    for step in report["steps"]:
        detail = step.get("error") or step.get("mesh") or ""
        print(f"  turn {step['turn']} octree={step['octree']} action={step['action']} {detail}")
    if report["status"] == "pass":
        print(f"connected {report['glb']}. This is not a look approval.")
        return agent_log.emit_result("PASS", summary="connected", glb=report["glb"], turns=report["turns"])
    print(f"progress report {dest / 'report.md'}. Do not present the mesh.")
    return agent_log.emit_result("FAIL", summary="body", turns=report["turns"], report=str(dest / "report.md"))


def _smooth(root: Path, args: object, dry: bool) -> int:
    """Generate four T-pose stills for one subject, tune each, then build a body from the front."""
    record = _record(root, args)
    gen = root / "data" / "pipeline" / "wip" / "gen"
    if dry:
        print(f"would tune four T-pose stills for {args.id}, then build a body from the front")
        return agent_log.emit_result("INFO", summary="dry-run")
    server = args.server or comfy_run.SERVER
    subprocess.run(["ollama", "stop", vision_review.MODEL], check=False)
    still_turns = args.turns if args.turns is not None else tune.DEFAULT_TURNS
    framed: dict[str, Path] = {}
    for view in smooth.views_for(record):
        slot = view["slot"]
        start = gen / f"{args.id}-mannequin-tpose-{slot}-src.png"
        workflow_path = gen / f"{args.id}-mannequin-tpose-{slot}.json"
        workflow = smooth.workflow_for(slot, record)
        workflow_path.write_text(json.dumps(workflow, indent=2) + "\n", encoding="utf-8")
        print(f"generate {slot} first", flush=True)
        comfy_run.run(server, workflow, start)
        try:
            comfy_run.free(server)
        except ValueError as exc:
            print(f"warn: Comfy did not free ({exc})")
        args.role = view["role"]
        args.image = [str(start)]
        args.workflow = str(workflow_path)
        args.turns = still_turns
        args.review_from = None
        code = _tune(root, args, False)
        if code != 0:
            return code
        dest = root / "data" / "pipeline" / "wip" / "review" / f"{start.stem}-tune"
        report = json.loads((dest / "report.json").read_text(encoding="utf-8"))
        if report.get("status") != "pass":
            print(f"error: {slot} tune exited clean with status {report.get('status')}")
            return agent_log.emit_result("FAIL", summary="tune status")
        passed = dest / str(report.get("image") or "")
        plate = gen / f"{args.id}-mannequin-tpose-{slot}-framed.png"
        plates.frame_file(passed, plate)
        print(f"framed {plate}")
        framed[slot] = plate
    args.front = str(framed["front"])
    args.left = str(framed["left"])
    args.back = str(framed["back"])
    args.right = str(framed["right"])
    args.turns = len(body.STAGES)
    return _body(root, args, False)


def _need(value: str | None, flag: str) -> str:
    if not value:
        agent_log.fail(f"{flag} is required")
    return value


def main(argv: list[str] | None = None) -> int:
    ap = agent_log.std_parser(
        "WIP and export store for the art and content pipeline.",
        writes=True,
        verbose=True,
    )
    ap.add_argument("cmd", help="status, check, list, coverage, prompts, new, show, link, mark, export, review, correct, tune, frame, mesh, proportion, body, or smooth.")
    ap.add_argument(
        "id", nargs="?", default=None,
        help="Subject id. Required for show, link, mark, export, proportion, body, and smooth. "
        "Tune, review, and correct use it for that subject's extra checks and measures.",
    )
    ap.add_argument("--type", choices=store.TYPES, help="Subject type for new.")
    ap.add_argument("--name", help="Display name for new. The id is the slug unless --id is set.")
    ap.add_argument("--template", default=None, help="For new: copy this subject id. Same type only.")
    ap.add_argument("--rel", default=None, help="Relation name for link, for example wears or talks.")
    ap.add_argument("--to", default=None, help="Other subject id for link.")
    ap.add_argument("--reason", default=None, help="Hard-dirty reason for mark, for example locked-front.")
    ap.add_argument("--area", action="append", default=[], help="Section id to export. Repeat for several. Default: every section.")
    ap.add_argument("--image", action="append", default=[], help="Image to review. Repeat to review several with the same --role.")
    ap.add_argument("--role", default=None, help="Vision checklist role, for example mannequin-front.")
    ap.add_argument("--cycle", default=None, help="JSON file with an images list of {image, role}.")
    ap.add_argument("--workflow", default=None, help="Still workflow to patch when a locked-image review fails.")
    ap.add_argument("--out", default=None, help="Patched workflow path for correct.")
    ap.add_argument("--from", dest="review_from", default=None, help="Existing review JSON. Skips a second model call.")
    ap.add_argument("--turns", type=int, default=None, help="Generation limit for tune. Default 4. The limit writes a progress report.")
    ap.add_argument("--server", default=None, help="Local ComfyUI for tune. Default http://127.0.0.1:8188.")
    ap.add_argument("--glb", default=None, help="Coarse glb for mesh. An empty height band fails.")
    ap.add_argument("--front", default=None, help="Framed front plate for body. Default: the locked mannequin front.")
    ap.add_argument("--left", default=None, help="Framed left plate for body.")
    ap.add_argument("--back", default=None, help="Framed back plate for body.")
    ap.add_argument("--right", default=None, help="Framed right plate for body.")
    args = ap.parse_args(argv)
    root = agent_log.resolve_root(args)
    dry = bool(args.dry_run)
    try:
        if args.cmd == "status":
            return _status(root)
        if args.cmd == "check":
            return _check(root)
        if args.cmd == "list":
            return _list(root)
        if args.cmd == "coverage":
            return _coverage(root, dry)
        if args.cmd == "prompts":
            return _prompts(root)
        if args.cmd == "new":
            args.type = _need(args.type, "--type")
            args.name = _need(args.name, "--name")
            return _new(root, args, dry)
        if args.cmd == "show":
            return _show(root, _need(args.id, "id"))
        if args.cmd == "link":
            _need(args.id, "id")
            _need(args.rel, "--rel")
            _need(args.to, "--to")
            return _link(root, args, dry)
        if args.cmd == "mark":
            _need(args.id, "id")
            _need(args.reason, "--reason")
            return _mark(root, args, dry)
        if args.cmd == "export":
            _need(args.id, "id")
            return _export(root, args, dry)
        if args.cmd == "review":
            return _review(root, args, dry)
        if args.cmd == "correct":
            return _correct(root, args, dry)
        if args.cmd == "tune":
            return _tune(root, args, dry)
        if args.cmd == "frame":
            return _frame(root, args, dry)
        if args.cmd == "mesh":
            return _mesh(root, args, dry)
        if args.cmd == "proportion":
            return _proportion(root, args, dry)
        if args.cmd == "body":
            return _body(root, args, dry)
        if args.cmd == "smooth":
            return _smooth(root, args, dry)
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return agent_log.emit_result("FAIL", summary=str(exc))
    agent_log.fail(f"unknown command {args.cmd}")
    return 2


if __name__ == "__main__":
    raise SystemExit(agent_log.guarded(main))
