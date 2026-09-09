extends Object

## Facing / animation lists, paint, D-pad columns, stick facing, focus.

const Facing := preload("res://scripts/world/facing.gd")
const ThemeS := preload("res://scripts/ui/theme.gd")

const DIR_ORDER := ["down", "down_left", "left", "up_left", "up", "up_right", "right", "down_right"]
const DIR_LABEL := {
	"down": "Down",
	"down_left": "Down-Left",
	"left": "Left",
	"up_left": "Up-Left",
	"up": "Up",
	"up_right": "Up-Right",
	"right": "Right",
	"down_right": "Down-Right",
}
const COL_IDLE := Color(1, 1, 1, 1)
const COL_ON := Color(1, 0.92, 0.45)


static func _anim_caption(nm: String) -> String:
	return nm.replace("_", " ").capitalize()


static func _mark(b: Button, on: bool) -> void:
	var col: Color = COL_ON if on else COL_IDLE
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_hover_color", col)
	b.add_theme_color_override("font_pressed_color", col)
	b.add_theme_color_override("font_focus_color", col)


static func _dir_caption(host: CanvasLayer, key: String) -> String:
	var n: int = 0
	var clips: Dictionary = host.clips
	if clips.has(key):
		n = (clips[key] as Dictionary).size()
	return "%s%s" % [str(DIR_LABEL.get(key, key)), "" if n > 0 else "  (empty)"]


static func pick_facing(host: CanvasLayer) -> void:
	var clips: Dictionary = host.clips
	var facing: String = str(host.facing)
	if facing == "idle_none" or not clips.has(facing) or (clips[facing] as Dictionary).is_empty():
		for k in DIR_ORDER:
			if clips.has(str(k)) and not (clips[str(k)] as Dictionary).is_empty():
				host.facing = str(k)
				return
		host.facing = "down"


static func focus_dir(host: CanvasLayer) -> void:
	host.nav_col = "dir"
	if not bool(host.open) or host.dir_box == null:
		return
	for c in host.dir_box.get_children():
		if c is Button and str((c as Button).get_meta("dir_key", "")) == str(host.facing):
			(c as Control).grab_focus()
			return
	for c in host.dir_box.get_children():
		if c is Control and (c as Control).focus_mode != Control.FOCUS_NONE:
			(c as Control).grab_focus()
			return


static func focus_anim(host: CanvasLayer) -> void:
	host.nav_col = "anim"
	if not bool(host.open) or host.anim_box == null:
		focus_dir(host)
		return
	for c in host.anim_box.get_children():
		if c is Button and str((c as Button).get_meta("anim_key", "")) == str(host.anim_name):
			(c as Control).grab_focus()
			return
	for c in host.anim_box.get_children():
		if c is Control and (c as Control).focus_mode != Control.FOCUS_NONE:
			(c as Control).grab_focus()
			return
	focus_dir(host)


static func keep_focus(host: CanvasLayer) -> void:
	if not bool(host.open):
		return
	var vp := host.get_viewport()
	var owner: Control = vp.gui_get_focus_owner() if vp else null
	if owner != null and host.is_ancestor_of(owner) and not owner.is_queued_for_deletion():
		return
	if str(host.nav_col) == "anim":
		focus_anim(host)
	else:
		focus_dir(host)


static func _note_focused(host: CanvasLayer) -> bool:
	return host.note_edit != null and is_instance_valid(host.note_edit) and host.note_edit.has_focus()


static func nudge_dir(host: CanvasLayer, delta_i: int) -> void:
	var i: int = DIR_ORDER.find(str(host.facing))
	if i < 0:
		i = 0
	i = (i + delta_i + DIR_ORDER.size()) % DIR_ORDER.size()
	set_facing(host, str(DIR_ORDER[i]))
	host.call_deferred("_focus_dir")


static func ui_nav(host: CanvasLayer, event: InputEvent) -> bool:
	if _note_focused(host):
		return false
	if event.is_action_pressed("ui_up"):
		if str(host.nav_col) == "anim":
			scroll_anim(host, -1)
		else:
			nudge_dir(host, -1)
		return true
	if event.is_action_pressed("ui_down"):
		if str(host.nav_col) == "anim":
			scroll_anim(host, 1)
		else:
			nudge_dir(host, 1)
		return true
	if event.is_action_pressed("ui_left"):
		if str(host.nav_col) == "anim":
			focus_dir(host)
		return true
	if event.is_action_pressed("ui_right"):
		if str(host.nav_col) == "dir":
			focus_anim(host)
		return true
	return false


static func paint_dirs(host: CanvasLayer) -> void:
	if host.dir_box == null:
		return
	for c in host.dir_box.get_children():
		if not (c is Button):
			continue
		var b := c as Button
		var key: String = str(b.get_meta("dir_key", ""))
		if key == "":
			continue
		b.text = _dir_caption(host, key)
		_mark(b, key == str(host.facing))


static func paint_anims(host: CanvasLayer) -> void:
	if host.anim_box == null:
		return
	for c in host.anim_box.get_children():
		if not (c is Button):
			continue
		var b := c as Button
		var key: String = str(b.get_meta("anim_key", ""))
		if key == "":
			continue
		b.text = _anim_caption(key)
		_mark(b, key == str(host.anim_name))


static func _lock_lr(b: Button) -> void:
	if not b.is_inside_tree():
		return
	var p := b.get_path()
	b.focus_neighbor_left = p
	b.focus_neighbor_right = p


static func rebuild_dirs(host: CanvasLayer) -> void:
	for c in host.dir_box.get_children():
		c.queue_free()
	for k in DIR_ORDER:
		var key: String = str(k)
		var kk: String = key
		var b := ThemeS.btn(_dir_caption(host, key), func(): set_facing(host, kk); host.nav_col = "dir")
		b.focus_mode = Control.FOCUS_ALL
		b.set_meta("dir_key", key)
		_mark(b, k == str(host.facing))
		host.dir_box.add_child(b)
		_lock_lr(b)


static func rebuild_anims(host: CanvasLayer) -> void:
	for c in host.anim_box.get_children():
		c.queue_free()
	var names := anim_names(host)
	if str(host.anim_name) == "" or names.find(str(host.anim_name)) < 0:
		host.anim_name = names[0] if names.size() > 0 else ""
	if names.is_empty():
		host.anim_box.add_child(ThemeS.lab("No animations for this facing.", 18, Color(0.8, 0.7, 0.6)))
		keep_focus(host)
		return
	host.anim_scroll = clampi(int(host.anim_scroll), 0, maxi(0, names.size() - 1))
	var shown := 12
	var start := clampi(int(host.anim_scroll), 0, maxi(0, names.size() - shown))
	for i in range(start, mini(names.size(), start + shown)):
		var nm: String = names[i]
		var b := ThemeS.btn(_anim_caption(nm), func(): set_anim(host, nm); host.nav_col = "anim")
		b.focus_mode = Control.FOCUS_ALL
		b.set_meta("anim_key", nm)
		_mark(b, nm == str(host.anim_name))
		host.anim_box.add_child(b)
		_lock_lr(b)
	keep_focus(host)


static func anim_names(host: CanvasLayer) -> PackedStringArray:
	var out := PackedStringArray()
	var clips: Dictionary = host.clips
	if not clips.has(str(host.facing)):
		return out
	var d: Dictionary = clips[str(host.facing)]
	for k in d.keys():
		out.append(str(k))
	out.sort()
	return out


static func set_facing(host: CanvasLayer, k: String) -> void:
	if k == "idle_none":
		k = "down"
	var same: bool = k == str(host.facing)
	host.facing = k
	if host.dir_box != null and host.dir_box.get_child_count() > 0 and host.dir_box.get_child(0).has_meta("dir_key"):
		paint_dirs(host)
	else:
		rebuild_dirs(host)
	if not same:
		rebuild_anims(host)
		host._show_clip()


static func set_anim(host: CanvasLayer, n: String) -> void:
	host.anim_name = n
	host.frame_i = 0
	host.frame_t = 0.0
	if host.anim_box != null and host.anim_box.get_child_count() > 0 and host.anim_box.get_child(0).has_meta("anim_key"):
		paint_anims(host)
	else:
		rebuild_anims(host)
	host._show_clip()
	if str(host.nav_col) == "anim":
		host.call_deferred("_focus_anim")


static func scroll_anim(host: CanvasLayer, d: int) -> void:
	var names := anim_names(host)
	if names.is_empty():
		return
	var i := names.find(str(host.anim_name))
	if i < 0:
		i = 0
	if d != 0:
		i = (i + d + names.size()) % names.size()
	host.anim_scroll = i
	set_anim(host, names[i])


static func stick_facing(host: CanvasLayer) -> void:
	var v := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if v.length() < 0.55:
		return
	var k := Facing.from_aim(v)
	if k == "idle_none":
		return
	if k != str(host.facing):
		set_facing(host, k)
