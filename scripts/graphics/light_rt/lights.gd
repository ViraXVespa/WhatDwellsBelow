extends Object

## Dungeon light picking and ring math. State stays on light_rt.gd.

const T := preload("res://scripts/data/tunables.gd")
const RT_PATH := "res://scripts/graphics/light_rt.gd"

static func _dungeon_lights(host: Node, x0: int, z0: int, tw: int, th: int) -> Array:
	var rt: Variant = load(RT_PATH)
	var focus: Vector2i = _focus(host)
	var cap: int = int(_bal("light_source_cap", T.LIGHT_SOURCE_CAP))
	var ranked: Array = []
	for node in rt._props:
		if not is_instance_valid(node):
			continue
		var kind: String = str(node.get("kind"))
		if kind != "crystal" and kind != "campfire":
			continue
		var cell: Vector2i = _node_cell(node)
		if not _inside(cell.x, cell.y, x0, z0, tw, th):
			continue
		var wx: float = float(cell.x) + 0.5
		var wz: float = float(cell.y) + 0.5
		if kind != "crystal":
			var body: Node3D = node as Node3D
			if body != null:
				wx = body.global_position.x
				wz = body.global_position.z
		var item: Dictionary = _light_at(wx, wz, x0, z0, kind)
		item["pri"] = 0
		item["dist"] = _dist(cell, focus)
		ranked.append(item)
	for raw_site in rt._sites:
		var site: Dictionary = raw_site as Dictionary
		var fx: int = int(site["fx"])
		var fz: int = int(site["fz"])
		if not _inside(fx, fz, x0, z0, tw, th):
			continue
		var lx: float = float(fx) + 0.5
		var lz: float = float(fz) + 0.5
		if site.has("lx"):
			lx = float(site["lx"])
		if site.has("lz"):
			lz = float(site["lz"])
		var torch: Dictionary = _light_at(lx, lz, x0, z0, "torch")
		torch["pri"] = 1
		torch["dist"] = _dist(Vector2i(fx, fz), focus)
		ranked.append(torch)
	var picked: Array = []
	var guard: int = 0
	while picked.size() < cap and guard < ranked.size() + 2:
		guard += 1
		var best_i: int = -1
		for i in ranked.size():
			if bool(ranked[i].get("used", false)):
				continue
			if best_i < 0 or _before(ranked[i], ranked[best_i]):
				best_i = i
		if best_i < 0:
			break
		ranked[best_i]["used"] = true
		picked.append(ranked[best_i])
	return picked

static func _before(a: Dictionary, b: Dictionary) -> bool:
	if int(a["pri"]) != int(b["pri"]):
		return int(a["pri"]) < int(b["pri"])
	return float(a["dist"]) < float(b["dist"])

static func _light_at(world_x: float, world_z: float, x0: int, z0: int, kind: String) -> Dictionary:
	return {
		"tx": int(floor(world_x)) - x0,
		"tz": int(floor(world_z)) - z0,
		"mx": world_x,
		"mz": world_z,
		"reach": _reach(kind),
		"energy": _energy(kind),
		"col": _color(kind),
		"kind": kind,
	}

static func _reach(kind: String) -> float:
	if kind == "sun":
		return _bal("light_sun_range", T.LIGHT_SUN_RANGE)
	if kind == "crystal":
		return _bal("light_crystal_range", T.LIGHT_CRYSTAL_RANGE)
	if kind == "campfire":
		return _bal("light_fire_range", T.LIGHT_FIRE_RANGE)
	return _bal("light_torch_range", T.LIGHT_TORCH_RANGE)

static func _energy(kind: String) -> float:
	if kind == "sun":
		return _bal("light_sun_energy", T.LIGHT_SUN_ENERGY)
	if kind == "crystal":
		return _bal("light_crystal_energy", T.LIGHT_CRYSTAL_ENERGY)
	if kind == "campfire":
		return _bal("light_fire_energy", T.LIGHT_FIRE_ENERGY)
	return _bal("light_torch_energy", T.LIGHT_TORCH_ENERGY)

static func _color(kind: String) -> Color:
	var rt: Variant = load(RT_PATH)
	if kind == "sun":
		return rt.COL_SUN
	if kind == "crystal":
		return rt.COL_CRYSTAL
	if kind == "campfire":
		return rt.COL_FIRE
	return rt.COL_TORCH

static func _bal(key: String, fallback: float) -> float:
	if App.bal == null:
		return fallback
	var v: float = App.bal.getv(key)
	if v <= 0.0:
		return fallback
	return v

static func _knob_key() -> String:
	return "%s|%s|%s|%s|%s|%s|%s|%s|%s" % [
		_bal("light_torch_range", T.LIGHT_TORCH_RANGE),
		_bal("light_torch_energy", T.LIGHT_TORCH_ENERGY),
		_bal("light_crystal_range", T.LIGHT_CRYSTAL_RANGE),
		_bal("light_crystal_energy", T.LIGHT_CRYSTAL_ENERGY),
		_bal("light_fire_range", T.LIGHT_FIRE_RANGE),
		_bal("light_fire_energy", T.LIGHT_FIRE_ENERGY),
		_bal("light_sun_range", T.LIGHT_SUN_RANGE),
		_bal("light_sun_energy", T.LIGHT_SUN_ENERGY),
		_bal("light_source_cap", T.LIGHT_SOURCE_CAP),
	]

static func _focus(host: Node) -> Vector2i:
	if host.player != null:
		return host._player_cell()
	var sp: Variant = host.data.get("spawn", Vector2i.ZERO)
	if sp is Vector2i:
		return sp
	return Vector2i.ZERO

static func _live_key(host: Node) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for job in host.geo_jobs:
		if str(job.state) != "live":
			continue
		var o: Vector2i = job.origin
		parts.append("%d,%d" % [o.x, o.y])
	return "|".join(parts)

static func _node_cell(node: Node) -> Vector2i:
	if str(node.get("kind")) == "crystal":
		var raw: Variant = node.get("crystal_cell")
		if raw is Vector2i:
			return raw
	var body: Node3D = node as Node3D
	return Vector2i(int(round(body.global_position.x - 0.5)), int(round(body.global_position.z - 0.5)))

static func _inside(x: int, z: int, x0: int, z0: int, tw: int, th: int) -> bool:
	return x >= x0 and z >= z0 and x < x0 + tw and z < z0 + th

static func _dist(cell: Vector2i, focus: Vector2i) -> float:
	var dx: float = float(cell.x - focus.x)
	var dz: float = float(cell.y - focus.y)
	return sqrt(dx * dx + dz * dz)
