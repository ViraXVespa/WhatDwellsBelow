extends Object

## P1 check (tools/relay/README.md): Report Bug is a Settings row in every build, its Door/Job pickers list
## exactly the routes.yaml doors and jobs (bug_doors.json = bug_doors.gd) with descriptions and walk with the pad, the
## summary is the title, the install id is stable, the state report carries only the relay's keys and no email, and
## logs ride only with a crash. Offline: the live dry_run recipe is in the task file.
## Prints "P1: bug_report_ok=" and SMOKE FAIL on a miss.

const Send := preload("res://scripts/app/bug_report/bug_send.gd")
const State := preload("res://scripts/app/bug_report/bug_state.gd")
const Crash := preload("res://scripts/app/bug_report/crash_mark.gd")
const Settings := preload("res://scripts/ui/pause_settings.gd")
const Page := preload("res://scripts/ui/pause_settings/report_page.gd")
const Pick := preload("res://scripts/ui/pause_settings/report_pick.gd")
const Doors := preload("res://scripts/data/bug_doors.gd")
const PickCheck := preload("res://scripts/debug/smoke/bug_report_pick_check.gd")

static func run(_host: Node) -> void:
	var fails: PackedStringArray = []
	var s: Control = Settings.new()
	var ids: Array = (s.split_rows() as Array).map(func(r: Dictionary) -> String: return str(r.get("id", "")))
	s.free()
	if not ids.has("report"):
		fails.append("no report row in Settings")
	fails.append_array(_picker_faults())
	for k: String in Send.KINDS:
		if App.tr(k) == k:
			fails.append("kind text " + k)
	if Send.valid_category("ui.no_such_job") or Send.valid_category("nope"):
		fails.append("valid_category accepts junk")
	var id1: String = Send.install_id()
	Send._id = ""
	if id1 != Send.install_id() or not Send.valid_id(id1):
		fails.append("install id not stable")
	var mail := "smoke.player@example.com"
	var log0: String = Crash.crashed_log
	Crash.crashed_log = ""
	var form := {"summary": " Smoke summary ", "door": "ui", "job": "", "kind": 1, "details": "smoke details", "email": mail, "opt_in": true, "shot": false, "crash": true}
	var body: Dictionary = Send.payload(form, "", true)
	var st: Dictionary = body.get("state", {})
	for k: Variant in st:
		if not State.KEYS.has(k):
			fails.append("state key " + str(k))
	if JSON.stringify(st).find(mail) >= 0 or str(body.get("description", "")).find(mail) >= 0:
		fails.append("email outside the email field")
	if body.has("log") or body.has("crash"):
		fails.append("log without a crash")
	Crash.crashed_log = "ERROR: smoke crash line"
	var crash_body: Dictionary = Send.payload(form, "", true)
	if not bool(crash_body.get("crash", false)) or str(crash_body.get("log", "")) == "":
		fails.append("crash log not attached")
	Crash.crashed_log = log0
	if str(body.get("category", "")) != "ui" or str(st.get("version", "")) == "" or not bool(body.get("dry_run", false)):
		fails.append("payload category/version/dry_run")
	if str(body.get("title", "")) != "Smoke summary":
		fails.append("summary is not the title")
	var cats: Array = [Send.category({}), Send.category({"door": "ui", "job": "hud"}), Send.category({"door": "", "job": "hud"})]
	if cats != ["", "ui.hud", ""] or str(Send.payload({"door": "nope"}, "", true).category) != "":
		fails.append("door/job category " + str(cats))
	fails.append_array(PickCheck.faults(_host))
	if not _backspace_ok(_host):
		fails.append("Backspace in the email field does not delete")
	fails.append_array(_opt_faults())
	var cfg := ConfigFile.new()
	if cfg.load("res://export_presets.cfg") == OK:
		for sec: String in cfg.get_sections():
			if str(cfg.get_value(sec, "platform", "")) == "Web" and not bool(cfg.get_value(sec + ".options", "html/experimental_virtual_keyboard", false)):
				fails.append("no web virtual keyboard " + sec)
	printerr("P1: bug_report payload_keys=" + ",".join(PackedStringArray(body.keys())) + " state_keys=" + str(st.size()))
	printerr("P1: bug_report_ok=" + str(fails.is_empty()))
	if fails.size():
		printerr("SMOKE FAIL: Report Bug (bug_report_check.gd): " + "; ".join(fails))

## Backspace is bound to ui_cancel too; in a focused, editing LineEdit it must delete a character.
static func _backspace_ok(host: Node) -> bool:
	if host == null or not host.is_inside_tree():
		return true
	var le := LineEdit.new()
	le.text = "abc"
	host.add_child(le)
	Page.guard_backspace(le)
	le.grab_focus()
	le.edit()
	le.caret_column = 3
	var k := InputEventKey.new()
	k.keycode = KEY_BACKSPACE
	k.physical_keycode = KEY_BACKSPACE
	k.pressed = true
	host.get_viewport().push_input(k)
	var ok := le.text == "ab" and InputMap.event_is_action(k, "ui_cancel")
	le.queue_free()
	return ok

## bug_doors.json (picker) lists the same doors and jobs as bug_doors.gd (relay check), each named and described.
static func _picker_faults() -> PackedStringArray:
	var out: PackedStringArray = []
	var keys: Array = Pick.doors().map(func(d: Dictionary) -> String: return str(d.key))
	if keys != Doors.DOORS.keys():
		out.append("picker doors != bug_doors.gd")
	for d: Dictionary in Pick.doors():
		var js: Array = (d.jobs as Array).map(func(j: Dictionary) -> String: return str(j.key))
		if js != Doors.DOORS.get(d.key, []) or str(d.name) == "" or str(d.about) == "":
			out.append("door " + str(d.key))
		for j: Dictionary in d.jobs:
			if str(j.name) == "" or str(j.about) == "" or not Send.valid_category(str(d.key) + "." + str(j.key)):
				out.append("job %s.%s" % [d.key, j.key])
	for k: String in ["bug_report.door", "bug_report.job", "bug_report.summary_hint", "bug_report.job_pick_door"]:
		if App.tr(k) == k:
			out.append("text " + k)
	return out

## Opt-in: off and disabled with no valid email, checks itself once one is typed, a cleared box stays cleared.
static func _opt_faults() -> PackedStringArray:
	var out: PackedStringArray = []
	var cb := CheckBox.new()
	var f := {"email": "", "opt_in": true}
	Page.gate_opt(f, cb, false)
	if not cb.disabled or cb.button_pressed or bool(f.opt_in):
		out.append("opt-in on without an email")
	for t: String in ["a@b", "a@b.co"]:
		f.email = t
		Page.gate_opt(f, cb, true)
	if cb.disabled or not cb.button_pressed or not bool(f.opt_in):
		out.append("email does not check the opt-in")
	cb.button_pressed = false
	f.opt_in = false
	f.email = "a@b.com"
	Page.gate_opt(f, cb, true)
	if cb.button_pressed:
		out.append("opt-in re-checked")
	f.email = ""
	Page.gate_opt(f, cb, true)
	if not cb.disabled or bool(f.opt_in):
		out.append("opt-in kept, no email")
	if App.tr("bug_report.privacy").find("never sold") < 0:
		out.append("privacy: never sold")
	cb.free()
	return out
