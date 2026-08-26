extends Object

const HubSpot := preload("res://scripts/view3d/hub_spot_3d.gd")
const DunSpot := preload("res://scripts/view3d/dungeon_spot_3d.gd")

const HUB := ["town_crystal", "receptionist", "sign", "vendor", "anvil"]


static func make(kind: String, tex := "", extra: Dictionary = {}) -> StaticBody3D:
	var n: StaticBody3D
	if kind in HUB:
		n = HubSpot.new()
	else:
		n = DunSpot.new()
	n.configure(kind, tex, extra)
	return n
