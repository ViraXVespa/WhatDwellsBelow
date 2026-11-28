extends RefCounted

## Stream chunk grid shared by the dungeon geo stream and the dungeon light ring. Graphics owns it so the light ring
## never loads dungeon code; geo_stream.gd re-exports these.

const RING_IN := 1
const RING_OUT := 2
const CHUNK := 32

static func chunk_origin(c: Vector2i) -> Vector2i:
	var x := c.x
	var y := c.y
	if x < 0:
		x -= CHUNK - 1
	if y < 0:
		y -= CHUNK - 1
	return Vector2i(int(x / float(CHUNK)) * CHUNK, int(y / float(CHUNK)) * CHUNK)
