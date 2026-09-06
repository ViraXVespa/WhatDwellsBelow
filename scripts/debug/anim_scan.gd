extends Object

const Facing := preload("res://scripts/world/facing.gd")
const Roster := preload("res://scripts/combat/roster.gd")


static func catalog_models() -> Array:
	var out: Array = []
	out.append({"id": "player_male", "label": "Player — Male", "dir": "res://assets/sprites/player/male/"})
	out.append({"id": "player_female", "label": "Player — Female", "dir": "res://assets/sprites/player/female/"})
	for id in Roster.IDS:
		out.append({"id": id, "label": id.capitalize(), "dir": "res://assets/sprites/enemies/%s/" % id})
	out.append({"id": "guardian", "label": "Floor Guardian", "dir": "res://assets/sprites/enemies/guardian/"})
	out.append({"id": "gate_master", "label": "Gate Master", "dir": "res://assets/sprites/enemies/gate_master/"})
	return out


static func model_count() -> int:
	return catalog_models().size()


static func scan(base: String) -> Dictionary:
	var out := {}
	out["idle_none"] = {}
	for k in Facing.KEYS:
		out[k] = {}
		put_single(out[k], "idle", base + "idle_%s.png" % k)
		put_seq(out[k], "walk", base + "walk_%s_" % k)
		for w in ["great_axe", "staff", "longbow"]:
			put_seq(out[k], "attack_%s" % w, base + "atk_%s_%s_" % [w, k])
			put_seq(out[k], "special_%s" % w, base + "spc_%s_%s_" % [w, k])
		put_single(out[k], "strike", base + "strike_%s.png" % k)
		put_single(out[k], "windup", base + "windup_%s.png" % k)
		put_seq_or(out[k], "gather_pickaxe", [
			base + "gather_pickaxe_%s_" % k,
			base + "gather_%s_" % k,
		])
		put_seq_or(out[k], "gather_hatchet", [
			base + "gather_hatchet_%s_" % k,
			base + "gather_%s_" % k,
		])
		put_seq(out[k], "gather", base + "gather_%s_" % k)
		put_seq(out[k], "death", base + "death_%s_" % k)
		put_seq(out[k], "dispel", base + "dispel_%s_" % k)
		if (out[k] as Dictionary).has("idle"):
			(out["idle_none"] as Dictionary)["idle_%s" % k] = (out[k] as Dictionary)["idle"]
	return out


static func put_single(into: Dictionary, name: String, path: String) -> void:
	if ResourceLoader.exists(path):
		into[name] = [load(path)]


static func put_seq(into: Dictionary, name: String, prefix: String) -> void:
	var frames: Array = []
	var i := 0
	while ResourceLoader.exists("%s%d.png" % [prefix, i]):
		frames.append(load("%s%d.png" % [prefix, i]))
		i += 1
	if not frames.is_empty():
		into[name] = frames


static func put_seq_or(into: Dictionary, name: String, prefixes: Array) -> void:
	for prefix in prefixes:
		put_seq(into, name, str(prefix))
		if into.has(name):
			return
