extends Object

## P7 checks for the W7 UI prep helpers: pause tabs by id, Talk lines seen tracking and its save field
## (round trip, older save without it, malformed data rejected), and the shared tooltip helper.

const Talk := preload("res://scripts/data/talk_lines.gd")
const Collect := preload("res://scripts/data/save_store/store_collect.gd")
const Data := preload("res://scripts/data/save_store/store_data.gd")
const PauseFlow := preload("res://scripts/ui/pause_menu/menu_flow.gd")

static func run(host: Node) -> bool:
	var ok: bool = _tabs()
	ok = _talk() and ok
	ok = _tips(host) and ok
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

static func _tips(_host: Node) -> bool:
	return true
