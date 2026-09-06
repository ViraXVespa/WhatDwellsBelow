extends Object

## HUD refresh. Host is the CanvasLayer at scripts/ui/hud.gd.

const Prompts := preload("res://scripts/input/prompts.gd")
const PromptView := preload("res://scripts/ui/prompt_view.gd")
const Look := preload("res://scripts/input/look_ctrl.gd")
const View := preload("res://scripts/ui/hud_view.gd")


static func refresh(host: CanvasLayer, player: Node, dungeon: Node) -> void:
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
	fill(host.hp_fill, 280.0, hp / maxh)
	host.hp_lab.text = "%d / %d" % [int(hp), int(maxh)]
	var pot: Dictionary = App.prog.slots.get("potion", {})
	var pn := int(pot.get("stack", 0))
	var pcd: float = App.prog.potion_cd
	var pmax: float = maxf(0.05, App.bal.potion_cooldown)
	fill(host.pot_fill, 120.0, 1.0 if pcd <= 0.0 and pn > 0 else 1.0 - clampf(pcd / pmax, 0.0, 1.0))
	if pcd > 0.0:
		host.pot_lab.text = "Potion x%d  %.1fs" % [pn, pcd]
	else:
		host.pot_lab.text = "Potion x%d" % pn
	fill(host.dash_fill, 112.0, dash)
	fill(host.spec_fill, 112.0, spec)
	var clv := App.prog.combat_lv()
	var slv := App.prog.style_lv()
	if slv < clv:
		host.lvl.text = "Level %d (%s %d)" % [clv, style_name(), slv]
	else:
		host.lvl.text = "Level %d" % clv
	host.res.text = "%dg   %d ore   %d wood" % [App.gold, App.ore, App.wood]
	host.floor_lab.text = "F%d" % App.floor_n
	if App.shrine_t > 0.0:
		host.shrine_icon.visible = true
		host.shrine_lab.visible = true
		host.shrine_lab.text = "Shrine +%d%%  %ds" % [int(App.bal.shrine_dmg * 100.0), int(ceil(App.shrine_t))]
	else:
		host.shrine_icon.visible = false
		host.shrine_lab.visible = false
	if App.prog.food_t > 0.0:
		host.food_icon.visible = true
		host.food_lab.visible = true
		host.food_lab.text = "Food HoT  %ds" % int(ceil(App.prog.food_t))
	else:
		host.food_icon.visible = false
		host.food_lab.visible = false
	paint_prompt(host)
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
		host.look_lab.text = "Look  RS zoom map" if Look.mode else "Look  RS pan map"
		return
	host.look_lab.text = "Look  RS zoom / HUD" if Look.mode else ""


static func paint_prompt(host: CanvasLayer) -> void:
	var text := str(App.interact_prompt)
	var scheme: String = Prompts.scheme()
	if text == host._prompt_shown and scheme == host._prompt_scheme:
		return
	host._prompt_shown = text
	host._prompt_scheme = scheme
	if text == "":
		PromptView.fill(host.prompt_row, [])
		return
	var locked := text.begins_with("Locked") or text.begins_with("Already") or text.begins_with("The fire") or text.begins_with("Spent") or text.begins_with("Empty")
	if locked:
		PromptView.fill(host.prompt_row, [{"text": text}], 16, Color(0.95, 0.82, 0.4))
	else:
		PromptView.fill(host.prompt_row, [{"action": "interact", "verb": text}], 16, Color(0.95, 0.82, 0.4))


static func style_name() -> String:
	if App.weapon == "staff":
		return "Magic"
	if App.weapon == "longbow":
		return "Ranged"
	return "Melee"


static func fill(r: ColorRect, w: float, t: float) -> void:
	r.size.x = w * clampf(t, 0.0, 1.0)


static func boss(host: CanvasLayer, dungeon: Node, player: Node) -> void:
	var b: Node = null
	if dungeon:
		var arr := dungeon.get_tree().get_nodes_in_group("boss")
		if arr.size() > 0:
			b = arr[0]
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
	var title := "Guardian"
	if b.get("tag") != null and str(b.tag.text) != "":
		title = str(b.tag.text)
	host.boss_lab.text = "%s  %d / %d" % [title, int(bh), int(bm)]
