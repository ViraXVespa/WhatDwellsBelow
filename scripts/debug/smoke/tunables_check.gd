extends Object

## P1 check (design/tunables.md "Saves and overrides"): saves carry no balance, an old save's `debug_bal` / `bal_rev`
## is ignored and dropped on the migrated rewrite (aim-line prefs kept), and the debug override file round-trips with
## clamping. Uses the smoke slot and a smoke-only override path; restores App.bal and both files.
## Prints "P1: tunables_ok=" and SMOKE FAIL on a miss.

const Store := preload("res://scripts/data/save_store.gd")
const Ov := preload("res://scripts/debug/tunable_overrides.gd")
const Bal := preload("res://scripts/data/balance.gd")

static func run(_host: Node) -> void:
	var bal0: Object = App.bal
	var pri: String = Store.primary_path("smoke")
	var bak: String = Store.backup_path("smoke")
	var pri0: Dictionary = Store.read_payload(pri)
	var bak0: Dictionary = Store.read_payload(bak)
	Store.ensure_dir("smoke")
	Ov.path = Store.dir_for("smoke").path_join("debug_tunables.json")
	Ov.reset()
	var fails: PackedStringArray = []
	var def: Object = Bal.new()
	# Override file: clamped to the schema max, prefs and unknown keys skipped, save() writes only non-defaults.
	App.bal = Bal.new()
	var f := FileAccess.open(Ov.path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"special_mana": 9999.0, "aim_line_on": 0.0, "no_such_key": 1.0}))
	f.close()
	if Ov.apply(App.bal) != 1 or not is_equal_approx(App.bal.special_mana, 100.0) or not App.bal.aim_line_on:
		fails.append("override clamp mana=%s aim=%s" % [App.bal.special_mana, App.bal.aim_line_on])
	App.bal.dash_cooldown = def.dash_cooldown + 0.5
	App.bal.aim_line_opacity = 0.11
	var n: int = Ov.save(App.bal)
	var b2: Object = Bal.new()
	Ov.apply(b2)
	if n != 2 or not is_equal_approx(b2.dash_cooldown, def.dash_cooldown + 0.5) or not is_equal_approx(b2.special_mana, 100.0) or is_equal_approx(b2.aim_line_opacity, 0.11):
		fails.append("override round-trip n=%d" % n)
	Ov.reset()
	if FileAccess.file_exists(Ov.path):
		fails.append("override reset")
	# Old save: bad debug_bal values and bal_rev are ignored, defaults win, the rewrite drops them, prefs stay.
	App.bal = Bal.new()
	var data: Dictionary = Store.collect()
	var keep_on: bool = not bool(data.get("aim_line_on", true))
	data["debug_bal"] = {"special_mana": -50.0, "move_speed": "junk", "dash_cooldown": 99.0}
	data["bal_rev"] = 3
	data["aim_line_on"] = keep_on
	data["aim_line_opacity"] = 0.37
	Store.write_payload(pri, data)
	Store.write_payload(bak, data)
	Store.load_slot("smoke")
	var re: Dictionary = Store.read_payload(pri)
	if not is_equal_approx(App.bal.special_mana, def.special_mana) or not is_equal_approx(App.bal.dash_cooldown, def.dash_cooldown):
		fails.append("old save applied debug_bal mana=%s" % App.bal.special_mana)
	if re.has("debug_bal") or re.has("bal_rev") or re.is_empty():
		fails.append("rewrite kept debug_bal/bal_rev")
	if bool(re.get("aim_line_on", not keep_on)) != keep_on or not is_equal_approx(float(re.get("aim_line_opacity", 0.0)), 0.37):
		fails.append("aim prefs lost")
	# Restore: the live state, the smoke slot files and the real override path.
	App.bal = bal0
	Store.apply(Store.collect())
	for pair: Array in [[pri, pri0], [bak, bak0]]:
		if (pair[1] as Dictionary).is_empty():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(str(pair[0])))
		else:
			Store.write_payload(str(pair[0]), pair[1])
	Ov.path = Ov.PATH
	printerr("P1: tunables " + ("; ".join(fails) if fails.size() else "override+old_save+prefs"))
	printerr("P1: tunables_ok=" + str(fails.is_empty()))
	if fails.size():
		printerr("SMOKE FAIL: tunables/save rework (tunables_check.gd): " + "; ".join(fails))
