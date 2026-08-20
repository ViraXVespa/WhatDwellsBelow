extends StaticBody3D

const SkillMath := preload("res://scripts/data/skills.gd")
const V3 := preload("res://scripts/view3d/v3.gd")

var kind := "sign"
var prompt := "Interact"
var tex_path := ""
var title := ""
var body := ""
var clerk_kind := "gather"
var clerk_id := "miner"
var spent_normal := false
var spent_gold := false
var locked := false
var remaining := 4
var used := false
var opened := false
var flipped := false
var lever_id := 0
var spr: Sprite3D
var rng := RandomNumberGenerator.new()
var _layer: CanvasLayer
var _built := false


func configure(p_kind: String, p_tex := "", extra: Dictionary = {}) -> void:
	kind = p_kind
	tex_path = p_tex
	title = str(extra.get("title", ""))
	body = str(extra.get("body", ""))
	clerk_kind = str(extra.get("clerk_kind", clerk_kind))
	clerk_id = str(extra.get("clerk_id", clerk_id))
	locked = bool(extra.get("locked", false))
	lever_id = int(extra.get("lever_id", 0))
	if title != "":
		prompt = title


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	add_to_group("interactable")
	rng.randomize()
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	match kind:
		"town_crystal":
			prompt = "Enter the dungeon"
			_spr_from(tex_path if tex_path != "" else V3.a("props", "crystal.png"), 1.35, true)
			V3.add_box(self, Vector3(0.85, 0.45, 0.45), Vector3(0, 0.22, 0.2))
		"receptionist":
			prompt = "Talk: Guild clerk"
			_spr_from(V3.a("npcs", "receptionist.png"), 1.1, true)
			V3.add_cyl(self, 0.18, 0.5, Vector3(0, 0.25, 0))
		"sign":
			prompt = title if title != "" else "Sign"
			_spr_from(tex_path if tex_path != "" else V3.a("props", "sign.png"), 0.95 if tex_path.ends_with("dumpster.png") else 0.85, true)
			if tex_path.ends_with("dumpster.png"):
				V3.add_box(self, Vector3(1.2, 0.8, 0.75), Vector3(0, 0.4, 0))
			else:
				V3.add_box(self, Vector3(0.44, 0.7, 0.28), Vector3(0, 0.35, 0))
		"vendor":
			prompt = "Talk: Stallkeep"
			process_mode = Node.PROCESS_MODE_ALWAYS
			_spr_from(V3.a("npcs", "vendor.png"), 1.05, true)
			V3.add_cyl(self, 0.2, 0.5, Vector3(0, 0.25, 0.1))
		"anvil":
			prompt = "Anvil"
			_spr_from(V3.a("props", "anvil.png"), 0.7, true)
			V3.add_box(self, Vector3(1.1, 0.55, 0.65), Vector3(0, 0.28, 0.15))
		"clerk":
			prompt = display_name()
			var path := V3.a("npcs", "%s.png" % clerk_id)
			_spr_from(path, 1.1, true)
			V3.add_cyl(self, 0.2, 0.55, Vector3(0, 0.28, 0))
		"stairs":
			prompt = "That's as deep as this expedition maps" if locked else "Descend stairs"
			_spr_from(V3.a("props", "stairs.png"), 1.0, true)
			V3.add_box(self, Vector3(0.7, 0.2, 0.7), Vector3(0, 0.1, 0))
		"floor_crystal":
			prompt = "Floor crystal"
			process_mode = Node.PROCESS_MODE_ALWAYS
			_spr_from(V3.a("props", "crystal.png"), 1.2, true)
			V3.add_box(self, Vector3(0.55, 0.4, 0.55), Vector3(0, 0.2, 0))
		"mining":
			prompt = "Mine ore"
			remaining = rng.randi_range(3, 5)
			_spr_from(V3.a("props", "ore.png"), 0.75, true)
			V3.add_box(self, Vector3(0.8, 0.7, 0.8), Vector3(0, 0.35, 0))
		"loot_stash":
			prompt = "Search stash"
			_spr_from(V3.a("props", "chest.png"), 0.75, true)
			V3.add_box(self, Vector3(0.7, 0.5, 0.55), Vector3(0, 0.25, 0))
		"campfire":
			prompt = "Warm up"
			_spr_from(V3.a("props", "campfire.png"), 0.7, true)
			V3.add_cyl(self, 0.28, 0.3, Vector3(0, 0.15, 0))
		"shrine":
			prompt = "Touch shrine"
			_spr_from("", 0.9, true, Art.solid(Vector2i(22, 40), Color(0.78, 0.58, 0.18)))
			V3.add_box(self, Vector3(0.4, 0.7, 0.4), Vector3(0, 0.35, 0))
		"ghost_shop":
			prompt = "Talk: shopkeep (safe)"
			_spr_from(V3.a("npcs", "shopkeep.png"), 1.1, true)
			if spr:
				spr.modulate = Color(0.75, 0.9, 1.0, 0.92)
			V3.add_cyl(self, 0.25, 0.6, Vector3(0, 0.3, 0))
		"artifact_chest":
			prompt = "Open chest"
			_spr_from(V3.a("props", "chest.png"), 0.8, true)
			if spr:
				spr.modulate = Color(0.95, 0.78, 0.35)
			V3.add_box(self, Vector3(0.7, 0.5, 0.55), Vector3(0, 0.25, 0))
		"lever":
			prompt = "Pull lever"
			_spr_from("", 0.7, true, Art.solid(Vector2i(18, 40), Color(0.62, 0.5, 0.28)))
			V3.add_box(self, Vector3(0.28, 0.6, 0.28), Vector3(0, 0.3, 0))
		_:
			prompt = "Interact"
			V3.add_cyl(self, 0.2, 0.5, Vector3(0, 0.25, 0))


func _spr_from(path: String, h: float, billboard: bool, fallback: Texture2D = null) -> void:
	var tex := Art.load_tex(path) if path != "" else fallback
	if tex == null:
		tex = fallback if fallback else Art.solid(Vector2i(40, 48), Color(0.55, 0.45, 0.3))
	spr = V3.sprite(tex, h, billboard)
	add_child(spr)


func display_name() -> String:
	match clerk_id:
		"miner":
			return "Miner"
		"lumberjack":
			return "Lumberjack"
		"alchemist":
			return "Alchemist"
		"stonemason":
			return "Stonemason"
		"fishmonger":
			return "Fishmonger"
		"gopher":
			return "Gear Gopher"
		"runner":
			return "Guild Runner"
		"patty":
			return "Packmule Patty"
		_:
			return "Clerk"


func family_accepted() -> String:
	match clerk_id:
		"miner":
			return "ore"
		"lumberjack":
			return "wood"
		"alchemist":
			return "plants"
		"stonemason":
			return "stone"
		"fishmonger":
			return "fish"
		_:
			return ""


func get_prompt() -> String:
	match kind:
		"clerk":
			if spent_gold:
				return "%s (done)" % display_name()
			return "Talk: %s" % display_name()
		"stairs":
			if _guardian_up():
				return "The guardian blocks the stairs"
			if locked:
				return "That's as deep as this expedition maps"
			return "Descend stairs"
		"floor_crystal":
			if Game.run == null:
				return "Crystal"
			if Game.save == null or Game.save.deepest_floor <= Game.run.current_floor:
				return "Crystal (no deeper memory)"
			return "Crystal: skip deeper"
		"mining":
			if remaining <= 0:
				return "Depleted vein"
			return "Mine ore (%d)" % remaining
		"loot_stash":
			return "Empty stash" if opened else "Search stash"
		"campfire":
			return "Embers (spent)" if used else "Campfire — sit a second"
		"shrine":
			return "Quiet shrine" if used else "Shrine — a little courage"
		"ghost_shop":
			return "Talk: shopkeep (safe)"
		"artifact_chest":
			return "Empty chest" if opened else "Open chest"
		"lever":
			return "Lever (flipped)" if flipped else "Pull lever"
		_:
			return prompt


func interact(player: Node) -> void:
	match kind:
		"town_crystal":
			var uis := get_tree().get_nodes_in_group("loadout_ui")
			if uis.is_empty():
				Game.begin_run({"weapon": ItemData.make_starter_axe(), "tool": ItemData.make_starter_pickaxe()}, 1)
				return
			uis[0].open()
		"receptionist":
			var copy := "Welcome to Placeholdia, pop. whoever showed up. Real city's still in permitting. Crystal's open. Dying's a workplace hazard — pack snacks."
			if Game.save and not Game.save.has_dived:
				copy = "First time? Eh, I'm sure you'll be able to figure it out.\n\n" + copy
			_long_toast(copy)
		"sign":
			_long_toast(body)
		"vendor":
			if _layer:
				return
			_open_vendor()
		"anvil":
			var uis := get_tree().get_nodes_in_group("anvil_ui")
			if not uis.is_empty():
				uis[0].open()
		"clerk":
			if spent_gold:
				return
			var uis := get_tree().get_nodes_in_group("extract_ui")
			if uis.is_empty():
				return
			uis[0].open_for(self)
		"stairs":
			if _guardian_up() or locked:
				return
			Game.next_floor()
		"floor_crystal":
			_crystal_skip()
		"mining":
			_begin_mine(player)
		"loot_stash":
			_open_stash()
		"campfire":
			if used or Game.run == null:
				return
			used = true
			Game.heal_player(28.0)
			Sfx.play("pickup")
			if spr:
				spr.modulate = Color(0.5, 0.5, 0.52)
			prompt = "Embers (spent)"
		"shrine":
			if used or Game.run == null:
				return
			used = true
			Game.run.shrine_buff_t = 45.0
			Sfx.play("level")
			if spr:
				spr.modulate = Color(0.55, 0.55, 0.58)
			prompt = "Quiet shrine"
			Game.toast("Something in the stone likes your odds.", Color(0.95, 0.82, 0.4))
		"ghost_shop":
			var uis := get_tree().get_nodes_in_group("shop_ui")
			if not uis.is_empty():
				uis[0].open()
		"artifact_chest":
			_open_art()
		"lever":
			if flipped:
				return
			flipped = true
			if spr:
				spr.modulate = Color(0.85, 0.75, 0.4)
			prompt = "Lever (flipped)"
			Sfx.play("ui")
			for g in get_tree().get_nodes_in_group("gates"):
				if g.has_method("open_gate") and int(g.get("gate_id")) == lever_id:
					g.open_gate()


func _guardian_up() -> bool:
	return not get_tree().get_nodes_in_group("boss").is_empty()


func _begin_mine(player: Node) -> void:
	if remaining <= 0:
		return
	if Game.run == null or Game.run.tool == null or Game.run.tool.family != "pickaxe":
		Game.toast("Need a pickaxe equipped.", Color(0.9, 0.75, 0.5))
		return
	if player.has_method("start_channel"):
		player.start_channel(self, channel_time(player))


func can_channel() -> bool:
	return remaining > 0


func channel_time(_player: Node) -> float:
	var mult := 1.0
	if Game.run and Game.run.tool:
		mult = Game.run.tool.gather_mult
	var art := 1.0
	if Game.run:
		art = Game.run.mine_mult
	return maxf(0.55, 1.85 / maxf(0.5, mult) / SkillMath.mine_speed_mult(Game.skill_level("mining")) / art)


func complete_channel(player: Node) -> void:
	if remaining <= 0:
		return
	var amt := rng.randi_range(1, 2)
	if Game.run and Game.run.lucky_mine and rng.randf() < 0.22:
		amt += 1
	var ore := ItemData.make_ore(amt)
	if not Game.give_or_drop(ore, V3.xz(global_position)):
		if player.has_method("interrupt_channel"):
			player.interrupt_channel()
	remaining -= 1
	Sfx.play("mine")
	Game.grant_xp("mining", 12.0 * float(amt))
	if remaining <= 0:
		if spr:
			spr.modulate = Color(0.45, 0.45, 0.48)
		prompt = "Depleted vein"


func _open_stash() -> void:
	if opened:
		return
	opened = true
	prompt = "Empty stash"
	if spr:
		spr.modulate = Color(0.45, 0.45, 0.48)
	var bits: PackedStringArray = []
	var gold_amt := rng.randi_range(10, 32)
	Game.add_run_gold(gold_amt)
	bits.append("%dg" % gold_amt)
	var at := V3.xz(global_position)
	if rng.randf() < 0.55:
		var ore := rng.randi_range(1, 4)
		var ore_it := ItemData.make_ore(ore)
		if Game.give_or_drop(ore_it, at):
			bits.append("%d ore" % ore)
		else:
			bits.append("ore (on the floor)")
	if rng.randf() < 0.38:
		var gear := LootGen.roll_any(rng)
		if Game.give_or_drop(gear, at):
			bits.append(gear.full_name())
		else:
			bits.append("gear (on the floor)")
	Game.toast("Stash: " + ", ".join(bits), Color(1.0, 0.86, 0.35))


func _open_art() -> void:
	if opened or Game.run == null:
		return
	opened = true
	prompt = "Empty chest"
	if spr:
		spr.modulate = Color(0.5, 0.5, 0.52)
	var art_s = load("res://scripts/data/artifacts.gd")
	var art: Dictionary = art_s.pick(rng, Game.run.artifact_ids)
	var gold_amt := rng.randi_range(8, 22)
	Game.add_run_gold(gold_amt)
	if Game.give_artifact(str(art.id)):
		Game.toast("%s  (+%dg)" % [str(art.get("name", "Relic")), gold_amt], Color(0.92, 0.78, 0.45))
	else:
		Game.toast("Coin, and a relic you already carry. (+%dg)" % gold_amt, Color(0.92, 0.78, 0.45))


func _crystal_skip() -> void:
	if Game.run == null or Game.save == null:
		return
	var dests: Array = []
	for f in range(Game.run.current_floor + 1, Game.save.deepest_floor + 1):
		dests.append(f)
	if dests.is_empty():
		return
	if dests.size() == 1:
		Game.enter_floor(int(dests[0]))
		return
	_open_picker(dests)


func _unhandled_input(event: InputEvent) -> void:
	if _layer == null:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		_close_layer()
		get_viewport().set_input_as_handled()


func _open_picker(dests: Array) -> void:
	if _layer:
		return
	var layer := CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_to_group("wdb_modal")
	get_tree().paused = true
	var panel := Panel.new()
	panel.position = Vector2(660, 220)
	panel.size = Vector2(600, 520)
	layer.add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 24
	v.offset_top = 20
	v.offset_right = -24
	v.offset_bottom = -20
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var lab := Label.new()
	lab.text = "Skip down. You've walked these before."
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.add_theme_font_size_override("font_size", 20)
	v.add_child(lab)
	for f in dests:
		var fl := int(f)
		var b := Button.new()
		b.text = "Floor %d" % fl
		b.custom_minimum_size = Vector2(0, 48)
		b.pressed.connect(func():
			_close_layer()
			Game.enter_floor(fl)
		)
		v.add_child(b)
	var c := Button.new()
	c.text = "Stay"
	c.custom_minimum_size = Vector2(0, 48)
	c.pressed.connect(_close_layer)
	v.add_child(c)
	PadUi.wire(panel)
	_layer = layer
	get_tree().root.add_child(layer)
	PadUi.focus_first(panel)


func _open_vendor() -> void:
	var layer := CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	var panel := Panel.new()
	panel.position = Vector2(640, 260)
	panel.size = Vector2(640, 360)
	layer.add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 12)
	v.offset_left = 24
	v.offset_top = 24
	v.offset_right = -24
	v.offset_bottom = -24
	panel.add_child(v)
	Sfx.play("ui")
	var lab := Label.new()
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.text = _vendor_copy()
	lab.add_theme_font_size_override("font_size", 20)
	v.add_child(lab)
	v.add_child(_btn("Buy ration (5g) — next bag", func():
		if Game.save.gold < 5:
			lab.text = "I'm flattered. Your purse isn't."
			return
		if Game.save.extra_food >= 20:
			lab.text = "Twenty rations is a picnic, not a dive. Eat some first."
			return
		Game.save.gold -= 5
		Game.save.extra_food += 1
		Game.save.write()
		lab.text = _vendor_copy() + "\nRation's on the next dive. Don't skip breakfast in a hole."
	))
	v.add_child(_btn("Buy potion (15g) — next bag", func():
		if Game.save.gold < 15:
			lab.text = "Potions are 15. That's not a negotiation, that's arithmetic."
			return
		Game.save.gold -= 15
		Game.save.extra_potion += 1
		Game.save.write()
		lab.text = _vendor_copy() + "\nRed bottle. For when the job gets opinionated."
	))
	v.add_child(_btn("Sell 5 ore (10g)", func():
		if Game.save.banked_ore < 5:
			lab.text = "Bring me five rocks that used to be a wall. Then we talk."
			return
		Game.save.banked_ore -= 5
		Game.save.gold += 10
		Game.save.write()
		lab.text = _vendor_copy() + "\nUgly ore. Pretty coins. Everybody wins."
	))
	v.add_child(_btn("Close", _close_layer))
	PadUi.wire(panel)
	_layer = layer
	layer.add_to_group("wdb_modal")
	get_tree().root.add_child(layer)
	PadUi.focus_first(panel)


func _close_layer() -> void:
	get_tree().paused = false
	if _layer:
		_layer.queue_free()
		_layer = null


func _vendor_copy() -> String:
	return "Placeholdia stall. Gold %d. Banked ore %d.\nPacked for the next dive: %d/20 rations, %d potions in the sack.\nRations 5g. Potions 15g. I'll take 5 ore for 10g." % [
		Game.save.gold if Game.save else 0,
		Game.save.banked_ore if Game.save else 0,
		Game.save.extra_food if Game.save else 0,
		Game.save.extra_potion if Game.save else 0,
	]


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 48)
	b.pressed.connect(cb)
	return b


func _long_toast(text: String) -> void:
	for c in get_tree().root.get_children():
		if c.name == "ToastLayer":
			c.queue_free()
	var layer := CanvasLayer.new()
	layer.name = "ToastLayer"
	layer.layer = 80
	var lab := Label.new()
	lab.text = text
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.position = Vector2(480, 80)
	lab.size = Vector2(960, 100)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 22)
	lab.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
	lab.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08))
	lab.add_theme_constant_override("outline_size", 6)
	layer.add_child(lab)
	get_tree().root.add_child(layer)
	get_tree().create_timer(3.6).timeout.connect(layer.queue_free)
