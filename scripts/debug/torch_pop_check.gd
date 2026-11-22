extends RefCounted

## Torch pop-in probe (dungeon-torch-pop flow). The flow walks the player at run speed (.hop: HOP m per 20 frames
## = 4.5 m/s) and calls .check after each hop: every torch site whose light pool reaches the screen must already be
## in the published stamp (a cast at the site) and every on-screen bracket must have its bill. .faults lists the
## misses ("" when none). .plant_on sets Lights.plant_old (the 5 Hz stamp, bills held behind it, the old 32 cap);
## a planted walk must make .plant_caught read "caught" (it clears the plant).
## .hide_foes hides and freezes every enemy (dungeon-torch-walls close-ups).

const LightRt := preload("res://scripts/graphics/light_rt.gd")
const Lights := preload("res://scripts/graphics/light_rt/lights.gd")
const T := preload("res://scripts/data/tunables.gd")
const HOP := 1.5

static var _faults: PackedStringArray = PackedStringArray()

var hop: String:
	get:
		var p: Node3D = _player()
		p.global_position += Vector3(HOP, 0.0, 0.0)
		return "ok"
var check: String:
	get:
		var p: Node3D = _player()
		var bad: String = view_fault() + flame_fault()
		if bad != "":
			_faults.append("at=%.0f,%.0f %s" % [p.global_position.x, p.global_position.z, bad])
		return "ok"
var faults: String:
	get:
		var out: String = "" if _faults.is_empty() else "%d: %s" % [_faults.size(), _faults[0]]
		_faults.clear()
		return out
var plant_on: String:
	get:
		Lights.plant_old = true
		_faults.clear()
		return "set"
var plant_caught: String:
	get:
		Lights.plant_old = false
		var hit: bool = not _faults.is_empty()
		_faults.clear()
		return "caught" if hit else "missed"
var hide_foes: String:
	get:
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		for n: Node in tree.get_nodes_in_group("enemies"):
			n.process_mode = Node.PROCESS_MODE_DISABLED
			if n is Node3D:
				(n as Node3D).visible = false
		return "ok"

static func _host() -> Node:
	var n: Node = _player()
	while n != null and not ("geo_jobs" in n):
		n = n.get_parent()
	return n

static func _player() -> Node3D:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.get_first_node_in_group("player") as Node3D

static func _cam() -> Camera3D:
	var p: Node3D = _player()
	if p != null and p.get_viewport() != null:
		return p.get_viewport().get_camera_3d()
	return null

## A site's pool reaches the screen: the light point, or one torch range from it, is in the frustum.
static func _on_screen(cam: Camera3D, lx: float, lz: float) -> bool:
	var r: float = T.LIGHT_TORCH_RANGE
	for off: Vector2 in [Vector2.ZERO, Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
		if cam.is_position_in_frustum(Vector3(lx + off.x, 0.0, lz + off.y)):
			return true
	return false

static func view_fault() -> String:
	var cam: Camera3D = _cam()
	if cam == null:
		return "no camera "
	for site: Dictionary in LightRt._sites:
		var lx: float = float(site.get("lx", float(site["fx"]) + 0.5))
		var lz: float = float(site.get("lz", float(site["fz"]) + 0.5))
		if not _on_screen(cam, lx, lz):
			continue
		var lit: bool = false
		for c: Dictionary in LightRt._casts:
			if (c["xz"] as Vector2).distance_to(Vector2(lx, lz)) < 0.05:
				lit = true
				break
		if not lit:
			return "unlit %.1f,%.1f " % [lx, lz]
	return ""

static func flame_fault() -> String:
	var cam: Camera3D = _cam()
	if cam == null:
		return "no camera "
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var bills: Array[Node] = tree.get_nodes_in_group("wall_torch")
	for site: Dictionary in LightRt._sites:
		var at := Vector3(float(site.get("px", float(site["fx"]) + 0.5)), 0.0, float(site.get("pz", float(site["fz"]) + 0.5)))
		if not cam.is_position_in_frustum(at + Vector3(0.0, 1.0, 0.0)):
			continue
		var found: bool = false
		for n: Node in bills:
			if (n as Node3D).global_position.distance_to(at) < 0.05:
				found = true
				break
		if not found:
			return "no bill %.1f,%.1f " % [at.x, at.z]
	return ""

## Issue #82: .ends is "" when every torch site sits at least 0.5 m from both ends of its wall run (or mid-run on
## a run under 1.1 m). .plant_ends re-plans the floor with Spans.plant_no_inset (the old end clamp) and must read
## "caught"; the live plan is left as it was.
var ends: String:
	get:
		return ends_fault(LightRt._sites)
var plant_ends: String:
	get:
		var plan: GDScript = load("res://scripts/graphics/torch_plan.gd") as GDScript
		var spans: GDScript = load("res://scripts/graphics/torch_plan/spans.gd") as GDScript
		var host: Node = _host()
		spans.set("plant_no_inset", true)
		plan.set("_cache_key", "")
		var bad: String = ends_fault(plan.call("build", host, [], Rect2i()))
		spans.set("plant_no_inset", false)
		plan.set("_cache_key", "")
		plan.call("build", host, [], Rect2i())
		return "caught" if bad != "" else "missed"

static func ends_fault(sites: Array) -> String:
	var sp: GDScript = load("res://scripts/graphics/torch_plan/spans.gd") as GDScript
	var ori: PackedVector2Array = sp.get("_sori")
	var nrm: PackedVector2Array = sp.get("_snrm")
	var ux: PackedFloat32Array = sp.get("_sux")
	var uy: PackedFloat32Array = sp.get("_suy")
	var slen: PackedFloat32Array = sp.get("_slen")
	var pn: int = int(sp.get("_pn"))
	var host: Node = _host()
	var scale: float = float(maxi(1, int(host.data.get("solid_n", 1))))
	var n_bad: int = 0
	var first: String = ""
	for site: Dictionary in sites:
		var nx: float = float(site["nx"])
		var nz: float = float(site["nz"])
		var wall := Vector2(float(site["px"]) - nx * 0.12, float(site["pz"]) - nz * 0.12) * scale
		var best_room: float = -INF
		for i in pn:
			if nrm[i].dot(Vector2(nx, nz)) < 0.99:
				continue
			var u := Vector2(ux[i], uy[i])
			var along: float = (wall - ori[i]).dot(u)
			if along < -0.01 or along > slen[i] + 0.01:
				continue
			if (wall - ori[i] - u * along).length() > 0.02 * scale:
				continue
			# Collinear runs can share the point: judge it on the run it sits deepest in.
			var room: float = minf(along, slen[i] - along) - minf(0.5 * scale, slen[i] * 0.5 - 0.01)
			if room > best_room:
				best_room = room
		if best_room == -INF:
			continue
		if best_room < 0.0:
			n_bad += 1
			if first == "":
				first = "%.2f,%.2f" % [float(site["px"]), float(site["pz"])]
	return "" if n_bad == 0 else "on_end=%d first=%s" % [n_bad, first]
