extends Object

const PATH := "res://scripts/data/archive_catalog.json"
const NEED: Array[String] = ["classic_2d", "art_experiment", "full_3d_pass", "grok_build_w1", "grok_web_w1"]


static func raw() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return v if v is Dictionary else {}


static func all() -> Array:
	var a: Variant = raw().get("archives", [])
	return a if a is Array else []


static func by_id(id: String) -> Dictionary:
	for e in all():
		if e is Dictionary and str(e.get("id", "")) == id:
			return e
	return {}


static func pages_url(e: Dictionary) -> String:
	var origin := str(raw().get("pages_origin", "")).rstrip("/")
	var slug := str(e.get("pages_slug", "")).trim_prefix("/")
	if origin == "" or slug == "":
		return ""
	return origin + "/" + slug + "/"


static func raw_doc_url(e: Dictionary, path: String) -> String:
	var repo := str(raw().get("github_repo", ""))
	var sha := str(e.get("commit", ""))
	if repo == "" or sha == "" or path == "":
		return ""
	return "https://raw.githubusercontent.com/%s/%s/%s" % [repo, sha, path]


static func ok() -> bool:
	var seen := {}
	for e in all():
		if not e is Dictionary:
			return false
		var id := str(e.get("id", ""))
		var sha := str(e.get("commit", ""))
		var slug := str(e.get("pages_slug", ""))
		if id == "" or sha.length() != 40 or slug == "":
			return false
		seen[id] = true
	for need in NEED:
		if not seen.has(need):
			return false
	return true
