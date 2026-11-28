"""Real backend: the studio's adapter over the pipeline store and `media.py pipeline`.

Store reads and writes call tools/lib/media/pipeline/store.py. Long commands run the pipeline CLI
in a subprocess. Anything the pipeline does not offer yet raises NotWired; the page shows that text.
UI-owned fields live under `studio` on the WIP record (see UI_KEY) until the schema adopts them.
"""
from __future__ import annotations

import base64
import json
import re
import subprocess
import sys
import time
from pathlib import Path
from urllib.parse import urlparse

from media.pipeline import store

from .jobs import Job

UI_KEY = "studio"
STILL_EXT = {".png", ".jpg", ".jpeg", ".webp"}
MESH_EXT = {".glb"}
MAX_UPLOAD = 25 * 1024 * 1024
GUARDED = {("female", "edit"), ("female", "body"), ("female", "smooth")}
HIDDEN_NAMES = {"female-hunyuan-body-digits.glb", "female-edit-head.png"}
HIDDEN_TOKENS = (  # closed prompts (design/content-pipeline-mesh.md): not presented
    "918e696e", "5b5de309", "d3e0b159", "fcc6c199", "004e9412", "ffec9ef8", "a89468e1", "1e889747",
    "07176358", "ef7de895", "75f81c41", "c5f67d50", "2e90b57c", "c855bdf0", "45195711",
)
POST_HOSTS = {"x.com", "www.x.com", "twitter.com", "www.twitter.com", "mobile.twitter.com"}


def F(name: str, kind: str, label: str, *, flag: str | None = None, required: bool = False, default: object = None) -> dict:
    return {"name": name, "kind": kind, "label": label, "flag": flag or f"--{name}", "required": required, "default": default}


# Generation and long commands. `gpu` jobs run one at a time. `id`: none | optional | required.
COMMANDS: dict[str, dict] = {
    "review": {"label": "Review", "gpu": True, "id": "optional", "about": "Qwen3-VL checks the still against a role checklist and the sent prompt.",
               "fields": [F("image", "still", "Still", required=True), F("role", "role", "Checklist role", required=True), F("workflow", "path", "Still workflow (optional)")]},
    "correct": {"label": "Correct", "gpu": True, "id": "optional", "about": "Turns a review miss into a prompt change. Does not run Comfy.",
                "fields": [F("from", "review", "Review JSON (or a still below)"), F("image", "still", "Still"), F("role", "role", "Checklist role", required=True),
                           F("workflow", "path", "Still workflow", required=True), F("out", "path", "Patched workflow out")]},
    "tune": {"label": "Auto-tune", "gpu": True, "id": "optional", "about": "Review, patch and regenerate until the checklist passes or the turn limit.",
             "fields": [F("image", "still", "Start still", required=True), F("role", "role", "Checklist role", required=True),
                        F("workflow", "path", "Still workflow", required=True), F("turns", "int", "Turns", default=4)]},
    "frame": {"label": "Frame", "gpu": False, "id": "optional", "about": "Keeps the largest opaque mass.",
              "fields": [F("image", "still", "Still", required=True), F("out", "path", "Framed still out", required=True)]},
    "proportion": {"label": "Proportion", "gpu": False, "id": "required", "about": "Measures a still or a mesh against this subject's measures.",
                   "fields": [F("image", "still", "Still (or a mesh below)"), F("glb", "glb", "Mesh"), F("role", "role", "View role (optional)")]},
    "mesh": {"label": "Mesh check", "gpu": False, "id": "optional", "about": "Fails an empty height band or a fragmented mesh. Not a look approval.",
             "fields": [F("glb", "glb", "Mesh", required=True)]},
    "smooth": {"label": "Smooth", "gpu": True, "id": "required", "about": "Tunes four T-pose stills, then builds the body from the front.",
               "fields": [F("turns", "int", "Turns per still", default=4)]},
    "body": {"label": "Body", "gpu": True, "id": "required", "about": "Hunyuan3D body from the passing front plate.",
             "fields": [F("front", "still", "Front plate"), F("left", "still", "Left plate"), F("back", "still", "Back plate"), F("right", "still", "Right plate")]},
    "edit": {"label": "Text edit", "gpu": True, "id": "required", "about": "Draws the change on a whole-body still, then refines a copy of the kept mesh.",
             "fields": [F("text", "text", "Change", required=True), F("glb", "glb", "Source mesh (optional)"), F("image", "still", "Reference still (optional)"),
                        F("passes", "str", "Hi3D passes", default="512,1024,1536")]},
    "reference": {"label": "Ingest reference", "gpu": True, "id": "required", "about": "Pulls the reference image and describes it for the Character flow.", "fields": []},
    "export": {"label": "Export", "gpu": False, "id": "required", "about": "Writes the game contract for the chosen sections.",
               "fields": [F("areas", "areas", "Sections"), F("bypass", "bool", "Export despite hard-dirty flags")]},
}


class ApiError(Exception):
    def __init__(self, status: int, message: str, **extra: object) -> None:
        super().__init__(message)
        self.status, self.message, self.extra = status, message, extra


class NotWired(ApiError):
    """The pipeline side is missing. `seam` names the gap in the task's UI gaps list."""

    def __init__(self, seam: str, message: str) -> None:
        super().__init__(501, f"Not wired yet: {message}", not_wired=seam)


def hidden(name: str) -> bool:
    return name in HIDDEN_NAMES or any(tok in name for tok in HIDDEN_TOKENS)


class Backend:
    simulated = False

    def __init__(self, repo: Path) -> None:
        self.repo = repo      # the checkout (assets, scripts, tools)
        self.root = repo      # the store root (sim uses its own)

    # ---- paths ---------------------------------------------------------------
    def wip(self) -> Path:
        return store.wip_dir(self.root)

    def rel(self, path: Path) -> str:
        try:
            return path.resolve().relative_to(self.root.resolve()).as_posix()
        except ValueError:
            return path.resolve().relative_to(self.repo.resolve()).as_posix()

    def resolve_file(self, rel: str) -> Path:
        """A repo-relative path the page may read: WIP files, export files, and live sprites."""
        if not rel or rel.startswith(("/", "\\")) or ".." in Path(rel).parts:
            raise ApiError(400, "bad path")
        if hidden(Path(rel).name):
            raise ApiError(404, "not presented")
        for base, allowed in ((self.root, ("data/pipeline/wip/", "data/pipeline/export/")), (self.repo, ("assets/sprites/", "data/pipeline/export/"))):
            if rel.startswith(allowed):
                path = (base / rel).resolve()
                if path.is_file() and base.resolve() in path.parents:
                    return path
        raise ApiError(404, f"no file {rel}")

    # ---- info ----------------------------------------------------------------
    def info(self) -> dict:
        try:
            roles = sorted(json.loads((self.root / "data/pipeline/prompts/vision-checks.json").read_text(encoding="utf-8"))["roles"])
        except (OSError, ValueError, KeyError):
            roles = []
        return {
            "simulated": self.simulated,
            "types": list(store.TYPES),
            "sections": {t: [{"id": s, "skeleton": sk} for s, sk in rows] for t, rows in store.SECTIONS.items()},
            "commands": COMMANDS,
            "roles": roles,
            "canvas": store.CANVAS,
            "store_root": "data/pipeline/wip/_sim" if self.simulated else "data/pipeline/wip",
        }

    def prompts(self) -> dict:
        path = self.root / "data/pipeline/prompts/defaults.json"
        return json.loads(path.read_text(encoding="utf-8")) if path.is_file() else {}

    # ---- subjects ------------------------------------------------------------
    def list_subjects(self) -> list[dict]:
        rows = []
        for row in store.list_subjects(self.root):
            try:
                doc = store.load_subject(self.root, row["id"])
            except ValueError:
                rows.append({**row, "broken": True})
                continue
            rows.append({**row, "hard": len(doc["dirty"]["hard"]), "soft": len(doc["dirty"]["soft"]),
                         "exported_at": doc.get("exported_at"), "pending": self._pending(doc)})
        return rows

    def _load(self, subject_id: str) -> dict:
        try:
            return store.load_subject(self.root, subject_id)
        except ValueError as exc:
            raise ApiError(404, str(exc)) from None

    def _ui(self, doc: dict) -> dict:
        ui = doc.setdefault(UI_KEY, {})
        ui.setdefault("schema", "wdb.studio/1")
        ui.setdefault("stills", [])
        ui.setdefault("approvals", {})
        ui.setdefault("history", [])
        return ui

    def _pending(self, doc: dict) -> int:
        return sum(1 for s in self.stills(doc) if s["state"] == "pending" and s["kind"] == "still")

    def show(self, subject_id: str) -> dict:
        doc = self._load(subject_id)
        names = {r["id"]: r for r in store.list_subjects(self.root)}
        links = [{**link, "type": names.get(link["id"], {}).get("type"), "name": names.get(link["id"], {}).get("name"),
                  "missing": link["id"] not in names} for link in doc["links"]]
        return {"subject": doc, "links": links, "stills": self.stills(doc), "reviews": self.reviews(doc)}

    def create(self, body: dict) -> dict:
        try:
            return store.create_subject(self.root, str(body.get("type") or ""), str(body.get("name") or ""),
                                        body.get("id") or None, body.get("template") or None)
        except ValueError as exc:
            raise ApiError(400, str(exc)) from None

    def save_section(self, subject_id: str, section: str, body: dict) -> dict:
        doc = self._load(subject_id)
        if section not in doc["sections"]:
            raise ApiError(404, f"no section {section}")
        data = body.get("data")
        if not isinstance(data, dict):
            raise ApiError(400, "data must be an object")
        doc["sections"][section]["data"] = data
        self._ui(doc).setdefault("edited", {})[section] = store._now()
        if section == "details" and body.get("name") is not None:
            if not str(body["name"]).strip():
                raise ApiError(400, "name is required")
            doc["name"] = str(body["name"]).strip()
        return self._save(doc)

    def save_prompts(self, subject_id: str, body: dict) -> dict:
        doc = self._load(subject_id)
        steps = body.get("steps") or {}
        if not isinstance(steps, dict) or not all(isinstance(v, str) for v in steps.values()):
            raise ApiError(400, "steps must map step names to text")
        self._ui(doc).setdefault("edited", {})["prompts"] = store._now()
        doc["prompts"] = {**doc.get("prompts", {}), "detail": str(body.get("detail") or ""), "steps": {k: v for k, v in steps.items() if v.strip()}}
        if "negative" in body:
            doc["prompts"]["negative"] = str(body.get("negative") or "")
        return self._save(doc)

    def _exists(self, subject_id: str) -> bool:
        return any(r["id"] == subject_id for r in store.list_subjects(self.root))

    def _save(self, doc: dict, before: dict | None = None) -> dict:
        """Local save with dirty propagation. Returns what the save flagged on linked subjects."""
        try:
            saved = store.save_subject(self.root, doc)
        except ValueError as exc:
            raise ApiError(400, str(exc)) from None
        flagged = []
        for link in saved["links"]:
            if not self._exists(link["id"]):
                continue
            soft = [f for f in store.load_subject(self.root, link["id"])["dirty"]["soft"] if f.get("source") == saved["id"]]
            if soft:
                flagged.append({"id": link["id"], "soft": soft})
        return {"subject": saved, "flagged": flagged}

    def link(self, subject_id: str, body: dict) -> dict:
        try:
            return store.link_subjects(self.root, subject_id, str(body.get("rel") or ""), str(body.get("to") or ""))
        except ValueError as exc:
            raise ApiError(400, str(exc)) from None

    def mark(self, subject_id: str, body: dict) -> dict:
        reason = str(body.get("reason") or "").strip()
        if not reason:
            raise ApiError(400, "reason is required")
        return store.mark_hard(self.root, subject_id, reason)

    def clear_flag(self, subject_id: str, body: dict) -> dict:
        raise NotWired("dirty-clear", "clearing a hard or soft flag needs a pipeline command (pipeline mark --clear).")

    # ---- reference -----------------------------------------------------------
    def set_reference(self, subject_id: str, body: dict) -> dict:
        doc = self._load(subject_id)
        kind = body.get("kind")
        ref: dict = {"kind": kind, "at": store._now()}
        if kind == "upload":
            name = re.sub(r"[^A-Za-z0-9._-]+", "-", str(body.get("filename") or "reference.png")).strip("-.") or "reference.png"
            if Path(name).suffix.lower() not in STILL_EXT:
                raise ApiError(400, "upload a png, jpg or webp")
            try:
                raw = base64.b64decode(str(body.get("data") or ""), validate=True)
            except ValueError:
                raise ApiError(400, "upload data is not base64") from None
            if not raw or len(raw) > MAX_UPLOAD:
                raise ApiError(400, "upload is empty or over 25 MB")
            dest = self.wip() / "ref" / subject_id / name
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(raw)
            ref["path"] = self.rel(dest)
        elif kind in ("url", "post"):
            value = str(body.get("value") or "").strip()
            url = urlparse(value)
            if url.scheme not in ("http", "https") or not url.netloc:
                raise ApiError(400, "enter a full http(s) link")
            if kind == "post" and (url.netloc.lower() not in POST_HOSTS or "/status/" not in url.path):
                raise ApiError(400, "a post link looks like https://x.com/NAME/status/ID")
            ref["url"] = value
        else:
            raise ApiError(400, "kind is upload, url or post")
        ui = self._ui(doc)
        ui["reference"] = ref
        store.save_subject(self.root, doc, propagate=False)
        return ref

    # ---- stills and reviews ----------------------------------------------------
    def _scan(self, subject_id: str) -> list[Path]:
        out = []
        for folder in ("gen", "review", "ref/" + subject_id):
            base = self.wip() / folder
            if not base.is_dir():
                continue
            for p in base.iterdir():
                if p.is_file() and p.suffix.lower() in STILL_EXT | MESH_EXT and not hidden(p.name):
                    if folder.startswith("ref/") or p.name.startswith((subject_id + "-", subject_id + "_")):
                        out.append(p)
        return out

    def stills(self, doc: dict) -> list[dict]:
        ui = doc.get(UI_KEY) or {}
        approvals = ui.get("approvals") or {}
        rows: dict[str, dict] = {}
        for row in ui.get("stills") or []:
            path = self.root / row.get("path", "")
            if row.get("path") and path.is_file() and not hidden(path.name):
                rows[row["path"]] = dict(row)
        for p in self._scan(doc["id"]):
            rel = self.rel(p)
            rows.setdefault(rel, {"path": rel})
        out = []
        for rel, row in rows.items():
            p = self.root / rel
            row["kind"] = "mesh" if p.suffix.lower() in MESH_EXT else "still"
            row["mtime"] = p.stat().st_mtime
            row["size"] = p.stat().st_size
            row["state"] = (approvals.get(rel) or {}).get("state", "pending")
            row["simulated"] = bool(row.get("simulated"))
            out.append(row)
        out.sort(key=lambda r: -r["mtime"])
        return out

    def reviews(self, doc: dict) -> list[dict]:
        base = self.wip() / "review"
        out = []
        if base.is_dir():
            for p in sorted(base.glob(f"{doc['id']}*.json"), key=lambda q: -q.stat().st_mtime)[:20]:
                if hidden(p.name):
                    continue
                try:
                    data = json.loads(p.read_text(encoding="utf-8"))
                except (OSError, ValueError):
                    continue
                if isinstance(data, dict) and isinstance(data.get("checks"), list):
                    out.append({"path": self.rel(p), "mtime": p.stat().st_mtime, "verdict": data.get("verdict"),
                                "role": data.get("role") or p.stem.split("-", 1)[-1], "checks": data["checks"],
                                "image": data.get("image"), "simulated": bool(data.get("simulated"))})
        return out

    def set_still_state(self, subject_id: str, body: dict) -> dict:
        doc = self._load(subject_id)
        rel, state = str(body.get("path") or ""), body.get("state")
        if state not in ("approved", "rejected", "pending"):
            raise ApiError(400, "state is approved, rejected or pending")
        if rel not in {s["path"] for s in self.stills(doc)}:
            raise ApiError(404, "no such still on this subject")
        ui = self._ui(doc)
        ui["approvals"][rel] = {"state": state, "at": store._now()}
        store.save_subject(self.root, doc, propagate=False)
        return {"path": rel, "state": state}

    def register(self, subject_id: str | None, paths: list[Path], job: Job, extra: dict | None = None) -> list[dict]:
        if not subject_id or not paths or not self._exists(subject_id):
            return []
        doc = store.load_subject(self.root, subject_id)
        ui = self._ui(doc)
        known = {s["path"] for s in ui["stills"]}
        added = []
        for p in paths:
            rel = self.rel(p)
            if rel in known or hidden(p.name):
                continue
            row = {"path": rel, "cmd": job.cmd, "job": job.id, "args": job.args, "at": store._now(), "simulated": job.simulated, **(extra or {})}
            ui["stills"].append(row)
            added.append(row)
        ui["history"] = (ui["history"] + [{"job": job.id, "cmd": job.cmd, "at": store._now(), "status": "done"}])[-30:]
        store.save_subject(self.root, doc, propagate=False)
        return added

    # ---- coverage --------------------------------------------------------------
    def coverage(self) -> dict:
        doc = store.coverage(self.root)
        return self._coverage_view(doc)

    def _coverage_view(self, doc: dict) -> dict:
        subjects = {r["id"] for r in store.list_subjects(self.root)}
        slots = []
        for slot in doc.get("missing", []):
            src = Path(slot.get("source", ""))
            try:
                src_rel = src.resolve().relative_to(self.repo.resolve()).as_posix()
            except ValueError:
                src_rel = src.name
            slots.append({**slot, "source": src_rel, "subject": slot["id"] in subjects})
        return {"slots": doc["slots"], "open": doc["open"], "missing": slots}

    # ---- jobs --------------------------------------------------------------------
    def precheck(self, cmd: str, subject_id: str | None, args: dict) -> None:
        spec = COMMANDS.get(cmd)
        if spec is None:
            raise ApiError(400, f"unknown command {cmd}")
        if spec["id"] == "required" and not subject_id:
            raise ApiError(400, f"{cmd} needs a subject")
        if subject_id and (subject_id, cmd) in GUARDED:
            raise ApiError(403, f"{cmd} does not run on {subject_id} from the studio.")
        if subject_id:
            self._load(subject_id)
        for f in spec["fields"]:
            if f["required"] and args.get(f["name"]) in (None, "", []):
                raise ApiError(400, f"{f['label']} is required")
        if cmd == "proportion" and not (args.get("image") or args.get("glb")):
            raise ApiError(400, "proportion needs a still or a mesh")
        if cmd == "correct" and not (args.get("from") or args.get("image")):
            raise ApiError(400, "correct needs a review JSON or a still")

    def clear_soft(self, subject_id: str) -> None:
        raise NotWired("soft-dirty-clear", "the store has no call that clears a soft flag after it was shown.")

    def export_check(self, subject_id: str, args: dict) -> None:
        doc = self._load(subject_id)
        if doc["dirty"]["hard"] and not args.get("bypass"):
            raise ApiError(409, "hard-dirty: resolve or bypass before export", hard=doc["dirty"]["hard"])
        if doc["dirty"]["hard"] and args.get("bypass"):
            raise NotWired("export-bypass", "export has no bypass flag for hard-dirty subjects.")

    def body_for(self, cmd: str, subject_id: str | None, args: dict):
        if cmd == "export":
            return lambda job: self._export(job, subject_id, args)
        if cmd == "reference":
            raise NotWired("reference-ingest", "no pipeline command pulls and describes a reference yet.")
        return lambda job: self._cli(job, cmd, subject_id, args)

    def _export(self, job: Job, subject_id: str, args: dict) -> dict:
        job.emit("stage", "Writing the export", 30)
        areas = [a for a in (args.get("areas") or []) if a] or None
        try:
            doc = store.export_subject(self.root, subject_id, areas)
        except ValueError as exc:
            raise ApiError(400, str(exc)) from None
        path = store.export_dir(self.root) / doc["type"] / f"{doc['id']}.json"
        job.emit("log", f"exported {doc['type']} {doc['id']} areas={len(doc['areas'])}")
        return {"ok": True, "export": self.rel(path), "areas": doc["areas"], "exported_at": doc["exported_at"]}

    def _cli(self, job: Job, cmd: str, subject_id: str | None, args: dict) -> dict:
        argv = [sys.executable, str(self.repo / "tools" / "media.py"), "pipeline", cmd]
        if subject_id:
            argv.append(subject_id)
        argv += ["--root", str(self.root)]
        for f in COMMANDS[cmd]["fields"]:
            value = args.get(f["name"])
            if value in (None, "", False, []):
                continue
            argv += [f["flag"], str(value)]
        started = time.time()
        job.emit("stage", f"pipeline {cmd}", 2)
        job.emit("log", "$ " + " ".join(argv[2:]))
        proc = subprocess.Popen(argv, cwd=self.repo, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
        if COMMANDS[cmd]["gpu"]:
            job.cancel_hook = None  # safe Comfy/Ollama cancel is a pipeline gap
        else:
            job.cancel_hook = proc.terminate
        last = ""
        for line in proc.stdout:  # type: ignore[union-attr]
            line = line.rstrip()
            if not line:
                continue
            last = line if line.startswith("RESULT ") else last
            job.emit("log", line, min(95.0, job.pct + (95.0 - job.pct) * 0.08))
        proc.wait()
        if job.cancel_requested:
            from .jobs import Cancelled
            raise Cancelled()
        result = parse_result(last)
        result["exit"] = proc.returncode
        result["ok"] = proc.returncode == 0 and result.get("status") in ("PASS", "INFO", None)
        inputs = {str(v) for v in args.values() if isinstance(v, str)}
        fresh = [p for p in self._fresh(started) if (not subject_id or p.name.startswith(subject_id) or "/ref/" in p.as_posix()) and self.rel(p) not in inputs]
        if not result["ok"]:
            fresh = [p for p in fresh if p.suffix.lower() not in MESH_EXT]  # a failed mesh is not presented
        result["added"] = self.register(subject_id, fresh, job)
        return result

    def _fresh(self, since: float) -> list[Path]:
        out = []
        for folder in ("gen", "review"):
            base = self.wip() / folder
            if base.is_dir():
                out += [p for p in base.iterdir() if p.is_file() and p.suffix.lower() in STILL_EXT | MESH_EXT and p.stat().st_mtime >= since]
        return out

    def cancel(self, job: Job) -> None:
        if job.cancel_hook is None and not self.simulated:
            raise NotWired("safe-cancel", f"{job.cmd} talks to Comfy or Ollama; stopping it safely needs stop_comfyui from the pipeline.")
        job.cancel_requested = True
        if job.cancel_hook:
            job.cancel_hook()


def parse_result(line: str) -> dict:
    """`RESULT PASS k=v k2=v2 summary=...` -> {status, k: v}."""
    if not line.startswith("RESULT "):
        return {"status": None}
    parts = line.split()
    out: dict = {"status": parts[1] if len(parts) > 1 else None}
    for item in parts[2:]:
        if "=" in item:
            k, v = item.split("=", 1)
            out[k] = v
    return out
