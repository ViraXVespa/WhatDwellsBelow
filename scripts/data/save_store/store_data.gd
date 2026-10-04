extends RefCounted

## Collect / apply / fresh-delver save payload.

const LocS := preload("res://scripts/app/app_loc.gd")
const Norm := preload("res://scripts/data/gear_rules/rules_norm.gd")

## One home for pref/bank defaults: apply() fallbacks, fresh_delver() and App's initial vars all read these.
const DEF := {
	"character_type": "male",
	"character_chosen": false,
	"last_seen_game_ver": "",
	"cam_zoom": 1.75,
	"hud_scale": 1.0,
	"vol_master": 1.0,
	"vol_music": 0.7,
	"vol_sfx": 0.85,
	"sprite_filter": 2,
	"sprite_mip_sharp": false,
	"sprite_mip_bias": 0.0,
	"display_mode": "borderless",
	"display_fs_kind": "borderless",
	"web_fullscreen": false,
	"aim_line_on": true,
	"aim_line_opacity": 0.85,
	"target_lock_pref": false,
	"salvage_dupes": false,
	"salvage_finish": 0.8,
	"salvage_fortune": 1.0,
	"bank_gold": 0,
	"bank_ore": 0,
	"bank_wood": 0,
	"bank_root": 0,
}

static func apply(data: Dictionary) -> bool:
	var migrated: bool = false
	App.character_type = str(data.get("character_type", DEF.character_type))
	App.character_chosen = bool(data.get("character_chosen", DEF.character_chosen))
	App.cam_zoom = float(data.get("cam_zoom", DEF.cam_zoom))
	App.hud_scale = float(data.get("hud_scale", DEF.hud_scale))
	App.ui_text_floor = float(data.get("ui_text_floor", App.T.UI_TEXT_FLOOR))
	App.vol_master = float(data.get("vol_master", DEF.vol_master))
	App.vol_music = float(data.get("vol_music", DEF.vol_music))
	App.vol_sfx = float(data.get("vol_sfx", DEF.vol_sfx))
	App.sprite_filter = int(data.get("sprite_filter", DEF.sprite_filter))
	App.sprite_mip_sharp = bool(data.get("sprite_mip_sharp", DEF.sprite_mip_sharp))
	App.sprite_mip_bias = float(data.get("sprite_mip_bias", DEF.sprite_mip_bias))
	App.display_mode = display_mode(str(data.get("display_mode", DEF.display_mode)))
	App.display_fs_kind = fs_kind(str(data.get("display_fs_kind", DEF.display_fs_kind)))
	App.web_fullscreen = bool(data.get("web_fullscreen", DEF.web_fullscreen))
	App.bal.aim_line_on = bool(data.get("aim_line_on", DEF.aim_line_on))
	App.bal.aim_line_opacity = float(data.get("aim_line_opacity", DEF.aim_line_opacity))
	App.target_lock_pref = bool(data.get("target_lock_pref", DEF.target_lock_pref))
	App.salvage_dupes = bool(data.get("salvage_dupes", DEF.salvage_dupes))
	App.salvage_finish = clampf(float(data.get("salvage_finish", DEF.salvage_finish)), 0.5, 1.0)
	App.salvage_fortune = clampf(float(data.get("salvage_fortune", DEF.salvage_fortune)), 0.75, 1.25)
	App.bank_gold = int(data.get("bank_gold", DEF.bank_gold))
	App.bank_ore = int(data.get("bank_ore", DEF.bank_ore))
	App.bank_wood = int(data.get("bank_wood", DEF.bank_wood))
	App.bank_root = int(data.get("bank_root", DEF.bank_root))
	App.last_seen_game_ver = str(data.get("last_seen_game_ver", DEF.last_seen_game_ver))
	LocS.apply_saved(str(data.get("locale", "")))
	var db: Variant = data.get("debug_bal", {})
	if db is Dictionary:
		for k in (db as Dictionary).keys():
			App.bal.setv(str(k), float((db as Dictionary)[k]))
	var old_rev: int = int(data.get("bal_rev", 0))
	if App.bal.has_method("migrate_from") and App.bal.migrate_from(old_rev):
		migrated = true
	var p: Variant = data.get("prog", {})
	if p is Dictionary:
		App.prog.from_meta(p)
	Norm.normalize_prog(App.prog)
	if not App.character_chosen and (App.bank_gold > 0 or App.bank_ore > 0 or App.prog.deepest > 1):
		App.character_chosen = true
	var binds: Variant = data.get("binds", [])
	if binds is Array and (binds as Array).size() > 0:
		App.apply_binds(binds)
	_apply_prefs()
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
	Norm.normalize_prog(App.prog)
	App.bank_gold = DEF.bank_gold
	App.bank_ore = DEF.bank_ore
	App.bank_wood = DEF.bank_wood
	App.bank_root = DEF.bank_root
	App.bal = (load("res://scripts/data/balance.gd") as GDScript).new()
	App.character_type = DEF.character_type
	App.character_chosen = DEF.character_chosen
	App.last_seen_game_ver = DEF.last_seen_game_ver
	App.cam_zoom = DEF.cam_zoom
	App.hud_scale = DEF.hud_scale
	App.ui_text_floor = App.T.UI_TEXT_FLOOR
	App.vol_master = DEF.vol_master
	App.vol_music = DEF.vol_music
	App.vol_sfx = DEF.vol_sfx
	App.sprite_filter = DEF.sprite_filter
	App.sprite_mip_sharp = DEF.sprite_mip_sharp
	App.sprite_mip_bias = DEF.sprite_mip_bias
	App.display_mode = DEF.display_mode
	App.display_fs_kind = DEF.display_fs_kind
	App.web_fullscreen = DEF.web_fullscreen
	App.target_lock_pref = DEF.target_lock_pref
	App.salvage_dupes = DEF.salvage_dupes
	App.salvage_finish = DEF.salvage_finish
	App.salvage_fortune = DEF.salvage_fortune
	App.bal.aim_line_on = DEF.aim_line_on
	App.bal.aim_line_opacity = DEF.aim_line_opacity
	App.reset_binds()
	_apply_prefs()

static func _apply_prefs() -> void:
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
