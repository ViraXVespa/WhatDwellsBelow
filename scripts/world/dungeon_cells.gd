extends Object

const Gen := preload("res://scripts/dungeon/gen.gd")


static func player_cell(host: Node) -> Vector2i:
	if host.player == null:
		return Vector2i(int(host.data.spawn.x), int(host.data.spawn.y))
	return Vector2i(int(host.player.global_position.x), int(host.player.global_position.z))


static func cell_manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func near_spawn(host: Node, c: Vector2i, rad: int = -1) -> bool:
	if rad < 0:
		rad = host.SPAWN_CLEAR
	return cell_manhattan(c, host.data.spawn) < rad


static func center_room(r: Dictionary) -> Vector2i:
	return Vector2i(int(r.x) + int(r.w) / 2, int(r.y) + int(r.h) / 2)


static func find_kind_room(host: Node, kind: String) -> Dictionary:
	for r in host.data.get("rooms", []):
		if str(r.get("kind", "")) == kind:
			return r
	return {}


static func away_room(host: Node) -> Dictionary:
	var best := {}
	var best_d := -1
	for r in host.data.get("rooms", []):
		var k := str(r.get("kind", "normal"))
		if k == "spawn" or k == "boss":
			continue
		var d := cell_manhattan(center_room(r), host.data.spawn)
		if d < host.SPAWN_CLEAR:
			continue
		if d > best_d:
			best_d = d
			best = r
	if not best.is_empty():
		return best
	for r in host.data.get("rooms", []):
		if str(r.get("kind", "")) != "spawn":
			return r
	return {}


static func combat_room(host: Node) -> Dictionary:
	for r in host.data.get("rooms", []):
		var kind := str(r.get("kind", "normal"))
		if kind != "normal" and kind != "base":
			continue
		if near_spawn(host, center_room(r)):
			continue
		return r
	return away_room(host)


static func rand_cell(host: Node, r: Dictionary) -> Vector2i:
	var rx := int(r.x)
	var ry := int(r.y)
	var rw := int(r.w)
	var rh := int(r.h)
	for _i in 16:
		var x := host.floor_rng.randi_range(rx + 1, rx + maxi(2, rw) - 2)
		var y := host.floor_rng.randi_range(ry + 1, ry + maxi(2, rh) - 2)
		var c := Vector2i(x, y)
		if is_floor_cell(host, c):
			return c
	return Vector2i(rx + rw / 2, ry + rh / 2)


static func cell_pos(c: Vector2i) -> Vector3:
	return Vector3(float(c.x) + 0.5, 0.0, float(c.y) + 0.5)


static func world_cell(p: Vector3) -> Vector2i:
	return Vector2i(int(round(p.x - 0.5)), int(round(p.z - 0.5)))


static func mark_cell(host: Node, c: Vector2i) -> void:
	if c.x >= 0 and c.y >= 0:
		host.occupied[c] = true


static func is_floor_cell(host: Node, c: Vector2i) -> bool:
	var w: int = host.data.w
	var h: int = host.data.h
	if c.x < 1 or c.y < 1 or c.x >= w - 1 or c.y >= h - 1:
		return false
	var grid: PackedByteArray = host.data.grid
	return grid[Gen.idx(c.x, c.y, w)] == Gen.FLOOR


static func is_safe_cell(host: Node, c: Vector2i) -> bool:
	if near_spawn(host, c, 8):
		return true
	for r in host.data.get("rooms", []):
		if not Gen.is_safe_kind(str(r.get("kind", ""))):
			continue
		if c.x >= int(r.x) and c.y >= int(r.y) and c.x < int(r.x) + int(r.w) and c.y < int(r.y) + int(r.h):
			return true
	return false


static func is_safe_world(host: Node, p: Vector3) -> bool:
	return is_safe_cell(host, Vector2i(int(p.x), int(p.z)))


static func cell_clear(host: Node, c: Vector2i, gap: int = -1) -> bool:
	if gap < 0:
		gap = host.PROP_GAP
	if not is_floor_cell(host, c):
		return false
	for p in host.occupied.keys():
		var o: Vector2i = p
		if maxi(absi(o.x - c.x), absi(o.y - c.y)) < gap:
			return false
	return true


static func free_cell(host: Node, r: Dictionary, gap: int = -1) -> Vector2i:
	if gap < 0:
		gap = host.PROP_GAP
	if r.is_empty():
		return Vector2i(-1, -1)
	var rx := int(r.x)
	var ry := int(r.y)
	var rw := int(r.w)
	var rh := int(r.h)
	var opts: Array[Vector2i] = []
	for y in range(ry + 1, ry + maxi(2, rh) - 1):
		for x in range(rx + 1, rx + maxi(2, rw) - 1):
			var c := Vector2i(x, y)
			if cell_clear(host, c, gap):
				opts.append(c)
	if not opts.is_empty():
		return opts[host.floor_rng.randi() % opts.size()]
	opts.clear()
	for y in range(ry + 1, ry + maxi(2, rh) - 1):
		for x in range(rx + 1, rx + maxi(2, rw) - 1):
			var c2 := Vector2i(x, y)
			if cell_clear(host, c2, 1):
				opts.append(c2)
	if not opts.is_empty():
		return opts[host.floor_rng.randi() % opts.size()]
	return rand_cell(host, r)


static func free_cell_world(host: Node, prefer: Dictionary, gap: int = -1) -> Vector2i:
	if gap < 0:
		gap = host.PROP_GAP
	var rooms: Array = []
	if not prefer.is_empty() and str(prefer.get("kind", "")) != "spawn" and not near_spawn(host, center_room(prefer)):
		rooms.append(prefer)
	for r in host.data.get("rooms", []):
		if r in rooms:
			continue
		if str(r.get("kind", "")) == "spawn" or near_spawn(host, center_room(r)):
			continue
		rooms.append(r)
	for g in [gap, 1]:
		for r in rooms:
			var c := free_cell(host, r, g)
			if c.x >= 0 and cell_clear(host, c, g) and not near_spawn(host, c):
				return c
	var away := away_room(host)
	if not away.is_empty():
		return rand_cell(host, away)
	return Vector2i(int(host.data.spawn.x) + 8, int(host.data.spawn.y) + 8)


static func free_near(host: Node, center: Vector2i, gap: int = -1) -> Vector2i:
	if gap < 0:
		gap = host.PROP_GAP
	if cell_clear(host, center, gap):
		return center
	for rad in range(1, 7):
		var opts: Array[Vector2i] = []
		for y in range(center.y - rad, center.y + rad + 1):
			for x in range(center.x - rad, center.x + rad + 1):
				var c := Vector2i(x, y)
				if cell_clear(host, c, gap):
					opts.append(c)
		if not opts.is_empty():
			return opts[host.floor_rng.randi() % opts.size()]
	for rad in range(1, 7):
		var opts2: Array[Vector2i] = []
		for y in range(center.y - rad, center.y + rad + 1):
			for x in range(center.x - rad, center.x + rad + 1):
				var c2 := Vector2i(x, y)
				if cell_clear(host, c2, 1):
					opts2.append(c2)
		if not opts2.is_empty():
			return opts2[host.floor_rng.randi() % opts2.size()]
	return center


static func seed_occupied(host: Node) -> void:
	host.occupied.clear()
	mark_cell(host, host.data.spawn)
	mark_cell(host, host.data.crystal)
	mark_cell(host, host.data.stairs)
	mark_cell(host, host.data.boss)
	mark_cell(host, host.data.door)
	for o in host.data.get("openings", []):
		for raw in o.get("cells", []):
			mark_cell(host, Vector2i(raw))
	if host.player:
		mark_cell(host, world_cell(host.player.global_position))
	for n in host.get_tree().get_nodes_in_group("interact"):
		if n is Node3D:
			mark_cell(host, world_cell((n as Node3D).global_position))


static func walkable_near(host: Node, center: Vector2i, radius: int, allow_safe: bool) -> Vector2i:
	var opts: Array[Vector2i] = []
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			var c := Vector2i(x, y)
			if not is_floor_cell(host, c):
				continue
			if not allow_safe and is_safe_cell(host, c):
				continue
			if absi(x - center.x) + absi(y - center.y) < 2:
				continue
			opts.append(c)
	if opts.is_empty():
		return Vector2i(-1, -1)
	return opts[host.floor_rng.randi() % opts.size()]
