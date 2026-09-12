extends Object

const GameVer := preload("res://scripts/data/game_ver.gd")
const Pad := preload("res://scripts/input/pad.gd")
const ThemeS := preload("res://scripts/ui/theme.gd")

static func lock_news_focus(close_btn: Button, older_btn: Button) -> void:
	close_btn.focus_neighbor_left = close_btn.get_path()
	close_btn.focus_neighbor_right = close_btn.get_path()
	if older_btn == null:
		close_btn.focus_neighbor_top = close_btn.get_path()
		close_btn.focus_neighbor_bottom = close_btn.get_path()
		close_btn.focus_next = close_btn.get_path()
		close_btn.focus_previous = close_btn.get_path()
		return
	close_btn.focus_neighbor_top = older_btn.get_path()
	close_btn.focus_neighbor_bottom = older_btn.get_path()
	close_btn.focus_next = older_btn.get_path()
	close_btn.focus_previous = older_btn.get_path()
	older_btn.focus_neighbor_left = older_btn.get_path()
	older_btn.focus_neighbor_right = older_btn.get_path()
	older_btn.focus_neighbor_top = close_btn.get_path()
	older_btn.focus_neighbor_bottom = close_btn.get_path()
	older_btn.focus_next = close_btn.get_path()
	older_btn.focus_previous = close_btn.get_path()
