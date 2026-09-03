extends Object

const Cat := preload("res://scripts/data/archives_catalog.gd")
const CLIP := 4000


static func names(e: Dictionary) -> PackedStringArray:
	var raw: Variant = e.get("docs", [])
	var out := PackedStringArray()
	if raw is PackedStringArray:
		return raw
	if raw is Array:
		for x in raw:
			out.append(str(x))
	return out


static func display_name(path: String) -> String:
	var n := path.replace("\\", "/").get_file()
	return n if n != "" else path


static func clip(t: String) -> String:
	if t.length() > CLIP:
		return t.substr(0, CLIP) + "\n…"
	return t


static func extra_path(id: String, path: String) -> String:
	return "res://archives/docs/%s/%s" % [id, path.get_file()]


static func read_now(e: Dictionary, path: String) -> String:
	if path == "":
		return ""
	var extra := extra_path(str(e.get("id", "")), path)
	if FileAccess.file_exists(extra):
		return clip(FileAccess.get_file_as_string(extra))
	if OS.has_feature("web"):
		return ""
	var sha := str(e.get("commit", ""))
	if sha == "":
		return "(missing)"
	var root := ProjectSettings.globalize_path("res://").trim_suffix("/").trim_suffix("\\")
	var out: Array = []
	var code := OS.execute("git", PackedStringArray(["-C", root, "show", "%s:%s" % [sha, path]]), out, true, false)
	if code != 0 or out.is_empty():
		return "(missing)"
	var t := ""
	for line in out:
		if t != "":
			t += "\n"
		t += str(line)
	if t.strip_edges() == "":
		return "(missing)"
	return clip(t)
