extends Object

## Actor shade-mark slot driver: hub sun and crystal, dungeon light claims. State stays on the actor_lit.gd node passed as lit.

const K := preload("res://scripts/graphics/actor_lit/lit_k.gd")
const LightRt := preload("res://scripts/graphics/light_rt.gd")
const Lights := preload("res://scripts/graphics/light_rt/lights.gd")

static func _is_player(host: Node) -> bool:
	var scr: Script = host.get_script()
	if scr == null:
		return false
	return str(scr.resource_path).ends_with("player.gd")

## Hub: slot 0 is the sun mark; the player also takes point-light marks from the two nearest hub point lights (the
## floor crystal and every face lantern, group hub_lamp), planned by _plan exactly like the dungeon crystal and torches.
static func _drive_hub(lit: Variant, host: Node3D, feet: Vector2) -> void:
	_drive_sun(lit)
	if not _is_player(host):
		return
	var hits: Array[Dictionary] = hub_casts(lit as Node, feet, K.MARK_N - 1)
	var plan: Dictionary = _plan(hits, feet)
	for i in hits.size():
		var slot: int = i + 1
		lit._away_at[slot] = plan["aims"][i]
		lit._stretch_at[slot] = plan["s"][i]
		# Each hub light keeps its own full mark (no dungeon split): the hub ground is lit, so split marks vanish.
		lit._alpha_at[slot] = plan["raw"][i]
		lit._src_at[slot] = plan["srcs"][i]
		lit._held[slot] = true
		lit._rank_at[slot] = slot

## Hub point lights in reach of feet, nearest first, as LightRt.nearest_casts rows (crystal / torch reach).
static func hub_casts(n: Node, feet: Vector2, cap: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var pts: Array[Vector2] = hub_points(n)
	for i in pts.size():
		var kind: String = "crystal" if i == 0 and LightRt.hub_crystal != Vector2.ZERO else "torch"
		var dist: float = feet.distance_to(pts[i])
		var reach: float = Lights._reach(kind)
		if dist <= reach and dist > 0.02:
			out.append({"xz": pts[i], "dist": dist, "reach": reach, "kind": kind})
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["dist"]) < float(y["dist"]))
	return out.slice(0, cap)

## Ground xz of the hub's point lights: the floor crystal and each face lantern (lamps.gd hub_lamp nodes).
static func hub_points(n: Node) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if LightRt.hub_crystal != Vector2.ZERO:
		out.append(LightRt.hub_crystal)
	if n != null and n.is_inside_tree():
		for lamp: Node in n.get_tree().get_nodes_in_group("hub_lamp"):
			if lamp is Node3D:
				out.append(Vector2((lamp as Node3D).global_position.x, (lamp as Node3D).global_position.z))
	return out

static func _drive_sun(lit: Variant) -> void:
	lit._away_at[0] = K.SUN_AWAY
	lit._stretch_at[0] = K.HUB_STRETCH
	lit._alpha_at[0] = K.HUB_ALPHA
	lit._held[0] = false
	lit._src_at[0] = Vector2.ZERO
	lit._rank_at[0] = 0
	lit._ink_budget = 0.0
	for slot in range(1, K.MARK_N):
		lit._alpha_at[slot] = 0.0
		lit._held[slot] = false
		lit._src_at[slot] = Vector2.ZERO
		lit._rank_at[slot] = slot

static func _drive_many(lit: Variant, feet: Vector2, delta: float) -> void:
	var hits: Array[Dictionary] = LightRt.nearest_casts(feet, K.MARK_N)
	var hit_n: int = hits.size()
	var plan: Dictionary = _plan(hits, feet)
	var srcs: Array[Vector2] = plan["srcs"]
	var aims: Array[Vector2] = plan["aims"]
	var goal_s: PackedFloat32Array = plan["s"]
	var goal_a: PackedFloat32Array = plan["a"]
	lit._ink_budget = plan["budget"]
	var claim: Array[int] = []
	var taken: Array[bool] = []
	var fresh: Array[bool] = []
	for slot in K.MARK_N:
		claim.append(-1)
		fresh.append(false)
	taken.resize(hit_n)
	taken.fill(false)
	for slot in K.MARK_N:
		if not lit._held[slot]:
			continue
		var best: int = -1
		var best_d: float = 0.5
		for hi in hit_n:
			if taken[hi]:
				continue
			var gap: float = lit._src_at[slot].distance_to(srcs[hi])
			if gap < best_d:
				best_d = gap
				best = hi
		if best >= 0:
			taken[best] = true
			claim[slot] = best
	for hi in hit_n:
		if taken[hi]:
			continue
		var open: int = _open_slot(lit, claim)
		if open < 0:
			continue
		claim[open] = hi
		taken[hi] = true
		fresh[open] = true
	var k: float = clampf(delta * K.EASE_RATE, 0.0, 1.0)
	for slot in K.MARK_N:
		var pick: int = claim[slot]
		if pick < 0:
			lit._alpha_at[slot] = lerpf(lit._alpha_at[slot], 0.0, k)
			lit._rank_at[slot] = K.MARK_N
			if lit._alpha_at[slot] < K.HIDE_A:
				lit._alpha_at[slot] = 0.0
				lit._held[slot] = false
			continue
		if fresh[slot] and lit._alpha_at[slot] < K.HIDE_A:
			var born: Vector2 = aims[pick]
			if born.length_squared() > 0.0004:
				lit._away_at[slot] = born
			else:
				lit._away_at[slot] = K.SUN_AWAY
			lit._stretch_at[slot] = goal_s[pick]
		lit._src_at[slot] = srcs[pick]
		lit._held[slot] = true
		lit._rank_at[slot] = pick
		_turn_slot(lit, slot, aims[pick], delta)
		lit._stretch_at[slot] = lerpf(lit._stretch_at[slot], goal_s[pick], k)
		lit._alpha_at[slot] = lerpf(lit._alpha_at[slot], goal_a[pick], k)

static func _split(raw: PackedFloat32Array) -> PackedFloat32Array:
	var hit_n: int = raw.size()
	var out: PackedFloat32Array = PackedFloat32Array()
	if hit_n < 1:
		return out
	var sum_w: float = 0.0
	var weights: PackedFloat32Array = PackedFloat32Array()
	for i in hit_n:
		var w: float = float(hit_n - i) * maxf(raw[i], 0.001)
		weights.append(w)
		sum_w += w
	var budget: float = raw[0]
	if sum_w < 0.0001:
		out.resize(hit_n)
		return out
	for i in hit_n:
		out.append(budget * (weights[i] / sum_w))
	return out

static func _open_slot(lit: Variant, claim: Array[int]) -> int:
	var fading: int = -1
	var fading_a: float = 2.0
	for slot in K.MARK_N:
		if claim[slot] >= 0:
			continue
		if not lit._held[slot]:
			return slot
		if lit._alpha_at[slot] < fading_a:
			fading_a = lit._alpha_at[slot]
			fading = slot
	return fading

static func _turn_slot(lit: Variant, slot: int, aim: Vector2, delta: float) -> void:
	if aim.length_squared() <= 0.0004:
		return
	var dest: Vector2 = aim.normalized()
	var away: Vector2 = lit._away_at[slot]
	if away.length_squared() < 0.0004:
		lit._away_at[slot] = dest
		return
	var src: Vector2 = away.normalized()
	var ang: float = src.angle_to(dest)
	var step: float = K.TURN_RATE * delta
	if absf(ang) <= step:
		lit._away_at[slot] = dest
		return
	var spin: float = step
	if ang <= 0.0:
		spin = -step
	lit._away_at[slot] = src.rotated(spin)

## Shared point-light mark plan (dungeon and hub): per hit its away aim, stretch and split alpha.
static func _plan(hits: Array[Dictionary], feet: Vector2) -> Dictionary:
	var hit_n: int = hits.size()
	var srcs: Array[Vector2] = []
	var aims: Array[Vector2] = []
	var goal_s: PackedFloat32Array = PackedFloat32Array()
	var raw_a: PackedFloat32Array = PackedFloat32Array()
	for i in hit_n:
		var hit: Dictionary = hits[i]
		var src: Vector2 = hit["xz"]
		var aim: Vector2 = Vector2.ZERO
		var step: Vector2 = feet - src
		if step.length_squared() > 0.0004:
			aim = step.normalized()
		var reach: float = maxf(float(hit["reach"]), 0.001)
		var along: float = clampf(float(hit["dist"]) / reach, 0.0, 1.0)
		var mid: float = sin(along * PI)
		var kind: String = str(hit.get("kind", ""))
		var stretch: float = lerpf(K.D_NEAR, K.D_FAR, mid)
		if kind == "crystal":
			stretch = lerpf(1.85, 1.15, along)
		else:
			# aim.y is floor Z. A side light shortens the mark into a puddle.
			stretch *= maxf(absf(aim.y), 0.2)
		var raw: float = lerpf(K.A_NEAR, K.A_FAR, along)
		srcs.append(src)
		aims.append(aim)
		goal_s.append(stretch)
		raw_a.append(raw)
	var budget: float = raw_a[0] if hit_n > 0 else 0.0
	return {"srcs": srcs, "aims": aims, "s": goal_s, "a": _split(raw_a), "raw": raw_a, "budget": budget}
