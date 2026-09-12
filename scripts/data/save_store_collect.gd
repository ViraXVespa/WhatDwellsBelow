extends RefCounted

## Build the save JSON dictionary.


static func collect() -> Dictionary:
	return {
		"v": 1,
		"bal_rev": App.bal.BAL_REV,
		"character_type": App.character_type,
		"character_chosen": App.character_chosen,
		"cam_zoom": App.cam_zoom,
		"hud_scale": App.hud_scale,
		"ui_text_floor": App.ui_text_floor,
		"vol_master": App.vol_master,
		"vol_music": App.vol_music,
		"vol_sfx": App.vol_sfx,
		"sprite_filter": App.sprite_filter,
		"sprite_mip_sharp": App.sprite_mip_sharp,
		"sprite_mip_bias": App.sprite_mip_bias,
		"display_mode": App.display_mode,
		"display_fs_kind": App.display_fs_kind,
		"web_fullscreen": App.web_fullscreen,
		"aim_line_on": App.bal.aim_line_on,
		"aim_line_opacity": App.bal.aim_line_opacity,
		"target_lock_pref": bool(App.get("target_lock_pref")),
		"salvage_dupes": bool(App.get("salvage_dupes")),
		"salvage_finish": float(App.get("salvage_finish")),
		"salvage_fortune": float(App.get("salvage_fortune")),
		"bank_gold": App.bank_gold,
		"bank_ore": App.bank_ore,
		"bank_wood": App.bank_wood,
		"bank_root": App.bank_root,
		"last_seen_game_ver": App.last_seen_game_ver,
		"binds": App.collect_binds(),
		"debug_bal": App.bal.snapshot(),
		"prog": App.prog.to_meta(),
	}
