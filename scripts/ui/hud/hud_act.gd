extends Object

## Sample dynamic HUD values; repaint individual elements only when their inputs change.

const Prompts := preload("res://scripts/input/prompts.gd")
const PromptView := preload("res://scripts/ui/prompt_view.gd")
const Look := preload("res://scripts/input/look_ctrl.gd")
const View := preload("res://scripts/ui/hud/hud_view.gd")
const Threat := preload("res://scripts/combat/threat.gd")
const Cells := preload("res://scripts/world/dungeon/dungeon_cells.gd")

static func refresh(host: CanvasLayer, player: Node, dungeon: Node) -> void:
	var lay_key: Vector3 = Vector3(App.hud_scale * View.UiText.play_scale(), host.get_viewport().get_visible_rect().size.x, host.get_viewport().get_visible_rect().size.y)
	if lay_key != host._lay_key:
		host._lay_key = lay_key
		View.layout(host)
		host._state.clear()
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
		else:
			spec = 1.0 - clampf(float(player.get("special_cd")) / maxf(0.05, App.bal.special_recovery), 0.0, 1.0)
	var inner: float = View.BAR_INSET * 2.0
	fill(host.hp_fill, host.HP_W - inner, hp / maxh)
	var mana_now: float = float(App.prog.mana)
	var mana_cap: float = maxf(1.0, App.prog.mana_max())
	fill(host.mana_fill, host.MANA_W - inner, mana_now / mana_cap)
	var atk_now: int = 0
	if player:
		atk_now = int(player.get("atk_state"))
	if atk_now == 0:
		spec = minf(spec, mana_now / maxf(1.0, float(App.bal.special_mana)))
	var pot: Dictionary = App.prog.slots.get("potion", {})
	var pn := int(pot.get("stack", 0))
	var pcd: float = App.prog.potion_cd
	var pmax: float = maxf(0.05, App.bal.potion_cooldown)
	fill(host.pot_fill, host.POT_W - inner, 1.0 if pcd <= 0.0 and pn > 0 else 1.0 - clampf(pcd / pmax, 0.0, 1.0))
	if changed(host, "potion", [pn, snappedf(pcd, 0.1), pcd > 0.0, TranslationServer.get_locale()]):
		paint_potion(host, pn, pcd)
	fill(host.dash_fill, host.DASH_W - inner, dash)
	fill(host.spec_fill, host.SPEC_W - inner, spec)
	var clv := App.prog.combat_lv()
	var slv := App.prog.style_lv()
	var locale: String = TranslationServer.get_locale()
	if changed(host, "hp", [int(hp), int(maxh), locale]):
		host.hp_lab.text = App.tr("hud_act.text") % [int(hp), int(maxh)]
	if changed(host, "mana", [int(mana_now), int(mana_cap), locale]):
		host.mana_lab.text = App.tr("hud_act.text") % [int(mana_now), int(mana_cap)]
	if changed(host, "level", [clv, slv, App.weapon, locale]):
		host.lvl.text = App.tr("hud_act.level") % [clv, style_name(), slv] if slv < clv else App.tr("hud_act.level_2") % clv
	if changed(host, "resources", [App.gold, App.ore, App.wood, locale]):
		host.res.text = App.tr("hud_act.g_ore_wood") % [App.gold, App.ore, App.wood]
	if changed(host, "floor", [App.floor_n, locale]):
		host.floor_lab.text = App.tr("hud_act.f") % App.floor_n
	if changed(host, "shrine", [ceili(App.shrine_t), App.bal.shrine_dmg, locale]):
		host.shrine_icon.visible = App.shrine_t > 0.0
		host.shrine_lab.visible = App.shrine_t > 0.0
		if App.shrine_t > 0.0:
			host.shrine_lab.text = App.tr("hud_act.shrine_s") % [int(App.bal.shrine_dmg * 100.0), ceili(App.shrine_t)]
	if changed(host, "food", [ceili(App.prog.food_t), locale]):
		host.food_icon.visible = App.prog.food_t > 0.0
		host.food_lab.visible = App.prog.food_t > 0.0
		if App.prog.food_t > 0.0:
			host.food_lab.text = App.tr("hud_act.food_hot_s") % ceili(App.prog.food_t)
	paint_prompt(host)
	paint_gem(host, dungeon)
	paint_look(host)
	var toast: String = App.toast_msg if App.toast_t > 0.0 else ""
	if changed(host, "toast", toast):
		host.toast.text = toast
	boss(host, dungeon, player)
	if host.fps_lab and host.fps_lab.text != "":
		host.fps_lab.text = ""

## Snapshots reconcile direct resource/dictionary writes as well as setters. No scene walk.
static func changed(host: CanvasLayer, key: String, value: Variant) -> bool:
	if host._state.get(key) == value:
		return false
	host._state[key] = value
	return true

static func paint_potion(host: CanvasLayer, count: int, cooldown: float) -> void:
	host.pot_lab.text = App.tr("hud_act.potion_x_s") % [count, cooldown] if cooldown > 0.0 else App.tr("hud_act.potion_x") % count

static func paint_look(host: CanvasLayer) -> void:
	if not changed(host, "look", [Look.blocked(), Look.map_open(), Look.mode, TranslationServer.get_locale()]):
		return
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
	if not changed(host, "prompt", [text, scheme, App.interact_locked, View.UiText.frame_scale(), View.UiText.applied(), TranslationServer.get_locale()]):
		return
	host.prompt_row.set_meta("prompt_tap", false)
	if text == "":
		PromptView.fill(host.prompt_row, [])
		return
	# The strip already scales by play_scale(); keep the row's own font at its pre-DPR size (16 x frame_scale()).
	var px: int = maxi(1, int(round(16.0 * View.UiText.frame_scale() / maxf(View.UiText.applied(), 0.001))))
	if App.interact_locked:
		PromptView.fill(host.prompt_row, [{"text": text}], px, View.STRIP_INK)
	else:
		PromptView.fill(host.prompt_row, [{"action": "interact", "verb": text}], px, View.STRIP_INK)

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
		if host.gem.has_meta("pulse_tween"):
			var tw: Tween = host.gem.get_meta("pulse_tween")
			if tw:
				tw.kill()
			host.gem.set_meta("pulse_tween", null)
		return
	var col: Color = gem_color(dungeon)
	var alpha: float = host.gem.modulate.a
	if host.gem.modulate.r != col.r or host.gem.modulate.g != col.g or host.gem.modulate.b != col.b:
		host.gem.modulate = Color(col.r, col.g, col.b, alpha)
	if not host.gem.has_meta("pulse_tween") or host.gem.get_meta("pulse_tween") == null:
		var tw: Tween = host.gem.create_tween().set_loops()
		tw.tween_property(host.gem, "modulate:a", 0.44, 0.6).set_trans(Tween.TRANS_SINE)
		tw.tween_property(host.gem, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
		host.gem.set_meta("pulse_tween", tw)
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
	var width: float = w * clampf(t, 0.0, 1.0)
	if r.size.x != width:
		r.size.x = width

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
	if changed(host, "boss", [title, int(bh), int(bm), TranslationServer.get_locale()]):
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
