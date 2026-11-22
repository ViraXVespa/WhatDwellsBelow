extends Object

## Settings > UI page (HUD scale, minimap, map toggle, red border glow, menu transitions). Row helpers live in
## settings_pages.gd.

const T := preload("res://scripts/data/tunables.gd")
const View := preload("res://scripts/ui/split_menu/split_menu_view.gd")
const ThemeS := preload("res://scripts/ui/theme.gd")
const Pages := preload("res://scripts/ui/pause_settings/settings_pages.gd")
const MenuFade := preload("res://scripts/ui/menu_fade.gd")

static func page_ui(host: Node) -> void:
	Pages._slider(host, App.tr("settings_pages.hud_scale"), float(App.hud_scale), T.HUD_SCALE_MIN, T.HUD_SCALE_MAX, 0.05, func(v: float) -> void:
		if App.has_method("set_hud_scale"):
			App.set_hud_scale(v)
		else:
			App.hud_scale = v
	)
	Pages._span_slider(host, App.tr("settings_pages.minimap_size"), float(App.mini_px), T.MINI_PX_MIN, T.MINI_PX_DEFAULT, T.MINI_PX_MAX, func(v: float) -> String:
		return "%d" % int(round(v))
	, func(v: float) -> void:
		App.set_mini_px(v)
	)
	Pages._slider(host, App.tr("settings_pages.minimap_opacity"), float(App.mini_opacity), 0.0, 1.0, 0.01, func(v: float) -> void:
		App.set_mini_opacity(v)
	)
	Pages._span_slider(host, App.tr("settings_pages.minimap_zoom"), float(App.mini_zoom), T.MINI_ZOOM_MIN, T.MINI_ZOOM_DEFAULT, T.MINI_ZOOM_MAX, func(v: float) -> String:
		return _zoom_text(v)
	, func(v: float) -> void:
		App.set_mini_zoom(v)
	)
	var fit_on: bool = bool(App.mini_zoom_fit)
	var fit_word: String = App.tr("settings_pages.zoom_minimum") if fit_on else App.tr("settings_pages.zoom_fixed")
	View.add_page_btn(host, ThemeS.btn(App.tr("settings_pages.zoom_mode") % fit_word, func() -> void:
		App.set_mini_zoom_fit(not bool(App.mini_zoom_fit))
		host.split_build_page("ui")
		View.apply_col(host)
		View.focus_col(host)
	))
	var share_on: bool = bool(App.full_map_opacity)
	var share: CheckBox = Pages._check(App.tr("settings_pages.full_map_opacity"), share_on, func(on: bool) -> void:
		App.set_full_map_opacity(on)
	)
	Pages._add_check_centered(host, share)
	var adapt_on: bool = bool(App.map_toggle_adapt)
	var adapt_word: String = App.tr("settings_pages.toggle_adaptive") if adapt_on else App.tr("settings_pages.toggle_cycle")
	View.add_page_btn(host, ThemeS.btn(App.tr("settings_pages.map_toggle") % adapt_word, func() -> void:
		App.set_map_toggle_adapt(not bool(App.map_toggle_adapt))
		host.split_build_page("ui")
		View.apply_col(host)
		View.focus_col(host)
	))
	var glow_on: bool = bool(App.red_border_glow)
	var glow_box: CheckBox = Pages._check(App.tr("settings_pages.red_border_glow"), glow_on, func(on: bool) -> void:
		App.red_border_glow = on
		if App.has_method("save_now"):
			App.save_now()
	)
	Pages._add_check_centered(host, glow_box)
	var fade_box: CheckBox = Pages._check(App.tr("page_ui.menu_transitions"), MenuFade.enabled, func(on: bool) -> void:
		MenuFade.enabled = on
		if App.has_method("save_now"):
			App.save_now()
	)
	Pages._add_check_centered(host, fade_box)

static func _zoom_text(z: float) -> String:
	var shown: float = T.snap_mini_zoom(z)
	if absf(shown - round(shown)) < 0.001:
		return "%dx" % int(round(shown))
	if shown >= 10.0:
		return "%.1fx" % shown
	return "%.2fx" % shown
