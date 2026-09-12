extends Object

## Shared gather timing math. Gameplay + smokes must call these — do not hardcode intervals.


static func gather_spd_now() -> float:
	if App.prog == null:
		return 0.0
	return float(App.prog.gear_stat("gather_spd"))


static func interval_for(kind: String, gather_spd: float = -1.0) -> float:
	var spd: float = gather_spd
	if spd < 0.0:
		spd = gather_spd_now()
	var base: float = App.bal.wood_time if kind == "wood" else App.bal.mine_time
	return maxf(0.2, base / (1.0 + spd))
