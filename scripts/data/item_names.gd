extends Object

## Item display names come from ids: `nk` (name key, one entry) plus `forged`.
## The saved `name` is only a cache, refreshed on load and when the language changes.

const KEYS: PackedStringArray = ["common.great_axe", "common.lightning_staff", "gear.staff", "gear.longbow", "gear.pickaxe", "gear.hatchet", "gear.potion", "gear.ration", "progress_make.trail_bread", "slot.head", "slot.body", "slot.legs"]
const ARMOR: PackedStringArray = ["head", "body", "legs"]
const OLD_FORGED := "Forged "

## Name key for a rolled weapon, tool or armor piece; empty when the type has no key.
static func base_nk(slot: String, type_id: String) -> Array:
	var k := ""
	if slot == "weapon":
		k = str({"great_axe": "common.great_axe", "staff": "gear.staff", "longbow": "gear.longbow"}.get(type_id, ""))
	elif slot == "tool":
		k = str({"pickaxe": "gear.pickaxe", "hatchet": "gear.hatchet"}.get(type_id, ""))
	elif slot in ARMOR:
		k = "slot." + slot
	return [k] if k != "" else []

static func name_of(it: Dictionary) -> String:
	var nk: Variant = it.get("nk", [])
	if not (nk is Array) or (nk as Array).is_empty():
		return str(it.get("name", ""))
	var s: String = App.tr(str((nk as Array)[0]))
	if bool(it.get("forged", false)):
		s = App.tr("gear.forged").format({"name": s})
	return s

## Name for an item that is being forged now (works for items without a name key too).
static func forge(it: Dictionary) -> void:
	it["forged"] = true
	var a: Variant = it.get("nk", [])
	if a is Array and not (a as Array).is_empty():
		it["name"] = name_of(it)
	else:
		it["name"] = App.tr("gear.forged").format({"name": str(it.get("name", "item"))})

## Old saves hold only the English `name`: infer the ids once, then refresh the cache.
static func migrate(it: Dictionary) -> void:
	if it.is_empty():
		return
	if not it.has("nk"):
		_infer(it)
	if not (it["nk"] as Array).is_empty():
		it["name"] = name_of(it)

static func _infer(it: Dictionary) -> void:
	var nm: String = str(it.get("name", ""))
	var nk: Array = []
	if nm.begins_with(OLD_FORGED):
		it["forged"] = true
		nm = nm.substr(OLD_FORGED.length())
	for k: String in KEYS:
		if nk.is_empty() and _en(k) == nm:
			nk = [k]
	var aid: String = str(it.get("id", ""))
	if nk.is_empty() and str(it.get("kind", "")) == "artifact" and _en("item.%s.name" % aid) == nm:
		nk = ["item.%s.name" % aid]
	it["nk"] = nk

static func _en(key: String) -> String:
	var t: Translation = TranslationServer.get_translation_object("en")
	return str(t.get_message(key)) if t != null and t.locale == "en" else ""

## Re-derive every cached name (after the language changed).
static func refresh(p: Object) -> void:
	var lists: Array = [p.bag, p.bank_items]
	for k: Variant in p.holds.keys():
		lists.append(p.holds[k])
	for k2: Variant in p.starters.keys():
		lists.append(p.starters[k2])
	for lst: Variant in lists:
		if lst is Array:
			for it: Variant in lst:
				if it is Dictionary:
					migrate(it)
	for s: Variant in p.slots.values():
		if s is Dictionary:
			migrate(s)
