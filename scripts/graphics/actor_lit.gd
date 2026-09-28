extends Node

## Feet tint from the light RT. Hub keeps one sun mark. Dungeon uses up to three.
## Player uses the live sticker after flip_h. Dummy and enemies use their still.
## Sole pixels pin to the sticker. The head shears with a signed floor-Z bias.
## Dungeon alpha is split across the live marks so they do not smear black.

const T := preload("res://scripts/data/tunables.gd")
const LightRt := preload("res://scripts/graphics/light_rt.gd")

const SUN_AWAY := Vector2(0.406138, 0.913811)
const HUB_STRETCH := 0.72
const HUB_ALPHA := 0.55
const D_NEAR := 0.12
const D_FAR := 0.72
const A_NEAR := 0.50
const A_FAR := 0.0
const MIN_DOWN := 0.28
const TURN_RATE := 20.0
const EASE_RATE := 12.0
const HIDE_A := 0.03
const MARK_N := 3

const SHADE := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;
uniform sampler2D albedo_tex : source_color, filter_nearest;
uniform vec4 shade = vec4(0.02, 0.02, 0.02, 0.55);

void vertex() {
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	clip.z += 0.003 * clip.w;
	POSITION = clip;
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	if (tex.a < 0.2) {
		discard;
	}
	ALBEDO = shade.rgb;
	ALPHA = shade.a;
}
"""

static var _shade: Shader
static var _spans: Dictionary = {}
static var _sole_at: Dictionary = {}

var spr: Sprite3D
var marks: Array[MeshInstance3D] = []
var _game: Color = Color.WHITE
var _sent: Color = Color(-1.0, -1.0, -1.0, -1.0)
var _key_at: Array[String] = []
var _away_at: Array[Vector2] = []
var _stretch_at: Array[float] = []
var _alpha_at: Array[float] = []
var _src_at: Array[Vector2] = []
var _held: Array[bool] = []
var _rank_at: Array[int] = []
var _ink_budget: float = 0.0
var _flip: bool = false


static func bind(body: Node3D, sticker: Sprite3D) -> void:
	if body == null or sticker == null:
		return
	var script: GDScript = load("res://scripts/graphics/actor_lit.gd") as GDScript
	var lit: Node = script.new() as Node
	if lit == null:
		return
	lit.set("spr", sticker)
	lit.name = "ActorLit"
	body.add_child(lit)


func _ready() -> void:
	for slot in MARK_N:
		var mesh_node: MeshInstance3D = MeshInstance3D.new()
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat: ShaderMaterial = _mat()
		mat.render_priority = 8 - slot
		mesh_node.material_override = mat
		mesh_node.visible = false
		mesh_node.top_level = true
		marks.append(mesh_node)
		add_child(mesh_node)
		_key_at.append("")
		_away_at.append(SUN_AWAY)
		_stretch_at.append(HUB_STRETCH)
		var start_a: float = 0.0
		if slot == 0:
			start_a = HUB_ALPHA
		_alpha_at.append(start_a)
		_src_at.append(Vector2.ZERO)
		_held.append(false)
		_rank_at.append(slot)


func _process(delta: float) -> void:
	if spr == null or not is_instance_valid(spr):
		queue_free()
		return
	var body: Node = get_parent()
	if body != null and body.get("dead") == true:
		_hide_all()
		return
	var host: Node3D = body as Node3D
	if host == null:
		return
	_tint(host)
	_lay(host, delta)


func _hide_all() -> void:
	for slot in marks.size():
		marks[slot].visible = false


func _tint(host: Node3D) -> void:
	var cur: Color = spr.modulate
	if cur != _sent:
		_game = cur
	var feet: Vector2 = Vector2(host.global_position.x, host.global_position.z)
	var sample: Color = LightRt.sample_xz(feet)
	_sent = _mix(sample)
	spr.modulate = _sent


func _lay(host: Node3D, delta: float) -> void:
	if spr.texture == null or not spr.visible:
		_hide_all()
		return
	var feet: Vector2 = Vector2(host.global_position.x, host.global_position.z)
	if App.in_dungeon and not LightRt.floor_open(feet):
		_hide_all()
		return
	var tex: Texture2D = spr.texture
	if not _usable(tex):
		_hide_all()
		return
	_flip = spr.flip_h
	if App.in_dungeon:
		_drive_many(feet, delta)
	else:
		_drive_hub(host, feet)
	_place(tex, feet)


func _is_player(host: Node) -> bool:
	var scr: Script = host.get_script()
	if scr == null:
		return false
	return str(scr.resource_path).ends_with("player.gd")


func _drive_hub(host: Node3D, feet: Vector2) -> void:
	_drive_sun()
	if not _is_player(host):
		return
	var src: Vector2 = LightRt.hub_crystal
	if src == Vector2.ZERO:
		return
	var reach: float = 2.2
	var dist: float = feet.distance_to(src)
	if dist > reach:
		return
	var step: Vector2 = feet - src
	if step.length_squared() < 0.0004:
		return
	var along: float = clampf(dist / reach, 0.0, 1.0)
	_away_at[1] = step.normalized()
	_stretch_at[1] = lerpf(1.45, 1.05, along)
	_alpha_at[1] = lerpf(0.16, 0.05, along)
	_src_at[1] = src
	_held[1] = true
	_rank_at[1] = 1



func _drive_sun() -> void:
	_away_at[0] = SUN_AWAY
	_stretch_at[0] = HUB_STRETCH
	_alpha_at[0] = HUB_ALPHA
	_held[0] = false
	_src_at[0] = Vector2.ZERO
	_rank_at[0] = 0
	_ink_budget = 0.0
	for slot in range(1, MARK_N):
		_alpha_at[slot] = 0.0
		_held[slot] = false
		_src_at[slot] = Vector2.ZERO
		_rank_at[slot] = slot


func _drive_many(feet: Vector2, delta: float) -> void:
	var hits: Array[Dictionary] = LightRt.nearest_casts(feet, MARK_N)
	var hit_n: int = hits.size()
	var srcs: Array[Vector2] = []
	var aims: Array[Vector2] = []
	var goal_s: PackedFloat32Array = PackedFloat32Array()
	var raw_a: PackedFloat32Array = PackedFloat32Array()
	_ink_budget = 0.0
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
		var stretch: float = lerpf(D_NEAR, D_FAR, mid)
		if kind == "crystal":
			stretch = lerpf(1.85, 1.15, along)
		else:
			# aim.y is floor Z. A side light shortens the mark into a puddle.
			stretch *= maxf(absf(aim.y), 0.2)
		var raw: float = lerpf(A_NEAR, A_FAR, along)
		srcs.append(src)
		aims.append(aim)
		goal_s.append(stretch)
		raw_a.append(raw)
	var goal_a: PackedFloat32Array = _split(raw_a)
	if hit_n > 0:
		_ink_budget = raw_a[0]
	var claim: Array[int] = []
	var taken: Array[bool] = []
	var fresh: Array[bool] = []
	for slot in MARK_N:
		claim.append(-1)
		fresh.append(false)
	taken.resize(hit_n)
	taken.fill(false)
	for slot in MARK_N:
		if not _held[slot]:
			continue
		var best: int = -1
		var best_d: float = 0.5
		for hi in hit_n:
			if taken[hi]:
				continue
			var gap: float = _src_at[slot].distance_to(srcs[hi])
			if gap < best_d:
				best_d = gap
				best = hi
		if best >= 0:
			taken[best] = true
			claim[slot] = best
	for hi in hit_n:
		if taken[hi]:
			continue
		var open: int = _open_slot(claim)
		if open < 0:
			continue
		claim[open] = hi
		taken[hi] = true
		fresh[open] = true
	var k: float = clampf(delta * EASE_RATE, 0.0, 1.0)
	for slot in MARK_N:
		var pick: int = claim[slot]
		if pick < 0:
			_alpha_at[slot] = lerpf(_alpha_at[slot], 0.0, k)
			_rank_at[slot] = MARK_N
			if _alpha_at[slot] < HIDE_A:
				_alpha_at[slot] = 0.0
				_held[slot] = false
			continue
		if fresh[slot] and _alpha_at[slot] < HIDE_A:
			var born: Vector2 = aims[pick]
			if born.length_squared() > 0.0004:
				_away_at[slot] = born
			else:
				_away_at[slot] = SUN_AWAY
			_stretch_at[slot] = goal_s[pick]
		_src_at[slot] = srcs[pick]
		_held[slot] = true
		_rank_at[slot] = pick
		_turn_slot(slot, aims[pick], delta)
		_stretch_at[slot] = lerpf(_stretch_at[slot], goal_s[pick], k)
		_alpha_at[slot] = lerpf(_alpha_at[slot], goal_a[pick], k)


func _split(raw: PackedFloat32Array) -> PackedFloat32Array:
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


func _open_slot(claim: Array[int]) -> int:
	var fading: int = -1
	var fading_a: float = 2.0
	for slot in MARK_N:
		if claim[slot] >= 0:
			continue
		if not _held[slot]:
			return slot
		if _alpha_at[slot] < fading_a:
			fading_a = _alpha_at[slot]
			fading = slot
	return fading


func _turn_slot(slot: int, aim: Vector2, delta: float) -> void:
	if aim.length_squared() <= 0.0004:
		return
	var dest: Vector2 = aim.normalized()
	var away: Vector2 = _away_at[slot]
	if away.length_squared() < 0.0004:
		_away_at[slot] = dest
		return
	var src: Vector2 = away.normalized()
	var ang: float = src.angle_to(dest)
	var step: float = TURN_RATE * delta
	if absf(ang) <= step:
		_away_at[slot] = dest
		return
	var spin: float = step
	if ang <= 0.0:
		spin = -step
	_away_at[slot] = src.rotated(spin)


func _biased(away: Vector2) -> Vector2:
	# Keep a little Z so a side-on light does not flatten the quad.
	# Sign follows the light so a source toward the camera can cast up-screen.
	var dir: Vector2 = away
	if dir.length_squared() < 0.0004:
		dir = SUN_AWAY
	else:
		dir = dir.normalized()
	if absf(dir.y) < MIN_DOWN:
		dir.y = MIN_DOWN if dir.y >= 0.0 else -MIN_DOWN
	return dir.normalized()


func _mix(sample: Color) -> Color:
	return Color(_game.r * sample.r, _game.g * sample.g, _game.b * sample.b, _game.a)


func _usable(tex: Texture2D) -> bool:
	return tex != null and tex.get_width() > 8 and tex.get_height() > 8


func _place(tex: Texture2D, feet: Vector2) -> void:
	var soles: Vector4 = _soles(tex)
	var tw: float = float(maxi(1, tex.get_width()))
	var th: float = float(maxi(1, tex.get_height()))
	var px: float = spr.pixel_size
	var fl: Vector2 = _sole_xz(soles.x, soles.y, tw, th) - feet
	var fr: Vector2 = _sole_xz(soles.z, soles.w, tw, th) - feet
	var origin: Vector3 = Vector3(feet.x, T.FLOOR_Y, feet.y)
	var ink: float = 0.0
	if App.in_dungeon:
		for slot in MARK_N:
			if _alpha_at[slot] >= HIDE_A:
				ink += _alpha_at[slot]
	var scale: float = 1.0
	if App.in_dungeon and _ink_budget > 0.001 and ink > _ink_budget:
		scale = _ink_budget / ink
	for slot in MARK_N:
		var node: MeshInstance3D = marks[slot]
		var live: bool = _alpha_at[slot] >= HIDE_A
		if not App.in_dungeon and slot > 1:
			live = false
		if not live:
			node.visible = false
			continue
		var dir: Vector2 = _biased(_away_at[slot])
		_sync_slot(slot, tex, soles, fl, fr, dir, px)
		node.global_transform = Transform3D(Basis.IDENTITY, origin)
		var shade_mat: ShaderMaterial = node.material_override as ShaderMaterial
		if shade_mat != null:
			shade_mat.render_priority = 8 - _rank_at[slot]
			var shown: float = _alpha_at[slot] * scale
			shade_mat.set_shader_parameter("shade", Color(0.02, 0.02, 0.02, shown))
		node.visible = true


func _sync_slot(slot: int, tex: Texture2D, soles: Vector4, fl: Vector2, fr: Vector2, dir: Vector2, px: float) -> void:
	var node: MeshInstance3D = marks[slot]
	var reach: Vector2 = dir * _stretch_at[slot]
	var key: String = "%s|%s|%s|%s|%s|%s|%s|%s|%s" % [
		tex.get_instance_id(), px, _flip,
		snappedf(fl.x, 0.01), snappedf(fl.y, 0.01),
		snappedf(fr.x, 0.01), snappedf(fr.y, 0.01),
		snappedf(reach.x, 0.01), snappedf(reach.y, 0.01),
	]
	var mat: ShaderMaterial = node.material_override as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("albedo_tex", tex)
	if key == _key_at[slot] and node.mesh != null:
		return
	_key_at[slot] = key
	node.mesh = _quad(tex, _span(tex), soles, fl, fr, dir, px, _stretch_at[slot])


func _sole_xz(tx: float, ty: float, tw: float, th: float) -> Vector2:
	var ox: float = spr.offset.x
	var oy: float = spr.offset.y
	if spr.centered:
		ox -= tw * 0.5
		oy -= th * 0.5
	var g: float = tx / tw
	if _flip:
		g = 1.0 - g
	var lx: float = (ox + g * tw) * spr.pixel_size
	var ly: float = (oy + (th - ty)) * spr.pixel_size
	var axis: Vector3 = _bill_x()
	var world: Vector3 = spr.global_position + axis * lx + Vector3(0.0, ly, 0.0)
	return _drop_floor(world)


func _bill_x() -> Vector3:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.RIGHT
	var side: Vector3 = Vector3.UP.cross(cam.global_transform.basis.z)
	if side.length_squared() < 0.0004:
		return Vector3.RIGHT
	return side.normalized()


func _drop_floor(world: Vector3) -> Vector2:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return Vector2(world.x, world.z)
	var view: Vector3 = -cam.global_transform.basis.z
	if absf(view.y) < 0.05:
		return Vector2(world.x, world.z)
	var t: float = (T.FLOOR_Y - world.y) / view.y
	if absf(t) > 3.0:
		return Vector2(world.x, world.z)
	var hit: Vector3 = world + view * t
	return Vector2(hit.x, hit.z)


func _quad(tex: Texture2D, span: Vector4, soles: Vector4, fl: Vector2, fr: Vector2, dir: Vector2, px: float, stretch: float) -> ArrayMesh:
	var tw: float = float(maxi(1, tex.get_width()))
	var th: float = float(maxi(1, tex.get_height()))
	var x0: float = span.x * tw
	var x1: float = span.z * tw
	var y0: float = span.y * th
	var y1: float = span.w * th
	var verts: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	verts.append(_corner(x0, y1, soles, fl, fr, dir, px, stretch))
	verts.append(_corner(x1, y1, soles, fl, fr, dir, px, stretch))
	verts.append(_corner(x1, y0, soles, fl, fr, dir, px, stretch))
	verts.append(_corner(x0, y0, soles, fl, fr, dir, px, stretch))
	uvs.append(Vector2(span.x, span.w))
	uvs.append(Vector2(span.z, span.w))
	uvs.append(Vector2(span.z, span.y))
	uvs.append(Vector2(span.x, span.y))
	indices.append_array(PackedInt32Array([0, 1, 2, 0, 2, 3]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _corner(tx: float, ty: float, soles: Vector4, fl: Vector2, fr: Vector2, dir: Vector2, px: float, stretch: float) -> Vector3:
	var span_x: float = soles.z - soles.x
	if absf(span_x) < 0.5:
		span_x = 0.5 if soles.z >= soles.x else -0.5
	var a: float = (tx - soles.x) / span_x
	var foot_y: float = soles.y + a * (soles.w - soles.y)
	var pos: Vector2 = fl.lerp(fr, a) + dir * ((foot_y - ty) * px * stretch)
	return Vector3(pos.x, 0.0, pos.y)


static func _soles(tex: Texture2D) -> Vector4:
	var id: int = tex.get_rid().get_id()
	if _sole_at.has(id):
		return _sole_at[id] as Vector4
	var tw: int = maxi(1, tex.get_width())
	var th: int = maxi(1, tex.get_height())
	var fb: Vector4 = Vector4(0.0, float(th), float(tw), float(th))
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return _keep(id, fb)
	if img.get_format() != Image.FORMAT_RGBA8:
		var copy: Image = img.duplicate()
		copy.convert(Image.FORMAT_RGBA8)
		img = copy
	var w: int = img.get_width()
	var h: int = img.get_height()
	var bytes: PackedByteArray = img.get_data()
	if w < 1 or h < 1 or bytes.size() < w * h * 4:
		return _keep(id, fb)
	var min_x: int = w
	var min_y: int = h
	var max_x: int = -1
	var max_y: int = -1
	for y in h:
		var row: int = y * w * 4
		for x in w:
			if bytes[row + x * 4 + 3] < 51:
				continue
			if x < min_x:
				min_x = x
			if y < min_y:
				min_y = y
			if x > max_x:
				max_x = x
			if y > max_y:
				max_y = y
	if max_x < 0:
		return _keep(id, fb)
	_spans[id] = Vector4(
		float(min_x) / float(w), float(min_y) / float(h),
		float(max_x + 1) / float(w), float(max_y + 1) / float(h)
	)
	var mid: int = int(float(min_x + max_x) * 0.5)
	var ly: int = -1
	var ry: int = -1
	var ls: float = 0.0
	var ln: int = 0
	var rs: float = 0.0
	var rn: int = 0
	for y2 in range(min_y, max_y + 1):
		var row2: int = y2 * w * 4
		var lsum: float = 0.0
		var lnum: int = 0
		var rsum: float = 0.0
		var rnum: int = 0
		for x2 in range(min_x, max_x + 1):
			if bytes[row2 + x2 * 4 + 3] < 51:
				continue
			if x2 <= mid:
				lsum += float(x2) + 0.5
				lnum += 1
			else:
				rsum += float(x2) + 0.5
				rnum += 1
		if lnum > 0:
			ly = y2
			ls = lsum
			ln = lnum
		if rnum > 0:
			ry = y2
			rs = rsum
			rn = rnum
	if ly < 0 or ry < 0:
		return _keep(id, _bottom_span(bytes, w, max_y, min_x, max_x))
	var lx: float = ls / float(ln)
	var rx: float = rs / float(rn)
	if absf(rx - lx) < 0.5:
		lx = float(min_x) + 0.5
		rx = float(max_x) + 0.5
	return _keep(id, Vector4(lx, float(ly + 1), rx, float(ry + 1)))


static func _keep(id: int, sole: Vector4) -> Vector4:
	_sole_at[id] = sole
	return sole


static func _bottom_span(bytes: PackedByteArray, w: int, y: int, x0: int, x1: int) -> Vector4:
	var row: int = y * w * 4
	var left: int = x1
	var right: int = x0
	for x in range(x0, x1 + 1):
		if bytes[row + x * 4 + 3] < 51:
			continue
		if x < left:
			left = x
		if x > right:
			right = x
	if right <= left:
		right = mini(w - 1, left + 1)
	return Vector4(float(left) + 0.5, float(y + 1), float(right) + 0.5, float(y + 1))


static func _span(tex: Texture2D) -> Vector4:
	var id: int = tex.get_rid().get_id()
	if not _spans.has(id):
		_soles(tex)
	if _spans.has(id):
		return _spans[id] as Vector4
	return Vector4(0.0, 0.0, 1.0, 1.0)


static func _mat() -> ShaderMaterial:
	if _shade == null:
		var sh: Shader = Shader.new()
		sh.code = SHADE
		_shade = sh
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = _shade
	mat.render_priority = 8
	return mat
