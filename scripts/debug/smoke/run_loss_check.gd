extends Object

## P3 check: a mid-run save must not keep run loot (design/inventory-gear.md). Picks up white legs, equips them from
## the bag, takes the save meta, then restores the live state. Prints "P3: run_loss_ok=" and SMOKE FAIL on a miss.

const Bag := preload("res://scripts/data/progress_gear/gear_bag.gd")

static func run(_host: Node) -> void:
	var p: Object = App.prog
	var slots0: Dictionary = p.slots.duplicate(true)
	var bag0: Array = p.bag.duplicate(true)
	var root0: int = int(p.root)
	var legs: Dictionary = Bag.make_armor(p, "legs", "white", 1)
	legs["smoke_tag"] = "run_loss"
	p.bag.append(legs)
	Bag.equip_uid(p, int(legs.uid))
	p.root = 3
	var worn: bool = str((p.slots.get("legs", {}) as Dictionary).get("smoke_tag", "")) == "run_loss"
	var m: Dictionary = p.to_meta()
	var saved: Dictionary = (m.get("slots", {}) as Dictionary).get("legs", {})
	var ok: bool = App.in_dungeon and worn and str(saved.get("smoke_tag", "")) == "" and int(m.get("root", -1)) == 0
	p.slots = slots0
	p.bag = bag0
	p.root = root0
	printerr("P3: run_loss worn=%s saved_legs=%s root=%s" % [worn, str(saved.get("name", "-")), m.get("root")])
	printerr("P3: run_loss_ok=" + str(ok))
	if not ok:
		printerr("SMOKE FAIL: mid-run save kept unextracted gear (run_loss_check.gd)")
