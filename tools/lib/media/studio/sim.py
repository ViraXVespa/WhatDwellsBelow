"""Simulate backend (WDB_PIPELINE_SIMULATE=1): the real store calls on a separate store root, fake long jobs.

The store root is data/pipeline/wip/_sim, a stand-in repo root with its own WIP and export folders,
so a simulated subject, still, mesh or export never lands in the real WIP or the real export index.
Long jobs walk through staged progress with delays (WDB_PIPELINE_SIM_DELAY seconds per stage).
"""
from __future__ import annotations

import json
import os
import shutil
import zlib
from pathlib import Path

from media.pipeline import store

from . import fakes
from .backend import COMMANDS, ApiError, Backend
from .jobs import Job

SIM_DIR = Path("data/pipeline/wip/_sim")


def sim_delay() -> float:
    try:
        return max(0.0, float(os.environ.get("WDB_PIPELINE_SIM_DELAY", "0.8")))
    except ValueError:
        return 0.8


class SimBackend(Backend):
    simulated = True

    def __init__(self, repo: Path) -> None:
        super().__init__(repo)
        self.root = repo / SIM_DIR
        self._setup()

    def _setup(self) -> None:
        pipe = self.root / "data" / "pipeline"
        for sub in ("prompts", "schemas"):
            src = self.repo / "data" / "pipeline" / sub
            if src.is_dir() and not (pipe / sub).is_dir():
                shutil.copytree(src, pipe / sub)
        idx = pipe / "export" / "index.json"
        if not idx.is_file():
            idx.parent.mkdir(parents=True, exist_ok=True)
            idx.write_text(json.dumps({"schema": store.EXPORT_INDEX_SCHEMA, "subjects": []}, indent=2) + "\n", encoding="utf-8")
        (self.root / "SIMULATED.txt").write_text(
            "Simulated studio store (WDB_PIPELINE_SIMULATE=1). Nothing here is real pipeline output. Safe to delete.\n", encoding="utf-8")
        if not store.list_subjects(self.root):
            self._seed()

    def _seed(self) -> None:
        hero = store.create_subject(self.root, "character", "Sim Hero", "sim-hero")
        hero["sections"]["details"]["data"] = {"notes": "Simulated sample subject."}
        hero["sections"]["body"]["data"] = {"measures": ["head", "thigh", "calf"], "bands": {"front": {"head": [0.73, 1.2], "thigh_max": 0.5, "calf_max": 0.32}}}
        store.save_subject(self.root, hero, propagate=False)
        store.create_subject(self.root, "enemy", "Sim Slime", "sim-slime")
        store.create_subject(self.root, "item", "Sim Potion", "sim-potion")
        store.link_subjects(self.root, "sim-hero", "carries", "sim-potion")
        store.link_subjects(self.root, "sim-slime", "drops", "sim-potion")

    # ---- seams that work in simulate -------------------------------------------
    def clear_flag(self, subject_id: str, body: dict) -> dict:
        doc = self._load(subject_id)
        kind, reason = body.get("kind"), str(body.get("reason") or "")
        if kind == "hard":
            doc["dirty"]["hard"] = [r for r in doc["dirty"]["hard"] if r != reason]
        elif kind == "soft":
            doc["dirty"]["soft"] = [f for f in doc["dirty"]["soft"] if f.get("reason") != reason]
        else:
            raise ApiError(400, "kind is hard or soft")
        return store.save_subject(self.root, doc, propagate=False)

    def clear_soft(self, subject_id: str) -> None:
        doc = self._load(subject_id)
        doc["dirty"]["soft"] = []
        store.save_subject(self.root, doc, propagate=False)

    def coverage(self) -> dict:
        doc = store.coverage(self.repo, write=False)
        exported = {r["id"] for r in json.loads((self.root / "data/pipeline/export/index.json").read_text(encoding="utf-8")).get("subjects", [])}
        missing = [s for s in doc["missing"] if s["id"] not in exported]
        view = self._coverage_view({"slots": doc["slots"], "open": len(missing), "missing": missing})
        view["simulated"] = True
        return view

    def cancel(self, job: Job) -> None:
        job.cancel_requested = True

    # ---- fake long jobs ------------------------------------------------------------
    def body_for(self, cmd: str, subject_id: str | None, args: dict):
        fn = getattr(self, f"_sim_{cmd}", None)
        if fn is None:
            raise ApiError(400, f"no simulated {cmd}")
        return lambda job: fn(job, subject_id, args)

    def _seed_of(self, job: Job) -> int:
        return zlib.crc32(job.id.encode())

    def _step(self, job: Job, msg: str, pct: float, factor: float = 1.0) -> None:
        job.emit("stage", msg, pct)
        job.emit("log", f"[simulated] {msg}")
        job.sleep(sim_delay() * factor)

    def _gen(self, name: str) -> Path:
        return self.wip() / "gen" / name

    def _still(self, job: Job, subject_id: str | None, view: str, tag: str) -> Path:
        name = f"{subject_id or 'sim'}-sim-{tag}-{view}-{job.id[:6]}.png"
        return fakes.still_png(self._gen(name), label=subject_id or "sim", view=view, seed=self._seed_of(job) + len(tag))

    def _checks(self, role: str) -> list[dict]:
        doc = json.loads((self.root / "data/pipeline/prompts/vision-checks.json").read_text(encoding="utf-8"))
        spec = doc.get("roles", {}).get(role)
        if not spec:
            raise ApiError(400, f"unknown role {role}")
        return spec["checks"]

    def _write_review(self, image: str, role: str, doc: dict) -> Path:
        dest = self.wip() / "review" / f"{Path(image).stem}-{role}.json"
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(json.dumps({**doc, "role": role, "image": image}, indent=2) + "\n", encoding="utf-8")
        return dest

    def _sim_review(self, job: Job, sid: str | None, args: dict) -> dict:
        self._step(job, "Freeing Comfy", 10, 0.5)
        self._step(job, "Loading Qwen3-VL", 25)
        checks = self._checks(args["role"])
        for i in range(0, len(checks), 4):
            self._step(job, f"Checks {i + 1}-{min(i + 4, len(checks))} of {len(checks)}", 30 + 60 * i / max(1, len(checks)), 0.5)
        doc = fakes.review(checks, seed=self._seed_of(job))
        path = self._write_review(args["image"], args["role"], doc)
        self._step(job, "Stopping qwen3-vl:8b", 95, 0.3)
        return {"ok": doc["verdict"] == "pass", "verdict": doc["verdict"], "failed": doc["failed"], "review": self.rel(path), "simulated": True}

    def _sim_correct(self, job: Job, sid: str | None, args: dict) -> dict:
        self._step(job, "Reading the review", 20)
        failed = []
        if args.get("from"):
            try:
                failed = json.loads(self.resolve_file(args["from"]).read_text(encoding="utf-8")).get("failed") or []
            except (ApiError, ValueError):
                failed = []
        self._step(job, "Restating the misses as prompt changes", 60)
        out = self.wip() / "gen" / Path(str(args.get("out") or f"{sid or 'sim'}-sim-retry-{job.id[:6]}.json")).name
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps({"simulated": True, "adds": [f"fix {f}" for f in failed], "from": args.get("workflow")}, indent=2) + "\n", encoding="utf-8")
        return {"ok": True, "action": "prompt" if failed else "pass", "failed": failed, "out": self.rel(out), "simulated": True}

    def _sim_tune(self, job: Job, sid: str | None, args: dict) -> dict:
        turns = max(1, min(int(args.get("turns") or 4), 6))
        checks = self._checks(args["role"])
        made, verdict, review_path = [], "fail", None
        for turn in range(1, turns + 1):
            base = 100 * (turn - 1) / turns
            self._step(job, f"Turn {turn}/{turns}: generating still (Qwen Image)", base + 5)
            still = self._still(job, sid, "front", f"tune{turn}")
            made.append(still)
            self._step(job, f"Turn {turn}/{turns}: reviewing (Qwen3-VL)", base + 60 / turns)
            doc = fakes.review(checks, seed=self._seed_of(job) + turn, force_pass=turn == turns or turn >= 2)
            review_path = self._write_review(self.rel(still), args["role"], doc)
            verdict = doc["verdict"]
            job.emit("log", f"turn {turn} {verdict.upper()} failed={','.join(doc['failed']) or 'none'}")
            if verdict == "pass":
                break
        added = self.register(sid, made, job)
        return {"ok": verdict == "pass", "verdict": verdict, "turns": len(made), "review": self.rel(review_path) if review_path else None,
                "added": added, "simulated": True}

    def _sim_frame(self, job: Job, sid: str | None, args: dict) -> dict:
        self._step(job, "Keeping the largest opaque mass", 50)
        dest = fakes.still_png(self._gen(Path(str(args["out"])).name), label=f"{sid or 'sim'} framed", seed=self._seed_of(job))
        added = self.register(sid, [dest], job)
        return {"ok": True, "out": self.rel(dest), "height": 930, "canvas": 1024, "added": added, "simulated": True}

    def _sim_proportion(self, job: Job, sid: str | None, args: dict) -> dict:
        self._step(job, "Measuring head, thigh and calf", 50)
        return {**fakes.proportion(self._seed_of(job)), "target": args.get("image") or args.get("glb")}

    def _sim_mesh(self, job: Job, sid: str | None, args: dict) -> dict:
        self._step(job, "Reading the mesh", 40)
        self._step(job, "Checking height bands", 80, 0.5)
        return {**fakes.mesh_report(self._seed_of(job)), "glb": args.get("glb")}

    def _sim_smooth(self, job: Job, sid: str | None, args: dict) -> dict:
        made = []
        for i, view in enumerate(fakes.VIEWS):
            self._step(job, f"T-pose {view}: generate and tune", 5 + i * 18)
            made.append(self._still(job, sid, view, "tpose"))
        self._step(job, "Hunyuan3D body from the front", 80, 1.5)
        glb = fakes.tpose_glb(self._gen(f"{sid}-sim-body-{job.id[:6]}.glb"))
        added = self.register(sid, made + [glb], job)
        return {"ok": True, "glb": self.rel(glb), "added": added, "simulated": True}

    def _sim_body(self, job: Job, sid: str | None, args: dict) -> dict:
        self._step(job, "Loading Hunyuan3D 2.1", 15)
        self._step(job, "Shape: latent 4096, octree 256", 45, 1.5)
        self._step(job, "Surface net", 75)
        glb = fakes.tpose_glb(self._gen(f"{sid}-sim-body-{job.id[:6]}.glb"))
        self._step(job, "Mesh and proportion gates", 90, 0.5)
        added = self.register(sid, [glb], job)
        return {"ok": True, "glb": self.rel(glb), "verts": 3024, "added": added, "simulated": True}

    def _sim_edit(self, job: Job, sid: str | None, args: dict) -> dict:
        self._step(job, "Drawing the change on a whole-body still", 20)
        still = self._still(job, sid, "front", "edit")
        self._step(job, "Vision and proportion on the still", 45)
        for i, res in enumerate(str(args.get("passes") or "512,1024,1536").split(",")):
            self._step(job, f"Hi3D refine {res.strip()}", 55 + i * 12)
        glb = fakes.tpose_glb(self._gen(f"{sid}-sim-body-edit-{job.id[:6]}.glb"))
        added = self.register(sid, [still, glb], job)
        return {"ok": True, "still": self.rel(still), "glb": self.rel(glb), "text": args.get("text"), "added": added, "simulated": True}

    def _sim_reference(self, job: Job, sid: str, args: dict) -> dict:
        doc = self._load(sid)
        ref = (doc.get("studio") or {}).get("reference")
        if not ref:
            raise ApiError(400, "store a reference first")
        self._step(job, "Fetching the reference" if ref.get("url") else "Reading the upload", 15)
        if ref.get("path"):
            image = self.root / ref["path"]
        else:
            image = fakes.still_png(self.wip() / "ref" / sid / f"sim-extracted-{job.id[:6]}.png", label="reference", seed=self._seed_of(job))
        self._step(job, "Describing structure and traits (Qwen3-VL)", 55, 1.5)
        ingest = {
            "image": self.rel(image),
            "description": "(simulated) One adult figure, full body, three-quarter view, long dark hair, light armor.",
            "mannequin": ["(simulated) slightly longer legs than the locked base", "(simulated) narrower shoulders"],
            "traits": ["hair: long, dark", "eyes: green", "outfit: light armor, belt pouches"],
            "simulated": True,
        }
        doc = self._load(sid)
        doc.setdefault("studio", {}).setdefault("reference", ref)["ingest"] = ingest
        store.save_subject(self.root, doc, propagate=False)
        added = self.register(sid, [image], job)
        return {"ok": True, **ingest, "added": added}

    def _sim_export(self, job: Job, sid: str, args: dict) -> dict:
        self._step(job, "Collecting sections", 20)
        doc = self._load(sid)
        hard = list(doc["dirty"]["hard"])
        if hard and args.get("bypass"):
            doc["dirty"]["hard"] = []
            store.save_subject(self.root, doc, propagate=False)
            job.emit("log", "[simulated] bypassed hard-dirty: " + ", ".join(hard))
        self._step(job, "Writing the game contract", 60)
        try:
            exported = store.export_subject(self.root, sid, [a for a in (args.get("areas") or []) if a] or None)
        finally:
            if hard and args.get("bypass"):
                doc = self._load(sid)
                doc["dirty"]["hard"] = hard
                store.save_subject(self.root, doc, propagate=False)
        path = store.export_dir(self.root) / exported["type"] / f"{sid}.json"
        return {"ok": True, "export": self.rel(path), "areas": exported["areas"], "exported_at": exported["exported_at"],
                "bypassed": hard if args.get("bypass") else [], "simulated": True}


assert set(COMMANDS) <= {n[5:] for n in dir(SimBackend) if n.startswith("_sim_")}
