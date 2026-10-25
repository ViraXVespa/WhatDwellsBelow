extends Object

## Report Bug client (design/tasks/bug-report-relay.md): stable install id, the payload and the POST to the relay.
## The game holds no token, only RELAY_URL. The optional email goes only in the `email` field (the relay keeps it
## private in D1); the state report is built by bug_state.gd. HTTPRequest uses fetch on the web export.

const RELAY_URL := "https://wdb-bug-relay.viraxvespa.workers.dev/report"
const ID_PATH := "user://install_id.txt"
const Doors := preload("res://scripts/data/bug_doors.gd")
const State := preload("res://scripts/app/bug_report/bug_state.gd")
const Crash := preload("res://scripts/app/bug_report/crash_mark.gd")
const SHOT_W := 1280
const SHOT_MAX := 1_400_000

## Player-facing areas -> a door or door.job from routes.yaml ("" = triage). bug_report_check.gd keeps them valid.
const AREAS: Array = [
	["bug_report.area_unsure", ""],
	["bug_report.area_combat", "combat"],
	["bug_report.area_enemies", "enemies"],
	["bug_report.area_controls", "input"],
	["bug_report.area_gear", "inventory"],
	["bug_report.area_menus", "ui"],
	["bug_report.area_graphics", "graphics"],
	["bug_report.area_camp", "hub"],
	["bug_report.area_dungeon", "dungeon"],
	["bug_report.area_sound", "audio_visual"],
	["bug_report.area_saving", "save_tech"],
]
## Quick "what happened" picks, so a gamepad-only player can send without typing.
const KINDS: Array = ["bug_report.kind_looks_wrong", "bug_report.kind_stuck", "bug_report.kind_controls",
	"bug_report.kind_crash", "bug_report.kind_other"]

static var _id := ""

static func install_id() -> String:
	if _id != "":
		return _id
	if FileAccess.file_exists(ID_PATH):
		var have: String = FileAccess.get_file_as_string(ID_PATH).strip_edges()
		if valid_id(have):
			_id = have
			return _id
	_id = "i" + Crypto.new().generate_random_bytes(12).hex_encode()
	var f := FileAccess.open(ID_PATH, FileAccess.WRITE)
	if f:
		f.store_string(_id)
		f.close()
	return _id

static func valid_id(s: String) -> bool:
	var re := RegEx.create_from_string("^[A-Za-z0-9_-]{8,64}$")
	return re.search(s) != null

static func valid_category(cat: String) -> bool:
	if cat == "":
		return true
	var parts: PackedStringArray = cat.split(".")
	if parts.size() > 2 or not Doors.DOORS.has(parts[0]):
		return false
	return parts.size() == 1 or (Doors.DOORS[parts[0]] as Array).has(parts[1])

static func email_ok(e: String) -> bool:
	var s: String = e.strip_edges()
	return s == "" or RegEx.create_from_string("^[^\\s@]+@[^\\s@]+\\.[^\\s@]{2,}$").search(s) != null

## form: area, kind (indices), details, email, opt_in, crash (attach last session's log). shot: base64 or "".
static func payload(form: Dictionary, shot: String, dry_run: bool) -> Dictionary:
	var kind: String = App.tr(str(KINDS[clampi(int(form.get("kind", 0)), 0, KINDS.size() - 1)]))
	var details: String = str(form.get("details", "")).strip_edges().left(3800)
	var body := {
		"install_id": install_id(),
		"title": kind,
		"description": kind + "\n\n" + (details if details != "" else "(no details given)"),
		"category": str(AREAS[clampi(int(form.get("area", 0)), 0, AREAS.size() - 1)][1]),
		"state": State.build(),
	}
	var email: String = str(form.get("email", "")).strip_edges()
	if email != "":
		body["email"] = email
		body["opt_in"] = bool(form.get("opt_in", false))
	if bool(form.get("crash", false)) and Crash.crashed_log != "":
		body["crash"] = true
		body["log"] = Crash.crashed_log
	if shot != "":
		body["screenshot"] = shot
	if dry_run:
		body["dry_run"] = true
	return body

## POSTs under App (survives the pause menu closing). done(code: int, data: Dictionary); code 0 = no answer.
static func post(body: Dictionary, done: Callable) -> void:
	var http := HTTPRequest.new()
	http.timeout = 20.0
	http.process_mode = Node.PROCESS_MODE_ALWAYS
	App.add_child(http)
	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, raw: PackedByteArray) -> void:
		var data: Variant = JSON.parse_string(raw.get_string_from_utf8()) if raw.size() > 0 else null
		http.queue_free()
		done.call(code if result == HTTPRequest.RESULT_SUCCESS else 0, data if data is Dictionary else {})
	)
	var err: int = http.request(RELAY_URL, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		http.queue_free()
		done.call(0, {})

static func status_text(code: int, data: Dictionary) -> String:
	match code:
		201:
			return App.tr("bug_report.sent") % str(data.get("reporter", ""))
		200:
			return App.tr("bug_report.sent_dry")
		409:
			return App.tr("bug_report.dupe")
		429:
			return App.tr("bug_report.rate")
		0:
			return App.tr("bug_report.offline")
	if code == 422 and str(data.get("error", "")) == "bad_email":
		return App.tr("bug_report.bad_email")
	return App.tr("bug_report.failed") % code

## Hides the menu layer for two drawn frames and returns the game view as base64 JPEG ("" when unavailable).
static func capture(layer: CanvasLayer) -> String:
	if DisplayServer.get_name() == "headless":
		return ""
	var was: bool = layer.visible
	layer.visible = false
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = layer.get_viewport().get_texture().get_image()
	layer.visible = was
	if img == null or img.is_empty():
		return ""
	if img.get_width() > SHOT_W:
		img.resize(SHOT_W, int(img.get_height() * SHOT_W / float(img.get_width())), Image.INTERPOLATE_BILINEAR)
	var buf: PackedByteArray = img.save_jpg_to_buffer(0.82)
	return "" if buf.size() > SHOT_MAX else Marshalls.raw_to_base64(buf)
