"""WIP and export store for the art and content pipeline.

WIP lives under data/pipeline/wip and is gitignored. Export under
data/pipeline/export is the game contract and is what gets committed.
"""
from __future__ import annotations

import json
import re
from datetime import datetime, timezone
from pathlib import Path

SCHEMA = "wdb.pipeline/1"
EXPORT_SCHEMA = "wdb.export/1"
INDEX_SCHEMA = "wdb.pipeline.index/1"
EXPORT_INDEX_SCHEMA = "wdb.export.index/1"
CANVAS = 128

TYPES = (
    "character", "npc", "enemy", "sub-boss", "boss", "equipment", "item",
    "projectile", "decoration", "resource", "ui", "biome", "building", "vfx",
)

# (section id, skeleton). Skeleton sections navigate and stay empty on purpose.
SECTIONS: dict[str, tuple[tuple[str, bool], ...]] = {
    "character": (
        ("details", False), ("body", False), ("model", False), ("portrait", False),
        ("traits", False), ("defaults", False), ("equipment", False), ("animation", False),
    ),
    "npc": (
        ("details", False), ("body", False), ("portrait", False), ("dialog", False), ("animation", False),
    ),
    "enemy": (
        ("details", False), ("description", False), ("model", False), ("portrait", False),
        ("behavior", False), ("stats", False), ("animation", False), ("items", True),
        ("alternates", False), ("diversity", False), ("named", False),
    ),
    "sub-boss": (
        ("details", False), ("description", False), ("model", False), ("portrait", False),
        ("behavior", False), ("stats", False), ("animation", False), ("items", True),
    ),
    "boss": (
        ("details", False), ("description", False), ("model", False), ("portrait", False),
        ("behavior", False), ("stats", False), ("animation", False), ("items", True),
    ),
    "equipment": (
        ("details", False), ("skin", False), ("skills", False), ("offsets", False), ("stats", False), ("hooks", False),
    ),
    "item": (("details", False), ("art", False), ("stats", False)),
    "projectile": (("details", False), ("art", False), ("motion", False)),
    "decoration": (("details", False), ("art", False)),
    "resource": (("details", False), ("art", False), ("recipes", True)),
    "ui": (("details", False), ("art", False)),
    "biome": (
        ("details", False), ("overview", False), ("features", False), ("art", False), ("layout", True),
    ),
    "building": (
        ("details", False), ("art", False), ("dimensions", False), ("interior", True),
    ),
    "vfx": (("details", False), ("art", False), ("attach", True)),
}

_ID = re.compile(r"^[a-z0-9][a-z0-9_-]{0,63}$")
_DRAW = {"sub-boss": 2, "boss": 4}


def pipeline_root(repo: Path) -> Path:
    return repo / "data" / "pipeline"


def wip_dir(repo: Path) -> Path:
    return pipeline_root(repo) / "wip"


def export_dir(repo: Path) -> Path:
    return pipeline_root(repo) / "export"


def _now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def slug(name: str) -> str:
    text = re.sub(r"[^a-z0-9]+", "-", name.strip().lower()).strip("-")
    if not text:
        raise ValueError("name must contain a letter or number")
    return text[:64]


def _read(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _write(path: Path, doc: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(doc, indent=2) + "\n", encoding="utf-8")


def _index_path(repo: Path) -> Path:
    return wip_dir(repo) / "index.json"


def _export_index_path(repo: Path) -> Path:
    return export_dir(repo) / "index.json"


def load_index(repo: Path) -> dict:
    path = _index_path(repo)
    if not path.is_file():
        return {"schema": INDEX_SCHEMA, "subjects": []}
    doc = _read(path)
    if doc.get("schema") != INDEX_SCHEMA or not isinstance(doc.get("subjects"), list):
        raise ValueError(f"invalid WIP index: {path}")
    return doc


def _subject_path(repo: Path, type_name: str, subject_id: str) -> Path:
    return wip_dir(repo) / type_name / f"{subject_id}.json"


def _find(repo: Path, subject_id: str) -> Path | None:
    for row in load_index(repo)["subjects"]:
        if row["id"] == subject_id:
            path = _subject_path(repo, row["type"], subject_id)
            if path.is_file():
                return path
    return None


def _blank_sections(type_name: str) -> dict:
    return {
        name: {"skeleton": skeleton, "data": {}}
        for name, skeleton in SECTIONS[type_name]
    }


def _blank(type_name: str, subject_id: str, name: str, template_of: str | None) -> dict:
    return {
        "schema": SCHEMA,
        "id": subject_id,
        "type": type_name,
        "name": name,
        "body_type": None,
        "template_of": template_of,
        "draw_scale": _DRAW.get(type_name, 1),
        "prompts": {"detail": "", "steps": {}},
        "links": [],
        "dirty": {"hard": [], "soft": []},
        "sections": _blank_sections(type_name),
        "assets": {},
        "review": {},
        "exported_at": None,
        "updated": _now(),
    }


def validate(doc: dict) -> None:
    if not isinstance(doc, dict):
        raise ValueError("subject must be an object")
    if doc.get("schema") != SCHEMA:
        raise ValueError(f"schema must be {SCHEMA}")
    if doc.get("type") not in TYPES:
        raise ValueError(f"unknown type {doc.get('type')!r}")
    if not isinstance(doc.get("name"), str) or not doc["name"].strip():
        raise ValueError("name is required")
    if not isinstance(doc.get("id"), str) or not _ID.fullmatch(doc["id"]):
        raise ValueError(f"id must match {_ID.pattern}")
    dirty = doc.get("dirty")
    if not isinstance(dirty, dict) or not isinstance(dirty.get("hard"), list) or not isinstance(dirty.get("soft"), list):
        raise ValueError("dirty.hard and dirty.soft must be lists")
    links = doc.get("links")
    if not isinstance(links, list):
        raise ValueError("links must be a list")
    for link in links:
        if not isinstance(link, dict) or not link.get("rel") or not link.get("id"):
            raise ValueError("each link needs rel and id")
    sections = doc.get("sections")
    if not isinstance(sections, dict):
        raise ValueError("sections must be an object")
    expected = {name for name, _ in SECTIONS[doc["type"]]}
    missing = expected - set(sections)
    if missing:
        raise ValueError("missing sections: " + ", ".join(sorted(missing)))


def load_subject(repo: Path, subject_id: str) -> dict:
    path = _find(repo, subject_id)
    if path is None:
        raise ValueError(f"no subject {subject_id}")
    doc = _read(path)
    validate(doc)
    return doc


def list_subjects(repo: Path) -> list[dict]:
    return list(load_index(repo)["subjects"])


def _upsert_index(repo: Path, doc: dict) -> None:
    index = load_index(repo)
    row = {"id": doc["id"], "type": doc["type"], "name": doc["name"], "updated": doc["updated"]}
    rows = [r for r in index["subjects"] if r["id"] != doc["id"]]
    rows.append(row)
    rows.sort(key=lambda r: r["id"])
    index["subjects"] = rows
    _write(_index_path(repo), index)


def _soft(doc: dict, reason: str, source: str) -> bool:
    flag = {"reason": reason, "source": source, "at": _now()}
    for old in doc["dirty"]["soft"]:
        if old.get("reason") == reason and old.get("source") == source:
            return False
    doc["dirty"]["soft"].append(flag)
    return True


def save_subject(repo: Path, doc: dict, *, propagate: bool = True) -> dict:
    validate(doc)
    doc["name"] = doc["name"].strip()
    doc["updated"] = _now()
    _write(_subject_path(repo, doc["type"], doc["id"]), doc)
    _upsert_index(repo, doc)
    if propagate:
        for link in doc["links"]:
            other_path = _find(repo, link["id"])
            if other_path is None:
                continue
            other = _read(other_path)
            reverse = {"rel": link["rel"], "id": doc["id"]}
            if reverse not in other["links"]:
                other["links"].append(reverse)
            _soft(other, f"linked {doc['id']} changed", doc["id"])
            save_subject(repo, other, propagate=False)
    return doc


def create_subject(repo: Path, type_name: str, name: str, subject_id: str | None = None, template: str | None = None) -> dict:
    if type_name not in TYPES:
        raise ValueError(f"unknown type {type_name!r}")
    if not name or not name.strip():
        raise ValueError("name is required")
    subject_id = subject_id or slug(name)
    if _find(repo, subject_id) is not None:
        raise ValueError(f"subject {subject_id} already exists")
    if template:
        base = load_subject(repo, template)
        if base["type"] != type_name:
            raise ValueError(f"template {template} is a {base['type']}, not a {type_name}")
        doc = json.loads(json.dumps(base))
        doc["id"] = subject_id
        doc["name"] = name.strip()
        doc["template_of"] = template
        doc["exported_at"] = None
        doc["dirty"] = {"hard": [], "soft": []}
        doc["review"] = {}
    else:
        doc = _blank(type_name, subject_id, name.strip(), None)
    return save_subject(repo, doc, propagate=False)


def link_subjects(repo: Path, subject_id: str, rel: str, other_id: str) -> dict:
    if not rel.strip():
        raise ValueError("rel is required")
    doc = load_subject(repo, subject_id)
    if _find(repo, other_id) is None:
        raise ValueError(f"no subject {other_id}")
    link = {"rel": rel.strip(), "id": other_id}
    if link not in doc["links"]:
        doc["links"].append(link)
    return save_subject(repo, doc)


def mark_hard(repo: Path, subject_id: str, reason: str) -> dict:
    doc = load_subject(repo, subject_id)
    if reason not in doc["dirty"]["hard"]:
        doc["dirty"]["hard"].append(reason)
    return save_subject(repo, doc, propagate=False)


def export_subject(repo: Path, subject_id: str, areas: list[str] | None = None) -> dict:
    doc = load_subject(repo, subject_id)
    hard = list(doc["dirty"]["hard"])
    if hard:
        raise ValueError("hard-dirty, resolve or bypass before export: " + ", ".join(hard))
    known = set(doc["sections"])
    chosen = list(areas) if areas else sorted(known)
    unknown = [name for name in chosen if name not in known]
    if unknown:
        raise ValueError("unknown area(s): " + ", ".join(unknown))
    stamp = _now()
    exported = {
        "schema": EXPORT_SCHEMA,
        "id": doc["id"],
        "type": doc["type"],
        "name": doc["name"],
        "canvas": CANVAS,
        "draw_scale": doc.get("draw_scale", 1),
        "areas": chosen,
        "sections": {name: doc["sections"][name] for name in chosen},
        "frames": {},
        "sheets": [],
        "paperdoll": [],
        "rules": [],
        "dialog": [],
        "audio": [],
        "stats": {},
        "exported_at": stamp,
    }
    path = export_dir(repo) / doc["type"] / f"{doc['id']}.json"
    _write(path, exported)
    index_path = _export_index_path(repo)
    index = _read(index_path) if index_path.is_file() else {"schema": EXPORT_INDEX_SCHEMA, "subjects": []}
    if index.get("schema") != EXPORT_INDEX_SCHEMA:
        raise ValueError(f"invalid export index: {index_path}")
    row = {"id": doc["id"], "type": doc["type"], "name": doc["name"], "exported_at": stamp}
    index["subjects"] = [r for r in index["subjects"] if r["id"] != doc["id"]]
    index["subjects"].append(row)
    index["subjects"].sort(key=lambda r: r["id"])
    _write(index_path, index)
    doc["exported_at"] = stamp
    save_subject(repo, doc, propagate=False)
    return exported


def _slot_dirs(folder: Path, type_name: str) -> list[dict]:
    if not folder.is_dir():
        return []
    rows = []
    for child in sorted(p for p in folder.iterdir() if p.is_dir()):
        rows.append({"id": child.name, "type": type_name, "source": child.as_posix()})
    return rows


def _slot_pngs(folder: Path, type_name: str) -> list[dict]:
    if not folder.is_dir():
        return []
    rows = []
    for child in sorted(folder.glob("*.png")):
        rows.append({"id": child.stem, "type": type_name, "source": child.as_posix()})
    return rows


def _const_block(text: str, name: str) -> str:
    match = re.search(rf"const {name}\b.*?=\s*\{{(.*?)\n\}}", text, re.S)
    return match.group(1) if match else ""


def _dict_keys(block: str) -> list[str]:
    return re.findall(r'^\t"([a-z0-9_]+)":', block, re.M)


def _merge(slots: list[dict]) -> list[dict]:
    seen: dict[tuple[str, str], dict] = {}
    for slot in slots:
        seen[(slot["type"], slot["id"])] = slot
    return [seen[key] for key in sorted(seen)]


def _talk_slots(repo: Path) -> list[dict]:
    path = repo / "scripts" / "data" / "talk_lines.gd"
    if not path.is_file():
        return []
    text = path.read_text(encoding="utf-8")
    ids = _dict_keys(_const_block(text, "LINES")) + _dict_keys(_const_block(text, "ONCE"))
    source = path.as_posix()
    return [{"id": name, "type": "npc", "source": source} for name in ids]


def _gear_slots(repo: Path) -> list[dict]:
    slots = _slot_pngs(repo / "assets" / "ui" / "gear", "equipment")
    path = repo / "scripts" / "data" / "catalog.gd"
    if path.is_file():
        ids = re.findall(r'"id"\s*:\s*"([a-z0-9_]+)"', path.read_text(encoding="utf-8"))
        slots += [{"id": name, "type": "equipment", "source": path.as_posix()} for name in ids]
    return slots


def coverage(repo: Path) -> dict:
    sprites = repo / "assets" / "sprites"
    slots = []
    slots += _slot_dirs(sprites / "player", "character")
    slots += _slot_dirs(sprites / "enemies", "enemy")
    slots += _slot_pngs(sprites / "npcs", "npc")
    slots += _talk_slots(repo)
    slots += _gear_slots(repo)
    slots += _slot_pngs(sprites / "props", "decoration")
    slots += _slot_pngs(sprites / "buildings", "building")
    slots = _merge(slots)
    exported = {row["id"] for row in (_read(_export_index_path(repo)).get("subjects") or [])} if _export_index_path(repo).is_file() else set()
    open_slots = []
    for slot in slots:
        slot["exported"] = slot["id"] in exported
        if not slot["exported"]:
            open_slots.append(slot)
    doc = {
        "schema": "wdb.pipeline.coverage/1",
        "slots": len(slots),
        "open": len(open_slots),
        "missing": open_slots,
    }
    _write(wip_dir(repo) / "coverage.json", doc)
    return doc
