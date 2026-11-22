extends RefCounted

## Letter defaults (table.gd "letter" rows: P Potion, F Food, T Target lock) bind by the key's printed label. On a
## layout where that label sits on a key another in-play action holds by position (Colemak prints F on QWERTY E,
## Interact's key), the letter action falls back to a free physical key next to WASD instead of firing both.
## The keyboard layout comes from the OS (desktop) or is learned from key presses (web and headless have no layout
## query: a press carries both the printed and the physical key). Only untouched letter defaults move; a fitted
## default saves as its letter (binds.gd collect), so a save moved to another keyboard fits again there.

const Table := preload("res://scripts/input/binds/table.gd")

## Menu-only rows (and the unrebindable debug anim-browser rows): their keys never act in play, so a letter on the
## same key is not a clash (Dvorak F on QWERTY Y).
const MENU_ONLY: PackedStringArray = ["gear_tip", "gear_drop", "crystal_zoom", "tab_left", "tab_right"]
## Fallback physical keys, nearest the left hand first.
const NEAR: Array[int] = [KEY_G, KEY_H, KEY_V, KEY_C, KEY_B, KEY_R, KEY_Z, KEY_N]

## printed letter keycode -> physical keycode seen for it (learned from presses).
static var learned: Dictionary = {}
## action -> [letter, physical] for letter defaults currently moved off their label.
static var fitted: Dictionary = {}

## Pure: which letter actions must fall back, for label_phys (letter -> physical key printing it; a missing letter
## is at its QWERTY position). Returns {action: physical}.
static func plan(label_phys: Dictionary) -> Dictionary:
	var taken: Dictionary = {}
	var letters: Array = []
	for r: Dictionary in Table.ROWS:
		if str(r.get("rebind", "")) != "" and not MENU_ONLY.has(str(r.id)):
			for k: int in r.get("kb", []):
				taken[k] = true
		for l: int in r.get("letter", []):
			letters.append([str(r.id), l])
	var label_at: Dictionary = {}
	for pair: Array in letters:
		label_at[int(label_phys.get(pair[1], pair[1]))] = true
		label_at[int(pair[1])] = true
	var out: Dictionary = {}
	for pair: Array in letters:
		if not taken.has(int(label_phys.get(pair[1], pair[1]))):
			continue
		for c: int in NEAR:
			if not taken.has(c) and not label_at.has(c) and not out.values().has(c):
				out[pair[0]] = c
				break
	return out

## The OS keyboard layout for the letter rows (desktop), plus what presses taught us.
static func label_map() -> Dictionary:
	var out: Dictionary = learned.duplicate()
	if DisplayServer.get_name() == "headless" or OS.has_feature("web"):
		return out
	var want: Dictionary = {}
	for r: Dictionary in Table.ROWS:
		for l: int in r.get("letter", []):
			want[l] = true
	for phys: int in range(KEY_A, KEY_Z + 1):
		var code: int = int(DisplayServer.keyboard_get_keycode_from_physical(phys as Key))
		if want.has(code) and not out.has(code):
			out[code] = phys
	return out

## Re-fit the letter defaults to label_map(): moved ones go to their fallback key, others back to their label.
static func fit(label_phys: Dictionary = label_map()) -> Dictionary:
	var p: Dictionary = plan(label_phys)
	for r: Dictionary in Table.ROWS:
		for l: int in r.get("letter", []):
			_place(str(r.id), l, int(p.get(str(r.id), 0)))
	return p

static func _place(action: String, letter: int, phys: int) -> void:
	if not InputMap.has_action(action):
		return
	var was: Array = fitted.get(action, [])
	var cur: InputEvent = null
	for e: InputEvent in InputMap.action_get_events(action):
		if e is InputEventKey:
			var k := e as InputEventKey
			if (k.physical_keycode == 0 and int(k.keycode) == letter) or (not was.is_empty() and int(k.physical_keycode) == int(was[1])):
				cur = e
	if cur == null:
		fitted.erase(action)
		return
	var ev := InputEventKey.new()
	if phys != 0:
		ev.physical_keycode = phys as Key
		fitted[action] = [letter, phys]
	else:
		ev.keycode = letter as Key
		fitted.erase(action)
	InputMap.action_erase_event(action, cur)
	InputMap.action_add_event(action, ev)

## A key press on a layout that differs from QWERTY teaches where a letter sits; a new clash re-fits at once and
## lets go of the letter action this press fired by mistake. Returns true when the binds changed.
static func learn(event: InputEvent) -> bool:
	if not (event is InputEventKey) or not event.is_pressed():
		return false
	var k := event as InputEventKey
	var code: int = int(k.keycode)
	var phys: int = int(k.physical_keycode)
	if code == 0 or phys == 0 or code == phys or int(learned.get(code, phys)) == phys and learned.has(code):
		return false
	var is_letter := false
	for r: Dictionary in Table.ROWS:
		if r.get("letter", []).has(code):
			is_letter = true
	if not is_letter:
		return false
	learned[code] = phys
	var before: Dictionary = fitted.duplicate(true)
	var p: Dictionary = fit()
	for a: String in p:
		Input.action_release(a)
	return before != fitted
