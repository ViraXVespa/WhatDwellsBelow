extends RefCounted

## Saved binds from an older default layout (table.gd LAYOUT). A pool (keys + mouse, or pad) the player never
## changed moves to the current defaults; a pool with any rebind keeps the saved layout as it was, and an action
## the old save never had keeps only the defaults that do not collide with that pool's saved inputs.

const Table := preload("res://scripts/input/binds/table.gd")

const LAYOUT_ROW := "_layout"

## Layout 1 defaults of the rows layout 2 changed (rows not listed kept their defaults).
const LEGACY_1: Dictionary = {
	"attack": {"mouse": [MOUSE_BUTTON_LEFT], "axis": [[JOY_AXIS_TRIGGER_RIGHT, 1.0]], "web": [7]},
	"special": {"mouse": [MOUSE_BUTTON_RIGHT], "axis": [[JOY_AXIS_TRIGGER_LEFT, 1.0]], "web": [6]},
	"dash": {"kb": [KEY_SPACE], "pad": [JOY_BUTTON_B]},
	"target_lock": {"kb": [KEY_Q], "pad": [JOY_BUTTON_RIGHT_STICK]},
	"interact": {"kb": [KEY_E, KEY_ENTER, KEY_KP_ENTER], "pad": [JOY_BUTTON_A]},
	"map_view": {"kb": [KEY_M], "pad": [JOY_BUTTON_BACK]},
	"inventory": {"kb": [KEY_I], "pad": [JOY_BUTTON_DPAD_RIGHT]},
	"potion": {"kb": [KEY_F], "pad": [JOY_BUTTON_DPAD_UP]},
	"food": {"kb": [KEY_C], "pad": [JOY_BUTTON_DPAD_LEFT]},
	"look_mode": {"pad": [JOY_BUTTON_DPAD_DOWN]},
}
## Actions layout 1 did not have.
const NEW_IN_2: PackedStringArray = ["aim", "fire"]

static func layout_of(rows: Array) -> int:
	for r: Variant in rows:
		if r is Dictionary and str((r as Dictionary).get("action", "")) == LAYOUT_ROW:
			return int((r as Dictionary).get("v", 1))
	return 1

static func migrate(rows: Array) -> Array:
	if layout_of(rows) >= Table.LAYOUT:
		return rows
	var out: Array = []
	for a: String in NEW_IN_2:
		out.append({"action": a, "type": "none"})  # Binds.apply clears the action first, then adds what survives
	for pool: String in ["kb", "pad"]:
		var mine: Array = _pool_rows(rows, pool)
		if untouched(mine, pool):
			for r: Dictionary in Table.ROWS:
				for e: InputEvent in Table.stock(r, pool):
					out.append(row_of(str(r.id), e, pool))
			continue
		out.append_array(mine)
		var taken: Dictionary = {}
		for m: Dictionary in mine:
			taken[sig_row(m)] = true
		for a: String in NEW_IN_2:
			for e: InputEvent in Table.stock(Table.row(a), pool):
				var nr: Dictionary = row_of(a, e, pool)
				if not taken.has(sig_row(nr)):
					out.append(nr)
	return out

## True when the saved pool is exactly the layout-1 defaults (any order).
static func untouched(mine: Array, pool: String) -> bool:
	var want: Dictionary = {}
	for r: Dictionary in Table.ROWS:
		if NEW_IN_2.has(str(r.id)):
			continue
		var old: Dictionary = LEGACY_1.get(str(r.id), r)
		for e: InputEvent in Table.stock(old, pool):
			want[str(r.id) + "|" + sig_row(row_of(str(r.id), e, pool))] = true
	var have: Dictionary = {}
	for m: Dictionary in mine:
		have[str(m.get("action", "")) + "|" + sig_row(m)] = true
	return have == want

static func _pool_rows(rows: Array, pool: String) -> Array:
	var out: Array = []
	for r: Variant in rows:
		if not (r is Dictionary):
			continue
		var d: Dictionary = r
		if str(d.get("action", "")) == LAYOUT_ROW or Table.row(str(d.get("action", ""))).is_empty():
			continue
		var t: String = str(d.get("type", ""))
		var p: String = "pad" if t == "joy" or t == "axis" else "kb"
		if p == pool:
			out.append(d)
	return out

static func sig_row(d: Dictionary) -> String:
	var t: String = str(d.get("type", ""))
	if t == "axis":
		return "a:%d:%d" % [int(d.get("code", 0)), int(signf(float(d.get("value", 1.0))))]
	return "%s:%d" % [t, int(d.get("code", 0))]

static func row_of(action: String, e: InputEvent, pool: String) -> Dictionary:
	var d: Dictionary = {"action": action, "pool": pool}
	if e is InputEventKey:
		var k: InputEventKey = e as InputEventKey
		d["type"] = "key"
		d["code"] = k.physical_keycode if k.physical_keycode != 0 else k.keycode
		if k.physical_keycode == 0:
			d["letter"] = true
	elif e is InputEventMouseButton:
		d["type"] = "mouse"
		d["code"] = (e as InputEventMouseButton).button_index
	elif e is InputEventJoypadButton:
		d["type"] = "joy"
		d["code"] = (e as InputEventJoypadButton).button_index
	elif e is InputEventJoypadMotion:
		d["type"] = "axis"
		d["code"] = (e as InputEventJoypadMotion).axis
		d["value"] = (e as InputEventJoypadMotion).axis_value
	return d
