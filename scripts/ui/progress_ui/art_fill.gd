extends Object

## Scanline polygon fill shared by the code-drawn frame art (anvil_art.gd, crystal_art.gd).
## Even-odd spans per row, half-open [x0, x1); pixels outside the image are skipped.

static func poly(img: Image, pts: Array, col: Color) -> void:
	var n: int = pts.size()
	var miny: int = pts[0].y
	var maxy: int = pts[0].y
	for p: Vector2i in pts:
		miny = mini(miny, p.y)
		maxy = maxi(maxy, p.y)
	var w: int = img.get_width()
	var h: int = img.get_height()
	for y: int in range(miny, maxy + 1):
		var xs: Array[int] = []
		for i: int in n:
			var a: Vector2i = pts[i]
			var b: Vector2i = pts[(i + 1) % n]
			if a.y > b.y:
				var swap: Vector2i = a
				a = b
				b = swap
			if a.y == b.y or y < a.y or y >= b.y:
				continue
			var t: float = float(y - a.y) / float(b.y - a.y)
			xs.append(int(round(float(a.x) + t * float(b.x - a.x))))
		xs.sort()
		var j: int = 0
		while j + 1 < xs.size():
			var x0: int = xs[j]
			var x1: int = xs[j + 1]
			if x0 > x1:
				var tmp: int = x0
				x0 = x1
				x1 = tmp
			if y >= 0 and y < h:
				for x: int in range(maxi(x0, 0), mini(x1, w)):
					img.set_pixel(x, y, col)
			j += 2
