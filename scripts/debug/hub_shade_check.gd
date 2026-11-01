extends RefCounted

## Building faces turned from the sun read as shaded: per face (FaceLit.lam < SUNWARD) the CPU twin of face_lit.gd
## over a GRID of texels, mean light (no pools) <= SHADE_MAX (FaceLit.SHADE, the shaded-ground level, plus slack);
## lantern pools on top peak <= FaceLit.SUN_CAP (sunlit art). bad: "" or the failing faces; report: every face;
## plant: unshaded faces (flat) with 8x pools + 0.3 and no cap, must be "caught" on both counts.

const FaceLit := preload("res://scripts/world/camp_build/face_lit.gd")
const Pools := preload("res://scripts/graphics/light_rt/pools.gd")
const LightRt := preload("res://scripts/graphics/light_rt.gd")
const GRID := 16
const SUNWARD := 0.5
const SHADE_MAX := 0.55
const PLANT_POOL := 8.0
const PLANT_ADD := 0.3  # a lamp over-bright even where its graze on the face is ~0

var bad: String:
	get:
		return _run(false)[0]
var report: String:
	get:
		return _run(false)[1]
var plant: String:
	get:
		var b: String = _run(true)[0]
		return "caught" if b.contains("shade=") and b.contains("peak=") else "missed: " + b

static func _run(planted: bool) -> Array:
	var faces: Array = []
	_walk((Engine.get_main_loop() as SceneTree).root, faces)
	var bad := PackedStringArray()
	var rows := PackedStringArray()
	if faces.is_empty():
		bad.append("no faces")
	for s: Sprite3D in faces:
		var nrm: Vector3 = s.global_basis.z.normalized()
		var lm: float = FaceLit.lam(nrm)
		if lm >= SUNWARD:
			continue
		var sc: Vector3 = s.global_basis.get_scale()
		var w: float = s.texture.get_width() * s.pixel_size * sc.x
		var h: float = s.texture.get_height() * s.pixel_size * sc.y
		var sum := 0.0
		var peak := 0.0
		for i in GRID:
			var u: float = (i + 0.5) / GRID
			var x: float = s.global_position.x + w * (u - 0.5)
			var c: Color = LightRt.sample_xz(Vector2(x, s.global_position.z + FaceLit.AHEAD))
			var l: float = (c.r + c.g + c.b) / 3.0
			for j in GRID:
				var v: float = (j + 0.5) / GRID
				var base: float = lerpf(1.0, FaceLit.rel(l, planted, lm) * FaceLit.band(v) * FaceLit.edge(u, planted), FaceLit.K)
				var q := Vector3(x, s.global_position.y + h * (0.5 - v), s.global_position.z) + nrm * 0.02
				var pool: float = Pools.light_at(q, nrm, FaceLit.POOL_WRAP).get_luminance() * (PLANT_POOL if planted else 1.0) + (PLANT_ADD if planted else 0.0)
				sum += base
				peak = maxf(peak, FaceLit.lit(base, pool, not planted))
		var mean: float = sum / (GRID * GRID)
		rows.append("%s lam=%.2f mean=%.3f peak=%.3f" % [s.name, lm, mean, peak])
		if mean > SHADE_MAX:
			bad.append("%s shade=%.3f" % [s.name, mean])
		if peak > FaceLit.SUN_CAP + 0.001:
			bad.append("%s peak=%.3f" % [s.name, peak])
	return [", ".join(bad), " | ".join(rows)]

static func _walk(n: Node, out: Array) -> void:
	if n is Sprite3D and (n as Sprite3D).material_override is ShaderMaterial and (n as Sprite3D).texture != null:
		var m: ShaderMaterial = (n as Sprite3D).material_override
		if m.get_shader_parameter("ahead") != null and m.get_shader_parameter("face_light") == null:
			out.append(n)
	for c in n.get_children():
		_walk(c, out)
