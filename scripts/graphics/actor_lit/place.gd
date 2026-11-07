extends Object

## Split from actor_lit.gd: _place, _biased.

const Emis := preload("res://scripts/graphics/actor_lit/lit_emis.gd")
const Geo := preload("res://scripts/graphics/actor_lit/lit_geo.gd")
const Hulls := preload("res://scripts/graphics/light_rt/hub_hulls.gd")
const K := preload("res://scripts/graphics/actor_lit/lit_k.gd")
const Soles := preload("res://scripts/graphics/actor_lit/soles.gd")
const T := preload("res://scripts/data/tunables.gd")
const Slots := preload("res://scripts/graphics/actor_lit/slots.gd")

static func _place(host: Node, tex: Texture2D, feet: Vector2) -> void:
	var t0: int = host._mark_t()
	var t_sole: int = host._mark_t()
	var soles: Vector4 = Soles._soles(tex)
	host._mark_us(9, t_sole)
	var tw: float = float(maxi(1, tex.get_width()))
	var th: float = float(maxi(1, tex.get_height()))
	var px: float = host.spr.pixel_size
	# Both pins on the grounded (lowest) sole row: a raised foot keeps its x but not its lift, so it shows a gap
	# above the mark in proportion to the lift (hub_shadow_check/mark_matrix.gd).
	var sole_y: float = maxf(soles.y, soles.w)
	var up: float = K.RAISED_M / maxf(host.spr.pixel_size, 1e-5)
	var gl: bool = sole_y - soles.y < up and not (host.plant_flat and soles.y < sole_y)
	var gr: bool = sole_y - soles.w < up and not (host.plant_flat and soles.w < sole_y)
	# A grounded foot pins at its own sole (contact) row; the shader (lit_k feet) casts its rows from there.
	var t_pin: int = host._mark_t()
	var fl: Vector2 = Geo._sole_xz(host, soles.x, soles.y if gl else sole_y, tw, th, gl) - feet
	var fr: Vector2 = Geo._sole_xz(host, soles.z, soles.w if gr else sole_y, tw, th, gr) - feet
	host.lift = 0.0
	var kind: Variant = host.get_parent().get("move_kind")
	if host.air_force or kind == "fly" or kind == "hop":
		# Straight-down pins (no camera drop, no tuck): the mark stays under the body, detached by the altitude.
		var wl: Vector3 = Geo._sole_world(host, soles.x, sole_y, tw, th)
		var wr: Vector3 = Geo._sole_world(host, soles.z, sole_y, tw, th)
		if minf(wl.y, wr.y) - T.FLOOR_Y > K.AIR_MIN:
			host.lift = minf(wl.y, wr.y) - T.FLOOR_Y
			fl = Vector2(wl.x, wl.z) - feet
			fr = Vector2(wr.x, wr.z) - feet
	host._mark_us(10, t_pin)
	var s_air: float = clampf(1.0 - host.lift / K.AIR_S_M, K.AIR_S_MIN, 1.0)
	var a_air: float = clampf(1.0 - host.lift / K.AIR_A_M, K.AIR_A_MIN, 1.0)
	var origin: Vector3 = Vector3(feet.x, T.FLOOR_Y, feet.y)
	var ink: float = 0.0
	if App.in_dungeon:
		for slot in K.MARK_N:
			if host._alpha_at[slot] >= K.HIDE_A:
				ink += host._alpha_at[slot]
	var scale: float = 1.0
	if App.in_dungeon and host._ink_budget > 0.001 and ink > host._ink_budget:
		scale = host._ink_budget / ink
	var glow: bool = Emis.rule_of(host.get_parent()) == "glow"
	host._mark_us(2, t0)
	for slot in K.MARK_N:
		var node: MeshInstance3D = host.marks[slot]
		var live: bool = host._alpha_at[slot] >= K.HIDE_A and not glow
		if not live:
			node.visible = false
			continue
		var dir: Vector2 = _biased(host, host._away_at[slot])
		Slots._sync_slot(host, slot, tex, soles, fl, fr, dir, px, feet)
		var ts: int = host._mark_t()
		var at: Vector3 = origin
		if host.lift > 0.0:
			var run: Vector2 = dir * Geo._reach(host.lift, host._stretch_at[slot], host._src_at[slot])
			at += Vector3(run.x, 0.0, run.y)
		node.global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3(s_air, 1.0, s_air)), at)
		var shade_mat: ShaderMaterial = node.material_override as ShaderMaterial
		if shade_mat != null:
			var shown: float = host._alpha_at[slot] * scale * a_air
			var shade: Color = Color(0.02, 0.02, 0.02, shown)
			if not host._shade_set[slot] or shade != host._shade_at[slot]:
				shade_mat.set_shader_parameter("shade", shade)
				host._shade_at[slot] = shade
				host._shade_set[slot] = true
			var sun_c: float = 1.0 if slot == 0 and not App.in_dungeon else 0.0
			if sun_c != host._sun_at[slot]:
				shade_mat.set_shader_parameter("sun_cancel", sun_c)
				host._sun_at[slot] = sun_c
			if slot == 0 and host._hull_n != Hulls._n:
				Hulls.bind(shade_mat)
				host._hull_n = Hulls._n
			var grid_v: float = K.HUB_GRID if K.on_grid() else 0.0
			if grid_v != host._grid_at[slot]:
				shade_mat.set_shader_parameter("grid", grid_v)
				host._grid_at[slot] = grid_v
		node.visible = true
		host._mark_us(6, ts)

static func _biased(host: Node, away: Vector2) -> Vector2:
	# Keep a little Z so a side-on light does not flatten the quad.
	# Sign follows the light so a source toward the camera can cast up-screen.
	var dir: Vector2 = away
	if dir.length_squared() < 0.0004:
		dir = K.SUN_AWAY
	else:
		dir = dir.normalized()
	if absf(dir.y) < K.MIN_DOWN:
		dir.y = K.MIN_DOWN if dir.y >= 0.0 else -K.MIN_DOWN
	return dir.normalized()
