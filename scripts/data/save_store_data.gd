extends RefCounted

## Collect / apply / fresh-delver save payload.

const Rules := preload("res://scripts/data/gear_rules.gd")


static func apply(data: Dictionary) -> bool:
	var migrated := false
	App.character_type = str(data.get("character_type", "male"))
	App.character_chosen = bool(data.get("character_chosen", false))
	App.cam_zoom = float(data.get("cam_zoom", 1.75))
	App.hud_scale = float(data.get("hud_scale", 1.0))
	App.ui_text_floor = float(data.get("ui_text_floor", 14.0))
	App.vol_master = float(data.get("vol_master", 1.0))
	App.vol_music = float(data.get("vol_music", 0.7))
	App.vol_sfx = float(data.get("vol_sfx", 0.85))
	App.sprite_filter = int(data.get("sprite_filter", 2))
	App.sprite_mip_sharp = bool(data.get("sprite_mip_sharp", false))
	App.sprite_mip_bias = float(data.get("sprite_mip_bias", 0.0))
	App.display_mode = display_mode(str(data.get("display_mode", "borderless")))
	App.display_fs_kind = fs_kind(str(data.get("display_fs_kind", "borderless")))
	App.web_fullscreen = bool(data.get("web_fullscreen", false))
	App.bal.aim_line_on = bool(data.get("aim_line_on", true))
	App.bal.aim_line_opacity = float(data.get("aim_line_opacity", 0.85))
	App.target_lock_pref = bool(data.get("target_lock_pref", false))
	App.salvage_dupes = bool(data.get("salvage_dupes", false))
	App.salvage_finish = clampf(float(data.get("salvage_finish", 0.8)), 0.5, 1.0)
	App.salvage_fortune = clampf(float(data.get("salvage_fortune", 1.0)), 0.75, 1.25)
	App.bank_gold = int(data.get("bank_gold", 0))
	App.bank_ore = int(data.get("bank_ore", 0))
	App.bank_wood = int(data.get("bank_wood", 0))
	App.bank_root = int(data.get("bank_root", 0))
	App.last_seen_game_ver = str(data.get("last_seen_game_ver", ""))
	var db: Variant = data.get("debug_bal", {})
	if db is Dictionary:
		for k in (db as Dictionary).keys():
			App.bal.setv(str(k), float((db as Dictionary)[k]))
	var old_rev := int(data.get("bal_rev", 0))
	if App.bal.has_method("migrate_from") and App.bal.migrate_from(old_rev):
		migrated = true
	var p: Variant = data.get("prog", {})
	if p is Dictionary:
		App.prog.from_meta(p)
	Rules.normalize_prog(App.prog)
	if not App.character_chosen and (App.bank_gold > 0 or App.bank_ore > 0 or App.prog.deepest > 1):
		App.character_chosen = true
	var binds: Variant = data.get("binds", [])
	if binds is Array and (binds as Array).size() > 0:
		App.apply_binds(binds)
	App.set_volume("master", App.vol_master)
	App.set_volume("music", App.vol_music)
	App.set_volume("sfx", App.vol_sfx)
	if App.has_method("set_zoom"):
		App.set_zoom(App.cam_zoom)
	if App.has_method("set_hud_scale"):
		App.set_hud_scale(App.hud_scale)
	if App.has_method("set_ui_text_floor"):
		App.set_ui_text_floor(App.ui_text_floor)
	if App.has_method("set_sprite_filter"):
		App.set_sprite_filter(App.sprite_filter, true)
	if App.has_method("set_sprite_mip_sharp"):
		App.set_sprite_mip_sharp(App.sprite_mip_sharp)
	if App.has_method("set_sprite_mip_bias"):
		App.set_sprite_mip_bias(App.sprite_mip_bias)
	return migrated

static func display_mode(raw: String) -> String:
	if raw == "windowed" or raw == "exclusive":
		return raw
	return "borderless"

static func fs_kind(raw: String) -> String:
	if raw == "exclusive":
		return raw
	return "borderless"

static func fresh_delver() -> void:
	App.prog.reset_meta()
	Rules.normalize_prog(App.prog)
	App.bank_gold = 0
	App.bank_ore = 0
	App.bank_wood = 0
	App.bank_root = 0
	App.bal = (load("res://scripts/data/balance.gd") as GDScript).new()
	App.character_type = "male"
	App.character_chosen = false
	App.last_seen_game_ver = ""
	App.cam_zoom = 1.75
	App.hud_scale = 1.0
	App.ui_text_floor = 14.0
	App.vol_master = 1.0
	App.vol_music = 0.7
	App.vol_sfx = 0.85
	App.sprite_filter = 2
	App.sprite_mip_sharp = false
	App.sprite_mip_bias = 0.0
	App.display_mode = "borderless"
	App.display_fs_kind = "borderless"
	App.web_fullscreen = false
	App.target_lock_pref = false
	App.salvage_dupes = false
	App.salvage_finish = 0.8
	App.salvage_fortune = 1.0
	App.bal.aim_line_on = true
	App.bal.aim_line_opacity = 0.85
	App.reset_binds()
	App.set_volume("master", App.vol_master)
	App.set_volume("music", App.vol_music)
	App.set_volume("sfx", App.vol_sfx)
	if App.has_method("set_zoom"):
		App.set_zoom(App.cam_zoom)
	if App.has_method("set_hud_scale"):
		App.set_hud_scale(App.hud_scale)
	if App.has_method("set_ui_text_floor"):
		App.set_ui_text_floor(App.ui_text_floor)
	if App.has_method("set_sprite_filter"):
		App.set_sprite_filter(App.sprite_filter, true)
