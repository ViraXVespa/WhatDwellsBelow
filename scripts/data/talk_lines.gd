extends RefCounted

## NPC Talk lines with seen tracking. Lines are en.po keys (`talk.<npc>.<nn>`, shown through App.tr), registered per
## NPC id in LINES (or with register()). Each hub entry (camp _ready -> on_hub_entry) picks a new current line per NPC,
## never one already seen this cycle; when every line has been seen the cycle restarts (the last line is not repeated
## first). ONCE is a line that plays on the first Talk and then stays in `seen` across every restart. Save field
## `talk` (store_collect / store_data): {"v": SAVE_V, "seen": {npc: [key...]}, "cur": {npc: key}}.
## A save without it loads empty (older saves); a malformed field is an error, never guessed at.

const SAVE_V := 1
## npc id -> Array of en.po keys. The receptionist once-line is ONCE, not in this pool.
const LINES: Dictionary = {
	"vendor": [
		"talk.vendor.01",
		"talk.vendor.02",
		"talk.vendor.03",
		"talk.vendor.04",
		"talk.vendor.05",
		"talk.vendor.06",
		"talk.vendor.07",
		"talk.vendor.08",
	],
	"receptionist": [
		"talk.receptionist.02",
		"talk.receptionist.03",
		"talk.receptionist.04",
		"talk.receptionist.05",
		"talk.receptionist.06",
		"talk.receptionist.07",
		"talk.receptionist.08",
		"talk.receptionist.09",
		"talk.receptionist.10",
		"talk.receptionist.11",
	],
}

## npc id -> the one line that is shown on the first Talk and never again.
const ONCE: Dictionary = {
	"receptionist": "talk.receptionist.01",
}

static var extra: Dictionary = {}
static var seen: Dictionary = {}
static var cur: Dictionary = {}

## Add or replace an NPC's lines at runtime (tests, data loaded elsewhere).
static func register(npc: String, keys: Array) -> void:
	extra[npc] = keys.duplicate()

static func lines_of(npc: String) -> Array:
	if extra.has(npc):
		return extra[npc]
	return LINES.get(npc, [])

static func npcs() -> Array:
	var out: Array = LINES.keys()
	for k: Variant in extra.keys():
		if not out.has(k):
			out.append(k)
	return out

## Current line key for an NPC (picks one if none yet). "" when the NPC has no lines.
static func current(npc: String) -> String:
	var keys: Array = lines_of(npc)
	if keys.is_empty():
		return ""
	if not keys.has(cur.get(npc, "")):
		advance(npc)
	return str(cur[npc])

## Once-only key for this NPC, or "" when the NPC has none.
static func once_key(npc: String) -> String:
	return str(ONCE.get(npc, ""))

static func _seen_has(npc: String, key: String) -> bool:
	var done: Array = seen.get(npc, [])
	return done.has(key)

## Line to show for a Talk: the once-line on the first Talk, otherwise the hub-entry line.
static func line_key(npc: String) -> String:
	var once: String = once_key(npc)
	if once != "" and not _seen_has(npc, once):
		return once
	return current(npc)

## Mark the once-line seen so the next Talk uses the rotating line. The rotating pool is untouched.
static func commit_once(npc: String) -> void:
	var once: String = once_key(npc)
	if once == "" or _seen_has(npc, once):
		return
	var done: Array = seen.get(npc, [])
	done.append(once)
	seen[npc] = done

## Current line shown in the player's language.
static func text(npc: String) -> String:
	var key: String = current(npc)
	return App.tr(key) if key != "" else ""

## Move an NPC to a line not yet seen this cycle and mark it seen.
static func advance(npc: String) -> String:
	var keys: Array = lines_of(npc)
	if keys.is_empty():
		return ""
	var done: Array = seen.get(npc, [])
	var left: Array = keys.filter(func(k): return not done.has(k))
	if left.is_empty():
		var keep: Array = []
		for item: Variant in done:
			if not keys.has(item):
				keep.append(item)
		done = keep
		left = keys.filter(func(k): return k != cur.get(npc, "") or keys.size() == 1)
	var pick: String = str(left[randi() % left.size()])
	done.append(pick)
	seen[npc] = done
	cur[npc] = pick
	return pick

## Hub entry: every NPC with lines moves on.
static func on_hub_entry() -> void:
	for npc: Variant in npcs():
		advance(str(npc))

static func reset() -> void:
	seen = {}
	cur = {}

static func to_save() -> Dictionary:
	return {"v": SAVE_V, "seen": seen.duplicate(true), "cur": cur.duplicate()}

## Load the save field. null (older save) = nothing seen yet. Anything malformed is reported and stops in debug.
static func from_save(raw: Variant) -> void:
	reset()
	if raw == null:
		return
	var err: String = check(raw)
	if err != "":
		push_error("save field talk: " + err)
		assert(false, "save field talk: " + err)
		return
	seen = (raw["seen"] as Dictionary).duplicate(true)
	cur = (raw["cur"] as Dictionary).duplicate()

## "" when raw is a valid talk field, else what is wrong.
static func check(raw: Variant) -> String:
	if not raw is Dictionary:
		return "not a dictionary"
	var d: Dictionary = raw
	if int(d.get("v", -1)) < 1 or int(d.get("v", -1)) > SAVE_V:
		return "unknown version " + str(d.get("v"))
	if not d.get("seen") is Dictionary or not d.get("cur") is Dictionary:
		return "seen/cur must be dictionaries"
	for k: Variant in d["seen"]:
		if not d["seen"][k] is Array:
			return "seen." + str(k) + " is not a list"
	for k: Variant in d["cur"]:
		if not d["cur"][k] is String:
			return "cur." + str(k) + " is not a key"
	return ""
