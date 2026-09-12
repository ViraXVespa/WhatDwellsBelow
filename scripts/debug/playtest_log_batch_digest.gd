extends Object

const PlaytestLogUtil := preload("res://scripts/debug/playtest_log_util.gd")
const Flags := preload("res://scripts/debug/playtest_log_batch_flags.gd")

static func _digest() -> String:
	var _fac = load("res://scripts/debug/playtest_log_batch.gd")
	var lines: PackedStringArray = PackedStringArray()
	lines.append("WDB playtest batch %s  n=%d" % [_fac.stamp, _fac.runs.size()])
	lines.append("dir: " + PlaytestLogUtil._dir())
	lines.append("Send this .txt for a first pass. Attach the matching batch_*.json if a flag needs the raw events.")
	lines.append("")
	var i: int = 0
	for row: Variant in _fac.runs:
		i += 1
		if not (row is Dictionary):
			continue
		var body: Dictionary = row
		var header: Dictionary = body.get("header", {})
		if not (header is Dictionary):
			header = {}
		var tel: Dictionary = body.get("tel", {})
		if not (tel is Dictionary):
			tel = {}
		var events: Array = body.get("events", [])
		if not (events is Array):
			events = []
		var save: String = str(header.get("save", tel.get("save_type", "")))
		var wpn: String = str(header.get("weapon", tel.get("start_weapon", "")))
		var tool: String = str(header.get("tool", tel.get("tool", "")))
		var fail: String = str(body.get("fail", ""))
		var dur: float = float(tel.get("duration", 0.0))
		var fl: int = int(tel.get("deepest", 0))
		var kills: int = int(tel.get("kills", 0))
		var gold: int = int(tel.get("gold_gained", 0))
		var dealt: float = float(tel.get("dmg_dealt", 0.0))
		var taken: float = float(tel.get("dmg_taken", 0.0))
		lines.append("#%d %s / %s  tool=%s  fail=%s  t=%.1f fl=%d" % [i, save, wpn, tool, fail, dur, fl])
		lines.append("  file: %s" % str(body.get("file", "")))
		lines.append("  kills=%d gold=%d dealt=%.1f taken=%.1f spec=%s extract_t=%s clerk_t=%s" % [
			kills, gold, dealt, taken,
			str(tel.get("spec_n", 0)),
			str(tel.get("extract_t", -1)),
			str(tel.get("clerk_t", -1)),
		])
		lines.append("  mine_ok=%s wood_ok=%s gather_t=%s dash=%s" % [
			str(tel.get("mine_ok", 0)),
			str(tel.get("wood_ok", 0)),
			str(tel.get("gather_t", 0)),
			str(tel.get("dash_n", 0)),
		])
		var goals: Dictionary = Flags._goal_counts(events)
		var gparts: PackedStringArray = PackedStringArray()
		for k: Variant in goals.keys():
			gparts.append("%s=%d" % [str(k), int(goals[k])])
		if gparts.size() > 0:
			lines.append("  goals: " + ", ".join(gparts))
		var flags: PackedStringArray = Flags._flags(events)
		if flags.size() > 0:
			lines.append("  flags: " + " | ".join(flags))
		var flow: String = Flags._goal_flow(events)
		if flow != "":
			lines.append("  flow: " + flow)
		lines.append("")
	return "\n".join(lines) + "\n"
