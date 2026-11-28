extends RefCounted

const Facing := preload("res://scripts/world/facing.gd")
const Dbg := preload("res://scripts/app/dbg.gd")
const Frame := preload("res://scripts/world/player/anim_frame.gd")
const Load := preload("res://scripts/world/player/anim_load.gd")
const Loco := preload("res://scripts/world/player/anim_loco.gd")
const LOC_IDLE := 0
const LOC_START := 1
const LOC_LOOP := 2
const LOC_STOP := 3

static func load_sprites(host: Node) -> void:
	Load.load_sprites(host)

static func warmup_texs(host: Node) -> Array:
	var out: Array = []
	if host == null:
		return out
	var seen: Dictionary = {}
	for k in Facing.KEYS:
		_add_tex(out, seen, pose_tex(host, k))
		for tex in clip(host.idle_to_walk, k):
			_add_tex(out, seen, tex)
		for tex in clip(host.walk, k):
			_add_tex(out, seen, tex)
		for tex in clip(host.walk_to_idle, k):
			_add_tex(out, seen, tex)
	return out

static func _add_tex(out: Array, seen: Dictionary, tex: Texture2D) -> void:
	if tex == null:
		return
	var id: int = tex.get_instance_id()
	if seen.has(id):
		return
	seen[id] = true
	out.append(tex)

static func warmup_physics(host: Node) -> void:
	if host == null or not (host is CharacterBody3D):
		return
	var body: CharacterBody3D = host
	var stored: Vector3 = body.velocity
	body.velocity = Vector3(0.12, 0.0, 0.0)
	body.move_and_slide()
	body.velocity = stored
	body.global_position.y = 0.0

static func warmup(host: Node) -> void:
	if host == null:
		return
	if host.body:
		host.body.visible = true
	for k in Facing.KEYS:
		Load.ensure_loco(host, k)
		Load.ensure_attack(host, k)
	for tex in warmup_texs(host):
		apply_tex(host, tex)
	warmup_physics(host)
	var down: Texture2D = pose_tex(host, "down")
	if down:
		apply_tex(host, down)
	host.loc_state = LOC_IDLE
	host.loc_t = 0.0
	host.walk_t = 0.0

static func apply_facing(host: Node, delta: float) -> void:
	Loco.apply_facing(host, delta)

static func pose_tex(host: Node, key: String) -> Texture2D:
	return Frame.pose_tex(host, key)

static func clip(store: Dictionary, key: String) -> Array:
	return Frame.clip(store, key)

static func apply_tex(host: Node, tex: Texture2D) -> void:
	Frame.apply_tex(host, tex)

## Hub warm-up under the loader: draws every loaded still and walk frame (each_tex gets it first), then rests on Down.
static func warm_frames(host: Node, each_tex: Callable) -> void:
	var texs: Array = warmup_texs(host)
	Dbg.lt_note("warmup_texs", str(texs.size()))
	for tex in texs:
		apply_tex(host, tex)
		each_tex.call(tex)
		RenderingServer.force_draw()
	var down: Texture2D = pose_tex(host, "down")
	if down:
		apply_tex(host, down)
	host.loc_state = LOC_IDLE
	host.loc_t = 0.0
	host.walk_t = 0.0
