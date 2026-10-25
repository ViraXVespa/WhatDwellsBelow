extends Object

## P1 check (design/tasks/bug-report-relay.md): Report Bug is a Settings row in every build, its areas are routes.yaml
## doors (bug_doors.gd), the install id is stable, the state report carries only the relay's keys and no email, and
## logs ride only with a crash. Offline: the live dry_run recipe is in the task file.
## Prints "P1: bug_report_ok=" and SMOKE FAIL on a miss.

const Send := preload("res://scripts/app/bug_report/bug_send.gd")
const State := preload("res://scripts/app/bug_report/bug_state.gd")
const Crash := preload("res://scripts/app/bug_report/crash_mark.gd")
const Settings := preload("res://scripts/ui/pause_settings.gd")

static func run(_host: Node) -> void:
	var fails: PackedStringArray = []
	var s: Control = Settings.new()
	var ids: Array = (s.split_rows() as Array).map(func(r: Dictionary) -> String: return str(r.get("id", "")))
	s.free()
	if not ids.has("report"):
		fails.append("no report row in Settings")
	for a: Array in Send.AREAS:
		if not Send.valid_category(str(a[1])) or App.tr(str(a[0])) == str(a[0]):
			fails.append("area " + str(a))
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
	var form := {"area": 5, "kind": 1, "details": "smoke details", "email": mail, "opt_in": true, "shot": false, "crash": true}
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
	printerr("P1: bug_report payload_keys=" + ",".join(PackedStringArray(body.keys())) + " state_keys=" + str(st.size()))
	printerr("P1: bug_report_ok=" + str(fails.is_empty()))
	if fails.size():
		printerr("SMOKE FAIL: Report Bug (bug_report_check.gd): " + "; ".join(fails))
