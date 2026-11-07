"""Synthetic reference-grant/hook fixtures; no actual reference images or game runs."""
from __future__ import annotations
import importlib.util
import json
import tempfile
import time
from pathlib import Path
from unittest.mock import patch

import reference_policy as policy


def selftest() -> list[str]:
    from PIL import Image
    from reference_export import export
    source_root = Path(__file__).resolve().parents[3]
    spec = importlib.util.spec_from_file_location("wdb_pretool_test", source_root / ".grok/hooks/bin/wdb-pretool.py")
    hook = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(hook)
    bad = []
    checks = 0
    with tempfile.TemporaryDirectory() as tmp, patch.dict("os.environ", {"GROK_SESSION_ID": "test-session"}):
        root = Path(tmp).resolve() / "repo"
        root.mkdir()
        (root / "project.godot").write_text("")
        (root / "design/tasks").mkdir(parents=True)
        (root / "design/tasks/model.md").write_text("# Model\nid: model\nowner: build\nstatus: open\n\n## Goal\nMatch reference.\n")
        (root / "_logs").mkdir()
        state = {"task": "model", "session": "test-session", "unit": "body"}
        (root / policy.STATE).write_text(json.dumps(state))
        (root / "assets/sprites/player/female").mkdir(parents=True)
        image = root / "assets/sprites/player/bible.png"
        im = Image.new("RGBA", (12, 9))
        im.putdata([(x * 19, y * 23, 32, 255) for y in range(9) for x in range(12)])
        im.save(image)
        walk = root / "assets/sprites/player/female/walk_down_0.png"
        im.save(walk)
        (root / "tools").mkdir()
        for name in ("shots.py", "slice.py", "media.py", "bake.py"):
            (root / "tools" / name).write_text("# fixture")

        def event(name: str = "Read", path: str = str(image), **kw: str) -> dict:
            return {"toolName": name, "toolInput": {"path": path}, "cwd": str(root), "workspaceRoot": str(root), "sessionId": "test-session", **kw}

        def check(label: str, ev: dict, want: str) -> None:
            nonlocal checks
            checks += 1
            got, why = hook.decide(ev)
            if got != want:
                bad.append(f"{label}: expected {want}, got {got}: {why}")

        def shell(command: str) -> dict:
            return {**event("Shell"), "toolInput": {"command": command}}

        def save(grant: dict) -> None:
            (root / policy.GRANT).write_text(json.dumps(grant))

        check("default deny", event(), "deny")
        (root / "wdb-iso/job").mkdir(parents=True)
        check("repo folder name is not isolation", event(cwd=str(root / "wdb-iso/job")), "deny")
        check("repo folder cannot enable generation", event("image_gen", cwd=str(root / "wdb-iso/job")), "deny")
        check("default shell image deny", shell("cat assets/sprites/player/bible.png"), "deny")
        check("existing isolated visual read", event(cwd=str(Path(tmp) / "isolated"), workspaceRoot=str(Path(tmp) / "isolated")), "allow")
        grant = policy.make_grant(root, "model", "test-session", "Blender needs the exact body proportions", [str(image)])
        save(grant)
        check("explicit exact grant", event(), "allow")
        check("relative exact grant", event(path="assets/sprites/player/bible.png"), "allow")
        check("grant does not include sibling", event(path=str(walk)), "deny")
        check("different session", event(sessionId="other"), "deny")
        check("traversal spelling", event(path=str(root / "assets/../assets/sprites/player/bible.png")), "deny")
        check("image generation unchanged", event("image_gen"), "deny")
        check("granted source read-only", event("Write"), "deny")
        check("grant never authorizes shell reader", shell("cat assets/sprites/player/bible.png"), "deny")
        check("no shell Python bypass", shell('python -c "open(\"assets/sprites/player/bible.png\")"'), "deny")
        check("no arbitrary image script", shell("python mystery.py assets/sprites/player/bible.png"), "deny")
        check("catalog image tool", shell("python tools/shots.py inspect describe assets/sprites/player/bible.png"), "allow")
        check("grant command itself", shell('python tools/slice.py references grant --task model --reason "exact body proportions" --path assets/sprites/player/bible.png'), "allow")
        check("no chaining", shell("python tools/shots.py inspect describe assets/sprites/player/bible.png; cat assets/sprites/player/bible.png"), "deny")
        check("unrelated search policy unchanged", shell("rg body scripts"), "deny")
        alias = root / "assets/alias.txt"
        alias.symlink_to(image)
        check("symlink image disguised as text", event(path=str(alias)), "deny")
        check("shell symlink image disguised as text", shell("cat assets/alias.txt"), "deny")
        for label, mutate in [("task mismatch", {**state, "task": "other"}), ("unit mismatch", {**state, "unit": "gear"})]:
            (root / policy.STATE).write_text(json.dumps(mutate))
            check(label, event(), "deny")
        (root / policy.STATE).write_text(json.dumps(state))
        save({**grant, "expires": time.time() - 1})
        check("expired grant", event(), "deny")
        save({**grant, "purpose": "text-review"})
        check("not an OCR bypass", event(), "deny")
        save(grant)
        image.write_bytes(b"changed")
        check("content changed", event(), "deny")
        im.save(image)
        for value in (str(alias), str(root / "assets"), str(Path(tmp) / "outside.png"), "../outside.png", "design/tasks/model.md"):
            try:
                policy.make_grant(root, "model", "test-session", "exact body proportions needed", [value])
                bad.append("unsafe grant accepted: " + value)
            except (ValueError, OSError):
                checks += 1
        dry = export(root, "model", str(image), "assets/sprites/player/female", "", True)
        if (root / "_logs/references/model").exists() or len(dry["images"]) != 11:
            bad.append("dry export must validate without writing")
        original_hash = policy.digest(image)
        data = export(root, "model", str(image), "assets/sprites/player/female", "")
        if policy.digest(image) != original_hash:
            bad.append("export changed its input")
        for row in data["images"]:
            with Image.open(root / row["path"]) as cell, Image.open(root / row["source"]) as source:
                if cell.convert("RGBA").tobytes() != source.convert("RGBA").crop(row["crop"]).tobytes() or row["scale"] != 1 or cell.size != tuple(row["size"]):
                    bad.append("native cell provenance mismatch: " + row["path"])
        cell = root / data["images"][1]["path"]
        save(policy.make_grant(root, "model", "test-session", "Need full-resolution body reference", [str(cell)]))
        check("grant overrides only image log restriction", event(path=str(cell)), "allow")
        check("other logs remain denied", event(path="_logs/slice-state.json"), "deny")
        (root / policy.GRANT).unlink()
        check("revocation", event(path=str(cell)), "deny")
        # A symlinked state folder must not enable copied grants.
        (root / "_logs").rename(root / "saved-logs")
        (root / "_logs").symlink_to(root / "saved-logs", target_is_directory=True)
        check("symlink state folder", event(), "deny")
    print(f"reference fixtures: {checks} policy assertions plus native export/provenance checks")
    return bad
