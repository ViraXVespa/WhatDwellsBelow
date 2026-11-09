"""lint.py unused --selftest: tiny fixture repos written to a throwaway root (never live .gd)."""
from __future__ import annotations

import json
import tempfile
from pathlib import Path

FIX = {
    "project.godot": '[application]\nrun/main_scene="res://scenes/main.tscn"\n[autoload]\nApp="*res://scripts/app.gd"\n',
    "scenes/main.tscn": '[gd_scene format=3]\n[ext_resource type="Script" path="res://scripts/main.gd" id="1"]\n'
                        '[node name="Main" type="Node"]\nscript = ExtResource("1")\n'
                        '[connection signal="pressed" from="." to="." method="_on_scene_pressed"]\n',
    "tools/run_cli.py": 'CLI = "res://scripts/debug/cli.gd"\n',
    "tools/data/flow.json": '{"steps": [{"op": "call", "target": "script:debug/shots", "method": "still"}]}\n',
    "docs/notes.md": "documented_fn is kept for the modding docs.\n",
    "tools/data/unused_hold.json": json.dumps({"hold": [{"path": "scripts/c.gd", "name": "held_fn", "why": "fixture hold"}]}),
    "scripts/app.gd": """extends Node
const B := preload("res://scripts/b.gd")
const C := preload("res://scripts/c.gd")
const D := preload("res://scripts/d.gd")
const Child := preload("res://scripts/child.gd")
const TABS := ["_tab_a"]
var never_used := 3
var wo := 0
var built: Node

func _ready() -> void:
	B.helper()
	wo = 5
	built = Node.new()
	built.name = "x"
	add_child(built)
	call(TABS[0])
	smoke_attach("x")
	$Btn.pressed.connect(_on_hit.bind(1))
	var s := Dbg.script("probe")
	s.ping()
	Child.new().run()
	untyped(null)
	C.live_c()

func smoke_attach(what: String) -> void:
	call("attach_" + what)

func attach_x() -> void:
	pass

func _tab_a() -> void:
	pass

func _on_hit(_n: int) -> void:
	pass

func untyped(x) -> void:
	x.maybe_fn(1)
""",
    "scripts/main.gd": "extends Node\nfunc _on_scene_pressed() -> void:\n\tpass\n",
    "scripts/b.gd": "static func helper() -> void:\n\tpass\n",
    "scripts/c.gd": """static func live_c() -> void:
	pass

static func helper() -> void:
	pass

static func dead_a() -> void:
	dead_b()

static func dead_b() -> void:
	dead_a()

static func dead_root() -> void:
	leaf()

static func leaf() -> void:
	pass

static func documented_fn() -> void:
	pass

static func held_fn() -> void:
	pass
""",
    "scripts/d.gd": "static func maybe_fn(_v: int) -> void:\n\tpass\n",
    "scripts/base.gd": "extends Node\nfunc run() -> void:\n\thook()\n\nfunc hook() -> void:\n\tpass\n",
    "scripts/child.gd": 'extends "res://scripts/base.gd"\nfunc hook() -> void:\n\tpass\n',
    "scripts/orphan.gd": "static func lonely() -> void:\n\tpass\n",
    "scripts/debug/probe.gd": "static func ping() -> void:\n\tpass\n",
    "scripts/debug/shots.gd": "static func still() -> void:\n\tpass\n",
    "scripts/debug/cli.gd": "extends SceneTree\nfunc _initialize() -> void:\n\tgo()\n\nfunc go() -> void:\n\tquit()\n",
}

def _write(root: Path) -> None:
    for rel, text in FIX.items():
        p = root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text, encoding="utf-8")

def _cats(rows: dict) -> dict[tuple[str, str], str]:
    out = {}
    for kind, items in rows.items():
        for r in items:
            out[(r["rel"].rsplit("/", 1)[-1], r["name"])] = kind
    return out

def run() -> list[str]:
    import list_unused_funcs as luf
    bad: list[str] = []
    with tempfile.TemporaryDirectory(prefix="unused-st-") as tmp:
        root = Path(tmp)
        _write(root)
        _g, rows = luf.analyse(root)
        cat = _cats(rows)
        want = {
            ("c.gd", "helper"): "shadowed", ("c.gd", "dead_a"): "dead_chain", ("c.gd", "dead_b"): "dead_chain",
            ("c.gd", "leaf"): "dead_chain", ("c.gd", "dead_root"): "unused", ("orphan.gd", "orphan.gd"): "orphan_file",
            ("app.gd", "never_used"): "unused_var", ("app.gd", "wo"): "write_only_var", ("app.gd", "built"): "init_only_var",
            ("d.gd", "maybe_fn"): "ambiguous",
        }
        for key, kind in want.items():
            if cat.get(key) != kind:
                bad.append(f"report: {key} expected {kind}, got {cat.get(key)}")
        live = [("b.gd", "helper"), ("c.gd", "live_c"), ("app.gd", "attach_x"), ("app.gd", "_tab_a"), ("app.gd", "_on_hit"),
                ("probe.gd", "ping"), ("shots.gd", "still"), ("child.gd", "hook"), ("base.gd", "hook"), ("cli.gd", "go"),
                ("main.gd", "_on_scene_pressed")]
        for key in live:
            if key in cat:
                bad.append(f"live: {key} reported as {cat[key]}")
        cyc = [r for r in rows.get("dead_chain", []) if r["name"] == "dead_a"]
        if not cyc or "cycle" not in cyc[0]["why"]:
            bad.append("dead_a: cycle not named in why")
        # apply: only verified rows go; uncertain ones are refused and stay
        luf.run(root, True, 0, quiet=True)
        c_text = (root / "scripts/c.gd").read_text(encoding="utf-8")
        app_text = (root / "scripts/app.gd").read_text(encoding="utf-8")
        for gone in ("func helper", "func dead_a", "func dead_b", "func dead_root", "func leaf"):
            if gone in c_text:
                bad.append(f"apply: c.gd still has {gone}")
        if "never_used" in app_text:
            bad.append("apply: unused var never_used kept")
        if (root / "scripts/orphan.gd").exists():
            bad.append("apply: orphan.gd not deleted")
        for kept, text in (("func live_c", c_text), ("func documented_fn", c_text), ("func held_fn", c_text),
                           ("var wo", app_text), ("var built", app_text), ("func attach_x", app_text), ("func _tab_a", app_text)):
            if kept not in text:
                bad.append(f"apply: removed {kept} (must be refused/kept)")
        if "func maybe_fn" not in (root / "scripts/d.gd").read_text(encoding="utf-8"):
            bad.append("apply: removed ambiguous maybe_fn")
        if "func helper" not in (root / "scripts/b.gd").read_text(encoding="utf-8"):
            bad.append("apply: removed live same-name b.helper")
        blob = json.loads((root / "_logs/unused-funcs/unused-funcs.json").read_text(encoding="utf-8"))
        refused = {r["name"]: r["refuse"] for r in blob["apply_refused"]}
        if "held" not in refused.get("held_fn", ""):
            bad.append(f"apply: held_fn refusal missing ({refused.get('held_fn')})")
        if "non-GDScript" not in refused.get("documented_fn", ""):
            bad.append(f"apply: documented_fn refusal missing ({refused.get('documented_fn')})")
        if not blob["applied"]:
            bad.append("apply: nothing recorded in applied")
    return bad
