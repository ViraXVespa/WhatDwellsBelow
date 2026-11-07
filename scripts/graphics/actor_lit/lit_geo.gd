extends Object

## Actor shade-mark quad geometry. Reads state from the actor_lit.gd node passed as lit.

const T := preload("res://scripts/data/tunables.gd")
const K := preload("res://scripts/graphics/actor_lit/lit_k.gd")
const Commit := preload("res://scripts/graphics/mesh_commit.gd")
const Soles := preload("res://scripts/graphics/actor_lit/soles.gd")

static var _pin_at: Dictionary = {}
static var _air_at: Dictionary = {}
static var _mesh_at: Dictionary = {}

static func _sole_xz(lit: Variant, tx: float, ty: float, tw: float, th: float, tucked: bool = true) -> Vector2:
	var dropped: Vector2 = _drop_floor(lit, _sole_world(lit, tx, ty, tw, th))
	# Drop lands down-screen of the boot. Pull up-screen so the sole tucks under it.
	var tuck: float = lit.spr.pixel_size * (2.0 + float(lit.foot)) if tucked else 0.0
	# Hub marks snap to hub grid cells (K.GRID_M) (up to a cell down-screen): tuck two more cells so both boots (heels above their toes too) sit on the mark.
	if tucked and K.on_grid():
		tuck += 2.0 * K.GRID_M
	var back: Vector2 = Vector2(0.0, -1.0)
	var cam: Camera3D = lit.get_viewport().get_camera_3d()
	if cam != null:
		var flat: Vector2 = Vector2(-cam.global_transform.basis.z.x, -cam.global_transform.basis.z.z)
		if flat.length_squared() > 0.0004:
			back = flat.normalized()
	return dropped + back * tuck

## World point of a sticker texel (billboard axis, sprite origin, pixel size).
static func _sole_world(lit: Variant, tx: float, ty: float, tw: float, th: float) -> Vector3:
	var ox: float = lit.spr.offset.x
	var oy: float = lit.spr.offset.y
	if lit.spr.centered:
		ox -= tw * 0.5
		oy -= th * 0.5
	var g: float = tx / tw
	if lit._flip:
		g = 1.0 - g
	var lx: float = (ox + g * tw) * lit.spr.pixel_size
	var ly: float = (oy + (th - ty)) * lit.spr.pixel_size
	var axis: Vector3 = _bill_x(lit)
	return lit.spr.global_position + axis * lx + Vector3(0.0, ly, 0.0)

## Ground run of a height h along the light (head shear; a flyer's altitude offset uses the same run).
static func _reach(h: float, stretch: float, src: Vector2) -> float:
	var elev: float = 0.85 if src.length_squared() > 0.0004 else K.SUN_ELEV
	return minf(h * maxf(stretch, 0.15) / elev, h * clampf(0.55 + stretch * 0.45, 0.45, 1.35))
static func _bill_x(lit: Variant) -> Vector3:
	var cam: Camera3D = lit.get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.RIGHT
	var side: Vector3 = Vector3.UP.cross(cam.global_transform.basis.z)
	if side.length_squared() < 0.0004:
		return Vector3.RIGHT
	return side.normalized()

static func _drop_floor(lit: Variant, world: Vector3) -> Vector2:
	var cam: Camera3D = lit.get_viewport().get_camera_3d()
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

static func _quad(lit: Variant, tex: Texture2D, span: Vector4, soles: Vector4, fl: Vector2, fr: Vector2, dir: Vector2, px: float, stretch: float, src: Vector2) -> ArrayMesh:
	var tw: float = float(maxi(1, tex.get_width()))
	var th: float = float(maxi(1, tex.get_height()))
	# Hub: one ground cell (K.GRID_M) of pad all round, past the sole too, so a cell the feet straddle draws whole
	# (the shader clamps reads at the contact row) and the mark meets both boots at any facing.
	var sole_v: float = span.w - 0.5 / th
	var pad: float = clampf(ceilf(K.GRID_M / maxf(px, 1e-4)), 0.0, 8.0) if K.on_grid() else 0.0
	var x0: float = span.x * tw - pad
	var x1: float = span.z * tw + pad
	var y0: float = span.y * th - pad
	var y1: float = span.w * th + pad
	span = Vector4(x0 / tw, y0 / th, x1 / tw, y1 / th)
	var verts: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	verts.append(_corner(lit, x0, y1, soles, fl, fr, dir, px, stretch, src))
	verts.append(_corner(lit, x1, y1, soles, fl, fr, dir, px, stretch, src))
	verts.append(_corner(lit, x1, y0, soles, fl, fr, dir, px, stretch, src))
	verts.append(_corner(lit, x0, y0, soles, fl, fr, dir, px, stretch, src))
	uvs.append(Vector2(span.x, span.w))
	uvs.append(Vector2(span.z, span.w))
	uvs.append(Vector2(span.z, span.y))
	uvs.append(Vector2(span.x, span.y))
	indices.append_array(PackedInt32Array([0, 1, 2, 0, 2, 3]))
	# UV2.y is the contact row. UV2.x is the shear height so a later light can re-aim this sun bake.
	var uv2 := PackedVector2Array()
	uv2.append(Vector2(_h_of(y1, soles, px), sole_v))
	uv2.append(Vector2(_h_of(y1, soles, px), sole_v))
	uv2.append(Vector2(_h_of(y0, soles, px), sole_v))
	uv2.append(Vector2(_h_of(y0, soles, px), sole_v))
	return Commit.commit(verts, null, uvs, indices, uv2)

static func _corner(lit: Variant, tx: float, ty: float, soles: Vector4, fl: Vector2, fr: Vector2, dir: Vector2, px: float, stretch: float, src: Vector2) -> Vector3:
	# Sole edge is the camera-dropped foot line. Head shears along the light.
	# Width stays on the billboard axis so a side stance cannot collapse to a needle.
	var aim: Vector2 = dir
	if aim.length_squared() < 0.0004:
		aim = K.SUN_AWAY
	else:
		aim = aim.normalized()
	var span_x: float = soles.z - soles.x
	var u: float = 0.5
	if absf(span_x) >= 2.0:
		u = clampf((tx - soles.x) / span_x, 0.0, 1.0)
	var pin: Vector2 = fl.lerp(fr, u)
	var sole_tx: float = lerpf(soles.x, soles.z, u)
	var extra: float = (tx - sole_tx) * px
	if lit._flip:
		extra = -extra
	var axis: Vector3 = _bill_x(lit)
	var ax: Vector2 = Vector2(axis.x, axis.z)
	if ax.length_squared() < 0.0004:
		ax = Vector2.RIGHT
	else:
		ax = ax.normalized()
	var base: Vector2 = pin + ax * extra
	var sole_y: float = maxf(soles.y, soles.w)
	var h: float = maxf(sole_y - ty, 0.0) * px
	var reach: float = _reach(h, stretch, src)
	return Vector3(base.x + aim.x * reach, 0.0, base.y + aim.y * reach)

static func _h_of(ty: float, soles: Vector4, px: float) -> float:
	return maxf(maxf(soles.y, soles.w) - ty, 0.0) * px

## Feet-relative ground pin. The first sight of a pose fills the cache; later frames look it up.
static func pin_xz(lit: Variant, tx: float, ty: float, tw: float, th: float, tucked: bool, feet: Vector2) -> Vector2:
	var key: String = _pin_key(lit, tx, ty, tw, th, tucked)
	if _pin_at.has(key):
		return _pin_at[key] as Vector2
	var got: Vector2 = _sole_xz(lit, tx, ty, tw, th, tucked) - feet
	_pin_at[key] = got
	return got

## Straight-down air pin (no camera drop). Cached the same way.
static func air_pin(lit: Variant, tx: float, ty: float, tw: float, th: float, feet: Vector2) -> Vector2:
	var key: String = "air|" + _pin_key(lit, tx, ty, tw, th, false)
	if _air_at.has(key):
		return _air_at[key] as Vector2
	var world: Vector3 = _sole_world(lit, tx, ty, tw, th)
	var got: Vector2 = Vector2(world.x, world.z) - feet
	_air_at[key] = got
	return got

## One sun-sheared quad per pose. Point and dungeon slots re-aim it in the shader.
static func sun_mesh(lit: Variant, tex: Texture2D, soles: Vector4, fl: Vector2, fr: Vector2, px: float) -> ArrayMesh:
	var key: String = "%s|%s|%s|%s|%s|%s|%s|%s|%s" % [
		tex.resource_path, lit._flip, snappedf(px, 0.000001),
		snappedf(fl.x, 0.01), snappedf(fl.y, 0.01), snappedf(fr.x, 0.01), snappedf(fr.y, 0.01),
		K.on_grid(), _basis_key(lit),
	]
	if _mesh_at.has(key):
		return _mesh_at[key] as ArrayMesh
	var mesh: ArrayMesh = _quad(lit, tex, Soles._span(tex), soles, fl, fr, K.SUN_AWAY, px, K.HUB_STRETCH, Vector2.ZERO)
	_mesh_at[key] = mesh
	return mesh

static func _pin_key(lit: Variant, tx: float, ty: float, tw: float, th: float, tucked: bool) -> String:
	var spr: Sprite3D = lit.spr as Sprite3D
	var off: Vector2 = Vector2.ZERO
	var px: float = 0.0
	var centered: bool = false
	var y: float = 0.0
	if spr != null:
		off = spr.offset
		px = spr.pixel_size
		centered = spr.centered
		y = spr.global_position.y
	return "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [
		snappedf(tx, 0.01), snappedf(ty, 0.01), snappedf(tw, 0.01), snappedf(th, 0.01),
		tucked, lit._flip, snappedf(px, 0.000001), snappedf(off.x, 0.01), snappedf(off.y, 0.01),
		centered, lit.foot, snappedf(y, 0.01), _view_key(lit),
	]

static func _basis_key(lit: Variant) -> String:
	var cam: Camera3D = _cam(lit)
	if cam == null:
		return "nocam"
	var x: Vector3 = cam.global_transform.basis.x
	var z: Vector3 = cam.global_transform.basis.z
	return "%s,%s,%s,%s" % [snappedf(x.x, 0.001), snappedf(x.z, 0.001), snappedf(z.x, 0.001), snappedf(z.z, 0.001)]

static func _view_key(lit: Variant) -> String:
	var basis: String = _basis_key(lit)
	var cam: Camera3D = _cam(lit)
	var spr: Sprite3D = lit.spr as Sprite3D
	if cam == null or spr == null:
		return basis
	var rel: Vector3 = cam.global_position - spr.global_position
	return "%s|%s,%s,%s" % [basis, snappedf(rel.x, 0.05), snappedf(rel.y, 0.05), snappedf(rel.z, 0.05)]

static func _cam(lit: Variant) -> Camera3D:
	var spr: Sprite3D = lit.spr as Sprite3D
	if spr == null or spr.get_viewport() == null:
		return null
	return spr.get_viewport().get_camera_3d()
