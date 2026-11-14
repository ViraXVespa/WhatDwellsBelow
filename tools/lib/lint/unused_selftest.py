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
const ML := preload("res://scripts/ml.gd")
const LRun := preload("res://scripts/debug/lrun.gd")
const LOther := preload("res://scripts/debug/lother.gd")
const LHelp := preload("res://scripts/debug/lhelp.gd")
const SelfNew := preload("res://scripts/debug/selfnew.gd")
const TABS := ["_tab_a"]
var never_used := 3
var prop_never: int:
	get:
		return 1
var wo := 0
var built: Node

const SkinSet := preload("res://scripts/skins/skin_set.gd")
const SkinBake := preload("res://scripts/skins/skin_bake.gd")
const PlayHostScr := preload("res://scripts/play_host.gd")
const Bal := preload("res://scripts/data/balance/vars_fix.gd")
var doc_only_var := 1
var json_named_var := 1
var ui: PlayHost

func _ready() -> void:
	B.helper()
	B.shadowed_flow()
	B.lint_only_fn()
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
	ML.live_ml()
	LRun.go(self)
	LOther.other_live()
	LHelp.go()
	SelfNew.make()
	SkinSet.apply(self)
	SkinBake.bake()
	Bal.new().tick()
	typed_pt(PlayHost.new())
	node_pt(PlayHost.new())
	ui = PlayHost.new()
	ui.ui_fn()

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

func typed_pt(pt: PlayHost) -> void:
	pt.typed_fn()

func node_pt(x: Node) -> void:
	x.node_only_fn()
""",
    "scripts/main.gd": "extends Node\nfunc _on_scene_pressed() -> void:\n\tpass\n",
    "scripts/b.gd": "static func flow_node_fn() -> void:\n\tpass\n\nstatic func twin_flow() -> void:\n\tpass\n\nstatic func helper() -> void:\n\tpass\n\nstatic func shadowed_flow() -> void:\n\tpass\n\nstatic func lint_only_fn() -> void:\n\tpass\n",
    "scripts/c.gd": """class_name CMod

static var only_in_dead := 1

static func live_c() -> void:
	pass

static func helper() -> void:
	pass

static func dead_a() -> void:
	dead_b()

static func dead_b() -> void:
	dead_a()

static func dead_root() -> void:
	leaf()
	if only_in_dead > 0:
		pass

static func leaf() -> void:
	pass

static func documented_fn() -> void:
	pass

static func held_fn() -> void:
	pass

static func shadowed_flow() -> void:
	pass

static func lint_only_fn() -> void:
	pass
""",
    "scripts/ml.gd": '''static func live_ml() -> String:
	return """
func ghost_fn():
	call("ghost_target")
var g = preload("res://scripts/ghost.gd")
"""

static func dead_ml() -> String:
	var t := """
static func after():
	pass
"""
	return t + "x"

static func ghost_target() -> void:
	pass

class Inner:
	func dup() -> void:
		pass
	func inner_only() -> void:
		helper_outer()

static func dup() -> void:
	pass

static func helper_outer() -> void:
	pass

const MULTI := [
	1,
]
var side_eff := _bump()
var prop_side: int:
	set(v):
		_bump()

static func _bump() -> int:
	return 1
''',
    "scripts/ghost.gd": "static func boo() -> void:\n\tpass\n",
    "scripts/d.gd": "static func maybe_fn(_v: int) -> void:\n\tpass\n\nstatic func twin_flow() -> void:\n\tpass\n\nfunc own_live() -> void:\n\tpass\n",
    "scripts/base.gd": "extends Node\nfunc run() -> void:\n\thook()\n\nfunc hook() -> void:\n\tpass\n",
    "scripts/child.gd": 'extends "res://scripts/base.gd"\nfunc hook() -> void:\n\tpass\n',
    "scripts/orphan.gd": "static func lonely() -> void:\n\tpass\n",
    "scripts/debug/probe.gd": "static func ping() -> void:\n\tpass\n",
    "scripts/debug/shots.gd": "static func still() -> void:\n\tpass\n",
    "scripts/debug/cli.gd": "extends SceneTree\nfunc _initialize() -> void:\n\tgo()\n\nfunc go() -> void:\n\tquit()\n",
    "tools/lib/lint/list_unused_funcs.py": "# example: lint_only_fn is named only in the linter source\n",
    "design/notes.md": "dead_a and helper are named only in a design doc.\ndoc_only_var is unused except here.\n`CMod.dead_a` was a leftover facade name.\n- `CMod.dead_b` was its twin.\n",
    "tools/data/flow-extra.json": '{"note": "shadowed_flow and json_named_var appear in shot-flow adjacent data"}\n',
    "scripts/data/balance/vars_fix.gd": """extends RefCounted
const Schema := preload("res://scripts/data/balance/schema_fix.gd")
const Access := preload("res://scripts/data/balance/access_fix.gd")
var schema_live := 1.0
var also_keyed := 2.0
var balance_only_var := 1

func schema() -> Array:
	return Schema.rows()

func getv(name: String) -> float:
	return Access.getv(self, name)

func tick() -> void:
	for row in schema():
		getv(str(row[0]))
""",
    "scripts/data/balance/schema_fix.gd": """static func rows() -> Array:
	return [
		["schema_live", 0.0, 1.0, 0.1],
		["also_keyed", 0.0, 2.0, 0.1],
	]
""",
    "scripts/data/balance/access_fix.gd": """static func getv(host, name: String) -> float:
	var v: Variant = host.get(name)
	return 0.0 if v == null else float(v)
""",
    "scripts/play_host.gd": """class_name PlayHost
extends Node

func typed_fn() -> void:
	pass

func ui_fn() -> void:
	pass

func node_only_fn() -> void:
	pass
""",
    "scripts/skins/skin_a.gd": """static func spec() -> Dictionary:
	return {}

static func build(_c) -> void:
	pass

static func unused_skin_fn() -> void:
	pass

static func dress(_b) -> void:
	pass

static func only_string_skin() -> void:
	pass
""",
    "scripts/skins/skin_b.gd": """static func spec() -> Dictionary:
	return {}

static func build(_c) -> void:
	pass
""",
    "scripts/skins/skin_base.gd": """static func apply(host, skins: Array) -> void:
	for skin: GDScript in skins:
		mount(host, skin)

static func mount(host, skin: GDScript) -> void:
	skin.build(host)
""",
    "scripts/skins/skin_set.gd": """const SkinA := preload("res://scripts/skins/skin_a.gd")
const SkinB := preload("res://scripts/skins/skin_b.gd")
const SkinBase := preload("res://scripts/skins/skin_base.gd")
const SKINS: Array = [
	SkinA,
	SkinB,
]

static func apply(host) -> void:
	for skin: GDScript in SKINS:
		skin.spec()
	SkinBase.apply(host, SKINS)
	call("only_string_skin")
""",
    "scripts/skins/skin_bake.gd": """const SET := "res://scripts/skins/skin_set.gd"
const NotSkin := preload("res://scripts/skins/not_skin.gd")

static func bake() -> void:
	NotSkin.live()
	for skin: GDScript in (load(SET) as GDScript).get("SKINS"):
		dress_all(skin)

static func dress_all(skin: GDScript) -> void:
	skin.callv("dress", [null])
""",
    "scripts/skins/not_skin.gd": "static func live() -> void:\n\tpass\n\nstatic func dress(_b) -> void:\n\tpass\n",
    "scripts/debug/vis_check.gd": """extends RefCounted
var plant_x: String:
	get:
		return "ok"
var not_in_flow := 1
""",
    "scripts/debug/lrun.gd": 'static func go(host) -> void:\n\t(load("res://scripts/debug/lstep.gd") as GDScript).call("run", host)\n',
    "scripts/debug/lstep.gd": "static func run(_h) -> void:\n\tpass\n\nstatic func lstep_unused() -> void:\n\tpass\n",
    "scripts/debug/lother.gd": "static func other_live() -> void:\n\tpass\n\nstatic func run(_h) -> void:\n\tpass\n",
    "scripts/debug/lhelp.gd": 'static func _util():\n\treturn load("res://scripts/debug/hutil.gd")\n\nstatic func go() -> void:\n\tvar U = _util()\n\tU.h_live()\n\tvar W = _other()\n\tW.h_dead()\n\nstatic func _other():\n\treturn null\n',
    "scripts/debug/selfnew.gd": 'extends Node\nstatic func make() -> void:\n\tvar n := new()\n\tn.own_live()\n\tload("res://scripts/debug/lhelp.gd")._util().h_chain()\n\tvar S: GDScript = load("res://scripts/debug/hutil.gd") as GDScript\n\tvar m: Object = S.new()\n\tm.h_local_new()\n\nfunc own_live() -> void:\n\tpass\n',
    "scripts/debug/hutil.gd": "func h_local_new() -> void:\n\tpass\n\nstatic func h_chain() -> void:\n\tpass\n\nstatic func h_live() -> void:\n\tpass\n\nstatic func h_dead() -> void:\n\tpass\n\nstatic func h_never() -> void:\n\tpass\n",
    "tools/data/shot-flows/vis.json": '{ "steps": [ { "op": "assert", "target": "script:debug/vis_check.plant_x" } ] }\n',
    "tools/data/shot-flows/node.json": '{ "steps": [ {"op": "call", "target": "host.ui", "method": "flow_node_fn"}, {"op": "call", "target": "host", "method": "twin_flow"} ] }\n',

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
            ("play_host.gd", "node_only_fn"): "ambiguous",
            ("skin_a.gd", "unused_skin_fn"): "unused",
            ("c.gd", "shadowed_flow"): "shadowed", ("c.gd", "lint_only_fn"): "shadowed",
            ("app.gd", "doc_only_var"): "unused_var",
            ("app.gd", "json_named_var"): "unused_var",
            ("vars_fix.gd", "balance_only_var"): "unused_var",
            ("vis_check.gd", "not_in_flow"): "unused_var",
            ("hutil.gd", "h_dead"): "ambiguous", ("hutil.gd", "h_never"): "unused",
            ("lstep.gd", "lstep_unused"): "unused", ("lother.gd", "run"): "shadowed",
            ("not_skin.gd", "dress"): "unused", ("b.gd", "twin_flow"): "unused", ("d.gd", "twin_flow"): "unused", ("d.gd", "own_live"): "shadowed",
        }
        for key, kind in want.items():
            if cat.get(key) != kind:
                bad.append(f"report: {key} expected {kind}, got {cat.get(key)}")
        live = [("b.gd", "helper"), ("c.gd", "live_c"), ("app.gd", "attach_x"), ("app.gd", "_tab_a"), ("app.gd", "_on_hit"),
                ("probe.gd", "ping"), ("shots.gd", "still"), ("child.gd", "hook"), ("base.gd", "hook"), ("cli.gd", "go"),
                ("main.gd", "_on_scene_pressed"), ("skin_a.gd", "spec"), ("skin_a.gd", "build"),
                ("skin_b.gd", "spec"), ("skin_b.gd", "build"), ("skin_a.gd", "only_string_skin"),
                ("play_host.gd", "typed_fn"), ("play_host.gd", "ui_fn"), ("b.gd", "shadowed_flow"), ("b.gd", "lint_only_fn"),
                ("vars_fix.gd", "schema_live"), ("vars_fix.gd", "also_keyed"),
                ("vis_check.gd", "plant_x"), ("lstep.gd", "run"), ("hutil.gd", "h_live"),
                ("skin_a.gd", "dress"), ("b.gd", "flow_node_fn"), ("selfnew.gd", "own_live"), ("hutil.gd", "h_chain"), ("hutil.gd", "h_local_new")]
        for key in live:
            if key in cat:
                bad.append(f"live: {key} reported as {cat[key]}")
        allrows = {(r["rel"].rsplit("/", 1)[-1], r["name"]): (k, r) for k, v in rows.items() for r in v}
        for name in ("ghost_fn", "after", "inner_only"):
            if any(n == name for _f, n in allrows):
                bad.append(f"lexer/inner: {name} (inside a string or inner class) reported as {allrows[[k for k in allrows if k[1] == name][0]][0]}")
        if ("ml.gd", "helper_outer") in allrows:
            bad.append("inner: helper_outer (called from inner class) reported dead")
        if allrows.get(("ml.gd", "ghost_target"), ("", {"conf": ""}))[1]["conf"] not in ("medium", "low"):
            bad.append(f"lexer: ghost_target (named in a multi-line string) not demoted: {allrows.get(('ml.gd', 'ghost_target'))}")
        if allrows.get(("ghost.gd", "ghost.gd"), ("", {"conf": ""}))[1]["conf"] != "medium":
            bad.append(f"lexer: ghost.gd (path only in a multi-line string) should be a medium orphan: {allrows.get(('ghost.gd', 'ghost.gd'))}")
        if allrows.get(("ml.gd", "dead_ml"), ("",))[0] != "unused":
            bad.append(f"lexer: dead_ml expected unused, got {allrows.get(('ml.gd', 'dead_ml'))}")
        cyc = [r for r in rows.get("dead_chain", []) if r["name"] == "dead_a"]
        if not cyc or "cycle" not in cyc[0]["why"]:
            bad.append("dead_a: cycle not named in why")
        # apply: only verified rows go; uncertain ones are refused and stay
        luf.run(root, True, 0, quiet=True)
        c_text = (root / "scripts/c.gd").read_text(encoding="utf-8")
        app_text = (root / "scripts/app.gd").read_text(encoding="utf-8")
        for gone in ("func helper", "func dead_a", "func dead_b", "func dead_root", "func leaf"):
            if gone in c_text:
                bad.append(f"apply: c.gd still has {gone} (design.md-only mention must not hold shadowed/dead_chain)")
        if "var prop_never: int:" not in app_text or "\tget:\n\t\treturn 1" not in app_text:
            bad.append("apply: property block prop_never touched (must be refused whole)")
        if "never_used" in app_text:
            bad.append("apply: unused var never_used kept")
        if (root / "scripts/orphan.gd").exists():
            bad.append("apply: orphan.gd not deleted")
        for kept, text in (("func live_c", c_text), ("func documented_fn", c_text), ("func held_fn", c_text),
                           ("func shadowed_flow", c_text),
                           ("var wo", app_text), ("var built", app_text), ("func attach_x", app_text), ("func _tab_a", app_text),
                           ("var json_named_var", app_text)):
            if kept not in text:
                bad.append(f"apply: removed {kept} (must be refused/kept)")
        if "doc_only_var" in app_text:
            bad.append("apply: unused var doc_only_var kept (design.md-only mention must not hold unused_var)")
        if "func maybe_fn" not in (root / "scripts/d.gd").read_text(encoding="utf-8"):
            bad.append("apply: removed ambiguous maybe_fn")
        if "func node_only_fn" not in (root / "scripts/play_host.gd").read_text(encoding="utf-8"):
            bad.append("apply: removed ambiguous node_only_fn (Node-typed receiver must stay a warning)")
        if "func unused_skin_fn" in (root / "scripts/skins/skin_a.gd").read_text(encoding="utf-8"):
            bad.append("apply: unused_skin_fn kept")
        for kept in ("func spec", "func build", "func only_string_skin"):
            if kept not in (root / "scripts/skins/skin_a.gd").read_text(encoding="utf-8"):
                bad.append(f"apply: removed live skin_a {kept}")
        if "var balance_only_var" not in (root / "scripts/data/balance/vars_fix.gd").read_text(encoding="utf-8"):
            bad.append("apply: removed balance_only_var (balance unused_var must not be auto-promoted)")
        fix_text = (root / "scripts/data/balance/vars_fix.gd").read_text(encoding="utf-8")
        for kept in ("var schema_live", "var also_keyed"):
            if kept not in fix_text:
                bad.append(f"apply: removed {kept} (schema-key vars read via host.get(name)/getv are live)")
        vis_text = (root / "scripts/debug/vis_check.gd").read_text(encoding="utf-8")
        if "var plant_x" not in vis_text:
            bad.append("apply: removed plant_x (shot-flow script:path.member is a live property read)")
        if "func helper" not in (root / "scripts/b.gd").read_text(encoding="utf-8"):
            bad.append("apply: removed live same-name b.helper")
        if "func lint_only_fn" in c_text:
            bad.append("apply: c.lint_only_fn kept (a mention only in tools/lib/lint must not hold shadowed)")
        if "func lint_only_fn" not in (root / "scripts/b.gd").read_text(encoding="utf-8"):
            bad.append("apply: removed live same-name b.lint_only_fn")
        ml = (root / "scripts/ml.gd").read_text(encoding="utf-8")
        if "func dead_ml" in ml or "static func after" in ml:
            bad.append("apply: dead_ml (with its multi-line string) not removed whole")
        for kept in ("func live_ml", "func ghost_fn():", "func ghost_target", "class Inner:", "\tfunc dup", "static func dup",
                     "func helper_outer", "const MULTI := [\n\t1,\n]", "var side_eff := _bump()", "var prop_side: int:\n\tset(v):"):
            if kept not in ml:
                bad.append(f"apply: ml.gd lost {kept!r}")
        if not (root / "scripts/ghost.gd").exists():
            bad.append("apply: ghost.gd deleted although a multi-line string names its path")
        blob = json.loads((root / "_logs/unused-funcs/unused-funcs.json").read_text(encoding="utf-8"))
        refused = {r["name"]: r["refuse"] for r in blob["apply_refused"]}
        if "held" not in refused.get("held_fn", ""):
            bad.append(f"apply: held_fn refusal missing ({refused.get('held_fn')})")
        if "non-GDScript" not in refused.get("documented_fn", ""):
            bad.append(f"apply: documented_fn refusal missing ({refused.get('documented_fn')})")
        flow_refuse = refused.get("shadowed_flow", "")
        if "non-GDScript" not in flow_refuse and "confidence" not in flow_refuse:
            bad.append(f"apply: shadowed_flow (shot-flow/JSON word) refusal missing ({flow_refuse})")
        if "balance" not in refused.get("balance_only_var", ""):
            bad.append(f"apply: balance_only_var refusal missing ({refused.get('balance_only_var')})")
        if not blob["applied"]:
            bad.append("apply: nothing recorded in applied")
        if "only_in_dead" in c_text:
            bad.append("apply: only_in_dead kept (cascade: var only used by deleted dead_root must be removed on a later pass)")
        applied_names = {line.split("\t")[2] for line in blob["applied"] if line.startswith("deleted_") and line.count("\t") >= 2}
        if "only_in_dead" not in applied_names:
            bad.append(f"apply: only_in_dead not in applied ({applied_names})")
        phases = [p.get("phase") for p in blob.get("passes", [])]
        if "applied" not in phases or "fixed_point" not in phases:
            bad.append(f"apply: passes did not record a cascade then a fixed point: {phases}")
        if phases.count("applied") < 2:
            bad.append(f"apply: expected at least 2 apply passes for the dead_root -> only_in_dead cascade, got {phases}")
        stale = {(s["name"], s["rel"]) for s in blob.get("stale_docs", [])}
        if ("CMod.dead_a", "design/notes.md") not in stale:
            bad.append(f"apply: stale_docs missing qualified CMod.dead_a ({blob.get('stale_docs')})")
        if not any(s["name"] == "dead_a" and s["rel"] == "design/notes.md" for s in blob.get("stale_docs", [])):
            bad.append(f"apply: stale_docs missing bare dead_a ({blob.get('stale_docs')})")
        if "`CMod.dead_b`" in (root / "design/notes.md").read_text(encoding="utf-8") or not any(d["name"] == "CMod.dead_b" for d in blob.get("doc_fixes", [])):
            bad.append(f"apply: exact stale bullet `CMod.dead_b` not auto-removed ({blob.get('doc_fixes')})")
        if any(s["name"] == "helper" for s in blob.get("stale_docs", [])):
            bad.append("apply: stale_docs flagged helper which still has a live def")
    return bad
