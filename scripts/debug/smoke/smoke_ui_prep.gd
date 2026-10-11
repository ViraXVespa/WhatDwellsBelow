extends Object

## P7 checks for the W7 UI prep helpers: pause tabs by id, Talk lines seen tracking and its save field
## (round trip, older save without it, malformed data rejected), and the shared tooltip helper.

const Talk := preload("res://scripts/data/talk_lines.gd")
const Collect := preload("res://scripts/data/save_store/store_collect.gd")
const Data := preload("res://scripts/data/save_store/store_data.gd")
const PauseFlow := preload("res://scripts/ui/pause_menu/menu_flow.gd")
const PauseSkills := preload("res://scripts/ui/pause_skills.gd")
const TipHover := preload("res://scripts/ui/tip_hover.gd")
const ThemeS := preload("res://scripts/ui/theme.gd")
const ItemBoard := preload("res://scripts/ui/item_board.gd")
const Icons := preload("res://scripts/ui/gear_icons.gd")
const _TipHost := preload("res://scripts/debug/smoke/tip_host.gd")

static func run(host: Node) -> bool:
	var ok: bool = _tabs()
	ok = _talk() and ok
	ok = _tips(host) and ok
	ok = _board() and ok
	printerr("P7: ui_prep_ok=" + str(ok))
	assert(ok, "ui prep checks failed (see P7: lines above)")
	return ok

static func _say(name: String, good: bool, detail: String = "") -> bool:
	printerr("P7: " + name + "=" + str(good) + ("" if detail == "" else " " + detail))
	return good

static func _tabs() -> bool:
	var pm: CanvasLayer = App.pause_menu
	var ids: Array = []
	for t: Array in pm.TABS:
		ids.append(str(t[0]))
	var good: bool = true
	for id: String in ids:
		pm.show_tab(id)
		good = good and pm.tab == id and PauseFlow.tab_index(pm, id) == ids.find(id)
	pm.show_tab(ids[0])
	var walk: Array = []
	for i: int in ids.size():
		pm._cycle_tab(1)
		walk.append(pm.tab)
	var back: Array = []
	for i: int in ids.size():
		pm._cycle_tab(-1)
		back.append(pm.tab)
	var want: Array = ids.slice(1) + [ids[0]]
	var want_back: Array = ids.duplicate()
	want_back.reverse()
	pm.close_ui()
	return _say("tab_ids", good and walk == want and back == want_back, str(walk) + " " + str(back))

static func _talk() -> bool:
	var keys: Array = ["t.a", "t.b", "t.c"]
	var keep_seen: Dictionary = Talk.seen.duplicate(true)
	var keep_cur: Dictionary = Talk.cur.duplicate()
	Talk.register("smoke_npc", keys)
	Talk.reset()
	var first: Array = []
	for i: int in 3:
		Talk.on_hub_entry()
		first.append(Talk.current("smoke_npc"))
	var cycle_ok: bool = first.size() == 3 and keys.all(func(k): return first.has(k))
	Talk.on_hub_entry()
	var restart_ok: bool = Talk.current("smoke_npc") != first[2] and (Talk.seen["smoke_npc"] as Array).size() == 1
	var good: bool = _say("talk_seen", cycle_ok and restart_ok, str(first) + " then " + Talk.current("smoke_npc"))
	var save: Dictionary = Collect.collect()
	var want: Dictionary = Talk.to_save()
	Talk.reset()
	Data.apply(save)
	good = _say("talk_save_round_trip", Talk.to_save() == want and save.has("talk")) and good
	save.erase("talk")
	Data.apply(save)
	good = _say("talk_old_save", Talk.seen.is_empty() and Talk.cur.is_empty()) and good
	var bad: Array = [[], {"v": 1}, {"v": 2, "seen": {}, "cur": {}}, {"v": 1, "seen": {"a": "x"}, "cur": {}}, {"v": 1, "seen": {}, "cur": {"a": 3}}]
	var rejects: bool = Talk.check(want) == ""
	for b: Variant in bad:
		rejects = rejects and Talk.check(b) != ""
	good = _say("talk_bad_rejected", rejects) and good
	Talk.extra.erase("smoke_npc")
	Talk.seen = keep_seen
	Talk.cur = keep_cur
	return good

## Shared tooltip: the pause Skills tab shows its first skill tip on open (same text as before), hides on blur,
## and place_below keeps the recap placement (below, flipped above near the bottom, clamped at the sides).
static func _tips(_host: Node) -> bool:
	var pm: CanvasLayer = App.pause_menu
	pm.show_tab(pm.TAB_SKILLS)
	var shown: bool = pm.tip_host != null and pm.tip_host.visible and pm.tip_id != ""
	var text_ok: bool = shown and pm.tip_lab.text == ThemeS.skill_tip(pm.tip_id, PauseSkills.tip_lv(pm, pm.tip_id, pm.tip_kind))
	pm.get_viewport().gui_release_focus()
	pm._blur_tip()
	var hidden: bool = not pm.tip_host.visible and pm.tip_id == ""
	pm.close_ui()
	var host := CanvasLayer.new()
	host.set_script(_TipHost)
	var anchor := Control.new()
	host.add_child(anchor)
	host.tip_host = PanelContainer.new()
	host.add_child(host.tip_host)
	App.add_child(host)
	var place: Array = []
	for at: Vector2 in [Vector2(100, 100), Vector2(1800, 1000), Vector2(0, 500)]:
		anchor.position = at
		anchor.size = Vector2(200, 30)
		TipHover.place_below(host, anchor, 404.0, 120.0)
		place.append(host.tip_host.position)
	host.free()
	var want: Array = [Vector2(100, 138), Vector2(1496, 872), Vector2(20, 538)]
	return _say("tip_shared", shown and text_ok and hidden and place == want, str(place))

## Item board: one cell per row with the row's icon, press calls on_pick with the row, bad rows are rejected.
static func _board() -> bool:
	var it: Dictionary = App.prog.make_weapon("great_axe", "common")
	var tex: Texture2D = Icons.tex_for_item(it)
	var picked: Array = []
	var rows: Array = [
		{"id": "a", "tex": tex, "name": "Axe", "price": "5g", "on_pick": func(r): picked.append(r["id"])},
		{"id": "b", "tex": tex, "name": "Axe 2", "on_pick": func(r): picked.append(r["id"])},
	]
	var parent := Control.new()
	var grid: GridContainer = ItemBoard.build(parent, null, rows, 2)
	var btn: Button = grid.get_child(1).get_child(0) as Button
	btn.pressed.emit()
	var good: bool = tex != null and grid.get_child_count() == 2 and btn.icon == tex and picked == ["b"]
	good = good and ItemBoard.check([{"id": "x"}]) != "" and ItemBoard.check([{"tex": tex}]) != "" and ItemBoard.check(rows) == ""
	parent.free()
	return _say("item_board", good)
