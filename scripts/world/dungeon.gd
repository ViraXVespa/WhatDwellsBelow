extends Node3D

const T := preload("res://scripts/data/tunables.gd")
const HudS := preload("res://scripts/ui/hud.gd")
const DungeonStream := preload("res://scripts/world/dungeon_stream.gd")
const DungeonProps := preload("res://scripts/world/dungeon_props.gd")
const DungeonGeo := preload("res://scripts/world/dungeon_geo.gd")
const DungeonCells := preload("res://scripts/world/dungeon_cells.gd")
const DungeonPack := preload("res://scripts/world/dungeon_pack.gd")
const DungeonBoot := preload("res://scripts/world/dungeon_boot.gd")
const MapAct := preload("res://scripts/world/dungeon_map_act.gd")

var data: Dictionary = {}
var player: CharacterBody3D
var door: Node
var doors: Array = []
var stairs: Node
var visited: PackedByteArray
var fog_dirty := true
var floor_mm: MultiMeshInstance3D
var hint: Label
var prompt: Label
var fps_lab: Label
var hud: CanvasLayer
var map_layer: CanvasLayer
var map_img: Image
var map_tex: ImageTexture
var map_rect: TextureRect
var frame_acc := 0.0
var frame_n := 0
var walls: StaticBody3D
var _cleared := false
var groups: Dictionary = {}
var next_group := 1
var flee_used := 0
var types_present: PackedStringArray = PackedStringArray()
var idle_t := 0.0
var noreveal_t := 0.0
var pressure_cd_t := 0.0
var last_named := ""
var floor_rng := RandomNumberGenerator.new()
var ui: CanvasLayer
var toast_lab: Label
var shrine_lab: Label
var counts: Dictionary = {}
var occupied: Dictionary = {}
const PROP_GAP := 2
const SPAWN_CLEAR := 16
var spawn_jobs: Array = []
var stream_t := 0.0
var stream_all := false
var travel_dist: PackedInt32Array = PackedInt32Array()
var travel_cap := 1
var geo_jobs: Array = []
var geo_root: Node3D
var floor_mat: Material
var wall_mat: Material


func _ready() -> void:
	DungeonBoot.ready_floor(self)


func _process(delta: float) -> void:
	DungeonBoot.process_floor(self, delta)


func _world() -> void:
	DungeonGeo.world(self)


func _collision_walls() -> void:
	DungeonGeo.collision_walls(self)


func _build_visuals() -> void:
	DungeonGeo.build_visuals(self)


func _build_travel() -> void:
	DungeonGeo.build_travel(self)


func enemy_combat_lv(pos: Vector3) -> int:
	return DungeonGeo.enemy_combat_lv(self, pos)


func _spawns() -> void:
	DungeonBoot.spawns(self)


func _place_doors() -> void:
	DungeonBoot.place_doors(self)


func _on_boss_dead() -> void:
	DungeonBoot.on_boss_dead(self)


func _reveal_around(c: Vector2i, rad: int) -> bool:
	return DungeonGeo.reveal_around(self, c, rad)


func _hud() -> void:
	hud = HudS.new()
	add_child(hud)
	App.interact_prompt = ""
	hint = null
	prompt = null
	fps_lab = null
	toast_lab = null
	shrine_lab = null


func _refresh_hint() -> void:
	if hud and hud.has_method("refresh"):
		hud.refresh(player, self)
	if hud and hud.has_method("bind_map") and map_tex:
		hud.bind_map(map_tex)


func _map() -> void:
	DungeonGeo.make_map(self)


func _redraw_map() -> void:
	DungeonGeo.redraw_map(self)
	if map_layer and map_layer.visible:
		MapAct.apply(self)


func _note_verge() -> void:
	if stairs and not bool(stairs.get("locked")):
		App.saw_stairs = true
	for b: Node in get_tree().get_nodes_in_group("boss"):
		if b == null or not is_instance_valid(b):
			continue
		if b.has_method("is_alive") and not b.is_alive():
			continue
		var hp: float = float(b.get("hp"))
		var mx: float = maxf(1.0, float(b.get("max_hp")))
		if hp / mx <= 0.3:
			App.boss_low = true


func _player_cell() -> Vector2i:
	return DungeonCells.player_cell(self)


func _cell_manhattan(a: Vector2i, b: Vector2i) -> int:
	return DungeonCells.cell_manhattan(a, b)


func _near_spawn(c: Vector2i, rad: int = SPAWN_CLEAR) -> bool:
	return DungeonCells.near_spawn(self, c, rad)


func _away_room() -> Dictionary:
	return DungeonCells.away_room(self)


func _stream_force_all() -> void:
	DungeonStream.force_all(self)


func _spawn_room(r: Dictionary, pool: PackedStringArray) -> void:
	DungeonStream.activate_room(self, r, pool)


func _maybe_named(pool: PackedStringArray) -> void:
	DungeonStream.queue_named(self, pool)


func _combat_room() -> Dictionary:
	return DungeonCells.combat_room(self)


func _add_enemy(id: String, pos: Vector3, gid: int, named: bool, nname: String) -> Node:
	return DungeonPack.add_enemy(self, id, pos, gid, named, nname)


func _ensure_pool(pool: PackedStringArray) -> void:
	DungeonStream.queue_pool(self, pool)


func _rand_cell(r: Dictionary) -> Vector2i:
	return DungeonCells.rand_cell(self, r)


func _cell_pos(c: Vector2i) -> Vector3:
	return DungeonCells.cell_pos(c)


func _world_cell(p: Vector3) -> Vector2i:
	return DungeonCells.world_cell(p)


func _mark_cell(c: Vector2i) -> void:
	DungeonCells.mark_cell(self, c)


func _cell_clear(c: Vector2i, gap: int = PROP_GAP) -> bool:
	return DungeonCells.cell_clear(self, c, gap)


func _free_cell(r: Dictionary, gap: int = PROP_GAP) -> Vector2i:
	return DungeonCells.free_cell(self, r, gap)


func _free_cell_world(prefer: Dictionary, gap: int = PROP_GAP) -> Vector2i:
	return DungeonCells.free_cell_world(self, prefer, gap)


func _free_near(center: Vector2i, gap: int = PROP_GAP) -> Vector2i:
	return DungeonCells.free_near(self, center, gap)


func _seed_occupied() -> void:
	DungeonCells.seed_occupied(self)


func _is_floor_cell(c: Vector2i) -> bool:
	return DungeonCells.is_floor_cell(self, c)


func _is_safe_cell(c: Vector2i) -> bool:
	return DungeonCells.is_safe_cell(self, c)


func is_safe_world(p: Vector3) -> bool:
	return DungeonCells.is_safe_world(self, p)


func note_enemy_hit(e: Node, dmg: float) -> void:
	DungeonPack.note_enemy_hit(self, e, dmg)


func _trigger_flee(gid: int) -> Node:
	return DungeonPack.trigger_flee(self, gid)


func spawn_reinforcement(id: String, from: Vector3, gid: int) -> Node:
	return DungeonPack.spawn_reinforcement(self, id, from, gid)


func _walkable_near(center: Vector2i, radius: int, allow_safe: bool) -> Vector2i:
	return DungeonCells.walkable_near(self, center, radius, allow_safe)


func _tick_pressure(delta: float, grew: bool) -> void:
	DungeonPack.tick_pressure(self, delta, grew)


func _find_kind_room(kind: String) -> Dictionary:
	return DungeonCells.find_kind_room(self, kind)


func world_ui() -> Node:
	return ui


func _note(k: String) -> void:
	counts[k] = int(counts.get(k, 0)) + 1


func _center_room(r: Dictionary) -> Vector2i:
	return DungeonCells.center_room(r)


func _tick_plates() -> void:
	if player == null:
		return
	for n: Node in get_tree().get_nodes_in_group("plates"):
		if n == null or not is_instance_valid(n) or not n.has_method("plate_held"):
			continue
		var d: float = Vector2(n.global_position.x - player.global_position.x, n.global_position.z - player.global_position.z).length()
		n.plate_held(d < 0.7)
