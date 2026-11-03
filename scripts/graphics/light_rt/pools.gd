extends Object

## Live point-light pools (hub face lanterns; the dungeon's torches and crystals share it): a warm core falling off
## to a hard range cap, cut by the source's own wall (behind its face), its eave (above the awning hem) and any
## footprint box between the source and the lit point. Ground and wall shaders evaluate it per 1/82.6 m texel cell,
## so pool edges stay on the sprite-texel grid. Uniforms: GLSL; push with bind() after set_sources() / set_boxes().

const MAX_S := 16
const MAX_B := 24
## Falloff 1 / (1 + (r / SOFT)^2), Lambert on the receiver, windowed to 0 at the range cap.
const SOFT := 0.8
## Hub lantern: range (m), gain, core and rim colour. HOT is the core tint inside CORE of the range.
const LANTERN := {"range": 2.4, "gain": 0.9, "col": Color(1.0, 0.62, 0.3), "hot": Color(1.0, 0.86, 0.62), "core": 0.35}
## Debug plant: every source's facing flipped (light goes behind its wall; the pool check must catch it).
static var plant_flip := false
static var _p := PackedVector4Array()
static var _c := PackedVector4Array()
static var _f := PackedVector4Array()
static var _b := PackedVector4Array()
static var _n := 0
static var _bn := 0
static var last := ""

const GLSL := """
uniform int pool_n = 0;
uniform vec4 pool_p[16]; // source x, y, z, range
uniform vec4 pool_c[16]; // rim colour rgb, gain
uniform vec4 pool_f[16]; // facing x, z (0 = all round), eave y, core share
uniform vec4 pool_hot = vec4(1.0, 0.86, 0.62, 0.0);
uniform int occ_n = 0;
uniform vec4 occ_b[24]; // footprint x0, z0, x1, z1
bool occ_hit(vec2 a, vec2 b) {
	vec2 d = b - a;
	for (int i = 0; i < occ_n; i++) {
		vec4 r = occ_b[i];
		if (a.x > r.x && a.x < r.z && a.y > r.y && a.y < r.w) { continue; }
		vec2 inv = 1.0 / vec2(abs(d.x) < 1e-5 ? 1e-5 : d.x, abs(d.y) < 1e-5 ? 1e-5 : d.y);
		vec2 t0 = (r.xy - a) * inv;
		vec2 t1 = (r.zw - a) * inv;
		vec2 lo = min(t0, t1);
		vec2 hi = max(t0, t1);
		float tin = max(lo.x, lo.y);
		float tout = min(hi.x, hi.y);
		if (tin < tout && tout > 0.0 && tin < 1.0) { return true; }
	}
	return false;
}
// Light at point q with receiver normal nrm; wrap lifts grazing receivers (walls a lamp hangs on).
vec3 pool_light(vec3 q, vec3 nrm, float wrap) {
	vec3 sum = vec3(0.0);
	for (int i = 0; i < pool_n; i++) {
		vec3 l = pool_p[i].xyz;
		float range = pool_p[i].w;
		vec3 d = q - l;
		float r = length(d);
		if (r >= range) { continue; }
		vec4 f = pool_f[i];
		if (dot(f.xy, f.xy) > 0.0 && dot(d.xz, f.xy) < -0.02) { continue; }
		if (q.y > f.z) { continue; }
		if (occ_hit(l.xz, q.xz)) { continue; }
		float x = r / range;
		float win = 1.0 - x * x * x * x;
		float lam = mix(max(dot(nrm, -d / max(r, 1e-4)), 0.0), 1.0, wrap);
		float pk = pool_c[i].a * win * win * lam / (1.0 + r * r / 0.64); // SOFT 0.8
		sum += pk * mix(pool_hot.rgb, pool_c[i].rgb, smoothstep(0.0, max(f.w, 1e-3), x));
	}
	return sum;
}
"""

## Sources: Array of {pos: Vector3, range, gain, col: Color, face: Vector2 (zero = all round), eave: float, core}.
static func set_sources(rows: Array) -> void:
	_p = PackedVector4Array()
	_c = PackedVector4Array()
	_f = PackedVector4Array()
	for row: Dictionary in rows:
		if _p.size() >= MAX_S:
			break
		var pos: Vector3 = row["pos"]
		var col: Color = row["col"]
		var face: Vector2 = row.get("face", Vector2.ZERO)
		if plant_flip:
			face = -face
		_p.append(Vector4(pos.x, pos.y, pos.z, float(row["range"])))
		_c.append(Vector4(col.r, col.g, col.b, float(row["gain"])))
		_f.append(Vector4(face.x, face.y, float(row.get("eave", 1000.0)), float(row.get("core", 0.35))))
	_n = _p.size()
	_p.resize(MAX_S)
	_c.resize(MAX_S)
	_f.resize(MAX_S)

## Occluding footprints (Rect2 in xz).
static func set_boxes(rects: Array) -> void:
	_b = PackedVector4Array()
	for r: Rect2 in rects:
		if _b.size() >= MAX_B:
			break
		_b.append(Vector4(r.position.x, r.position.y, r.end.x, r.end.y))
	_bn = _b.size()
	_b.resize(MAX_B)

## Pushes the pools to one material; false if it has no pool uniforms.
static func bind(m: ShaderMaterial) -> bool:
	if m == null or m.shader == null or not m.shader.code.contains("pool_p"):
		return false
	m.set_shader_parameter("pool_n", _n)
	m.set_shader_parameter("pool_p", _p)
	m.set_shader_parameter("pool_c", _c)
	m.set_shader_parameter("pool_f", _f)
	var hot: Color = LANTERN["hot"]
	m.set_shader_parameter("pool_hot", Vector4(hot.r, hot.g, hot.b, 0.0))
	m.set_shader_parameter("occ_n", _bn)
	m.set_shader_parameter("occ_b", _b)
	return true

static func bind_all(mats: Array) -> int:
	var set := 0
	for m in mats:
		if m is ShaderMaterial and bind(m):
			set += 1
	last = "pools=%d boxes=%d mats=%d" % [_n, _bn, set]
	return set

## CPU twin of GLSL pool_light (same math), for checks.
static func light_at(q: Vector3, nrm: Vector3, wrap: float) -> Color:
	var sum := Color(0, 0, 0)
	for i in _n:
		var l := Vector3(_p[i].x, _p[i].y, _p[i].z)
		var d: Vector3 = q - l
		var r: float = d.length()
		var f: Vector4 = _f[i]
		if r >= _p[i].w or (Vector2(f.x, f.y).length_squared() > 0.0 and Vector2(d.x, d.z).dot(Vector2(f.x, f.y)) < -0.02) or q.y > f.z:
			continue
		if _occ_hit(Vector2(l.x, l.z), Vector2(q.x, q.z)):
			continue
		var x: float = r / _p[i].w
		var win: float = 1.0 - x * x * x * x
		var lam: float = lerpf(maxf(nrm.dot(-d / maxf(r, 1e-4)), 0.0), 1.0, wrap)
		var k: float = _c[i].w * win * win * lam / (1.0 + (r / SOFT) * (r / SOFT))
		var hot: Color = LANTERN["hot"]
		var rim := Color(_c[i].x, _c[i].y, _c[i].z)
		sum += hot.lerp(rim, smoothstep(0.0, maxf(f.w, 1e-3), x)) * k
	return sum

static func _occ_hit(a: Vector2, b: Vector2) -> bool:
	for i in _bn:
		var r := Rect2(_b[i].x, _b[i].y, _b[i].z - _b[i].x, _b[i].w - _b[i].y)
		if r.has_point(a):
			continue
		if Geometry2D.segment_intersects_segment(a, b, r.position, Vector2(r.end.x, r.position.y)) != null \
				or Geometry2D.segment_intersects_segment(a, b, Vector2(r.end.x, r.position.y), r.end) != null \
				or Geometry2D.segment_intersects_segment(a, b, r.end, Vector2(r.position.x, r.end.y)) != null \
				or Geometry2D.segment_intersects_segment(a, b, Vector2(r.position.x, r.end.y), r.position) != null:
			return true
	return false
