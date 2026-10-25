extends Object

## Crash capture for Report Bug: a session marker in user:// is written at boot and removed on a clean exit. If it is
## still there at the next boot, that session ended without quitting, and the tail of its rotated Godot log becomes
## `crashed_log` (offered as an opt-in attachment). Skipped on web (closing a tab is never a clean exit, and there is
## no file log) and in smokes. Not under scripts/debug/: release exports keep it.

const MARK := "user://session_open.txt"
const LOG_DIR := "user://logs"
const TAIL := 16000

static var crashed_log := ""

static func begin(host: Node) -> void:
	if OS.has_feature("web") or App.Dbg.smoke_active():
		return
	if FileAccess.file_exists(MARK):
		crashed_log = scrub(last_log())
	var f := FileAccess.open(MARK, FileAccess.WRITE)
	if f:
		f.store_string(Time.get_datetime_string_from_system())
		f.close()
	host.tree_exiting.connect(end)

static func end() -> void:
	if FileAccess.file_exists(MARK):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(MARK))

## Newest rotated log (godot.log is this session's).
static func last_log() -> String:
	var dir := DirAccess.open(LOG_DIR)
	if dir == null:
		return ""
	var best := ""
	var best_t := 0
	for f: String in dir.get_files():
		if not f.ends_with(".log") or f == "godot.log":
			continue
		var t: int = FileAccess.get_modified_time(LOG_DIR.path_join(f))
		if t > best_t:
			best_t = t
			best = f
	if best == "":
		return ""
	var txt: String = FileAccess.get_file_as_string(LOG_DIR.path_join(best))
	return txt.right(TAIL) if txt.length() > TAIL else txt

## Machine paths carry the OS user name: replace them before the log leaves the game.
static func scrub(txt: String) -> String:
	var s: String = txt.replace(OS.get_user_data_dir(), "user://")
	for env: String in ["HOME", "USERPROFILE"]:
		var home: String = OS.get_environment(env)
		if home.length() > 3:
			s = s.replace(home, "~")
	return s
