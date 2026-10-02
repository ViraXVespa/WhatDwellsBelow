extends Object

## Split from balance.gd: getv, setv, snapshot.

const Enemies := preload("res://scripts/data/balance/balance_enemies.gd")

static func getv(host: RefCounted, name: String) -> float:
	host._ensure_enemies()
	if name.begins_with("e_"):
		return Enemies.read_stat(host.enemy_stats, name)
	var v: Variant = host.get(name)
	if v is bool:
		return 1.0 if v else 0.0
	if v == null:
		return 0.0
	return float(v)

static func setv(host: RefCounted, name: String, value: float) -> void:
	host._ensure_enemies()
	if Enemies.write_stat(host.enemy_stats, name, value):
		return
	var cur: Variant = host.get(name)
	if cur is bool:
		host.set(name, value >= 0.5)
	elif cur is int:
		host.set(name, int(round(value)))
	else:
		host.set(name, value)

static func snapshot(host: RefCounted) -> Dictionary:
	var d := {}
	for row in host.schema():
		d[str(row[0])] = getv(host, str(row[0]))
	return d
