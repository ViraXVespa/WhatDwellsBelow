extends Object

## Radiance texture sampled in world xz. White until the buffer job replaces tex.

static var tex: Texture2D
static var origin := Vector2.ZERO
static var span := Vector2.ONE


static func texture() -> Texture2D:
	if tex != null:
		return tex
	var img: Image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var made: ImageTexture = ImageTexture.create_from_image(img)
	tex = made
	return tex
