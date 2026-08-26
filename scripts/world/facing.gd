extends Object

## Eight game-centric facings. Aim octants, not movement.
const KEYS := [
	"right", "down_right", "down", "down_left",
	"left", "up_left", "up", "up_right",
]


static func from_aim(dir: Vector2) -> String:
	if dir.length_squared() < 0.0001:
		return "down"
	var oct := int(round(atan2(dir.y, dir.x) / (PI * 0.25)))
	match oct:
		0:
			return "right"
		1:
			return "down_right"
		2:
			return "down"
		3:
			return "down_left"
		4, -4:
			return "left"
		-3:
			return "up_left"
		-2:
			return "up"
		-1:
			return "up_right"
		_:
			return "down"
