extends Object

## Clip playback tick / frame control for Animation Browser.

const T := preload("res://scripts/data/tunables.gd")
const Review := preload("res://scripts/debug/anim_browser_review.gd")
const Nav := preload("res://scripts/debug/anim_browser_nav.gd")

const SPEEDS: Array[float] = [0.25, 0.5, 1.0, 1.5, 2.0]


static func toggle_play(host: CanvasLayer) -> void:
	host.playing = not host.playing
	refresh_play(host)


static func refresh_play(host: CanvasLayer) -> void:
	if host.playing:
		host.play_btn.text = "Playing %.2fx - X to pause" % host.play_speed
		host.play_btn.add_theme_color_override("font_color", Color(0.85, 1.0, 0.7))
	else:
		host.play_btn.text = "Paused %.2fx - X to play" % host.play_speed
		host.play_btn.add_theme_color_override("font_color", Color(1.0, 0.82, 0.45))


static func frames(host: CanvasLayer) -> Array:
	if not host.clips.has(host.facing):
		return []
	var d: Dictionary = host.clips[host.facing]
	if not d.has(host.anim_name):
		return []
	return d[host.anim_name]


static func show_clip(host: CanvasLayer) -> void:
	var fr := frames(host)
	host.empty_lab.visible = fr.is_empty()
	host.preview.visible = not fr.is_empty()
	if fr.is_empty():
		host.preview.texture = null
		Review.refresh(host)
		return
	host.frame_i = clampi(host.frame_i, 0, fr.size() - 1)
	if host.preview:
		host.preview.texture = fr[host.frame_i]
	refresh_play(host)
	Review.refresh(host)


static func nudge_speed(host: CanvasLayer, delta_i: int) -> void:
	var idx: int = 2
	var best: float = absf(host.play_speed - SPEEDS[2])
	for i in SPEEDS.size():
		var dist: float = absf(host.play_speed - SPEEDS[i])
		if dist < best:
			best = dist
			idx = i
	idx = clampi(idx + delta_i, 0, SPEEDS.size() - 1)
	host.play_speed = SPEEDS[idx]
	refresh_play(host)


static func step_frame(host: CanvasLayer, delta_i: int) -> void:
	var fr: Array = frames(host)
	if fr.size() <= 1:
		return
	host.frame_i = (host.frame_i + delta_i + fr.size()) % fr.size()
	host.frame_t = 0.0
	if host.preview:
		host.preview.texture = fr[host.frame_i]


static func stick_play(host: CanvasLayer) -> void:
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if v.length() < 0.55:
		return
	var delta_i: int = 0
	if absf(v.y) >= absf(v.x):
		delta_i = -1 if v.y < 0.0 else 1
	else:
		delta_i = -1 if v.x < 0.0 else 1
	if host.playing:
		nudge_speed(host, delta_i)
	else:
		step_frame(host, delta_i)
	host.stick_cool = 0.18


static func tick(host: CanvasLayer, delta: float) -> void:
	if not host.open:
		return
	Nav.stick_facing(host)
	host.stick_cool = maxf(0.0, host.stick_cool - delta)
	if host.stick_cool <= 0.0:
		stick_play(host)
	if not host.playing:
		return
	var fr := frames(host)
	if fr.size() <= 1:
		return
	host.frame_t += delta * host.play_speed
	var fps := T.WALK_FPS
	if host.anim_name.begins_with("attack") or host.anim_name.begins_with("special"):
		fps = App.bal.atk_fps
	if host.frame_t >= 1.0 / maxf(1.0, fps):
		host.frame_t = 0.0
		host.frame_i = (host.frame_i + 1) % fr.size()
		if host.preview:
			host.preview.texture = fr[host.frame_i]
