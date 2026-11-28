extends Object

## Settings > Gameplay page (character, language, target lock, Bow mode, salvage, delete save). Row helpers live in
## settings_pages.gd.

const ThemeS := preload("res://scripts/ui/theme.gd")
const View := preload("res://scripts/ui/split_menu/split_menu_view.gd")
const Confirm := preload("res://scripts/ui/confirm_dlg.gd")
const LocS := preload("res://scripts/localization/app_loc.gd")
const ItemNames := preload("res://scripts/data/item_names.gd")
const Pages := preload("res://scripts/ui/pause_settings/settings_pages.gd")
const BowMode := preload("res://scripts/world/bow_mode.gd")
const Prompts := preload("res://scripts/input/prompts.gd")

static func page_gameplay(host: Node) -> void:
	var ch: Button = ThemeS.btn(App.tr("settings_pages.character") % App.character_type, func() -> void:
		var nxt: String = "female" if App.character_type == "male" else "male"
		if App.has_method("set_character"):
			App.set_character(nxt)
		else:
			App.character_type = nxt
		App.save_now()
		host.split_build_page("gameplay")
		View.apply_col(host)
		View.focus_col(host)
	)
	View.add_page_btn(host, ch)
	View.add_page_btn(host, ThemeS.btn(App.tr("settings_pages.language").format({"name": LocS.name_of(LocS.current)}), func() -> void:
		LocS.set_locale(LocS.next_locale())
		ItemNames.refresh(App.prog)
		App.save_now()
		host.split_build_page("gameplay")
		View.apply_col(host)
		View.focus_col(host)
	))
	var lock_on: bool = bool(App.get("target_lock_pref"))
	var lock: CheckBox = Pages._check(App.tr("settings_pages.target_lock"), lock_on, func(on: bool) -> void:
		App.target_lock_pref = on
		if App.has_method("save_now"):
			App.save_now()
	)
	Pages._add_check_centered(host, lock)
	_bow_mode(host)
	var salvage_on: bool = bool(App.get("salvage_dupes"))
	var salvage: CheckBox = Pages._check(App.tr("common.salvage_spare_gear"), salvage_on, func(on: bool) -> void:
		App.salvage_dupes = on
		if App.has_method("save_now"):
			App.save_now()
		host.split_build_page("gameplay")
		View.apply_col(host)
		Pages._focus_named(host, App.tr("common.salvage_spare_gear"))
	)
	Pages._add_check_centered(host, salvage)
	if salvage_on:
		var hint: Label = ThemeS.lab(App.tr("settings_pages.break_down_mailed_copies_you"), 16, Color(0.82, 0.76, 0.66))
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		host.info_box.add_child(hint)
		var keep: Label = ThemeS.lab(App.tr("settings_pages.keep_a_copy_when"), 20, ThemeS.INK)
		keep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		keep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		host.info_box.add_child(keep)
		var finish_v: float = clampf(float(App.get("salvage_finish")), 0.5, 1.0)
		Pages._slider(host, App.tr("settings_pages.finish") % finish_v, finish_v, 0.5, 1.0, 0.05, func(v: float) -> void:
			App.salvage_finish = v
			if App.has_method("save_now"):
				App.save_now()
		)
		var fortune_v: float = clampf(float(App.get("salvage_fortune")), 0.75, 1.25)
		Pages._slider(host, App.tr("settings_pages.fortune") % fortune_v, fortune_v, 0.75, 1.25, 0.05, func(v: float) -> void:
			App.salvage_fortune = v
			if App.has_method("save_now"):
				App.save_now()
		)
	var wipe: Button = ThemeS.btn(App.tr("common.delete_save_data"), func() -> void:
		Confirm.open(host.pause, App.tr("common.delete_save_data"), App.tr("settings_pages.wipe_all_save_data_and"), func() -> void:
			App.wipe_save()
			host.pause.close_ui()
			App.go_title()
		, Callable(), "danger")
	, true, "danger")
	View.add_page_btn(host, wipe)

## Bow mode (off by default): the longbow aims on a held {aim} (right stick / mouse steers) and fires on {fire}.
static func _bow_mode(host: Node) -> void:
	var bow: CheckBox = Pages._check(App.tr("page_gameplay.bow_mode"), BowMode.enabled, func(on: bool) -> void:
		BowMode.enabled = on
		if App.has_method("save_now"):
			App.save_now()
		host.split_build_page("gameplay")
		View.apply_col(host)
		Pages._focus_named(host, App.tr("page_gameplay.bow_mode"))
	)
	Pages._add_check_centered(host, bow)
	var key: String = "page_gameplay.bow_mode_off"
	if BowMode.enabled:
		key = "page_gameplay.bow_mode_on_pad" if Prompts.scheme() == "pad" else "page_gameplay.bow_mode_on_kb"
	var hint: Label = ThemeS.lab(Prompts.fmt(App.tr(key)), 16, Color(0.82, 0.76, 0.66))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.info_box.add_child(hint)
