extends Object

## Actor shade-mark quad geometry. Reads state from the actor_lit.gd node passed as lit.

const T := preload("res://scripts/data/tunables.gd")
const K := preload("res://scripts/graphics/actor_lit/lit_k.gd")
const Commit := preload("res://scripts/graphics/mesh_commit.gd")

static func _sole_xz(lit: Variant, tx: float, ty: float, tw: float, th: float) -> Vector2:
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
	var world: Vector3 = lit.spr.global_position + axis * lx + Vector3(0.0, ly, 0.0)
	var dropped: Vector2 = _drop_floor(lit, world)
	# Drop lands down-screen of the boot. Pull up-screen so the sole tucks under it.
	var tuck: float = lit.spr.pixel_size * 2.0
	var back: Vector2 = Vector2(0.0, -1.0)
	var cam: Camera3D = lit.get_viewport().get_camera_3d()
	if cam != null:
		var flat: Vector2 = Vector2(-cam.global_transform.basis.z.x, -cam.global_transform.basis.z.z)
		if flat.length_squared() > 0.0004:
			back = flat.normalized()
	return dropped + back * tuck
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
	var x0: float = span.x * tw
	var x1: float = span.z * tw
	var y0: float = span.y * th
	var y1: float = span.w * th
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
	return Commit.commit(verts, null, uvs, indices)

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
	var elev: float = K.SUN_ELEV
	if src.length_squared() > 0.0004:
		elev = 0.85
	var reach: float = h * maxf(stretch, 0.15) / elev
	var cap: float = h * clampf(0.55 + stretch * 0.45, 0.45, 1.35)
	if reach > cap:
		reach = cap
	return Vector3(base.x + aim.x * reach, 0.0, base.y + aim.y * reach)
