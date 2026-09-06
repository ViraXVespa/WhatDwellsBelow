extends Object

const T := preload("res://scripts/data/tunables.gd")
const SpriteFilt := preload("res://scripts/world/sprite_filter.gd")
const Touch := preload("res://scripts/input/touch_pad.gd")
const Look := preload("res://scripts/input/look_ctrl.gd")


static func page_settings(host) -> void:
	host.status.text = "Settings. In-test options. LB/RB change pages."
	host.root_box.add_child(_cap("Settings", 24, Color(0.95, 0.8, 0.45)))
	host.root_box.add_child(_cap("Not yet approved for the System tab. Changes apply live.", 18, Color(0.82, 0.76, 0.66)))
	host.root_box.add_child(_slider(host, "Camera zoom", App.cam_zoom, T.ZOOM_MIN, T.ZOOM_MAX, 0.05, func(v: float):
		App.set_zoom(v)
	))
	host.root_box.add_child(_slider(host, "HUD scale", App.hud_scale, T.HUD_SCALE_MIN, T.HUD_SCALE_MAX, 0.05, func(v: float):
		App.set_hud_scale(v)
	))
	host.root_box.add_child(_slider(host, "UI text floor", App.ui_text_floor, T.UI_TEXT_FLOOR_MIN, T.UI_TEXT_FLOOR_MAX, 1.0, func(v: float):
		App.set_ui_text_floor(v)
	))
	host.root_box.add_child(host._btn("Force touch overlay: %s" % ("On" if Touch.force_show else "Off"), func():
		Touch.force_show = not Touch.force_show
		host._rebuild()
	))
	host.root_box.add_child(host._btn("Sprite filter: %s" % SpriteFilt.label(int(App.sprite_filter)), func():
		App.set_sprite_filter(SpriteFilt.cycle_all(int(App.sprite_filter), 1), true)
		App.save_now()
		host._rebuild()
	))
	host.root_box.add_child(host._btn("Mip blend: %s" % ("Sharp" if App.sprite_mip_sharp else "Smooth"), func():
		App.set_sprite_mip_sharp(not App.sprite_mip_sharp)
		App.save_now()
		host._rebuild()
	))
	host.root_box.add_child(_slider(host, "Mip bias", App.sprite_mip_bias, -2.0, 2.0, 0.05, func(v: float):
		App.set_sprite_mip_bias(v)
	))
	host.root_box.add_child(_slider(host, "Touch stick deadzone", Touch.dead, 0.08, 0.4, 0.01, func(v: float):
		Touch.dead = v
	))
	host.root_box.add_child(host._btn("Reset touch defaults", func():
		Touch.reset_defaults()
		host._rebuild()
	))
	host.root_box.add_child(_slider(host, "Look wheel step", Look.wheel_step, 0.02, 0.25, 0.01, func(v: float):
		Look.wheel_step = v
	))
	host.root_box.add_child(_slider(host, "Look pinch gain", Look.pinch_gain, 0.4, 2.4, 0.05, func(v: float):
		Look.pinch_gain = v
	))
	host.root_box.add_child(_slider(host, "Look stick zoom rate", Look.stick_zoom, 0.2, 2.4, 0.05, func(v: float):
		Look.stick_zoom = v
	))
	host.root_box.add_child(_slider(host, "Look stick HUD rate", Look.stick_hud, 0.1, 1.2, 0.05, func(v: float):
		Look.stick_hud = v
	))
	host.root_box.add_child(_slider(host, "Look stick pan rate", Look.stick_pan, 120.0, 1200.0, 10.0, func(v: float):
		Look.stick_pan = v
	))
	host.root_box.add_child(host._btn("Reset look defaults", func():
		Look.reset_defaults()
		host._rebuild()
	))
	host.root_box.add_child(host._btn("Save settings", func():
		App.save_now()
		host.status.text = "Settings saved."
	))


static func _cap(t: String, size: int, col: Color) -> Label:
	var lab := Label.new()
	lab.text = t
	lab.add_theme_font_size_override("font_size", size)
	lab.add_theme_color_override("font_color", col)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lab


static func _slider(host, title: String, value: float, lo: float, hi: float, step: float, on_change: Callable) -> VBoxContainer:
	var wrap := VBoxContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("separation", 4)
	wrap.add_child(_cap(title, 20, Color(0.9, 0.84, 0.7)))
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = step
	sl.value = value
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.custom_minimum_size = Vector2(640, 28)
	sl.focus_mode = Control.FOCUS_ALL
	sl.value_changed.connect(on_change)
	wrap.add_child(sl)
	return wrap
