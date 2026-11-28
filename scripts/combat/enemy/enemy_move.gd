extends Object

## Enemy steering step: separation push and per-move-kind velocity. Leaf shared by enemy_ai.gd and enemy_atk.gd (moved from enemy_ai.gd).

const SepGrid := preload("res://scripts/combat/enemy/sep_grid.gd")

static func sep(host: EnemyHost) -> Vector3:
	var push: Vector3 = Vector3.ZERO
	var lim: float = App.bal.enemy_sep
	var cap: int = maxi(1, int(App.bal.sep_max))
	var n: int = 0
	var idx: PackedInt32Array = SepGrid.near((host as Node3D).global_position, lim)
	var list: Array = SepGrid.near_list()
	for i in idx:
		var e: Variant = list[i]
		if e == host or e == null or not is_instance_valid(e):
			continue
		var d: Vector3 = host.global_position - (e as Node3D).global_position
		d.y = 0.0
		var L: float = d.length()
		if L < lim and L > 0.01:
			push += d / L * (lim - L) * 2.4
			n += 1
			if n >= cap:
				break
	return push

static func move_dir(host: EnemyHost, dir: Vector2, spd_m: float, delta: float) -> void:
	var push: Vector3 = sep(host)
	var wish: Vector2 = dir.normalized() * host.move_spd * spd_m
	wish += Vector2(push.x, push.z)
	if host.move_kind == "hop":
		host.hop_t -= delta
		if host.hop_t <= 0.0:
			host.hop_t = 0.42
			host.velocity = Vector3(wish.x, 0.0, wish.y) * 1.35
		else:
			host.velocity = host.velocity.move_toward(Vector3.ZERO, host.move_spd * 3.0 * delta)
	else:
		host.velocity = Vector3(wish.x, 0.0, wish.y)
