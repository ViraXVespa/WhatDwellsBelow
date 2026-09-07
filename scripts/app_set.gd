extends Object

## Settings cluster split out of App. Facade path stays scripts/app.gd.

const T := preload("res://scripts/data/tunables.gd")
const SpriteFilt := preload("res://scripts/world/sprite_filter.gd")
const UiText := preload("res://scripts/ui/ui_text.gd")
const Disp := preload("res://scripts/display_mode.gd")


static func set_volume(host: Node, which: String, v: float) -> void:
	v = clampf(v, 0.0, 1.0)
	if which == "master":
		host.vol_master = v
		AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, v)))
	elif which == "music":
		host.vol_music = v
		if host.music and host.music.has_method("_apply_vol"):
			host.music._apply_vol()
	else:
		host.vol_sfx = v
		if host.sfx_node and host.sfx_node.has_method("_apply_vol"):
			host.sfx_node._apply_vol()
		elif host.sfx_node:
			for c in host.sfx_node.get_children():
				if c is AudioStreamPlayer:
					(c as AudioStreamPlayer).volume_db = linear_to_db(maxf(0.001, host.vol_sfx * host.vol_master))
	if which == "master":
		if host.music and host.music.has_method("_apply_vol"):
			host.music._apply_vol()
		if host.sfx_node and host.sfx_node.has_method("_apply_vol"):
			host.sfx_node._apply_vol()


static func set_zoom(host: Node, z: float) -> void:
	host.cam_zoom = clampf(z, T.ZOOM_MIN, T.ZOOM_MAX)
	var p: Node = host.get_tree().get_first_node_in_group("player")
	if p:
		var rig: Variant = p.get("rig")
		if rig and rig.has_method("apply_zoom"):
			rig.apply_zoom(host.cam_zoom)


static func set_hud_scale(host: Node, v: float) -> void:
	host.hud_scale = clampf(v, 0.7, 1.4)


static func set_ui_text_floor(host: Node, v: float) -> void:
	host.ui_text_floor = UiText.clamp_floor(v)
	refresh_ui_text_scale(host)


static func ui_text_applied(host: Node) -> float:
	return host.ui_text_scale


static func refresh_ui_text_scale(_host: Node) -> void:
	UiText.refresh()


static func set_sprite_filter(host: Node, id: int, allow_linear: bool = false) -> void:
	host.sprite_filter = SpriteFilt.clamp_id(id, allow_linear)
	SpriteFilt.apply_tree()


static func set_sprite_mip_sharp(host: Node, on: bool) -> void:
	host.sprite_mip_sharp = on
	SpriteFilt.apply_tree()


static func set_sprite_mip_bias(host: Node, v: float) -> void:
	host.sprite_mip_bias = clampf(v, -2.0, 2.0)
	SpriteFilt.apply_tree()


static func set_display_mode(_host: Node, mode: String) -> void:
	Disp.set_desktop_mode(mode)


static func set_web_fullscreen(_host: Node, on: bool) -> void:
	Disp.set_web_fullscreen(on)
