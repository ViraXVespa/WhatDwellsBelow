extends Object

## Campaign series: no acting-time end, floor-5 clears, vendor buy, crystal enter one floor below deepest.

const Store := preload("res://scripts/data/save_store.gd")
const PlaytestDb := preload("res://scripts/debug/playtest_db.gd")
const PlaytestHub := preload("res://scripts/debug/playtest_hub/forge_pass.gd")
const Cons := preload("res://scripts/data/progress_gear/consumable.gd")
const Shop := preload("res://scripts/ui/progress_ui/shop.gd")
const Board := preload("res://scripts/ui/gear_board.gd")

const WEAPONS: PackedStringArray = ["great_axe", "staff", "longbow"]
const CLEAR_LEAF := "floor5.json"
const DEFAULT_DIR := "user://playtest/campaign"

static func ignores_limit(slot_name: String) -> bool:
	return slot_name == "campaign"

static func dive_floor() -> int:
	return maxi(1, int(App.prog.deepest) - 1)

static func floor_cleared(floor_n: int, boss_dead: bool) -> bool:
	if floor_n > 5:
		return true
	return floor_n == 5 and boss_dead

static func read_cleared(dir_path: String = "") -> Array[String]:
	var out: Array[String] = []
	var path: String = _clear_path(dir_path)
	if not FileAccess.file_exists(path):
		return out
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return out
	var raw: Variant = (parsed as Dictionary).get("weapons", [])
	if not (raw is Array):
		return out
	for one: Variant in raw:
		var id: String = str(one)
		if WEAPONS.has(id) and not out.has(id):
			out.append(id)
	return out

static func mark(wpn: String, dir_path: String = "") -> void:
	if not WEAPONS.has(wpn):
		return
	var have: Array[String] = read_cleared(dir_path)
	if have.has(wpn):
		return
	have.append(wpn)
	_write_cleared(have, dir_path)

static func reset(dir_path: String = "") -> void:
	var path: String = _clear_path(dir_path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

static func next_weapon(dir_path: String = "") -> String:
	var done: Array[String] = read_cleared(dir_path)
	if done.size() >= WEAPONS.size():
		return ""
	var picked: String = PlaytestDb.pick_weapon(PlaytestDb.owned_levels(), "")
	if picked != "" and not done.has(picked):
		return picked
	for wpn: String in WEAPONS:
		if not done.has(wpn):
			return wpn
	return ""

static func buy_supplies() -> Dictionary:
	var pots: int = 0
	var foods: int = 0
	var pot_cost: int = int(App.bal.vendor_potion_cost)
	var food_cost: int = int(App.bal.vendor_food_cost)
	var guard: int = 0
	while guard < 12 and App.bank_gold >= pot_cost:
		guard += 1
		var it: Dictionary = Cons.roll_potion(App.prog)
		if not Cons.hold_potion(App.prog, it):
			break
		App.bank_gold -= pot_cost
		Shop.shop_spend(pot_cost)
		pots += 1
	var rows: Array = Cons.food_rows(App.prog)
	for raw: Variant in rows:
		if App.bank_gold < food_cost:
			break
		if not (raw is Dictionary):
			continue
		var row: Dictionary = raw
		var fid: String = str(row.get("food", ""))
		var mode: String = str(row.get("mode", "new"))
		if fid == "" or (mode == "new" and Cons.needs_toss(App.prog, fid)):
			continue
		if not Cons.give_food(App.prog, fid, 1):
			continue
		App.bank_gold -= food_cost
		Shop.shop_spend(food_cost)
		foods += 1
	return {"potions": pots, "foods": foods}

static func hub_ready(pt: Node) -> bool:
	if not bool(pt.get("campaign_enter")) or App.in_dungeon:
		return false
	var scene: Node = pt.get_tree().current_scene
	if scene == null or not scene.has_method("ensure_ui"):
		return false
	return scene.get("build_done") == true

static func hub_enter(pt: Node) -> void:
	pt.campaign_enter = false
	var job: Dictionary = pt.job
	if not bool(job.get("hub_forged", false)):
		var uid: int = PlaytestHub.run_hub()
		if uid > 0:
			PlaytestHub.equip_pending(uid)
			var sim: GDScript = load("res://scripts/debug/playtest/sim.gd") as GDScript
			sim.call("_wear_campaign_weapon")
		job["hub_forged"] = true
		pt.job = job
	buy_supplies()
	enter_from_crystal(str(job.get("weapon", "great_axe")), str(job.get("tool", "pickaxe")))

static func enter_from_crystal(wpn: String, tool: String) -> void:
	var tool_id: String = tool
	if tool_id == "":
		tool_id = "pickaxe"
	App.prog.tool_type = tool_id
	App.prog.pick_weapon = wpn
	App.prog.start_floor = dive_floor()
	App.weapon = wpn
	Board.pending_kit.clear()
	for s: String in App.prog.SLOTS:
		var it: Dictionary = App.prog.slots.get(s, {})
		if it is Dictionary and not it.is_empty():
			Board.pending_kit[s] = it.duplicate(true)
	# After the floor write, before the deferred enter, so the slot matches the dive.
	Store.save_slot("campaign")
	# Deferred, same as the perf sweep: a bare call from the playtest tick
	# stops at the first await inside the enter cover.
	App.call_deferred("enter_dungeon")

static func _clear_path(dir_path: String) -> String:
	var dir: String = dir_path if dir_path != "" else DEFAULT_DIR
	return dir.path_join(CLEAR_LEAF)

static func _write_cleared(have: Array[String], dir_path: String) -> void:
	var dir: String = dir_path if dir_path != "" else DEFAULT_DIR
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var handle: FileAccess = FileAccess.open(_clear_path(dir_path), FileAccess.WRITE)
	if handle == null:
		return
	handle.store_string(JSON.stringify({"weapons": have}))
	handle.close()
