extends Object

## HUD refresh. Host is the CanvasLayer at scripts/ui/hud.gd.

const Prompts := preload("res://scripts/input/prompts.gd")
const PromptView := preload("res://scripts/ui/prompt_view.gd")
const Look := preload("res://scripts/input/look_ctrl.gd")
const View := preload("res://scripts/ui/hud/hud_view.gd")
const Threat := preload("res://scripts/combat/threat.gd")
const Cells := preload("res://scripts/world/dungeon/dungeon_cells.gd")

static func refresh(host: CanvasLayer, player: Node, dungeon: Node) -> void:
	var text_sc: float = App.ui_text_applied() if App.has_method("ui_text_applied") else 1.0
	var lay_key := Vector3(App.hud_scale * text_sc, host.get_viewport().get_visible_rect().size.x, 0.0)
	if lay_key != host._lay_key:
		host._lay_key = lay_key
		View.layout(host)
	View.load_portrait(host)
	var hp := 1.0
	var maxh := 1.0
	var dash := 0.0
	var spec := 0.0
	if player:
		hp = float(player.get("hp"))
		maxh = maxf(1.0, float(player.get("max_hp")))
		var dcd := float(player.get("dash_cd"))
		dash = 1.0 - clampf(dcd / maxf(0.05, App.bal.dash_cooldown), 0.0, 1.0)
		var atk := int(player.get("atk_state"))
		if atk == 2 or atk == 3:
			spec = 0.0
		elif atk == 4:
			spec = clampf(float(player.get("atk_t")) / maxf(0.05, App.bal.special_recovery), 0.0, 1.0)
		else:
			spec = 1.0
	var inner: float = View.BAR_INSET * 2.0
	fill(host.hp_fill, host.HP_W - inner, hp / maxh)
	var mana_now: float = float(App.prog.mana)
	var mana_cap: float = maxf(1.0, App.prog.mana_max())
	fill(host.mana_fill, host.MANA_W - inner, mana_now / mana_cap)
	var atk_now: int = 0
	if player:
		atk_now = int(player.get("atk_state"))
	if atk_now == 0:
		spec = minf(1.0, mana_now / maxf(1.0, float(App.bal.special_mana)))
	var pot: Dictionary = App.prog.slots.get("potion", {})
	var pn := int(pot.get("stack", 0))
	var pcd: float = App.prog.potion_cd
	var pmax: float = maxf(0.05, App.bal.potion_cooldown)
	fill(host.pot_fill, host.POT_W - inner, 1.0 if pcd <= 0.0 and pn > 0 else 1.0 - clampf(pcd / pmax, 0.0, 1.0))
	if pcd > 0.0:
		host.pot_lab.text = App.tr("hud_act.potion_x_s") % [pn, pcd]
	else:
		host.pot_lab.text = App.tr("hud_act.potion_x") % pn
	fill(host.dash_fill, host.DASH_W - inner, dash)
	fill(host.spec_fill, host.SPEC_W - inner, spec)
	var clv := App.prog.combat_lv()
	var slv := App.prog.style_lv()
	var txt_key: Array = [int(hp), int(maxh), int(mana_now), int(mana_cap), clv, slv, App.weapon, App.gold, App.ore, App.wood, App.floor_n, TranslationServer.get_locale()]
	if txt_key != host._txt_key:
		host._txt_key = txt_key
		host.hp_lab.text = App.tr("hud_act.text") % [int(hp), int(maxh)]
		host.mana_lab.text = App.tr("hud_act.text") % [int(mana_now), int(mana_cap)]
		if slv < clv:
			host.lvl.text = App.tr("hud_act.level") % [clv, style_name(), slv]
		else:
			host.lvl.text = App.tr("hud_act.level_2") % clv
		host.res.text = App.tr("hud_act.g_ore_wood") % [App.gold, App.ore, App.wood]
		host.floor_lab.text = App.tr("hud_act.f") % App.floor_n
	if App.shrine_t > 0.0:
		host.shrine_icon.visible = true
		host.shrine_lab.visible = true
		host.shrine_lab.text = App.tr("hud_act.shrine_s") % [int(App.bal.shrine_dmg * 100.0), int(ceil(App.shrine_t))]
	else:
		host.shrine_icon.visible = false
		host.shrine_lab.visible = false
	if App.prog.food_t > 0.0:
		host.food_icon.visible = true
		host.food_lab.visible = true
		host.food_lab.text = App.tr("hud_act.food_hot_s") % int(ceil(App.prog.food_t))
	else:
		host.food_icon.visible = false
		host.food_lab.visible = false
	paint_prompt(host)
	paint_gem(host, dungeon)
	paint_look(host)
	host.toast.text = App.toast_msg if App.toast_t > 0.0 else ""
	boss(host, dungeon, player)
	if host.fps_lab:
		host.fps_lab.text = ""

static func paint_look(host: CanvasLayer) -> void:
	if host.look_lab == null:
		return
	if Look.blocked():
		host.look_lab.text = ""
		return
	if Look.map_open():
		host.look_lab.text = App.tr("hud_act.look_rs_zoom_map") if Look.mode else App.tr("hud_act.look_rs_pan_map")
		return
	host.look_lab.text = App.tr("hud_act.look_rs_zoom_hud") if Look.mode else ""

static func paint_prompt(host: CanvasLayer) -> void:
	var text := str(App.interact_prompt)
	var scheme: String = Prompts.scheme()
	if text == host._prompt_shown and scheme == host._prompt_scheme:
		return
	host._prompt_shown = text
	host._prompt_scheme = scheme
	host.prompt_row.set_meta("prompt_tap", false)
	if text == "":
		PromptView.fill(host.prompt_row, [])
		return
	var locked: bool = App.interact_locked
	if locked:
		PromptView.fill(host.prompt_row, [{"text": text}], 16, View.STRIP_INK)
	else:
		PromptView.fill(host.prompt_row, [{"action": "interact", "verb": text}], 16, View.STRIP_INK)

static func style_name() -> String:
	if App.weapon == "staff":
		return App.tr("hud_act.style_magic")
	if App.weapon == "longbow":
		return App.tr("hud_act.style_ranged")
	return App.tr("hud_act.style_melee")

static func paint_gem(host: CanvasLayer, dungeon: Node) -> void:
	if host.gem == null:
		return
	var show_gem: bool = bool(App.get("danger_gem"))
	host.gem.visible = show_gem
	if not show_gem:
		return
	var col: Color = gem_color(dungeon)
	var pulse: float = 0.72 + 0.28 * sin(float(Time.get_ticks_msec()) * 0.005)
	host.gem.modulate = Color(col.r, col.g, col.b, pulse)

static func gem_color(dungeon: Node) -> Color:
	var green := Color(0.28, 0.86, 0.38)
	var yellow := Color(0.95, 0.82, 0.22)
	var red := Color(0.92, 0.22, 0.18)
	var clv: int = App.prog.combat_lv()
	var threat: int = clv
	if dungeon != null and dungeon.get("data") != null and dungeon.get("travel_dist") != null:
		var cell: Vector2i = Cells.player_cell(dungeon)
		var dist: PackedInt32Array = dungeon.travel_dist
		var grid_w: int = int(dungeon.data.w)
		var cap: int = int(dungeon.travel_cap)
		threat = Threat.walk_level(App.floor_n, cell, dist, grid_w, cap)
	var diff: int = threat - clv
	if diff <= 0:
		return green
	if diff >= 7:
		return red
	if diff < 3:
		return green.lerp(yellow, float(diff) / 3.0)
	return yellow.lerp(red, float(diff - 3) / 4.0)

static func fill(r: ColorRect, w: float, t: float) -> void:
	r.size.x = w * clampf(t, 0.0, 1.0)

static func boss(host: CanvasLayer, dungeon: Node, player: Node) -> void:
	var b: Node = _boss_node(host, dungeon)
	if b == null or not is_instance_valid(b) or (b.has_method("is_alive") and not b.is_alive()):
		host.boss_wrap.visible = false
		return
	var dist := 99.0
	if player and b is Node3D:
		dist = Vector2((b as Node3D).global_position.x - player.global_position.x, (b as Node3D).global_position.z - player.global_position.z).length()
	if dist > 14.0:
		host.boss_wrap.visible = false
		return
	host.boss_wrap.visible = true
	var bh := float(b.get("hp"))
	var bm := maxf(1.0, float(b.get("max_hp")))
	fill(host.boss_fill, 360.0, bh / bm)
	var title := App.tr("hud_act.guardian")
	if b.get("tag") != null and str(b.tag.text) != "":
		title = str(b.tag.text)
	host.boss_lab.text = App.tr("hud_act.text_2") % [title, int(bh), int(bm)]

## First "boss" group node, re-fetched only when the group size changes or the cached node is gone.
static func _boss_node(host: CanvasLayer, dungeon: Node) -> Node:
	if dungeon == null:
		return null
	var n: int = dungeon.get_tree().get_node_count_in_group("boss")
	var b: Variant = host._boss
	if n != host._boss_n or (b != null and not is_instance_valid(b)):
		host._boss_n = n
		var arr := dungeon.get_tree().get_nodes_in_group("boss")
		host._boss = arr[0] if arr.size() > 0 else null
	return host._boss
