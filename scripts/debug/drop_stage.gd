extends RefCounted

## Debug helpers for enemy kill drops (shot flow dungeon-pickups, P3 drop sim). Target "script:debug/drop_stage".

const Hit := preload("res://scripts/combat/enemy/enemy_hit.gd")

## Lay one pickup of `kind` beside the player (dx, dz in meters).
func place(kind: String, dx: float, dz: float) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var pl := tree.get_first_node_in_group("player") as Node3D
	if pl == null:
		return
	var p: Node3D = (load("res://scripts/world/pickup.gd") as GDScript).new()
	tree.current_scene.add_child(p)
	p.setup(kind, pl.global_position + Vector3(dx, 0.0, dz), 3 if kind == "gold" else 0)
	p.set("life", 0.0)
	p.set("_block_t", 9999.0)

## `coins` is the total gold; coins / n is the average per kill.
## Roll `n` normal (non-boss) kills with the live tunables: counts of none / gold / hp / mana / gear.
static func sim(n: int) -> Dictionary:
	var c := {"none": 0, "gold": 0, "hp": 0, "mana": 0, "gear": 0, "coins": 0}
	for i: int in n:
		var d: PackedStringArray = Hit.roll_drops(false)
		if randf() < App.bal.enemy_gear_chance + App.bal.enemy_gear_floor * float(App.floor_n):
			d.append("gear")
		if d.has("gold"):
			c.coins += Hit.gold_amount(false)
		if d.is_empty():
			c.none += 1
		for k: String in d:
			c[k] += 1
	return c
