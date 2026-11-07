extends Object

const Balance := preload("res://scripts/data/balance.gd")

const META_ON := "crystal_on"
const META_BOSS := "crystal_boss"
const META_WARP := "crystal_warp"
const META_SEED := "crystal_seed"

static var _seed := 0

static func _clear_r() -> int:
	return _num("crystal_clear_r", 12)

static func _arrive_r() -> int:
	return _num("crystal_arrive_r", 8)

static func _num(key: String, fallback: int) -> int:
	return maxi(1, int(Balance.f(key, float(fallback))))

static func ensure_run() -> void:
	if _seed != int(App.run_seed):
		_seed = int(App.run_seed)
		App.set_meta(META_ON, {})
		App.set_meta(META_BOSS, {})
		App.set_meta(META_WARP, Vector2i(-1, -1))
		App.set_meta(META_SEED, _seed)

static func arrive() -> void:
	ensure_run()
	var dead: Dictionary = App.get_meta(META_BOSS, {})
	if bool(dead.get(App.floor_n, false)):
		App.boss_dead = true

static func note_boss() -> void:
	ensure_run()
	var dead: Dictionary = App.get_meta(META_BOSS, {})
	dead[App.floor_n] = true
	App.set_meta(META_BOSS, dead)

static func key_of(cell: Vector2i) -> String:
	return "%d:%d:%d" % [App.floor_n, cell.x, cell.y]

static func is_on(cell: Vector2i) -> bool:
	ensure_run()
	var on: Dictionary = App.get_meta(META_ON, {})
	return bool(on.get(key_of(cell), false))

static func mark_on(cell: Vector2i) -> void:
	ensure_run()
	var on: Dictionary = App.get_meta(META_ON, {})
	on[key_of(cell)] = true
	App.set_meta(META_ON, on)

static func landing_cell(host: Node) -> Vector2i:
	ensure_run()
	var warp: Vector2i = App.get_meta(META_WARP, Vector2i(-1, -1))
	App.set_meta(META_WARP, Vector2i(-1, -1))
	if warp.x >= 0 and host._is_floor_cell(warp):
		return warp
	return Vector2i(host.data.spawn)

static func place_floor(host: Node) -> void:
	var Place: GDScript = load("res://scripts/world/crystal/crystal_place.gd") as GDScript
	Place.place_entrance(host)

static func place_extras(host: Node) -> void:
	var Place: GDScript = load("res://scripts/world/crystal/crystal_place.gd") as GDScript
	Place.place_extras(host)

static func _tree(n: Node) -> SceneTree:
	if n == null or not is_instance_valid(n):
		return null
	return n.get_tree()

static func floor_list(host: Node) -> Array:
	var out: Array = []
	var tree := _tree(host)
	if tree == null:
		return out
	for n: Node in tree.get_nodes_in_group("floor_crystals"):
		if n == null or not is_instance_valid(n):
			continue
		out.append(n)
	out.sort_custom(func(a: Node, b: Node) -> bool:
		var ga: bool = bool(a.get("crystal_gate"))
		var gb: bool = bool(b.get("crystal_gate"))
		if ga != gb:
			return ga
		var ca: int = int(a.get("crystal_cl"))
		var cb: int = int(b.get("crystal_cl"))
		if ca != cb:
			return ca < cb
		return str(a.get("crystal_cell")) < str(b.get("crystal_cell"))
	)
	return out

static func activated_on_floor(host: Node) -> Array:
	var out: Array = []
	for n: Node in floor_list(host):
		if bool(n.get("crystal_on")):
			out.append(n)
	return out

static func local_unlocked(host: Node) -> bool:
	return activated_on_floor(host).size() >= 2

static func floor_unlocked() -> bool:
	return int(App.prog.deepest) > int(App.floor_n)

static func area_hostile(spot: Node) -> bool:
	var tree := _tree(spot)
	if tree == null:
		return false
	var scene: Node = tree.current_scene
	if scene == null or scene.get("spawn_jobs") == null:
		return _live_near(spot)
	var cell: Vector2i = Vector2i(spot.get("crystal_cell"))
	var rad: int = _clear_r()
	for job: Variant in scene.spawn_jobs:
		if str(job.state) == "cleared":
			continue
		if scene._cell_manhattan(Vector2i(job.cell), cell) <= rad:
			if str(job.state) == "pending":
				return true
			for raw: Variant in job.get("live", []):
				if raw == null or not is_instance_valid(raw):
					continue
				var e: Node = raw
				if e.has_method("is_alive") and not e.is_alive():
					continue
				return true
	return _live_near(spot)

static func _live_near(spot: Node) -> bool:
	var tree := _tree(spot)
	if tree == null:
		return false
	var cell: Vector2i = Vector2i(spot.get("crystal_cell"))
	var rad: int = _clear_r()
	for e: Node in tree.get_nodes_in_group("enemies"):
		if e == null or not is_instance_valid(e):
			continue
		if e.has_method("is_alive") and not e.is_alive():
			continue
		var ec := Vector2i(int(e.global_position.x), int(e.global_position.z))
		if absi(ec.x - cell.x) + absi(ec.y - cell.y) <= rad:
			return true
	return false

static func activate(spot: Node) -> void:
	var cell: Vector2i = Vector2i(spot.get("crystal_cell"))
	mark_on(cell)
	spot.set("crystal_on", true)
	var tree := _tree(spot)
	if tree == null:
		return
	var scene: Node = tree.current_scene
	if scene:
		scene.fog_dirty = true
		silence_near(scene, cell)

static func blocks_spawn(host: Node, cell: Vector2i) -> bool:
	ensure_run()
	var rad: int = _arrive_r()
	for n: Node in floor_list(host):
		if not bool(n.get("crystal_on")):
			continue
		if host._cell_manhattan(cell, Vector2i(n.get("crystal_cell"))) <= rad:
			return true
	return false

static func silence_near(host: Node, cell: Vector2i) -> void:
	var rad: int = _clear_r()
	if host.get("spawn_jobs") == null:
		return
	for job: Variant in host.spawn_jobs:
		if host._cell_manhattan(Vector2i(job.cell), cell) > rad:
			continue
		for raw: Variant in job.get("live", []):
			if raw == null or not is_instance_valid(raw):
				continue
			(raw as Node).queue_free()
		job.live = []
		job.ids = PackedStringArray()
		job.state = "cleared"

static func silence_on(host: Node) -> void:
	for n: Node in activated_on_floor(host):
		silence_near(host, Vector2i(n.get("crystal_cell")))


static func paint(host: Node) -> void:
	if host.map_img == null:
		return
	var Geo = load("res://scripts/world/dungeon/minimap.gd")
	for n: Node in floor_list(host):
		var cell: Vector2i = Vector2i(n.get("crystal_cell"))
		var on: bool = bool(n.get("crystal_on"))
		var col := Color(0.35, 0.95, 1.0) if on else Color(0.2, 0.45, 0.55)
		Geo.dot(host, cell, col, true)

static func warp_local(host: Node, cell: Vector2i) -> void:
	if host.player == null:
		return
	host.player.global_position = Vector3(float(cell.x) + 1.5, 0.0, float(cell.y) + 0.5)
	host.player.velocity = Vector3.ZERO
	host._reveal_around(cell, int(App.bal.fog_radius) + 2)
	silence_near(host, cell)
	host.fog_dirty = true
	App.toast(App.tr("net.the_crystal_takes_you_across"))

static func setup_volume(crystal: Node) -> void:
	if crystal.get_node_or_null("SafeVolume") != null:
		return
	var area := Area3D.new()
	area.name = "SafeVolume"
	area.collision_layer = 0
	area.collision_mask = 4
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = float(_arrive_r())
	shape.shape = sphere
	area.add_child(shape)
	area.body_entered.connect(func(b): on_enemy_entered(crystal, b))
	area.body_exited.connect(func(b): _on_enemy_exited(crystal, b))
	crystal.set_meta("vol_bodies", {})
	crystal.set_meta("vol_count", 0)
	crystal.add_child(area)

static func on_enemy_entered(crystal: Node, body: Node) -> void:
	if body == null or not body.is_in_group("enemies"):
		return
	var bodies: Dictionary = crystal.get_meta("vol_bodies", {})
	bodies[body.get_instance_id()] = weakref(body)
	crystal.set_meta("vol_bodies", bodies)
	crystal.refresh()
	if bool(crystal.get("crystal_on")) and not _is_pursuing(body):
		_reverse(body)

static func _on_enemy_exited(crystal: Node, body: Node) -> void:
	if body == null or not body.is_in_group("enemies"):
		return
	var bodies: Dictionary = crystal.get_meta("vol_bodies", {})
	bodies.erase(body.get_instance_id())
	crystal.set_meta("vol_bodies", bodies)
	crystal.refresh()

static func _is_pursuing(e: Node) -> bool:
	var st: int = int(e.get("state"))
	return st == 1 or st == 2 or st == 4 or st == 5 or st == 6

static func _reverse(e: Node) -> void:
	var v: Vector3 = e.velocity
	if v.length_squared() < 0.01:
		v = Vector3(e.aim.x, 0.0, e.aim.y)
	e.velocity = -v
	e.aim = Vector2(-v.x, -v.z).normalized()
	e.state = e.ST_RETURN
	e.reaggro_t = App.bal.reaggro_cd

static func relocate_inside(crystal: Node, _scene: Node = null) -> void:
	var area: Area3D = crystal.get_node_or_null("SafeVolume")
	if area == null:
		return
	for body in area.get_overlapping_bodies():
		if body.is_in_group("enemies"):
			var away: Vector3 = body.global_position - crystal.global_position
			away.y = 0.0
			if away.length_squared() < 0.01:
				away = Vector3.RIGHT
			body.global_position = crystal.global_position + away.normalized() * (float(_arrive_r()) + 1.0)

static func volume_clear(crystal: Node) -> bool:
	var bodies: Dictionary = crystal.get_meta("vol_bodies", {})
	for id in bodies.keys():
		var body: Node = bodies[id].get_ref()
		if body == null or (body.has_method("is_alive") and not body.is_alive()):
			bodies.erase(id)
	crystal.set_meta("vol_bodies", bodies)
	crystal.set_meta("vol_count", bodies.size())
	return bodies.is_empty()

static func attach_volume(crystal: Node) -> void:
	setup_volume(crystal)

static func warp_floor(n: int) -> void:
	n = clampi(n, 1, maxi(1, int(App.prog.deepest)))
	if n == App.floor_n:
		return
	var p := App.get_tree().get_first_node_in_group("player")
	if p:
		App.run_hp = float(p.get("hp"))
	App.floor_n = n
	App.prog.deepest = maxi(int(App.prog.deepest), n)
	var dead: Dictionary = App.get_meta(META_BOSS, {})
	App.boss_dead = bool(dead.get(n, false))
	App.set_meta(META_WARP, Vector2i(-1, -1))
	App.interact_prompt = ""
	App.shrine_t = 0.0
	App.ui_open = false
	App.go_dungeon()
