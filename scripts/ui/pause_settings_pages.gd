extends Object

const ThemeS := preload("res://scripts/ui/theme.gd")
const T := preload("res://scripts/data/tunables.gd")
const View := preload("res://scripts/ui/split_menu_view.gd")
const Confirm := preload("res://scripts/ui/confirm_dlg.gd")
const SpriteFilt := preload("res://scripts/world/sprite_filter.gd")
const Disp := preload("res://scripts/display_mode.gd")


static func page_gameplay(host: Node) -> void:
	var ch: Button = ThemeS.btn("Character: %s" % App.character_type, func() -> void:
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
	var lock_on: bool = bool(App.get("target_lock_pref"))
	var lock: CheckBox = _check("Target lock", lock_on, func(on: bool) -> void:
		App.target_lock_pref = on
		if App.has_method("save_now"):
			App.save_now()
	)
	_add_check_centered(host, lock)
	var wipe: Button = ThemeS.btn("Delete Save Data", func() -> void:
		Confirm.open(host.pause, "Delete Save Data", "Wipe all save data and return to the title screen?", func() -> void:
			App.wipe_save()
			host.pause.close_ui()
			App.go_title()
		)
	)
	View.add_page_btn(host, wipe)


static func page_audio(host: Node) -> void:
	_slider(host, "Master volume", float(App.vol_master), 0.0, 1.0, 0.01, func(v: float) -> void: App.set_volume("master", v))
	_slider(host, "Music volume", float(App.vol_music), 0.0, 1.0, 0.01, func(v: float) -> void: App.set_volume("music", v))
	_slider(host, "SFX volume", float(App.vol_sfx), 0.0, 1.0, 0.01, func(v: float) -> void: App.set_volume("sfx", v))


static func page_graphics(host: Node) -> void:
	var filt: int = SpriteFilt.clamp_id(int(App.sprite_filter), false)
	var mips_on: bool = SpriteFilt.mips_on(filt)
	var aniso_on: bool = SpriteFilt.aniso_on(filt)
	var cap: Label = ThemeS.lab("Sprite filtering", 20, Color(0.9, 0.84, 0.7))
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.info_box.add_child(cap)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 28)
	var mips: CheckBox = _check("Mipmaps", mips_on, func(on: bool) -> void:
		_set_filter(host, on, on and aniso_on)
	)
	var aniso: CheckBox = _check("Anisotropic", aniso_on, func(on: bool) -> void:
		_set_filter(host, true, on)
	)
	aniso.disabled = not mips_on
	row.add_child(mips)
	row.add_child(aniso)
	host.info_box.add_child(row)
	host.info_btns.append(mips)
	host.info_btns.append(aniso)
	_slider(host, "Camera zoom", float(App.cam_zoom), T.ZOOM_MIN, T.ZOOM_MAX, 0.05, func(v: float) -> void:
		if App.has_method("set_zoom"):
			App.set_zoom(v)
		else:
			App.cam_zoom = v
	)
	_slider(host, "HUD scale", float(App.hud_scale), 0.7, 1.4, 0.05, func(v: float) -> void:
		if App.has_method("set_hud_scale"):
			App.set_hud_scale(v)
		else:
			App.hud_scale = v
	)
	if Disp.uses_desktop_modes():
		View.add_page_btn(host, ThemeS.btn(Disp.desktop_label(), func() -> void:
			Disp.cycle_desktop()
			host.split_build_page("graphics")
			View.apply_col(host)
			View.focus_col(host)
		))
	elif Disp.uses_web_fs_toggle():
		View.add_page_btn(host, ThemeS.btn(Disp.web_label(), func() -> void:
			Disp.toggle_web_fullscreen()
			host.split_build_page("graphics")
			View.apply_col(host)
			View.focus_col(host)
		))
	var aim_on: bool = bool(App.bal.aim_line_on)
	View.add_page_btn(host, ThemeS.btn("Aim line: %s" % ("On" if aim_on else "Off"), func() -> void:
		App.bal.aim_line_on = not App.bal.aim_line_on
		App.save_now()
		host.split_build_page("graphics")
		View.apply_col(host)
		View.focus_col(host)
	))
	_slider(host, "Aim line opacity", float(App.bal.aim_line_opacity), 0.05, 1.0, 0.05, func(v: float) -> void:
		App.bal.aim_line_opacity = v
	)


static func _set_filter(host: Node, mips_on: bool, aniso_on: bool) -> void:
	var id: int = SpriteFilt.from_flags(mips_on, aniso_on)
	App.set_sprite_filter(id, false)
	App.save_now()
	host.split_build_page("graphics")
	View.apply_col(host)
	View.focus_col(host)


static func _slider(host: Node, title: String, value: float, lo: float, hi: float, step: float, on_change: Callable) -> void:
	var shell := VBoxContainer.new()
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.add_theme_constant_override("separation", 4)
	shell.add_child(ThemeS.lab(title, 20, Color(0.9, 0.84, 0.7)))
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = step
	sl.value = value
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.custom_minimum_size = Vector2(640, 28)
	sl.focus_mode = Control.FOCUS_ALL
	sl.value_changed.connect(on_change)
	shell.add_child(sl)
	host.info_box.add_child(shell)
	host.info_btns.append(sl)


static func _check(title: String, on: bool, on_change: Callable) -> CheckBox:
	var b := CheckBox.new()
	b.text = title
	b.button_pressed = on
	b.focus_mode = Control.FOCUS_ALL
	b.toggled.connect(on_change)
	return b


static func _add_check_centered(host: Node, b: CheckBox) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(b)
	host.info_box.add_child(row)
	host.info_btns.append(b)
